import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/data/course/course_knowledge_repository_impl.dart';
import 'package:ogretmen_os/data/course/teacher_guide_database_data_source.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/teacher_guide_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('generic teacher guide runtime', () {
    late Database database;
    late CourseKnowledgeRepository repository;

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await _seedGenericRuntime(database);
      repository = _repository(database);
    });

    tearDown(() => database.close());

    test('capability olan hayali FIZIK_10 rehberini okuyabilir', () async {
      final capability = await repository.getTeacherGuideCapability();

      expect(capability.available, isTrue);
      expect(capability.usable, isTrue);
      expect(capability.canonicalEntityCount, 5);
      expect(capability.guideCount, 1);
      expect(capability.sectionCount, 2);
      expect(capability.unitCount, 3);
      expect(capability.itemCount, 5);
      expect(capability.relationCount, 3);

      final guide = await repository.getTeacherGuideForTheme('THEME_MECHANICS');
      expect(guide, isNotNull);
      expect(guide!.courseId, 'FIZIK_10');
      expect(guide.scopeType, 'theme');
      expect(guide.scopeId, 'THEME_MECHANICS');
    });

    test(
      'section/unit/item sıralaması runtime order alanlarıyla deterministiktir',
      () async {
        final guide = (await repository.getTeacherGuideForTheme(
          'THEME_MECHANICS',
        ))!;
        final sections = await repository.getTeacherGuideSections(
          guide.guideId,
        );
        expect(
          sections.map((section) => section.sectionId),
          orderedEquals(['SECTION_CORE', 'SECTION_EXTENSION']),
        );

        final units = await repository.getTeacherGuideUnits('SECTION_CORE');
        expect(
          units.map((unit) => unit.unitId),
          orderedEquals(['UNIT_OBSERVATION', 'UNIT_MODEL']),
        );

        final items = await repository.getTeacherGuideItems('UNIT_OBSERVATION');
        expect(
          items.map((item) => item.itemId),
          orderedEquals(['ITEM_BLOCK', 'ITEM_ACTIVITY']),
        );
      },
    );

    test('explicit activity/block/outcome relationları item bulur', () async {
      final activityItems = await repository.getTeacherGuideItemsForEntity(
        targetType: 'activity',
        targetId: 'ACTIVITY_EXPERIMENT',
      );
      expect(
        activityItems.map((item) => item.itemId),
        orderedEquals(['ITEM_ACTIVITY']),
      );
      expect(activityItems.single.relations.single.relationType, 'explains');

      final blockItems = await repository.getTeacherGuideItemsForEntity(
        targetType: 'block',
        targetId: 'BLOCK_MECHANICS',
      );
      expect(
        blockItems.map((item) => item.itemId),
        orderedEquals(['ITEM_BLOCK']),
      );

      final outcomeItems = await repository.getTeacherGuideItemsForEntity(
        targetType: 'outcome',
        targetId: 'OUTCOME_FORCE',
      );
      expect(
        outcomeItems.map((item) => item.itemId),
        orderedEquals(['ITEM_OUTCOME']),
      );
    });

    test(
      'relation yoksa label benzerliğinden eşleşme tahmin edilmez',
      () async {
        final items = await repository.getTeacherGuideItemsForEntity(
          targetType: 'activity',
          targetId: 'ACTIVITY_NOT_LINKED',
        );
        expect(items, isEmpty);

        final unrelated = await repository.getTeacherGuideItem(
          'ITEM_UNRELATED',
        );
        expect(unrelated, isNotNull);
        expect(unrelated!.relations, isEmpty);
      },
    );

    test(
      'text/list/structured response JSON kayıpsız ve status/provenance korunur',
      () async {
        final textItem = await repository.getTeacherGuideItem('ITEM_ACTIVITY');
        final listItem = await repository.getTeacherGuideItem('ITEM_BLOCK');
        final structuredItem = await repository.getTeacherGuideItem(
          'ITEM_OUTCOME',
        );

        expect(textItem!.expectedResponse, 'Bir ölçüm tablosu oluşturur.');
        expect(listItem!.expectedResponse, ['ölçüm', 'model', 'kanıt']);
        expect(structuredItem!.expectedResponse, {
          'steps': ['ölç', 'karşılaştır'],
          'threshold': 0.5,
        });
        expect(structuredItem.contentStatus, 'REVIEW_REQUIRED');
        expect(structuredItem.provenance.contentClass, 'MIXED');
        expect(structuredItem.provenance.sourceIds, ['physics_textbook']);
        expect(structuredItem.differentiation.support, ['grafik şablonu']);
        expect(structuredItem.differentiation.enrichment, {
          'challenge': 'modeli değiştir',
        });
      },
    );
  });

  test(
    'capability olmayan eski runtime güvenli unavailable/boş fallback verir',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(database.close);
      await database.execute('''
      CREATE TABLE courses (
        course_id TEXT PRIMARY KEY,
        grade INTEGER,
        title TEXT NOT NULL,
        schema_version TEXT NOT NULL,
        source_manifest_fingerprint TEXT NOT NULL
      )
    ''');
      await database.insert('courses', {
        'course_id': 'FIZIK_10',
        'grade': 10,
        'title': 'Fizik',
        'schema_version': '1.2.0',
        'source_manifest_fingerprint': 'legacy',
      });
      final manifest = RuntimeManifest.fromJson(
        _manifest(advertised: false, rowCounts: const {}),
      );
      final legacyRepository = CourseKnowledgeRepositoryImpl(
        dataSource: CourseDatabaseDataSource(database),
        manifest: manifest,
        teacherGuideDataSource: TeacherGuideDatabaseDataSource(database),
      );

      final capability = await legacyRepository.getTeacherGuideCapability();
      expect(capability.available, isFalse);
      expect(capability.reason, 'TEACHER_GUIDE_NOT_ADVERTISED');
      expect(
        await legacyRepository.getTeacherGuideForTheme('THEME_MECHANICS'),
        isNull,
      );
      expect(
        await legacyRepository.getTeacherGuideItemsForEntity(
          targetType: 'activity',
          targetId: 'ACTIVITY_EXPERIMENT',
        ),
        isEmpty,
      );
    },
  );

  test(
    'runtime veritabanı read-only açıldığında guide adapter yazmaz',
    () async {
      final root = await Directory.systemTemp.createTemp('teacher_guide_ro_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final path = '${root.path}/course_runtime.sqlite';
      final writable = await databaseFactoryFfi.openDatabase(path);
      await _seedGenericRuntime(writable);
      await writable.close();

      final readOnly = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      addTearDown(readOnly.close);
      final repository = _repository(readOnly);
      expect(
        await repository.getTeacherGuideCapability(),
        isA<TeacherGuideCapability>(),
      );
      expect(
        (await repository.getTeacherGuideItem('ITEM_ACTIVITY'))!.itemId,
        'ITEM_ACTIVITY',
      );
      await expectLater(
        readOnly.insert('teacher_guide_sections', {
          'section_id': 'SHOULD_FAIL',
          'guide_id': 'GUIDE_PHYSICS',
          'section_order': 3,
          'title': 'No write',
          'section_type': 'generic',
          'content_status': 'VERIFIED',
          'provenance_json': jsonEncode({
            'source_ids': ['physics_textbook'],
            'source_locators': ['p.1'],
          }),
        }),
        throwsA(isA<Object>()),
      );
    },
  );

  test('TDE_11 V2.2 additive runtime canonical katmanı korur', () async {
    final runtimeRoot =
        '${Directory.current.path}/tymm-verileri/turk-dili-ve-edebiyati/TDE_11/runtime';
    final manifestMap =
        jsonDecode(
              await File('$runtimeRoot/runtime_manifest.json').readAsString(),
            )
            as Map<String, dynamic>;
    final manifest = RuntimeManifest.fromJson(manifestMap);
    final packageManifest =
        jsonDecode(
              await File(
                '${Directory.current.path}/tymm-verileri/turk-dili-ve-edebiyati/TDE_11/package_manifest.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(packageManifest['data_mode'], 'FULL_RUNTIME');
    expect(packageManifest['textbook_status'], 'AVAILABLE');
    expect(packageManifest['lesson_plan_package_count'], 88);
    expect(packageManifest['lesson_plan_instruction_hours'], 172);
    expect(packageManifest['lesson_plan_validation_status'], 'VERIFIED');
    expect(packageManifest['lesson_plan_source_payload_parity'], isFalse);
    expect(
      packageManifest['teacher_guide_source_commit'],
      'dc12e50ccf2e2e27e7a4a1d06793a9b8c0fb091a',
    );
    final overlay = Map<String, dynamic>.from(
      manifestMap['teacher_guide_capabilities'] is Map
          ? ((manifestMap['teacher_guide_capabilities']
                    as Map)['pedagogy_overlay']
                as Map)
          : const <String, dynamic>{},
    );
    expect(overlay['available'], isTrue);
    expect(overlay['architecture_version'], '2.2.0');
    expect(overlay['projection_version'], '1.2.0+pedagogy-v2.2-profile');
    expect(
      overlay['source_tymm_commit'],
      'dc12e50ccf2e2e27e7a4a1d06793a9b8c0fb091a',
    );
    expect(overlay['themes'], ['TEMA_02', 'TEMA_03', 'TEMA_04']);
    expect(overlay['sections'], 21);
    expect(overlay['blocks'], 69);
    expect(overlay['canonical_task_items_reused'], 216);
    final database = await databaseFactoryFfi.openDatabase(
      '$runtimeRoot/course_runtime.sqlite',
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    addTearDown(database.close);
    final repository = CourseKnowledgeRepositoryImpl(
      dataSource: CourseDatabaseDataSource(database),
      manifest: manifest,
      teacherGuideDataSource: TeacherGuideDatabaseDataSource(database),
    );

    final capability = await repository.getTeacherGuideCapability();
    expect(capability.available, isTrue);
    expect(capability.guideCount, 4);
    expect(capability.sectionCount, 28);
    expect(capability.unitCount, 163);
    expect(capability.itemCount, 352);
    expect(
      capability.relationCount,
      manifest.rowCounts['teacher_guide_item_relations'],
    );

    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_units WHERE unit_id NOT LIKE '__pedv2_unit__%'",
      )).single['count'],
      94,
    );
    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_items WHERE item_id NOT LIKE '__pedv2_block__%'",
      )).single['count'],
      283,
    );
    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_item_relations WHERE item_id NOT LIKE '__pedv2_block__%'",
      )).single['count'],
      3750,
    );
    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_units WHERE unit_id LIKE '__pedv2_unit__%'",
      )).single['count'],
      69,
    );
    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_items WHERE item_id LIKE '__pedv2_block__%'",
      )).single['count'],
      69,
    );
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    final v22ItemId = (await database.rawQuery(
      "SELECT item_id FROM teacher_guide_items WHERE item_id LIKE '__pedv2_block__%' ORDER BY item_id LIMIT 1",
    )).single['item_id']!.toString();
    final v22Item = await repository.getTeacherGuideItem(v22ItemId);
    expect(v22Item, isNotNull);
    expect(v22Item!.itemType, 'ÖĞRETMEN_REHBERİ_V2_2');
    final guidance = v22Item.teacherGuidance as Map;
    expect(guidance['öğretmen_hamleleri'], isNotEmpty);
    expect(guidance['takip_soruları'], isNotEmpty);
    expect(guidance['tahtaya_yaz'], isNotEmpty);
    expect(v22Item.commonMisconceptions, isNotEmpty);
    expect(v22Item.assessmentEvidence, isNotEmpty);
    expect(v22Item.differentiation.support, isNotEmpty);
    expect(v22Item.differentiation.enrichment, isNotEmpty);
    expect(v22Item.canonicalPayloadSha256, matches(RegExp(r'^[0-9a-f]{64}$')));

    final guide = await repository.getTeacherGuideForScope(
      scopeType: 'theme',
      scopeId: 'TEMA_01',
    );
    expect(guide, isNotNull);
    final sections = await repository.getTeacherGuideSections(guide!.guideId);
    expect(sections, hasLength(7));
    final units = await repository.getTeacherGuideUnits(
      sections.first.sectionId,
    );
    expect(units, isNotEmpty);
    final items = await repository.getTeacherGuideItems(units.first.unitId);
    expect(items, isNotEmpty);
    expect(
      items.first.canonicalPayloadSha256,
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );

    final activityItems = await repository.getTeacherGuideItemsForEntity(
      targetType: 'activity',
      targetId: 'T1_ACT_01_OKUMA_YONETIM',
    );
    expect(activityItems, isNotEmpty);
    expect(
      await repository.getTeacherGuideItemsForEntity(
        targetType: 'activity',
        targetId: 'NOT_A_CANONICAL_ACTIVITY',
      ),
      isEmpty,
    );

    final formItems = await repository.getTeacherGuideItemsForEntity(
      targetType: 'form',
      targetId: 'FORM_T1_P035_OZ_DEGERLENDIRME_01',
    );
    expect(formItems, isNotEmpty);
    expect(
      await repository.getForm('FORM_T1_P035_OZ_DEGERLENDIRME_01'),
      isNotNull,
    );
    expect(
      (await repository.getFormTemplateStatus(
        'FORM_T1_P035_OZ_DEGERLENDIRME_01',
      ))?.isReady,
      isTrue,
    );
    final externalStatus = await repository.getFormTemplateStatus(
      'LINK_T1_KONUSMA_DPA',
    );
    expect(externalStatus?.isExternalReference, isTrue);
    expect(externalStatus?.targetUrlCandidates, isNotEmpty);
  });
}

CourseKnowledgeRepositoryImpl _repository(Database database) =>
    CourseKnowledgeRepositoryImpl(
      dataSource: CourseDatabaseDataSource(database),
      manifest: RuntimeManifest.fromJson(_manifest()),
      teacherGuideDataSource: TeacherGuideDatabaseDataSource(database),
    );

Map<String, dynamic> _manifest({
  bool advertised = true,
  Map<String, int> rowCounts = const {
    'canonical_entities': 5,
    'teacher_guides': 1,
    'teacher_guide_sections': 2,
    'teacher_guide_units': 3,
    'teacher_guide_items': 5,
    'teacher_guide_item_relations': 3,
  },
}) => <String, dynamic>{
  'course_id': 'FIZIK_10',
  'schema_version': '1.3.0',
  'runtime_package_version': '1.4.0',
  'validation_status': 'PASS',
  'canonical_content_fingerprint': 'physics-fingerprint',
  'runtime_database_path': 'runtime/course_runtime.sqlite',
  'row_counts': rowCounts,
  'capabilities': {'teacher_guide': advertised},
  if (advertised) ...{
    'teacher_guide_capabilities': {
      'available': true,
      'schema_version': '1.0.0',
      'validation_status': 'PASS',
      'source_bound': true,
    },
    'teacher_guide_validation': {
      'status': 'PASS',
      'scope': 'COURSE',
      'content_fingerprint': 'sha256:physics-guide',
      'canonical_content_fingerprint': 'physics-fingerprint',
      'source_bound': true,
      'seal_path': 'runtime/teacher_guide_validation_seal.json',
      'seal_sha256': 'a' * 64,
    },
  },
};

Future<void> _seedGenericRuntime(Database database) async {
  await database.execute('PRAGMA foreign_keys = ON');
  await database.execute('''
    CREATE TABLE courses (
      course_id TEXT PRIMARY KEY,
      grade INTEGER,
      title TEXT NOT NULL,
      schema_version TEXT NOT NULL,
      source_manifest_fingerprint TEXT NOT NULL
    )
  ''');
  final schema = await File(
    '${Directory.current.path}/tool/teacher_guide/teacher_guide_runtime_schema.sql',
  ).readAsString();
  for (final statement in schema.split(';')) {
    final sql = statement
        .split('\n')
        .where((line) => !line.trim().startsWith('--'))
        .join('\n')
        .trim();
    if (sql.isNotEmpty) {
      await database.execute(sql);
    }
  }

  await database.insert('courses', {
    'course_id': 'FIZIK_10',
    'grade': 10,
    'title': 'Fizik',
    'schema_version': '1.3.0',
    'source_manifest_fingerprint': 'physics-fingerprint',
  });
  for (final entity in const [
    ['course', 'FIZIK_10'],
    ['theme', 'THEME_MECHANICS'],
    ['block', 'BLOCK_MECHANICS'],
    ['outcome', 'OUTCOME_FORCE'],
    ['activity', 'ACTIVITY_EXPERIMENT'],
  ]) {
    await database.insert('canonical_entities', {
      'entity_type': entity[0],
      'entity_id': entity[1],
    });
  }

  final provenance = jsonEncode({
    'source_ids': ['physics_textbook'],
    'source_locators': ['printed p. 4'],
    'content_class': 'MIXED',
  });
  await database.insert('teacher_guides', {
    'guide_id': 'GUIDE_PHYSICS',
    'course_id': 'FIZIK_10',
    'scope_type': 'theme',
    'scope_id': 'THEME_MECHANICS',
    'title': 'Mechanics teacher guide',
    'content_status': 'VERIFIED',
    'schema_version': '1.0.0',
    'provenance_json': provenance,
  });
  await database.insert('teacher_guide_sections', {
    'section_id': 'SECTION_EXTENSION',
    'guide_id': 'GUIDE_PHYSICS',
    'section_order': 2,
    'title': 'Extension',
    'section_type': 'EXTENSION',
    'page_locator': '5',
    'source_locator': 'physics_textbook#5',
    'content_status': 'VERIFIED',
    'provenance_json': provenance,
  });
  await database.insert('teacher_guide_sections', {
    'section_id': 'SECTION_CORE',
    'guide_id': 'GUIDE_PHYSICS',
    'section_order': 1,
    'title': 'Observation',
    'section_type': 'INQUIRY',
    'page_locator': '1-4',
    'source_locator': 'physics_textbook#1-4',
    'content_status': 'VERIFIED',
    'provenance_json': provenance,
  });
  await database.insert('teacher_guide_units', {
    'unit_id': 'UNIT_MODEL',
    'section_id': 'SECTION_CORE',
    'unit_order': 2,
    'title': 'Model the force',
    'page_locator': '3-4',
    'source_locator': 'physics_textbook#3-4',
    'content_status': 'VERIFIED',
    'purpose_json': jsonEncode({'focus': 'model'}),
    'provenance_json': provenance,
  });
  await database.insert('teacher_guide_units', {
    'unit_id': 'UNIT_OBSERVATION',
    'section_id': 'SECTION_CORE',
    'unit_order': 1,
    'title': 'Observe the experiment',
    'page_locator': '1-2',
    'source_locator': 'physics_textbook#1-2',
    'content_status': 'VERIFIED',
    'purpose_json': jsonEncode(['observe', 'record']),
    'provenance_json': provenance,
  });
  await database.insert('teacher_guide_units', {
    'unit_id': 'UNIT_EXTENSION',
    'section_id': 'SECTION_EXTENSION',
    'unit_order': 1,
    'title': 'Change a variable',
    'page_locator': '5',
    'source_locator': 'physics_textbook#5',
    'content_status': 'VERIFIED',
    'purpose_json': jsonEncode('transfer the model'),
    'provenance_json': provenance,
  });

  await _insertItem(
    database,
    itemId: 'ITEM_ACTIVITY',
    unitId: 'UNIT_OBSERVATION',
    order: 2,
    title: 'Record the measurement',
    label: 'measurement activity',
    itemType: 'PERFORMANCE_TASK',
    expectedResponse: 'Bir ölçüm tablosu oluşturur.',
    contentStatus: 'VERIFIED',
    relations: const [
      ['activity', 'ACTIVITY_EXPERIMENT', 'explains'],
    ],
  );
  await _insertItem(
    database,
    itemId: 'ITEM_BLOCK',
    unitId: 'UNIT_OBSERVATION',
    order: 1,
    title: 'Identify the evidence',
    label: 'measurement evidence',
    itemType: 'PROCESS',
    expectedResponse: const ['ölçüm', 'model', 'kanıt'],
    contentStatus: 'VERIFIED',
    relations: const [
      ['block', 'BLOCK_MECHANICS', 'supports'],
    ],
  );
  await _insertItem(
    database,
    itemId: 'ITEM_OUTCOME',
    unitId: 'UNIT_MODEL',
    order: 1,
    title: 'Compare models',
    label: 'force model comparison',
    itemType: 'ASSESSMENT',
    expectedResponse: const {
      'steps': ['ölç', 'karşılaştır'],
      'threshold': 0.5,
    },
    contentStatus: 'REVIEW_REQUIRED',
    relations: const [
      ['outcome', 'OUTCOME_FORCE', 'evidences'],
    ],
  );
  await _insertItem(
    database,
    itemId: 'ITEM_UNRELATED',
    unitId: 'UNIT_MODEL',
    order: 2,
    title: 'Activity-looking label without a link',
    label: 'ACTIVITY_EXPERIMENT is mentioned only in prose',
    itemType: 'TEACHER_NOTE',
    expectedResponse: null,
    contentStatus: 'VERIFIED',
  );
  await _insertItem(
    database,
    itemId: 'ITEM_EXTENSION',
    unitId: 'UNIT_EXTENSION',
    order: 1,
    title: 'Vary the input',
    label: 'structured enrichment',
    itemType: 'INVESTIGATION',
    expectedResponse: const {'input': 'mass', 'output': 'force'},
    contentStatus: 'VERIFIED',
  );
}

Future<void> _insertItem(
  Database database, {
  required String itemId,
  required String unitId,
  required int order,
  required String title,
  required String label,
  required String itemType,
  required Object? expectedResponse,
  required String contentStatus,
  List<List<String>> relations = const [],
}) async {
  final provenance = jsonEncode({
    'source_ids': ['physics_textbook'],
    'source_locators': ['printed p. 4'],
    'content_class': 'MIXED',
  });
  await database.insert('teacher_guide_items', {
    'item_id': itemId,
    'unit_id': unitId,
    'item_order': order,
    'title': title,
    'label': label,
    'item_type': itemType,
    'page_locator': '4',
    'source_locator': 'physics_textbook#4',
    'content_status': contentStatus,
    'expected_response_json': jsonEncode(expectedResponse),
    'acceptance_criteria_json': jsonEncode(['evidence']),
    'teacher_guidance_json': jsonEncode(['ask for a reason']),
    'common_misconceptions_json': jsonEncode([]),
    'assessment_evidence_json': jsonEncode(['student record']),
    'differentiation_json': jsonEncode({
      'support': ['grafik şablonu'],
      'enrichment': {'challenge': 'modeli değiştir'},
    }),
    'provenance_json': provenance,
    'canonical_payload_sha256': 'a' * 64,
  });
  for (var index = 0; index < relations.length; index++) {
    final relation = relations[index];
    await database.insert('teacher_guide_item_relations', {
      'item_id': itemId,
      'target_type': relation[0],
      'target_id': relation[1],
      'relation_type': relation[2],
      'relation_order': index + 1,
    });
  }
}
