import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  final courseId = _valueFor(args, '--course') ?? 'TDE_9';
  final subjectId = _valueFor(args, '--subject') ?? 'turk-dili-ve-edebiyati';
  final projectRoot = File.fromUri(Platform.script).parent.parent.parent.parent;
  final packageRoot = _valueFor(args, '--package-root');
  final packageDirectory = packageRoot == null
      ? p.join(projectRoot.path, 'tymm-verileri', subjectId, courseId)
      : Directory(packageRoot).absolute.path;
  final packageManifestFile = File(
    p.join(packageDirectory, 'package_manifest.json'),
  );
  final runtimeDirectory = p.join(packageDirectory, 'runtime');
  final manifestFile = File(p.join(runtimeDirectory, 'runtime_manifest.json'));
  final databaseFile = File(p.join(runtimeDirectory, 'course_runtime.sqlite'));
  final validationReportFile = File(
    p.join(runtimeDirectory, 'runtime_validation_report.md'),
  );

  _check(packageManifestFile.existsSync(), 'package manifest bulunamadı');
  _check(manifestFile.existsSync(), 'runtime manifest bulunamadı');
  _check(databaseFile.existsSync(), 'runtime SQLite bulunamadı');

  final packageManifest = _decodeMap(await packageManifestFile.readAsString());
  final dataMode = packageManifest['data_mode']?.toString() ?? '';
  _check(
    dataMode == 'FULL_RUNTIME' || dataMode == 'CURRICULUM_ONLY',
    'bilinmeyen data_mode: $dataMode',
  );
  _check(
    packageManifest['course_id'] == courseId,
    'package course_id uyuşmuyor',
  );

  final manifestMap = _decodeMap(await manifestFile.readAsString());
  _check(manifestMap['course_id'] == courseId, 'course_id $courseId değil');
  _check(
    (manifestMap['schema_version']?.toString() ?? '').startsWith('1.'),
    'schema sürümü 1.x değil',
  );
  _check(
    manifestMap['validation_status'] == 'PASS',
    'validation_status PASS değil',
  );
  _checkFreshnessEvidence(
    manifestMap,
    validationReportFile.existsSync()
        ? await validationReportFile.readAsString()
        : null,
  );
  _check(
    (manifestMap['canonical_content_fingerprint']?.toString().trim() ?? '')
        .isNotEmpty,
    'canonical_content_fingerprint eksik',
  );
  _check(
    manifestMap['runtime_database_path'] == 'runtime/course_runtime.sqlite',
    'runtime_database_path beklenen değer değil',
  );
  final rawCounts = manifestMap['row_counts'];
  _check(rawCounts is Map, 'runtime manifest row_counts eksik');
  final counts = rawCounts as Map;

  final database = sqlite3.open(
    databaseFile.absolute.path,
    mode: OpenMode.readOnly,
  );
  try {
    final course = database.select('''
      SELECT course_id, schema_version, source_manifest_fingerprint
      FROM courses
      LIMIT 1
    ''').single;
    _checkValue(course['course_id'], courseId, 'course kimliği');
    _checkSchemaCompatibility(
      course['schema_version'],
      manifestMap['schema_version'],
    );
    _checkValue(
      course['source_manifest_fingerprint'],
      manifestMap['canonical_content_fingerprint'],
      'canonical fingerprint',
    );

    for (final entry in counts.entries) {
      final table = entry.key.toString();
      final expected = (entry.value as num).toInt();
      final actual = _count(database, table);
      _checkValue(actual, expected, '$table satır sayısı');
    }

    final sequence = database.select('''
      SELECT tb.block_id, tb.theme_id, tb.block_order, t.theme_order
      FROM timeline_blocks tb
      INNER JOIN themes t ON t.theme_id = tb.theme_id
      INNER JOIN blocks b ON b.block_id = tb.block_id
      ORDER BY t.theme_order, tb.block_order
    ''');
    _checkValue(
      sequence.length,
      (counts['timeline_blocks'] as num).toInt(),
      'timeline sırası',
    );
    _verifySequence(sequence);

    if (dataMode == 'CURRICULUM_ONLY') {
      _verifyCurriculumOnly(database, counts, packageManifest, manifestMap);
    } else {
      final policy = _loadFormTemplatePolicy(projectRoot.path);
      _verifyFullRuntime(database, manifestMap, policy);
    }
    _verifyTeacherGuide(database, manifestMap, runtimeDirectory);
  } finally {
    database.close();
  }

  stdout.writeln('RUNTIME_VERIFIER: PASS');
  stdout.writeln('COURSE_ID: $courseId');
  stdout.writeln('DATA_MODE: $dataMode');
}

void _verifyCurriculumOnly(
  Database database,
  Map counts,
  Map<String, dynamic> packageManifest,
  Map<String, dynamic> manifest,
) {
  _check(
    packageManifest['textbook_status'] == 'AWAITING_OFFICIAL_TEXTBOOK',
    'curriculum-only pakette textbook_status yanlış',
  );
  _check(
    manifest['data_mode'] == 'CURRICULUM_ONLY',
    'runtime manifest curriculum-only değil',
  );
  for (final table in const [
    'themes',
    'blocks',
    'outcomes',
    'block_outcomes',
    'timeline_themes',
    'timeline_blocks',
  ]) {
    final expected = counts[table];
    if (expected is num) {
      _checkValue(
        _count(database, table),
        expected.toInt(),
        'curriculum-only $table satır sayısı',
      );
    }
  }
  _check(
    _count(database, 'entity_source_references') > 0,
    'curriculum-only tema kaynak bağları eksik',
  );
  for (final table in [
    'textbook_sections',
    'activities',
    'block_activities',
    'forms',
    'activity_forms',
    'resource_decisions',
    'assessment_artifacts',
    'assessment_gap_mappings',
    'assessment_task_bindings',
  ]) {
    _checkValue(
      _count(database, table),
      0,
      '$table curriculum-only pakette boş olmalı',
    );
  }

  final blocksWithoutOutcome = database.select('''
    SELECT b.block_id
    FROM blocks b
    LEFT JOIN block_outcomes bo ON bo.block_id = b.block_id
    GROUP BY b.block_id
    HAVING COUNT(bo.outcome_id) = 0
  ''');
  _check(blocksWithoutOutcome.isEmpty, 'kazanımsız curriculum-only blok var');

  _check(
    database
        .select(
          "SELECT block_id FROM blocks WHERE skill_domain IS NULL OR "
          "length(trim(skill_domain)) = 0 LIMIT 1",
        )
        .isEmpty,
    'planlama bloklarında skill domain eksik',
  );

  final declaredCounts = <String, int>{
    for (final entry in counts.entries)
      entry.key.toString(): (entry.value as num).toInt(),
  };
  _check(
    declaredCounts['themes'] == _count(database, 'themes') &&
        declaredCounts['outcomes'] == _count(database, 'outcomes'),
    'manifest temel row count değerleri runtime ile uyuşmuyor',
  );
  final capabilities = manifest['capabilities'];
  _check(
    capabilities is Map &&
        capabilities['form_templates'] == false &&
        capabilities['teacher_guide'] == false,
    'curriculum-only form_templates/teacher_guide capability false olmalı',
  );
  if (_tableExists(database, 'form_templates')) {
    _checkValue(
      _count(database, 'form_templates'),
      0,
      'curriculum-only form_templates boş olmalı',
    );
  }
}

const _teacherGuideTables = <String>[
  'canonical_entities',
  'teacher_guides',
  'teacher_guide_sections',
  'teacher_guide_units',
  'teacher_guide_items',
  'teacher_guide_item_relations',
];
const _teacherGuideCoreTables = <String>[
  'teacher_guides',
  'teacher_guide_sections',
  'teacher_guide_units',
  'teacher_guide_items',
  'teacher_guide_item_relations',
];

void _verifyTeacherGuide(
  Database database,
  Map<String, dynamic> manifest,
  String runtimeDirectory,
) {
  final capabilities = manifest['capabilities'];
  final advertised =
      capabilities is Map && capabilities['teacher_guide'] == true;
  final tables = <String, bool>{
    for (final table in _teacherGuideTables)
      table: _tableExists(database, table),
  };

  if (!advertised) {
    for (final table in _teacherGuideCoreTables) {
      if (tables[table] == true) {
        _checkValue(
          _count(database, table),
          0,
          '$table capability false iken boş olmalı',
        );
      }
    }
    final metadata = manifest['teacher_guide_capabilities'];
    if (metadata is Map) {
      _check(
        metadata['available'] == false &&
            metadata['source_bound'] == false &&
            metadata['validation_status'] == 'NOT_PRESENT',
        'teacher_guide capability false metadata geçersiz',
      );
    }
    final validation = manifest['teacher_guide_validation'];
    if (validation is Map) {
      _check(
        validation['status'] == 'NOT_PRESENT' &&
            validation['source_bound'] == false,
        'teacher_guide_validation false kanıtı geçersiz',
      );
    }
    return;
  }

  _check(capabilities is Map, 'teacher_guide capabilities eksik');
  final metadata = manifest['teacher_guide_capabilities'];
  _check(metadata is Map, 'teacher_guide_capabilities eksik');
  _check(
    metadata['available'] == true &&
        metadata['validation_status'] == 'PASS' &&
        metadata['source_bound'] == true &&
        (metadata['schema_version']?.toString().trim() ?? '').isNotEmpty,
    'teacher_guide capability metadata geçersiz',
  );
  final validation = manifest['teacher_guide_validation'];
  _check(validation is Map, 'teacher_guide_validation eksik');
  _check(
    validation['status'] == 'PASS' &&
        validation['scope'] == 'COURSE' &&
        validation['source_bound'] == true &&
        (validation['content_fingerprint']?.toString().trim() ?? '')
            .isNotEmpty &&
        validation['canonical_content_fingerprint'] ==
            manifest['canonical_content_fingerprint'],
    'teacher_guide_validation geçersiz',
  );

  final sealPath = validation['seal_path']?.toString().trim() ?? '';
  final sealSha = validation['seal_sha256']?.toString().trim() ?? '';
  _check(
    sealPath.isNotEmpty && sealSha.isNotEmpty,
    'teacher_guide seal kanıtı eksik',
  );
  final sealFile = File(p.join(runtimeDirectory, p.basename(sealPath)));
  _check(sealFile.existsSync(), 'teacher_guide validation seal dosyası eksik');
  _checkValue(
    sha256.convert(sealFile.readAsBytesSync()).toString(),
    sealSha,
    'teacher_guide seal sha256',
  );
  final seal = _decodeMap(sealFile.readAsStringSync());
  _checkValue(
    seal['canonical_content_fingerprint'],
    manifest['canonical_content_fingerprint'],
    'teacher_guide seal canonical fingerprint',
  );
  final validationContentFingerprint =
      validation['content_fingerprint']?.toString().trim() ?? '';
  final expectedTeacherGuideFingerprint =
      validationContentFingerprint.startsWith('sha256:')
      ? validationContentFingerprint.substring('sha256:'.length)
      : validationContentFingerprint;
  _checkValue(
    seal['teacher_guide_content_fingerprint'],
    expectedTeacherGuideFingerprint,
    'teacher_guide seal content fingerprint',
  );

  for (final table in _teacherGuideTables) {
    _check(tables[table] == true, '$table tablosu eksik');
  }
  final rawCounts = manifest['row_counts'];
  _check(rawCounts is Map, 'teacher_guide row_counts eksik');
  for (final table in _teacherGuideTables) {
    final expected = rawCounts[table];
    _check(
      expected is num && expected >= 0 && expected == expected.toInt(),
      '$table row count geçersiz',
    );
    _checkValue(
      _count(database, table),
      expected.toInt(),
      '$table satır sayısı',
    );
  }
  _check(_count(database, 'teacher_guides') > 0, 'teacher_guides boş');
  _check(
    _count(database, 'teacher_guide_sections') > 0,
    'teacher_guide_sections boş',
  );
  _check(
    _count(database, 'teacher_guide_units') > 0,
    'teacher_guide_units boş',
  );
  _check(
    _count(database, 'teacher_guide_items') > 0,
    'teacher_guide_items boş',
  );

  _check(
    database.select('PRAGMA foreign_key_check').isEmpty,
    'teacher_guide foreign key bütünlüğü bozuk',
  );
  _check(
    database.select('''
          SELECT g.guide_id
          FROM teacher_guides g
          LEFT JOIN canonical_entities e
            ON e.entity_type = g.scope_type AND e.entity_id = g.scope_id
          WHERE e.entity_id IS NULL
          LIMIT 1
        ''').isEmpty,
    'teacher_guide scope canonical entity bulunamadı',
  );
  _check(
    database.select('''
          SELECT r.item_id
          FROM teacher_guide_item_relations r
          LEFT JOIN teacher_guide_items i ON i.item_id = r.item_id
          LEFT JOIN canonical_entities e
            ON e.entity_type = r.target_type AND e.entity_id = r.target_id
          WHERE i.item_id IS NULL OR e.entity_id IS NULL
          LIMIT 1
        ''').isEmpty,
    'teacher_guide relation canonical entity bulunamadı',
  );

  _verifyTeacherGuideRelations(database);
  _verifyTeacherGuideSequence(database);
  _verifyTeacherGuideItems(database);
  _verifyTeacherGuidePedagogyOverlay(database, manifest);
}

const _v22ArchitectureVersion = '2.2.0';
const _v22ProjectionVersion = '1.2.0+pedagogy-v2.2-profile';
const _v22SourceCommit = 'dc12e50ccf2e2e27e7a4a1d06793a9b8c0fb091a';
const _v22Themes = ['TEMA_02', 'TEMA_03', 'TEMA_04'];

void _verifyTeacherGuidePedagogyOverlay(
  Database database,
  Map<String, dynamic> manifest,
) {
  final capabilities = manifest['teacher_guide_capabilities'];
  if (capabilities is! Map || capabilities['pedagogy_overlay'] == null) {
    return;
  }
  final overlay = capabilities['pedagogy_overlay'];
  _check(overlay is Map, 'pedagogy_overlay metadata nesne değil');
  final metadata = overlay as Map;
  _check(
    metadata['available'] == true,
    'pedagogy_overlay kullanılabilir değil',
  );
  _checkValue(
    metadata['architecture_version'],
    _v22ArchitectureVersion,
    'pedagogy_overlay architecture version',
  );
  _checkValue(
    metadata['projection_version'],
    _v22ProjectionVersion,
    'pedagogy_overlay projection version',
  );
  _checkValue(
    metadata['source_tymm_commit'],
    _v22SourceCommit,
    'pedagogy_overlay source TYMM commit',
  );
  _checkValue(
    metadata['source_mode'],
    'CANONICAL_RUNTIME_PLUS_V2_PROFILE',
    'pedagogy_overlay source mode',
  );
  final themes = metadata['themes'];
  _check(
    themes is List &&
        themes.map((value) => value.toString()).toList().join('|') ==
            _v22Themes.join('|'),
    'pedagogy_overlay themes',
  );
  _checkValue(metadata['sections'], 21, 'pedagogy_overlay sections');
  _checkValue(metadata['blocks'], 69, 'pedagogy_overlay blocks');
  _checkValue(
    metadata['canonical_task_items_reused'],
    216,
    'pedagogy_overlay canonical task items',
  );

  _checkValue(
    _countWhere(database, 'teacher_guide_units', 'unit_id LIKE ?', [
      '__pedv2_unit__%',
    ]),
    69,
    'V2.2 synthetic unit sayısı',
  );
  _checkValue(
    _countWhere(database, 'teacher_guide_items', 'item_id LIKE ?', [
      '__pedv2_block__%',
    ]),
    69,
    'V2.2 synthetic item sayısı',
  );
  _checkValue(
    _countWhere(database, 'teacher_guide_units', 'unit_id NOT LIKE ?', [
      '__pedv2_unit__%',
    ]),
    94,
    'canonical unit sayısı',
  );
  _checkValue(
    _countWhere(database, 'teacher_guide_items', 'item_id NOT LIKE ?', [
      '__pedv2_block__%',
    ]),
    283,
    'canonical item sayısı',
  );
  _checkValue(
    _countWhere(
      database,
      'teacher_guide_item_relations',
      'item_id NOT LIKE ?',
      ['__pedv2_block__%'],
    ),
    3750,
    'canonical relation sayısı',
  );
  final rawCounts = manifest['row_counts'];
  _check(rawCounts is Map, 'V2.2 row_counts eksik');
  _checkValue(
    _count(database, 'teacher_guide_units'),
    (rawCounts['teacher_guide_units'] as num).toInt(),
    'V2.2 toplam unit sayısı',
  );
  _checkValue(
    _count(database, 'teacher_guide_items'),
    (rawCounts['teacher_guide_items'] as num).toInt(),
    'V2.2 toplam item sayısı',
  );
}

void _verifyTeacherGuideRelations(Database database) {
  final rows = database.select('''
    SELECT item_id, target_type, target_id, relation_type, relation_order
    FROM teacher_guide_item_relations
    ORDER BY item_id, relation_order, target_type, target_id, relation_type
  ''');
  for (final row in rows) {
    for (final field in const [
      'item_id',
      'target_type',
      'target_id',
      'relation_type',
    ]) {
      _check(
        row[field]?.toString().trim().isNotEmpty ?? false,
        'teacher_guide relation $field eksik',
      );
    }
    final order = row['relation_order'];
    _check(
      order is num && order > 0 && order == order.toInt(),
      'teacher_guide relation sırası geçersiz',
    );
  }
}

void _verifyTeacherGuideSequence(Database database) {
  final sectionRows = database.select('''
    SELECT guide_id, section_id, section_order
    FROM teacher_guide_sections
    ORDER BY guide_id, section_order, section_id
  ''');
  String? guideId;
  var expectedOrder = 0;
  for (final row in sectionRows) {
    if (row['guide_id'] != guideId) {
      guideId = row['guide_id']?.toString();
      expectedOrder = 1;
    } else {
      expectedOrder++;
    }
    _checkValue(
      row['section_order'],
      expectedOrder,
      '${row['section_id']} section sırası',
    );
  }

  final unitRows = database.select('''
    SELECT section_id, unit_id, unit_order
    FROM teacher_guide_units
    ORDER BY section_id, unit_order, unit_id
  ''');
  String? sectionId;
  expectedOrder = 0;
  for (final row in unitRows) {
    if (row['section_id'] != sectionId) {
      sectionId = row['section_id']?.toString();
      expectedOrder = 1;
    } else {
      expectedOrder++;
    }
    _checkValue(
      row['unit_order'],
      expectedOrder,
      '${row['unit_id']} unit sırası',
    );
  }

  final itemRows = database.select('''
    SELECT unit_id, item_id, item_order
    FROM teacher_guide_items
    ORDER BY unit_id, item_order, item_id
  ''');
  String? unitId;
  expectedOrder = 0;
  for (final row in itemRows) {
    if (row['unit_id'] != unitId) {
      unitId = row['unit_id']?.toString();
      expectedOrder = 1;
    } else {
      expectedOrder++;
    }
    _checkValue(
      row['item_order'],
      expectedOrder,
      '${row['item_id']} item sırası',
    );
  }
}

void _verifyTeacherGuideItems(Database database) {
  final rows = database.select('''
    SELECT item_id, title, label, content_status, expected_response_json,
           acceptance_criteria_json, teacher_guidance_json,
           common_misconceptions_json, assessment_evidence_json,
           differentiation_json, provenance_json, canonical_payload_sha256
    FROM teacher_guide_items
    ORDER BY item_id
  ''');
  for (final row in rows) {
    final itemId = row['item_id']?.toString() ?? '';
    _check(itemId.isNotEmpty, 'teacher_guide item id eksik');
    _check(
      row['content_status']?.toString().trim().isNotEmpty ?? false,
      '$itemId content_status eksik',
    );
    _check(
      (row['title']?.toString().trim().isNotEmpty ?? false) ||
          (row['label']?.toString().trim().isNotEmpty ?? false),
      '$itemId title/label eksik',
    );
    for (final field in const [
      'expected_response_json',
      'acceptance_criteria_json',
      'teacher_guidance_json',
      'common_misconceptions_json',
      'assessment_evidence_json',
      'differentiation_json',
      'provenance_json',
    ]) {
      final decoded = _decodeMapOrJson(
        row[field]?.toString() ?? '',
        '$itemId/$field',
      );
      if (field == 'differentiation_json') {
        _check(decoded is Map, '$itemId differentiation nesne değil');
        final differentiation = decoded as Map;
        _check(
          differentiation.containsKey('support') &&
              differentiation.containsKey('enrichment'),
          '$itemId differentiation support/enrichment eksik',
        );
      }
      if (field == 'provenance_json') {
        _check(decoded is Map && decoded.isNotEmpty, '$itemId provenance boş');
      }
    }
    _check(
      RegExp(
        r'^[0-9a-fA-F]{64}$',
      ).hasMatch(row['canonical_payload_sha256']?.toString().trim() ?? ''),
      '$itemId canonical payload hash eksik/geçersiz',
    );
  }
}

Object? _decodeMapOrJson(String raw, String field) {
  _check(raw.trim().isNotEmpty, '$field JSON boş');
  try {
    return jsonDecode(raw);
  } on FormatException catch (error) {
    throw StateError('$field geçersiz JSON: $error');
  }
}

void _verifyFullRuntime(
  Database database,
  Map<String, dynamic> manifest,
  Map<String, Set<String>> formTemplatePolicy,
) {
  final assessmentEnabled = _assessmentCapabilityEnabled(database, manifest);
  final assessmentPredicate = assessmentEnabled
      ? '''
      AND EXISTS (
        SELECT 1 FROM assessment_task_bindings atb
        WHERE atb.theme_id = b.theme_id
      )
      '''
      : '';
  final verificationCandidates = database.select('''
    SELECT b.theme_id, b.block_id
    FROM blocks b
    WHERE EXISTS (
      SELECT 1 FROM block_outcomes bo WHERE bo.block_id = b.block_id
    )
      AND EXISTS (
        SELECT 1
        FROM block_activities ba
        INNER JOIN activity_forms af ON af.activity_id = ba.activity_id
        WHERE ba.block_id = b.block_id
      )
      AND EXISTS (
        SELECT 1 FROM textbook_sections ts
        WHERE ts.theme_id = b.theme_id
      )
      AND EXISTS (
        SELECT 1 FROM resource_decisions rd WHERE rd.theme_id = b.theme_id
      )
      AND EXISTS (
        SELECT 1 FROM entity_source_references esr
        WHERE esr.entity_type = 'theme' AND esr.entity_id = b.theme_id
      )
      $assessmentPredicate
    ORDER BY b.theme_id, b.block_order
    LIMIT 1
  ''');
  _check(
    verificationCandidates.isNotEmpty,
    'full runtime ilişki doğrulaması için uygun theme/block bulunamadı',
  );
  final themeId = verificationCandidates.first['theme_id'] as String;
  final blockId = verificationCandidates.first['block_id'] as String;
  _check(
    _countWhere(database, 'block_outcomes', 'block_id = ?', [blockId]) > 0,
    'blok outcome ilişkisi yok',
  );
  _check(
    _countWhere(database, 'block_activities', 'block_id = ?', [blockId]) > 0,
    'blok etkinlik ilişkisi yok',
  );
  _check(
    _countWhere(database, 'textbook_sections', 'theme_id = ?', [themeId]) > 0,
    'theme kitap bölümü yok',
  );
  _check(
    _countWhere(database, 'resource_decisions', 'theme_id = ?', [themeId]) > 0,
    'theme kaynak kararı yok',
  );
  if (assessmentEnabled) {
    _check(
      _countWhere(database, 'assessment_task_bindings', 'theme_id = ?', [
            themeId,
          ]) >
          0,
      'theme ölçme bağlama yok',
    );
  }
  _verifyFormTemplates(database, manifest, formTemplatePolicy);
}

bool _assessmentCapabilityEnabled(
  Database database,
  Map<String, dynamic> manifest,
) {
  final capabilities = manifest['capabilities'];
  if (capabilities is Map && capabilities.containsKey('assessment')) {
    final value = capabilities['assessment'];
    _check(value is bool, 'assessment capability boolean olmalı');
    final bindingCount = _count(database, 'assessment_task_bindings');
    _check(
      value == (bindingCount > 0),
      'assessment capability ile assessment_task_bindings tutarsız',
    );
    return value;
  }
  return _count(database, 'assessment_task_bindings') > 0;
}

void _verifyFormTemplates(
  Database database,
  Map<String, dynamic> manifest,
  Map<String, Set<String>> policy,
) {
  final formCount = _count(database, 'forms');
  final capabilities = manifest['capabilities'];
  _check(capabilities is Map, 'runtime capabilities eksik');
  if (formCount == 0) {
    _check(
      capabilities['form_templates'] != true,
      'forms yokken form_templates capability true olamaz',
    );
    return;
  }
  _check(
    capabilities['form_templates'] is bool,
    'form_templates capability boolean olmalı',
  );
  _check(
    _tableExists(database, 'form_templates'),
    'form_templates tablosu yok',
  );
  _checkValue(
    _count(database, 'form_templates'),
    formCount,
    'her form için form_templates kaydı',
  );
  final foreignKeyErrors = database.select(
    'PRAGMA foreign_key_check(form_templates)',
  );
  _check(
    foreignKeyErrors.isEmpty,
    'form_templates foreign key bütünlüğü bozuk',
  );

  const allowedStatuses = {'ready', 'needs_review'};
  const allowedTypes = {
    'heading',
    'paragraph',
    'identityFields',
    'freeText',
    'checklist',
    'ratingScale',
    'table',
    'rubric',
    'note',
    'signature',
    'spacer',
  };
  final rows = database.select('''
    SELECT ft.form_id, ft.schema_version, ft.template_json,
           ft.render_status, ft.provenance_json, ft.review_reason, f.title
    FROM form_templates ft
    INNER JOIN forms f ON f.form_id = ft.form_id
    ORDER BY ft.form_id
  ''');
  for (final row in rows) {
    final formId = row['form_id'];
    final metadataTitle = row['title']?.toString().trim() ?? '';
    _check(metadataTitle.isNotEmpty, '$formId kullanıcı başlığı boş');
    _check(
      metadataTitle != formId,
      '$formId kullanıcı başlığı teknik ID olamaz',
    );
    final schemaVersion = row['schema_version']?.toString() ?? '';
    _check(schemaVersion == '1.0', '$formId desteklenmeyen schema_version');
    final status = row['render_status']?.toString() ?? '';
    _check(allowedStatuses.contains(status), '$formId render_status geçersiz');
    final reviewReason = row['review_reason']?.toString().trim();
    if (status == 'needs_review') {
      _check(
        reviewReason != null && reviewReason.isNotEmpty,
        '$formId needs_review reason eksik',
      );
      _check(
        policy['review_reasons']!.contains(reviewReason),
        '$formId needs_review reason geçersiz: $reviewReason',
      );
    } else {
      _check(
        reviewReason == null || reviewReason.isEmpty,
        '$formId ready form review reason taşıyor',
      );
    }
    final provenance = _decodeMap(row['provenance_json']?.toString() ?? '');
    _check(provenance.isNotEmpty, '$formId provenance boş');
    if (status == 'ready') {
      final contentBasis = provenance['content_basis']?.toString().trim() ?? '';
      _check(
        policy['ready_content_bases']!.contains(contentBasis),
        '$formId ready content_basis canonical değil',
      );
      _check(
        (provenance['source_id']?.toString().trim() ?? '').isNotEmpty,
        '$formId ready source_id eksik',
      );
      final hasLocator = [
        provenance['source_locator'],
        provenance['source_page'],
        provenance['printed_page'],
        provenance['pdf_page'],
      ].any((value) => value?.toString().trim().isNotEmpty ?? false);
      _check(hasLocator, '$formId ready source locator/page eksik');
      _check(
        policy['verified_statuses']!.contains(
          provenance['verification_status']?.toString().trim(),
        ),
        '$formId ready verification_status geçersiz',
      );
    }
    _check(
      status == 'needs_review'
          ? provenance['review_reason'] == reviewReason
          : provenance['review_reason'] == null,
      '$formId provenance review_reason ile kayıt uyuşmuyor',
    );
    final template = _decodeMap(row['template_json']?.toString() ?? '');
    _check(
      template['schema_version'] == schemaVersion,
      '$formId şema uyuşmuyor',
    );
    _check(
      (template['title']?.toString().trim() ?? '').isNotEmpty,
      '$formId template başlığı boş',
    );
    _check(
      template['title'].toString().trim() != formId,
      '$formId template başlığı teknik ID olamaz',
    );
    _check(
      template['provenance'] is Map &&
          (template['provenance'] as Map).isNotEmpty,
      '$formId template provenance boş',
    );
    if (status == 'ready') {
      final templateProvenance = Map<String, dynamic>.from(
        template['provenance'] as Map,
      );
      _check(
        templateProvenance['content_basis'] == provenance['content_basis'] &&
            templateProvenance['source_id'] == provenance['source_id'] &&
            templateProvenance['verification_status'] ==
                provenance['verification_status'],
        '$formId template/provenance kanıtı uyuşmuyor',
      );
    }
    final sections = template['sections'];
    _check(
      sections is List && sections.isNotEmpty,
      '$formId sections boş veya liste değil',
    );
    for (final section in sections as List) {
      _check(section is Map, '$formId section nesne değil');
      final elements = (section as Map)['elements'];
      _check(
        elements is List && elements.isNotEmpty,
        '$formId elements boş veya liste değil',
      );
      for (final element in elements as List) {
        _check(element is Map, '$formId element nesne değil');
        final type = (element as Map)['type']?.toString() ?? '';
        _check(
          allowedTypes.contains(type),
          '$formId element type geçersiz: $type',
        );
        if (type == 'table') {
          final columns = element['columns'];
          _check(
            columns is List && columns.isNotEmpty,
            '$formId table columns boş',
          );
          final tableRows = element['rows'];
          _check(tableRows is List, '$formId table rows liste değil');
          for (final tableRow in tableRows as List) {
            _check(
              tableRow is List && tableRow.length == (columns as List).length,
              '$formId table satır/sütun sayısı uyuşmuyor',
            );
          }
        }
        if (type == 'rubric') {
          final criteria = element['criteria'];
          final levels = element['levels'];
          _check(
            criteria is List &&
                criteria.isNotEmpty &&
                levels is List &&
                levels.isNotEmpty,
            '$formId rubric ölçüt/düzey boş',
          );
          for (final criterion in criteria as List) {
            _check(criterion is Map, '$formId rubric ölçüt nesne değil');
            final descriptors = (criterion as Map)['descriptors'];
            _check(
              descriptors is List &&
                  descriptors.length == (levels as List).length,
              '$formId rubric descriptor/düzey sayısı uyuşmuyor',
            );
          }
        }
        if (type == 'ratingScale') {
          final options = element['options'];
          final items = element['items'];
          _check(
            options is List &&
                options.isNotEmpty &&
                items is List &&
                items.isNotEmpty,
            '$formId ratingScale seçenek/ölçüt boş',
          );
          final min = int.tryParse(element['min']?.toString() ?? '');
          final max = int.tryParse(element['max']?.toString() ?? '');
          _check(
            min != null &&
                max != null &&
                min <= max &&
                max - min + 1 == (options as List).length,
            '$formId ratingScale aralığı seçeneklerle uyuşmuyor',
          );
        }
      }
    }
  }
  final readyCount = _countWhere(
    database,
    'form_templates',
    "render_status = 'ready'",
    const [],
  );
  _check(
    capabilities['form_templates'] == (readyCount > 0),
    'form_templates capability hazır şablonlarla uyuşmuyor',
  );
  final statusCounts = <String, int>{};
  for (final row in database.select(
    'SELECT render_status, COUNT(*) AS count FROM form_templates '
    'GROUP BY render_status',
  )) {
    statusCounts[row['render_status'].toString()] = row['count'] as int;
  }
  final manifestCounts = manifest['form_template_status_counts'];
  _check(
    manifestCounts is Map &&
        (manifestCounts['ready'] ?? 0) == (statusCounts['ready'] ?? 0) &&
        (manifestCounts['needs_review'] ?? 0) ==
            (statusCounts['needs_review'] ?? 0),
    'form_template_status_counts runtime ile uyuşmuyor',
  );
  final manifestReasons = manifest['form_template_review_reasons'];
  final runtimeReasons = <String, String>{};
  for (final row in database.select(
    'SELECT form_id, review_reason FROM form_templates '
    "WHERE render_status = 'needs_review' ORDER BY form_id",
  )) {
    runtimeReasons[row['form_id'].toString()] = row['review_reason'].toString();
  }
  _check(
    manifestReasons is Map &&
        manifestReasons.length == runtimeReasons.length &&
        runtimeReasons.entries.every(
          (entry) => manifestReasons[entry.key] == entry.value,
        ),
    'form_template_review_reasons runtime ile uyuşmuyor',
  );
}

void _verifySequence(ResultSet sequence) {
  final seenBlockIds = <Object?>{};
  String? currentThemeId;
  var expectedBlockOrder = 0;
  for (final row in sequence) {
    final themeId = row['theme_id'] as String;
    if (themeId != currentThemeId) {
      currentThemeId = themeId;
      expectedBlockOrder = 1;
    } else {
      expectedBlockOrder++;
    }
    _checkValue(row['block_order'], expectedBlockOrder, '$themeId blok sırası');
    _check(
      seenBlockIds.add(row['block_id']),
      'timeline blokları tekrar ediyor',
    );
  }
}

Map<String, dynamic> _decodeMap(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) throw StateError('JSON nesnesi bekleniyordu');
  return Map<String, dynamic>.from(decoded);
}

Map<String, Set<String>> _loadFormTemplatePolicy(String projectRoot) {
  final policyFile = File(
    p.join(projectRoot, 'tool', 'form_templates', 'form_template_policy.json'),
  );
  _check(policyFile.existsSync(), 'form template policy bulunamadı');
  final decoded = jsonDecode(policyFile.readAsStringSync());
  _check(decoded is Map, 'form template policy nesne olmalı');
  final policy = <String, Set<String>>{};
  for (final key in const [
    'ready_content_bases',
    'verified_statuses',
    'review_reasons',
  ]) {
    final values = (decoded as Map)[key];
    _check(values is List, 'form template policy.$key liste olmalı');
    policy[key] = values.map<String>((value) => value.toString()).toSet();
  }
  return policy;
}

void _checkFreshnessEvidence(
  Map<String, dynamic> manifest,
  String? validationReport,
) {
  final manifestStatus = manifest['runtime_status']?.toString().trim();
  if (manifestStatus != null && manifestStatus.isNotEmpty) {
    if (manifestStatus == 'RUNTIME_FRESH') return;
    throw StateError('runtime_status fresh değil: $manifestStatus');
  }
  if (validationReport != null) {
    for (final line in validationReport.split('\n')) {
      if (!line.toLowerCase().contains('source fingerprint status')) continue;
      final normalized = line.toUpperCase();
      if (normalized.contains('PASS') && normalized.contains('RUNTIME_FRESH')) {
        return;
      }
    }
  }
  throw StateError('runtime freshness kanıtı bulunamadı');
}

int _count(Database database, String table) {
  final rows = database.select('SELECT COUNT(*) AS count FROM $table');
  return rows.single['count'] as int;
}

bool _tableExists(Database database, String table) => database.select(
  "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
  [table],
).isNotEmpty;

int _countWhere(
  Database database,
  String table,
  String where,
  List<Object?> parameters,
) {
  final rows = database.select(
    'SELECT COUNT(*) AS count FROM $table WHERE $where',
    parameters,
  );
  return rows.single['count'] as int;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _checkValue(Object? actual, Object? expected, String message) {
  if (actual != expected) {
    throw StateError('$message (beklenen: $expected, gerçek: $actual)');
  }
}

String? _valueFor(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

void _checkSchemaCompatibility(
  Object? databaseVersion,
  Object? manifestVersion,
) {
  final database = databaseVersion?.toString() ?? '';
  final manifest = manifestVersion?.toString() ?? '';
  if (database.isEmpty ||
      manifest.isEmpty ||
      database.split('.').first != manifest.split('.').first) {
    throw StateError(
      'schema major uyumsuz (manifest: $manifest, database: $database)',
    );
  }
}
