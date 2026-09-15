import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:ogretmen_os/domain/models/teacher_guide_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _minimumLessonPlanRuntimePackageVersion = '1.3.0';
const _minimumLessonPlanSchemaVersion = '1.2.0';

class RuntimeSyncRequest {
  const RuntimeSyncRequest({
    required this.courseId,
    required this.sourceRoot,
    required this.targetRoot,
    this.sourceCommit,
    this.requireLessonPlans = false,
    this.requireTeacherGuide = false,
    this.catalogPath,
  });

  final String courseId;
  final String sourceRoot;
  final String targetRoot;
  final String? sourceCommit;
  final bool requireLessonPlans;
  final bool requireTeacherGuide;
  final String? catalogPath;
}

Future<void> main(List<String> args) async {
  try {
    final courseId = _valueFor(args, '--course') ?? 'TDE_9';
    final sourceCommit = _valueFor(args, '--source-commit');
    final sourceRoot =
        _valueFor(args, '--source-root') ??
        '/Users/kadir/Desktop/tymm/courses/$courseId/runtime';
    final descriptor = runtimeForCourse(courseId);
    final targetRoot =
        _valueFor(args, '--target-root') ?? descriptor.runtimeRoot;

    await syncRuntimePackage(
      RuntimeSyncRequest(
        courseId: courseId,
        sourceRoot: sourceRoot,
        targetRoot: targetRoot,
        sourceCommit: sourceCommit,
        requireLessonPlans: args.contains('--require-lesson-plans'),
        requireTeacherGuide: args.contains('--require-teacher-guide'),
        catalogPath: _valueFor(args, '--catalog'),
      ),
    );
  } catch (error, stackTrace) {
    stderr.writeln('RUNTIME_SYNC: FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

Future<void> syncRuntimePackage(
  RuntimeSyncRequest request, {
  FutureOr<void> Function(Directory stagingDirectory)? beforeStagingValidation,
  FutureOr<void> Function()? beforeBackupCleanup,
}) async {
  final courseId = request.courseId;
  final descriptor = runtimeForCourse(courseId);
  if (descriptor.isCurriculumOnly) {
    throw StateError(
      '$courseId curriculum-only pakettir; tool/build_curriculum_only_runtime.py kullanın.',
    );
  }
  final sourceCommit = request.sourceCommit;
  if (sourceCommit != null &&
      !RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(sourceCommit)) {
    throw StateError('Geçersiz TYMM source commit SHA: $sourceCommit');
  }

  final sourceRoot = Directory(request.sourceRoot).absolute.path;
  final targetRoot = Directory(request.targetRoot).absolute.path;
  final sourceManifest = File(p.join(sourceRoot, 'runtime_manifest.json'));
  final sourceDatabase = File(p.join(sourceRoot, 'course_runtime.sqlite'));
  final sourceSchema = File(p.join(sourceRoot, 'runtime_schema.sql'));
  final sourceValidationReport = File(
    p.join(sourceRoot, 'runtime_validation_report.md'),
  );
  if (!sourceManifest.existsSync()) {
    throw StateError('Runtime manifest bulunamadı: ${sourceManifest.path}');
  }
  if (!sourceDatabase.existsSync()) {
    throw StateError('Runtime SQLite bulunamadı: ${sourceDatabase.path}');
  }

  final manifestJson = jsonDecode(await sourceManifest.readAsString());
  if (manifestJson is! Map<String, dynamic>) {
    throw StateError('Runtime manifest JSON nesnesi olmalı.');
  }
  if (manifestJson['course_id'] != courseId) {
    throw StateError(
      'İstenen course_id ile runtime uyuşmuyor: '
      '$courseId/${manifestJson['course_id']}',
    );
  }
  final validationReport = sourceValidationReport.existsSync()
      ? await sourceValidationReport.readAsString()
      : null;
  validateRuntimeFreshnessEvidence(
    manifestJson,
    validationReport: validationReport,
  );
  if (request.requireLessonPlans) {
    _validateLessonPlanManifest(manifestJson, courseId);
  }
  _validateTeacherGuideManifest(
    manifestJson,
    required: request.requireTeacherGuide,
  );
  await _validateTeacherGuideSeal(sourceRoot, manifestJson);
  await _validateRuntimeDatabase(
    sourceDatabase.path,
    manifestJson,
    requireLessonPlans: request.requireLessonPlans,
    requireTeacherGuide: request.requireTeacherGuide,
  );

  final targetDirectory = Directory(targetRoot);
  final stagingDirectory = Directory('$targetRoot.staging');
  final backupDirectory = Directory('$targetRoot.backup');
  final packageManifest = File(
    p.join(targetDirectory.parent.path, 'package_manifest.json'),
  );
  final stagedPackageManifest = File('$targetRoot.package_manifest.staging');
  final packageManifestBackup = File('$targetRoot.package_manifest.backup');
  await _removeIfExists(stagingDirectory);
  await _removeIfExists(backupDirectory);
  await _removeIfExists(stagedPackageManifest);
  await _removeIfExists(packageManifestBackup);
  var committed = false;
  try {
    await stagingDirectory.create(recursive: true);
    await _copyToDirectory(sourceDatabase, stagingDirectory);
    await _copyToDirectory(sourceManifest, stagingDirectory);
    if (sourceSchema.existsSync()) {
      await _copyToDirectory(sourceSchema, stagingDirectory);
    }
    await _copyTeacherGuideSeal(
      sourceRuntimeRoot: sourceRoot,
      targetRuntimeRoot: stagingDirectory.path,
      manifest: manifestJson,
    );
    if (sourceValidationReport.existsSync()) {
      await _copyToDirectory(sourceValidationReport, stagingDirectory);
    }

    await _projectFormTemplates(
      courseId: courseId,
      sourceRuntimeRoot: sourceRoot,
      targetRoot: stagingDirectory.path,
      catalogPath: request.catalogPath,
    );
    final stagedManifest = File(
      p.join(stagingDirectory.path, 'runtime_manifest.json'),
    );
    final projectedManifestJson = jsonDecode(
      await stagedManifest.readAsString(),
    );
    if (projectedManifestJson is! Map<String, dynamic>) {
      throw StateError('Projected runtime manifest JSON nesnesi olmalı.');
    }
    await beforeStagingValidation?.call(stagingDirectory);
    final stagedReport = File(
      p.join(stagingDirectory.path, 'runtime_validation_report.md'),
    );
    validateRuntimeFreshnessEvidence(
      projectedManifestJson,
      validationReport: stagedReport.existsSync()
          ? await stagedReport.readAsString()
          : null,
    );
    await _validateTeacherGuideSeal(
      stagingDirectory.path,
      projectedManifestJson,
    );
    await _validateRuntimeDatabase(
      p.join(stagingDirectory.path, 'course_runtime.sqlite'),
      projectedManifestJson,
      requireLessonPlans: request.requireLessonPlans,
      requireTeacherGuide: request.requireTeacherGuide,
    );
    await _stagePackageManifest(
      source: packageManifest,
      destination: stagedPackageManifest,
      runtimeManifest: projectedManifestJson,
      sourceCommit: sourceCommit,
      requireLessonPlans: request.requireLessonPlans,
    );
    await _atomicSwap(
      staging: stagingDirectory,
      target: targetDirectory,
      backup: backupDirectory,
      stagedPackageManifest: stagedPackageManifest,
      packageManifest: packageManifest,
      packageManifestBackup: packageManifestBackup,
      beforeBackupCleanup: beforeBackupCleanup,
    );
    committed = true;

    stdout.writeln('RUNTIME_SYNC: PASS');
    stdout.writeln('COURSE_ID: $courseId');
    stdout.writeln('TARGET_ROOT: ${request.targetRoot}');
    if (sourceCommit != null) {
      stdout.writeln('TYMM_SOURCE_COMMIT: $sourceCommit');
    }
    stdout.writeln(
      'RUNTIME_PACKAGE_VERSION: ${manifestJson['runtime_package_version']}',
    );
    stdout.writeln('SCHEMA_VERSION: ${manifestJson['schema_version']}');
    stdout.writeln('VALIDATION_STATUS: ${manifestJson['validation_status']}');
    if (request.requireLessonPlans) {
      stdout.writeln(
        'LESSON_PLAN_PACKAGES: ${manifestJson['lesson_plan_package_count']}',
      );
      stdout.writeln(
        'LESSON_PLAN_HOURS: ${manifestJson['lesson_plan_instruction_hours']}',
      );
      stdout.writeln(
        'LESSON_PLAN_VALIDATION: '
        '${(manifestJson['lesson_plan_validation'] as Map)['status']}',
      );
    }
  } finally {
    if (!committed) {
      await _removeIfExists(stagingDirectory);
      await _removeIfExists(stagedPackageManifest);
      await _removeIfExists(backupDirectory);
      await _removeIfExists(packageManifestBackup);
    }
  }
}

Future<void> _projectFormTemplates({
  required String courseId,
  required String sourceRuntimeRoot,
  required String targetRoot,
  String? catalogPath,
}) async {
  final projectRoot = Directory.current.absolute.path;
  final script = p.join(projectRoot, 'tool', 'build_form_templates.py');
  final formsIndex = p.join(
    Directory(sourceRuntimeRoot).parent.path,
    'textbook_forms_index.json',
  );
  if (!File(script).existsSync()) {
    throw StateError('Form template projector bulunamadı: $script');
  }
  if (!File(formsIndex).existsSync()) {
    throw StateError('Canonical form index bulunamadı: $formsIndex');
  }
  final catalog =
      catalogPath ??
      p.join(projectRoot, 'tool', 'form_templates', '$courseId.json');
  final arguments = <String>[
    script,
    '--course-id',
    courseId,
    '--runtime-dir',
    targetRoot,
    '--forms-index',
    formsIndex,
    if (File(catalog).existsSync()) ...['--catalog', catalog],
  ];
  final result = await Process.run('python3', arguments);
  if (result.exitCode != 0) {
    throw StateError(
      'Form template projection başarısız:\n${result.stdout}\n${result.stderr}',
    );
  }
  stdout.write(result.stdout);
}

void _validateTeacherGuideManifest(
  Map<String, dynamic> manifest, {
  required bool required,
}) {
  final rawCapabilities = manifest['capabilities'];
  final advertised =
      rawCapabilities is Map && rawCapabilities['teacher_guide'] == true;
  if (required && !advertised) {
    throw StateError(
      'Teacher-guide sync istendi ancak runtime capabilities.teacher_guide true değil.',
    );
  }
  if (!advertised) return;

  final metadata = manifest['teacher_guide_capabilities'];
  if (metadata is! Map ||
      metadata['available'] != true ||
      metadata['validation_status'] != 'PASS' ||
      metadata['source_bound'] != true) {
    throw StateError('Teacher-guide manifest capability kanıtı geçersiz.');
  }
  final validation = manifest['teacher_guide_validation'];
  if (validation is! Map ||
      validation['status'] != 'PASS' ||
      validation['scope'] != 'COURSE' ||
      validation['source_bound'] != true ||
      (validation['content_fingerprint']?.toString().trim() ?? '').isEmpty) {
    throw StateError('Teacher-guide runtime validation kanıtı geçersiz.');
  }
  if (validation['canonical_content_fingerprint']?.toString() !=
      manifest['canonical_content_fingerprint']?.toString()) {
    throw StateError(
      'Teacher-guide validation canonical fingerprint runtime ile uyuşmuyor.',
    );
  }
  final counts = manifest['row_counts'];
  if (counts is! Map) {
    throw StateError('Teacher-guide runtime row_counts eksik.');
  }
  final metadataCounts = metadata['row_counts'];
  if (metadataCounts is! Map) {
    throw StateError('Teacher-guide capability row_counts eksik.');
  }
  for (final table in teacherGuideRuntimeTableNames) {
    final value = counts[table];
    if (value is! num || value < 0 || value != value.toInt()) {
      throw StateError('Teacher-guide row count geçersiz: $table');
    }
    if (_int(metadataCounts[table]) != value.toInt()) {
      throw StateError(
        'Teacher-guide capability row count runtime ile uyuşmuyor: $table',
      );
    }
  }
}

Future<void> _validateTeacherGuideSeal(
  String runtimeRoot,
  Map<String, dynamic> manifest,
) async {
  final capabilities = manifest['capabilities'];
  if (capabilities is! Map || capabilities['teacher_guide'] != true) return;
  final validation = manifest['teacher_guide_validation'];
  if (validation is! Map) {
    throw StateError('Teacher-guide validation seal kanıtı eksik.');
  }
  final declaredPath = validation['seal_path']?.toString().trim() ?? '';
  final declaredSha = validation['seal_sha256']?.toString().trim() ?? '';
  if (declaredPath.isEmpty || declaredSha.isEmpty) {
    throw StateError('Teacher-guide validation seal yolu/hash eksik.');
  }
  final sealFile = File(p.join(runtimeRoot, p.basename(declaredPath)));
  if (!sealFile.existsSync()) {
    throw StateError('Teacher-guide validation seal dosyası bulunamadı.');
  }
  final actualSha = sha256.convert(await sealFile.readAsBytes()).toString();
  if (actualSha != declaredSha) {
    throw StateError('Teacher-guide validation seal hash uyuşmuyor.');
  }
  final seal = jsonDecode(await sealFile.readAsString());
  if (seal is! Map ||
      seal['canonical_content_fingerprint']?.toString() !=
          manifest['canonical_content_fingerprint']?.toString()) {
    throw StateError('Teacher-guide validation seal fingerprint uyuşmuyor.');
  }
  final contentFingerprint =
      validation['content_fingerprint']?.toString().trim() ?? '';
  final expectedTeacherGuideFingerprint =
      contentFingerprint.startsWith('sha256:')
      ? contentFingerprint.substring('sha256:'.length)
      : contentFingerprint;
  if (seal['teacher_guide_content_fingerprint']?.toString() !=
      expectedTeacherGuideFingerprint) {
    throw StateError(
      'Teacher-guide validation seal content fingerprint uyuşmuyor.',
    );
  }
}

Future<void> _copyTeacherGuideSeal({
  required String sourceRuntimeRoot,
  required String targetRuntimeRoot,
  required Map<String, dynamic> manifest,
}) async {
  final capabilities = manifest['capabilities'];
  if (capabilities is! Map || capabilities['teacher_guide'] != true) return;
  final validation = manifest['teacher_guide_validation'];
  if (validation is! Map) return;
  final declaredPath = validation['seal_path']?.toString().trim() ?? '';
  if (declaredPath.isEmpty) return;
  final source = File(p.join(sourceRuntimeRoot, p.basename(declaredPath)));
  final target = File(p.join(targetRuntimeRoot, p.basename(declaredPath)));
  if (!source.existsSync()) return;
  await target.parent.create(recursive: true);
  await source.copy(target.path);
}

void _validateLessonPlanManifest(
  Map<String, dynamic> manifest,
  String courseId,
) {
  // Lesson-plan validation is capability based.  Course/grade-specific
  // package counts belong to the canonical manifest, not to this tool.
  final runtimeVersion = manifest['runtime_package_version']?.toString() ?? '';
  final schemaVersion = manifest['schema_version']?.toString() ?? '';
  if (!_versionAtLeast(
    runtimeVersion,
    _minimumLessonPlanRuntimePackageVersion,
  )) {
    throw StateError(
      'Lesson-plan runtime package sürümü yetersiz: $runtimeVersion < '
      '$_minimumLessonPlanRuntimePackageVersion',
    );
  }
  if (!_versionAtLeast(schemaVersion, _minimumLessonPlanSchemaVersion)) {
    throw StateError(
      'Lesson-plan schema sürümü yetersiz: $schemaVersion < '
      '$_minimumLessonPlanSchemaVersion',
    );
  }

  final rowCounts = manifest['row_counts'];
  final declaredPackageCount = _int(
    rowCounts is Map ? rowCounts['lesson_plan_packages'] : null,
  );
  if (rowCounts is! Map || declaredPackageCount <= 0) {
    throw StateError('Manifest lesson_plan_packages row count geçersiz.');
  }
  if (_int(manifest['lesson_plan_package_count']) != declaredPackageCount) {
    throw StateError(
      'Manifest lesson_plan_package_count row_counts ile uyuşmuyor.',
    );
  }
  if (_int(manifest['lesson_plan_instruction_hours']) < 0) {
    throw StateError('Manifest lesson_plan_instruction_hours geçersiz.');
  }

  final capabilities = manifest['lesson_plan_capabilities'];
  if (capabilities is! Map) {
    throw StateError('lesson_plan_capabilities eksik.');
  }
  const requiredCapabilities = <String>{
    'available',
    'package_payload_json',
    'block_package_navigation',
    'source_hash_per_package',
    'source_payload_parity',
    'validation_bound',
    'calendar_neutral',
  };
  for (final capability in requiredCapabilities) {
    if (capabilities[capability] != true) {
      throw StateError('Lesson-plan capability aktif değil: $capability');
    }
  }

  final validation = manifest['lesson_plan_validation'];
  if (validation is! Map) {
    throw StateError('lesson_plan_validation eksik.');
  }
  if (validation['status'] != 'VERIFIED' || validation['scope'] != 'COURSE') {
    throw StateError(
      'Lesson-plan validation doğrulanmamış: '
      '${validation['status']}/${validation['scope']}',
    );
  }
  for (final key in <String>[
    'content_fingerprint',
    'validated_commit_sha',
    'seal_path',
  ]) {
    if ((validation[key]?.toString().trim() ?? '').isEmpty) {
      throw StateError('lesson_plan_validation.$key eksik.');
    }
  }
  final validatedCommit = validation['validated_commit_sha']?.toString() ?? '';
  if (!RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(validatedCommit)) {
    throw StateError('lesson_plan_validation.validated_commit_sha geçersiz.');
  }
}

Future<void> _validateRuntimeDatabase(
  String databasePath,
  Map<String, dynamic> manifest, {
  required bool requireLessonPlans,
  required bool requireTeacherGuide,
}) async {
  sqfliteFfiInit();
  final resolvedDatabasePath = File(databasePath).absolute.path;
  final database = await databaseFactoryFfi.openDatabase(
    resolvedDatabasePath,
    options: OpenDatabaseOptions(readOnly: true),
  );
  try {
    final courseRows = await database.rawQuery('''
      SELECT course_id, schema_version, source_manifest_fingerprint
      FROM courses
      LIMIT 1
    ''');
    if (courseRows.isEmpty) {
      throw StateError('Runtime SQLite courses satırı eksik.');
    }
    final course = courseRows.first;
    if (course['course_id']?.toString() != manifest['course_id']?.toString()) {
      throw StateError('Runtime SQLite course_id manifest ile uyuşmuyor.');
    }
    if (course['schema_version']?.toString() !=
        manifest['schema_version']?.toString()) {
      throw StateError('Runtime SQLite schema_version manifest ile uyuşmuyor.');
    }
    if (course['source_manifest_fingerprint']?.toString() !=
        manifest['canonical_content_fingerprint']?.toString()) {
      throw StateError('Runtime SQLite fingerprint manifest ile uyuşmuyor.');
    }

    final foreignKeyRows = await database.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeyRows.isNotEmpty) {
      throw StateError('Runtime SQLite foreign_key_check başarısız.');
    }

    await _validateTeacherGuideDatabase(
      database,
      manifest,
      required: requireTeacherGuide,
    );

    if (!requireLessonPlans) {
      return;
    }

    final tableRows = await database.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name='lesson_plan_packages'",
    );
    if (tableRows.isEmpty) {
      throw StateError('Runtime SQLite lesson_plan_packages tablosu eksik.');
    }
    final totals = (await database.rawQuery('''
      SELECT COUNT(*) AS package_count,
             COALESCE(SUM(lesson_hours), 0) AS instruction_hours,
             SUM(CASE WHEN validation_status = 'PASS' THEN 0 ELSE 1 END) AS invalid_rows
      FROM lesson_plan_packages
    ''')).first;
    final expectedPackageCount = _int(manifest['lesson_plan_package_count']);
    final expectedInstructionHours = _int(
      manifest['lesson_plan_instruction_hours'],
    );
    if (_int(totals['package_count']) != expectedPackageCount) {
      throw StateError(
        'Runtime SQLite lesson-plan package count manifest ile uyuşmuyor.',
      );
    }
    if (_int(totals['instruction_hours']) != expectedInstructionHours) {
      throw StateError(
        'Runtime SQLite lesson-plan instruction hours manifest ile uyuşmuyor.',
      );
    }
    if (_int(totals['invalid_rows']) != 0) {
      throw StateError(
        'Runtime SQLite doğrulanmamış lesson-plan satırı içeriyor.',
      );
    }

    final payloadRows = await database.rawQuery('''
      SELECT package_id, course_id, block_id, lesson_hours, payload_json,
             payload_sha256, source_path
      FROM lesson_plan_packages
      ORDER BY package_id
    ''');
    for (final row in payloadRows) {
      final rawPayload = row['payload_json']?.toString() ?? '';
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        throw StateError(
          'Lesson-plan payload JSON nesnesi değil: ${row['package_id']}',
        );
      }
      if (decoded['course_id']?.toString() != row['course_id']?.toString() ||
          decoded['block_id']?.toString() != row['block_id']?.toString() ||
          _int(decoded['lesson_hours']) != _int(row['lesson_hours'])) {
        throw StateError(
          'Lesson-plan payload/relational parity bozuk: ${row['package_id']}',
        );
      }
      if ((row['payload_sha256']?.toString().trim() ?? '').isEmpty ||
          (row['source_path']?.toString().trim() ?? '').isEmpty) {
        throw StateError('Lesson-plan provenance eksik: ${row['package_id']}');
      }
    }
  } finally {
    await database.close();
  }
}

Future<void> _validateTeacherGuideDatabase(
  Database database,
  Map<String, dynamic> manifest, {
  required bool required,
}) async {
  final rawCapabilities = manifest['capabilities'];
  final advertised =
      rawCapabilities is Map && rawCapabilities['teacher_guide'] == true;
  final tablePresence = <String, bool>{};
  for (final table in teacherGuideRuntimeTableNames) {
    final rows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    tablePresence[table] = rows.isNotEmpty;
  }

  if (!advertised) {
    final coreRows = <String, int>{};
    for (final table in teacherGuideCoreRuntimeTableNames) {
      if (tablePresence[table] == true) {
        coreRows[table] = _int(
          (await database.rawQuery(
            'SELECT COUNT(*) AS count FROM $table',
          )).first['count'],
        );
      }
    }
    if (coreRows.values.any((count) => count > 0)) {
      throw StateError(
        'Teacher-guide tabloları capability false iken veri içeriyor.',
      );
    }
    final metadata = manifest['teacher_guide_capabilities'];
    if (metadata is Map &&
        (metadata['available'] != false ||
            metadata['source_bound'] != false ||
            metadata['validation_status'] != 'NOT_PRESENT')) {
      throw StateError('Teacher-guide capability false metadata geçersiz.');
    }
    if (required) {
      throw StateError('Teacher-guide capability runtime manifestte yok.');
    }
    return;
  }

  final missingTables = teacherGuideRuntimeTableNames
      .where((table) => tablePresence[table] != true)
      .toList(growable: false);
  if (missingTables.isNotEmpty) {
    throw StateError(
      'Teacher-guide capability tabloları eksik: ${missingTables.join(', ')}',
    );
  }

  final counts = manifest['row_counts'];
  if (counts is! Map) throw StateError('Teacher-guide row_counts eksik.');
  for (final table in teacherGuideRuntimeTableNames) {
    final actual = _int(
      (await database.rawQuery(
        'SELECT COUNT(*) AS count FROM $table',
      )).first['count'],
    );
    if (_int(counts[table]) != actual) {
      throw StateError(
        'Teacher-guide $table satır sayısı manifest ile uyuşmuyor: '
        '${_int(counts[table])}/$actual',
      );
    }
  }

  if (_int(counts['teacher_guides']) == 0 ||
      _int(counts['teacher_guide_sections']) == 0 ||
      _int(counts['teacher_guide_units']) == 0 ||
      _int(counts['teacher_guide_items']) == 0) {
    throw StateError('Teacher-guide capability boş içerik taşıyor.');
  }

  final orphanRows = await database.rawQuery('''
    SELECT r.item_id, r.target_type, r.target_id
    FROM teacher_guide_item_relations r
    LEFT JOIN teacher_guide_items i ON i.item_id = r.item_id
    LEFT JOIN canonical_entities e
      ON e.entity_type = r.target_type AND e.entity_id = r.target_id
    WHERE i.item_id IS NULL OR e.entity_id IS NULL
    LIMIT 1
  ''');
  if (orphanRows.isNotEmpty) {
    throw StateError(
      'Teacher-guide relation canonical entity bütünlüğü bozuk.',
    );
  }

  final scopeOrphans = await database.rawQuery('''
    SELECT g.guide_id
    FROM teacher_guides g
    LEFT JOIN canonical_entities e
      ON e.entity_type = g.scope_type AND e.entity_id = g.scope_id
    WHERE e.entity_id IS NULL
    LIMIT 1
  ''');
  if (scopeOrphans.isNotEmpty) {
    throw StateError('Teacher-guide scope canonical entity bütünlüğü bozuk.');
  }

  final relationRows = await database.rawQuery('''
    SELECT item_id, target_type, target_id, relation_type, relation_order
    FROM teacher_guide_item_relations
    ORDER BY item_id, relation_order, target_type, target_id, relation_type
  ''');
  for (final row in relationRows) {
    for (final field in const [
      'item_id',
      'target_type',
      'target_id',
      'relation_type',
    ]) {
      if (row[field]?.toString().trim().isEmpty ?? true) {
        throw StateError('Teacher-guide relation $field eksik.');
      }
    }
    final order = row['relation_order'];
    if (order is! num || order <= 0 || order != order.toInt()) {
      throw StateError('Teacher-guide relation sırası geçersiz.');
    }
  }

  final itemRows = await database.rawQuery('''
    SELECT item_id, unit_id, item_order, title, label, item_type,
           content_status, expected_response_json, acceptance_criteria_json,
           teacher_guidance_json, common_misconceptions_json,
           assessment_evidence_json, differentiation_json, provenance_json,
           canonical_payload_sha256
    FROM teacher_guide_items
    ORDER BY unit_id, item_order, item_id
  ''');
  for (final row in itemRows) {
    for (final field in const [
      'item_id',
      'unit_id',
      'label',
      'item_type',
      'content_status',
    ]) {
      if (row[field]?.toString().trim().isEmpty ?? true) {
        throw StateError('Teacher-guide item $field eksik.');
      }
    }
    if ((row['title']?.toString().trim().isNotEmpty ?? false) == false &&
        (row['label']?.toString().trim().isNotEmpty ?? false) == false) {
      throw StateError('Teacher-guide item title/label eksik.');
    }
    for (final field in const [
      'expected_response_json',
      'acceptance_criteria_json',
      'teacher_guidance_json',
      'common_misconceptions_json',
      'assessment_evidence_json',
      'differentiation_json',
      'provenance_json',
    ]) {
      _decodeTeacherGuideJson(row[field]?.toString() ?? '', field);
    }
    final differentiation = _decodeTeacherGuideJson(
      row['differentiation_json']?.toString() ?? '',
      'differentiation_json',
    );
    if (differentiation is! Map ||
        !differentiation.containsKey('support') ||
        !differentiation.containsKey('enrichment')) {
      throw StateError('Teacher-guide differentiation alanları eksik.');
    }
    final provenance = _decodeTeacherGuideJson(
      row['provenance_json']?.toString() ?? '',
      'provenance_json',
    );
    if (provenance is! Map || provenance.isEmpty) {
      throw StateError('Teacher-guide provenance boş.');
    }
    final payloadHash =
        row['canonical_payload_sha256']?.toString().trim() ?? '';
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(payloadHash)) {
      throw StateError('Teacher-guide canonical payload hash geçersiz.');
    }
  }
}

Object? _decodeTeacherGuideJson(String raw, String field) {
  if (raw.trim().isEmpty) throw StateError('Teacher-guide $field boş.');
  try {
    return jsonDecode(raw);
  } on FormatException catch (error) {
    throw StateError('Teacher-guide $field geçersiz JSON: $error');
  }
}

Future<void> _stagePackageManifest({
  required File source,
  required File destination,
  required Map<String, dynamic> runtimeManifest,
  required String? sourceCommit,
  required bool requireLessonPlans,
}) async {
  if (!source.existsSync()) return;
  final decoded = jsonDecode(await source.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('package_manifest.json JSON nesnesi olmalı.');
  }
  if (decoded['course_id']?.toString() !=
      runtimeManifest['course_id']?.toString()) {
    throw StateError('package_manifest course_id runtime ile uyuşmuyor.');
  }

  if (sourceCommit != null) {
    decoded['tymm_source_repository'] = 'knigdelioglu/tymm';
    decoded['tymm_source_commit'] = sourceCommit;
  }
  decoded['runtime_package_version'] =
      runtimeManifest['runtime_package_version'];
  decoded['runtime_schema_version'] = runtimeManifest['schema_version'];
  decoded['runtime_canonical_content_fingerprint'] =
      runtimeManifest['canonical_content_fingerprint'];
  decoded['runtime_validation_status'] = runtimeManifest['validation_status'];

  final lessonPlanCapabilities = runtimeManifest['lesson_plan_capabilities'];
  final lessonPlanValidation = runtimeManifest['lesson_plan_validation'];
  final lessonPlanAvailable =
      lessonPlanCapabilities is Map &&
      lessonPlanCapabilities['available'] == true &&
      lessonPlanValidation is Map;
  if (lessonPlanAvailable || requireLessonPlans) {
    if (lessonPlanValidation is! Map) {
      throw StateError('lesson_plan_validation eksik.');
    }
    final validation = lessonPlanValidation;
    decoded['lesson_plan_package_count'] =
        runtimeManifest['lesson_plan_package_count'];
    decoded['lesson_plan_instruction_hours'] =
        runtimeManifest['lesson_plan_instruction_hours'];
    decoded['lesson_plan_validation_status'] = validation['status'];
    decoded['lesson_plan_content_fingerprint'] =
        validation['content_fingerprint'];
    decoded['lesson_plan_validated_commit_sha'] =
        validation['validated_commit_sha'];
    decoded['lesson_plan_source_payload_parity'] =
        lessonPlanCapabilities is Map &&
        lessonPlanCapabilities['source_payload_parity'] == true;
  }
  if (runtimeManifest['form_template_status_counts'] is Map) {
    decoded['form_template_status_counts'] =
        runtimeManifest['form_template_status_counts'];
    decoded['form_template_review_reasons'] =
        runtimeManifest['form_template_review_reasons'] ?? <String, dynamic>{};
  }
  final runtimeCapabilities = runtimeManifest['capabilities'];
  if (runtimeCapabilities is Map &&
      runtimeCapabilities.containsKey('teacher_guide')) {
    decoded['runtime_capabilities'] = runtimeCapabilities;
    decoded['teacher_guide_capabilities'] =
        runtimeManifest['teacher_guide_capabilities'];
    if (runtimeManifest['teacher_guide_validation'] is Map) {
      decoded['teacher_guide_validation'] =
          runtimeManifest['teacher_guide_validation'];
    }
    final rowCounts = runtimeManifest['row_counts'];
    if (rowCounts is Map) {
      decoded['teacher_guide_row_counts'] = <String, dynamic>{
        for (final table in teacherGuideRuntimeTableNames)
          if (rowCounts.containsKey(table)) table: rowCounts[table],
      };
    }
  }

  await destination.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(decoded)}\n',
    flush: true,
  );
}

String? _valueFor(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

Future<void> _copyToDirectory(File source, Directory destination) async {
  await source.copy(p.join(destination.path, p.basename(source.path)));
}

Future<void> _removeIfExists(FileSystemEntity entity) async {
  if (!await entity.exists()) return;
  if (entity is Directory) {
    await entity.delete(recursive: true);
  } else {
    await entity.delete();
  }
}

Future<void> _atomicSwap({
  required Directory staging,
  required Directory target,
  required Directory backup,
  required File stagedPackageManifest,
  required File packageManifest,
  required File packageManifestBackup,
  FutureOr<void> Function()? beforeBackupCleanup,
}) async {
  var targetMoved = false;
  var packageMoved = false;
  var stagingMoved = false;
  var stagedPackageMoved = false;

  // Everything inside this block is pre-commit. Any failure must restore the
  // previous generation before the error escapes.
  try {
    if (await target.exists()) {
      await target.rename(backup.path);
      targetMoved = true;
    }
    if (await packageManifest.exists()) {
      await packageManifest.rename(packageManifestBackup.path);
      packageMoved = true;
    }
    await staging.rename(target.path);
    stagingMoved = true;
    if (await stagedPackageManifest.exists()) {
      await stagedPackageManifest.rename(packageManifest.path);
      stagedPackageMoved = true;
    }
  } catch (_) {
    if (stagedPackageMoved) {
      await _removeIfExists(packageManifest);
    }
    if (packageMoved && await packageManifestBackup.exists()) {
      await packageManifestBackup.rename(packageManifest.path);
    }
    if (stagingMoved) {
      await _removeIfExists(target);
    }
    if (targetMoved && await backup.exists()) {
      await backup.rename(target.path);
    }
    rethrow;
  }

  // Commit point: target runtime + package manifest are now the new generation.
  // Backup cleanup is deliberately best-effort. A cleanup failure must never
  // roll back or delete the already-valid committed target.
  await _bestEffortCleanup(
    'post-commit cleanup hook',
    () async => beforeBackupCleanup?.call(),
  );
  await _bestEffortCleanup('runtime backup', () => _removeIfExists(backup));
  await _bestEffortCleanup(
    'package manifest backup',
    () => _removeIfExists(packageManifestBackup),
  );
}

Future<void> _bestEffortCleanup(
  String label,
  FutureOr<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    stderr.writeln('RUNTIME_SYNC_CLEANUP_WARNING [$label]: $error');
  }
}

bool _versionAtLeast(String actual, String minimum) {
  final actualParts = actual.split('.').map(int.tryParse).toList();
  final minimumParts = minimum.split('.').map(int.tryParse).toList();
  if (actualParts.any((part) => part == null) ||
      minimumParts.any((part) => part == null)) {
    return false;
  }
  final length = actualParts.length > minimumParts.length
      ? actualParts.length
      : minimumParts.length;
  for (var index = 0; index < length; index++) {
    final left = index < actualParts.length ? actualParts[index]! : 0;
    final right = index < minimumParts.length ? minimumParts[index]! : 0;
    if (left > right) {
      return true;
    }
    if (left < right) {
      return false;
    }
  }
  return true;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
