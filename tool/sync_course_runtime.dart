import 'dart:convert';
import 'dart:io';

import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _expectedLessonPlanPackages = 88;
const _expectedLessonPlanInstructionHours = 172;
const _minimumLessonPlanRuntimePackageVersion = '1.3.0';
const _minimumLessonPlanSchemaVersion = '1.2.0';

Future<void> main(List<String> args) async {
  try {
    final courseId = _valueFor(args, '--course') ?? 'TDE_9';
    final descriptor = runtimeForCourse(courseId);
    if (descriptor.isCurriculumOnly) {
      throw StateError(
        '$courseId curriculum-only pakettir; tool/build_curriculum_only_runtime.py kullanın.',
      );
    }

    final requireLessonPlans = args.contains('--require-lesson-plans');
    final sourceCommit = _valueFor(args, '--source-commit');
    if (sourceCommit != null && !RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(sourceCommit)) {
      throw StateError('Geçersiz TYMM source commit SHA: $sourceCommit');
    }

    final sourceRoot =
        _valueFor(args, '--source-root') ??
        '/Users/kadir/Desktop/tymm/courses/$courseId/runtime';
    final targetRoot =
        _valueFor(args, '--target-root') ?? descriptor.runtimeRoot;

    final sourceManifest = File(p.join(sourceRoot, 'runtime_manifest.json'));
    final sourceDatabase = File(p.join(sourceRoot, 'course_runtime.sqlite'));
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
        'İstenen course_id ile runtime uyuşmuyor: $courseId/${manifestJson['course_id']}',
      );
    }
    final validationReport = sourceValidationReport.existsSync()
        ? await sourceValidationReport.readAsString()
        : null;
    validateRuntimeFreshnessEvidence(
      manifestJson,
      validationReport: validationReport,
    );

    if (requireLessonPlans) {
      _validateLessonPlanManifest(manifestJson, courseId);
    }
    await _validateRuntimeDatabase(
      sourceDatabase.path,
      manifestJson,
      requireLessonPlans: requireLessonPlans,
    );

    final targetDirectory = Directory(targetRoot);
    await targetDirectory.create(recursive: true);
    final targetDatabase = File(p.join(targetRoot, 'course_runtime.sqlite'));
    final targetManifest = File(p.join(targetRoot, 'runtime_manifest.json'));
    final targetValidationReport = File(
      p.join(targetRoot, 'runtime_validation_report.md'),
    );

    await _replaceFromSource(sourceDatabase, targetDatabase);
    await _replaceFromSource(sourceManifest, targetManifest);
    if (sourceValidationReport.existsSync()) {
      await _replaceFromSource(sourceValidationReport, targetValidationReport);
    } else if (targetValidationReport.existsSync()) {
      await targetValidationReport.delete();
    }

    if (!await _filesEqual(sourceDatabase, targetDatabase)) {
      throw StateError('Runtime SQLite hedef doğrulaması başarısız.');
    }
    if (!await _filesEqual(sourceManifest, targetManifest)) {
      throw StateError('Runtime manifest hedef doğrulaması başarısız.');
    }
    if (sourceValidationReport.existsSync() &&
        !await _filesEqual(sourceValidationReport, targetValidationReport)) {
      throw StateError('Runtime validation report hedef doğrulaması başarısız.');
    }

    await _validateRuntimeDatabase(
      targetDatabase.path,
      manifestJson,
      requireLessonPlans: requireLessonPlans,
    );
    await _updatePackageManifest(
      targetRoot: targetRoot,
      runtimeManifest: manifestJson,
      sourceCommit: sourceCommit,
      requireLessonPlans: requireLessonPlans,
    );

    stdout.writeln('RUNTIME_SYNC: PASS');
    stdout.writeln('COURSE_ID: $courseId');
    stdout.writeln('TARGET_ROOT: $targetRoot');
    if (sourceCommit != null) stdout.writeln('TYMM_SOURCE_COMMIT: $sourceCommit');
    stdout.writeln(
      'RUNTIME_PACKAGE_VERSION: ${manifestJson['runtime_package_version']}',
    );
    stdout.writeln('SCHEMA_VERSION: ${manifestJson['schema_version']}');
    stdout.writeln('VALIDATION_STATUS: ${manifestJson['validation_status']}');
    if (requireLessonPlans) {
      stdout.writeln(
        'LESSON_PLAN_PACKAGES: ${manifestJson['lesson_plan_package_count']}',
      );
      stdout.writeln(
        'LESSON_PLAN_HOURS: ${manifestJson['lesson_plan_instruction_hours']}',
      );
      stdout.writeln(
        'LESSON_PLAN_VALIDATION: ${(manifestJson['lesson_plan_validation'] as Map)['status']}',
      );
    }
  } catch (error, stackTrace) {
    stderr.writeln('RUNTIME_SYNC: FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

void _validateLessonPlanManifest(
  Map<String, dynamic> manifest,
  String courseId,
) {
  if (courseId != 'TDE_9' && courseId != 'TDE_10') {
    throw StateError('Lesson-plan-aware sync yalnız TDE_9/TDE_10 için tanımlı.');
  }
  final runtimeVersion = manifest['runtime_package_version']?.toString() ?? '';
  final schemaVersion = manifest['schema_version']?.toString() ?? '';
  if (!_versionAtLeast(runtimeVersion, _minimumLessonPlanRuntimePackageVersion)) {
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
  if (rowCounts is! Map ||
      _int(rowCounts['lesson_plan_packages']) != _expectedLessonPlanPackages) {
    throw StateError('Manifest lesson_plan_packages row count 88 olmalı.');
  }
  if (_int(manifest['lesson_plan_package_count']) != _expectedLessonPlanPackages) {
    throw StateError('Manifest lesson_plan_package_count 88 olmalı.');
  }
  if (_int(manifest['lesson_plan_instruction_hours']) !=
      _expectedLessonPlanInstructionHours) {
    throw StateError('Manifest lesson_plan_instruction_hours 172 olmalı.');
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
}) async {
  sqfliteFfiInit();
  final database = await databaseFactoryFfi.openDatabase(
    databasePath,
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
    if (course['schema_version']?.toString() != manifest['schema_version']?.toString()) {
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

    if (!requireLessonPlans) return;

    final tableRows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='lesson_plan_packages'",
    );
    if (tableRows.isEmpty) {
      throw StateError('Runtime SQLite lesson_plan_packages tablosu eksik.');
    }
    final totals = (await database.rawQuery('''
      SELECT COUNT(*) AS package_count,
             COALESCE(SUM(lesson_hours), 0) AS instruction_hours,
             SUM(CASE WHEN validation_status = 'PASS' THEN 0 ELSE 1 END) AS invalid_rows
      FROM lesson_plan_packages
    '''))
        .first;
    if (_int(totals['package_count']) != _expectedLessonPlanPackages) {
      throw StateError('Runtime SQLite lesson-plan package count 88 değil.');
    }
    if (_int(totals['instruction_hours']) != _expectedLessonPlanInstructionHours) {
      throw StateError('Runtime SQLite lesson-plan instruction hours 172 değil.');
    }
    if (_int(totals['invalid_rows']) != 0) {
      throw StateError('Runtime SQLite doğrulanmamış lesson-plan satırı içeriyor.');
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
        throw StateError('Lesson-plan payload JSON nesnesi değil: ${row['package_id']}');
      }
      if (decoded['course_id']?.toString() != row['course_id']?.toString() ||
          decoded['block_id']?.toString() != row['block_id']?.toString() ||
          _int(decoded['lesson_hours']) != _int(row['lesson_hours'])) {
        throw StateError('Lesson-plan payload/relational parity bozuk: ${row['package_id']}');
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

Future<void> _updatePackageManifest({
  required String targetRoot,
  required Map<String, dynamic> runtimeManifest,
  required String? sourceCommit,
  required bool requireLessonPlans,
}) async {
  final packageManifest = File(
    p.join(Directory(targetRoot).parent.path, 'package_manifest.json'),
  );
  if (!packageManifest.existsSync()) return;

  final decoded = jsonDecode(await packageManifest.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('package_manifest.json JSON nesnesi olmalı.');
  }
  if (decoded['course_id']?.toString() != runtimeManifest['course_id']?.toString()) {
    throw StateError('package_manifest course_id runtime ile uyuşmuyor.');
  }

  if (sourceCommit != null) {
    decoded['tymm_source_repository'] = 'knigdelioglu/tymm';
    decoded['tymm_source_commit'] = sourceCommit;
  }
  decoded['runtime_package_version'] = runtimeManifest['runtime_package_version'];
  decoded['runtime_schema_version'] = runtimeManifest['schema_version'];
  decoded['runtime_canonical_content_fingerprint'] =
      runtimeManifest['canonical_content_fingerprint'];
  decoded['runtime_validation_status'] = runtimeManifest['validation_status'];

  if (requireLessonPlans) {
    final validation = runtimeManifest['lesson_plan_validation'] as Map;
    decoded['lesson_plan_package_count'] = runtimeManifest['lesson_plan_package_count'];
    decoded['lesson_plan_instruction_hours'] =
        runtimeManifest['lesson_plan_instruction_hours'];
    decoded['lesson_plan_validation_status'] = validation['status'];
    decoded['lesson_plan_content_fingerprint'] = validation['content_fingerprint'];
    decoded['lesson_plan_validated_commit_sha'] = validation['validated_commit_sha'];
  }

  await _replaceText(
    packageManifest,
    '${const JsonEncoder.withIndent('  ').convert(decoded)}\n',
  );
}

String? _valueFor(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

Future<void> _replaceFromSource(File source, File destination) async {
  final temporary = File('${destination.path}.sync-tmp');
  if (temporary.existsSync()) await temporary.delete();
  await source.copy(temporary.path);
  if (!await _filesEqual(source, temporary)) {
    await temporary.delete();
    throw StateError('Staging dosyası kaynakla uyuşmuyor: ${destination.path}');
  }
  if (destination.existsSync()) await destination.delete();
  await temporary.rename(destination.path);
}

Future<void> _replaceText(File destination, String content) async {
  final temporary = File('${destination.path}.sync-tmp');
  if (temporary.existsSync()) await temporary.delete();
  await temporary.writeAsString(content, flush: true);
  if (destination.existsSync()) await destination.delete();
  await temporary.rename(destination.path);
}

Future<bool> _filesEqual(File source, File target) async {
  if (!source.existsSync() || !target.existsSync()) return false;
  if (await source.length() != await target.length()) return false;
  final sourceBytes = await source.readAsBytes();
  final targetBytes = await target.readAsBytes();
  for (var index = 0; index < sourceBytes.length; index++) {
    if (sourceBytes[index] != targetBytes[index]) return false;
  }
  return true;
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
    if (left > right) return true;
    if (left < right) return false;
  }
  return true;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
