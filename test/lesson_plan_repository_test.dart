import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/data/course/course_knowledge_repository_impl.dart';
import 'package:ogretmen_os/data/course/lesson_plan_database_data_source.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createBaseRuntime(database);
    await _createLessonPlanRuntime(database);
  });

  tearDown(() async {
    await database.close();
  });

  CourseKnowledgeRepository repository({
    int manifestCount = 3,
    String validationStatus = 'PASS',
  }) {
    return CourseKnowledgeRepositoryImpl(
      dataSource: CourseDatabaseDataSource(database),
      manifest: _manifest(
        manifestCount,
        validationStatus: validationStatus,
      ),
      lessonPlanDataSource: LessonPlanDatabaseDataSource(database),
    );
  }

  test('capability manifest ve SQLite row count eşleşince kullanılabilir', () async {
    final capability = await repository().getLessonPlanCapability();

    expect(capability.available, isTrue);
    expect(capability.usable, isTrue);
    expect(capability.manifestAdvertised, isTrue);
    expect(capability.tableAvailable, isTrue);
    expect(capability.packageCount, 3);
    expect(capability.instructionHours, 5);
    expect(capability.schemaVersion, '1.0.0');
    expect(capability.reason, isNull);
  });

  test('blok planları package_no sırasıyla ve structured payload ile okunur', () async {
    final plans = await repository().getLessonPlansForBlock('BLOCK_01');

    expect(plans.map((plan) => plan.packageId), ['BLOCK_01_P01', 'BLOCK_01_P02']);
    expect(plans.first.outcomeCodes, ['TDE9.1.1']);
    expect(plans.first.lessons, hasLength(2));
    expect(plans.first.lessons.first.lessonNo, 1);
    expect(plans.first.lessons.first.title, 'Hazırlık');
    expect(plans.first.lessons.first.activityIds, ['A1']);
    expect(plans.first.continuation.plannedNowHours, 2);
    expect(plans.first.continuation.remainingBlockHours, 2);
    expect(plans.first.continuation.nextStepHint, 'İkinci pakete geç.');
  });

  test('önceki ve sonraki paket blok sınırını koruyarak yıllık sırada ilerler', () async {
    final repo = repository();

    expect(
      (await repo.getNextLessonPlan('BLOCK_01_P02'))?.packageId,
      'BLOCK_02_P01',
    );
    expect(
      (await repo.getPreviousLessonPlan('BLOCK_02_P01'))?.packageId,
      'BLOCK_01_P02',
    );
    expect(await repo.getPreviousLessonPlan('BLOCK_01_P01'), isNull);
    expect(await repo.getNextLessonPlan('BLOCK_02_P01'), isNull);
  });

  test('manifest row count drift capabilityyi ve doğrudan okumaları fail closed yapar', () async {
    final repo = repository(manifestCount: 2);
    final capability = await repo.getLessonPlanCapability();

    expect(capability.available, isFalse);
    expect(capability.reason, 'LESSON_PLAN_ROW_COUNT_MISMATCH');
    expect(capability.packageCount, 3);
    expect(await repo.getLessonPlansForBlock('BLOCK_01'), isEmpty);
    expect(await repo.getLessonPlan('BLOCK_01_P01'), isNull);
  });

  test('runtime validation PASS değilse plan satırları dışarı açılmaz', () async {
    final repo = repository(validationStatus: 'FAIL');
    final capability = await repo.getLessonPlanCapability();

    expect(capability.available, isFalse);
    expect(capability.reason, 'RUNTIME_VALIDATION_NOT_PASS');
    expect(await repo.getLessonPlansForBlock('BLOCK_01'), isEmpty);
    expect(await repo.getLessonPlan('BLOCK_01_P01'), isNull);
    expect(await repo.getPreviousLessonPlan('BLOCK_02_P01'), isNull);
    expect(await repo.getNextLessonPlan('BLOCK_01_P01'), isNull);
  });

  test('eski runtime lesson_plan_packages tablosu olmadan güvenli fallback verir', () async {
    await database.execute('DROP TABLE lesson_plan_packages');
    final repo = repository();

    final capability = await repo.getLessonPlanCapability();
    expect(capability.available, isFalse);
    expect(capability.reason, 'LESSON_PLAN_TABLE_MISSING');
    expect(await repo.getLessonPlansForBlock('BLOCK_01'), isEmpty);
    expect(await repo.getLessonPlan('BLOCK_01_P01'), isNull);
    expect(await repo.getPreviousLessonPlan('BLOCK_01_P01'), isNull);
    expect(await repo.getNextLessonPlan('BLOCK_01_P01'), isNull);
  });
}

RuntimeManifest _manifest(
  int packageCount, {
  String validationStatus = 'PASS',
}) => RuntimeManifest(
  runtimePackageVersion: '1.3.0',
  schemaVersion: '1.2.0',
  courseId: 'TDE_9',
  validationStatus: validationStatus,
  canonicalContentFingerprint: 'fixture',
  rowCounts: {'lesson_plan_packages': packageCount},
  timelineResolution: 'BLOCK_TIME_RESOLVED',
  timelineUnresolvedFields: const {},
);

Future<void> _createBaseRuntime(Database database) async {
  await database.execute('''
    CREATE TABLE courses (
      course_id TEXT PRIMARY KEY,
      grade INTEGER,
      title TEXT NOT NULL,
      schema_version TEXT NOT NULL,
      source_manifest_fingerprint TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE themes (
      theme_id TEXT PRIMARY KEY,
      course_id TEXT NOT NULL,
      theme_order INTEGER NOT NULL,
      title TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE blocks (
      block_id TEXT PRIMARY KEY,
      theme_id TEXT NOT NULL,
      block_order INTEGER NOT NULL,
      title TEXT NOT NULL
    )
  ''');

  await database.insert('courses', {
    'course_id': 'TDE_9',
    'grade': 9,
    'title': 'Türk Dili ve Edebiyatı 9',
    'schema_version': '1.2.0',
    'source_manifest_fingerprint': 'fixture',
  });
  await database.insert('themes', {
    'theme_id': 'TEMA_01',
    'course_id': 'TDE_9',
    'theme_order': 1,
    'title': 'Tema 1',
  });
  await database.insert('blocks', {
    'block_id': 'BLOCK_01',
    'theme_id': 'TEMA_01',
    'block_order': 1,
    'title': 'Blok 1',
  });
  await database.insert('blocks', {
    'block_id': 'BLOCK_02',
    'theme_id': 'TEMA_01',
    'block_order': 2,
    'title': 'Blok 2',
  });
}

Future<void> _createLessonPlanRuntime(Database database) async {
  await database.execute('''
    CREATE TABLE lesson_plan_packages (
      package_id TEXT PRIMARY KEY,
      course_id TEXT NOT NULL,
      theme_id TEXT NOT NULL,
      block_id TEXT NOT NULL,
      package_no INTEGER NOT NULL,
      lesson_hours INTEGER NOT NULL,
      plan_title TEXT NOT NULL,
      plan_summary TEXT NOT NULL,
      remaining_block_hours INTEGER NOT NULL,
      schema_version TEXT NOT NULL,
      validation_status TEXT NOT NULL,
      source_path TEXT NOT NULL,
      payload_sha256 TEXT NOT NULL,
      payload_json TEXT NOT NULL
    )
  ''');

  await _insertPlan(
    database,
    packageId: 'BLOCK_01_P01',
    blockId: 'BLOCK_01',
    packageNo: 1,
    lessonHours: 2,
    remainingHours: 2,
  );
  await _insertPlan(
    database,
    packageId: 'BLOCK_01_P02',
    blockId: 'BLOCK_01',
    packageNo: 2,
    lessonHours: 2,
    remainingHours: 0,
  );
  await _insertPlan(
    database,
    packageId: 'BLOCK_02_P01',
    blockId: 'BLOCK_02',
    packageNo: 1,
    lessonHours: 1,
    remainingHours: 0,
  );
}

Future<void> _insertPlan(
  Database database, {
  required String packageId,
  required String blockId,
  required int packageNo,
  required int lessonHours,
  required int remainingHours,
}) async {
  final payload = {
    'schema_version': '1.0.0',
    'course_id': 'TDE_9',
    'theme_id': 'TEMA_01',
    'block_id': blockId,
    'lesson_hours': lessonHours,
    'plan_title': 'Plan $packageNo',
    'plan_summary': 'Özet $packageNo',
    'outcome_codes': ['TDE9.1.1'],
    'used_activity_ids': ['A1'],
    'used_form_ids': ['F1'],
    'lessons': [
      {
        'lesson_no': 1,
        'duration_lesson_hours': 1,
        'title': 'Hazırlık',
        'objective': 'Hedef',
        'outcome_codes': ['TDE9.1.1'],
        'opening': 'Açılış',
        'teacher_actions': ['Yönerge ver.'],
        'student_actions': ['Metni incele.'],
        'activity_ids': ['A1'],
        'form_ids': ['F1'],
        'assessment': 'Kontrol et.',
        'closure': 'Özetle.',
        'materials': ['Ders kitabı'],
      },
      if (lessonHours > 1)
        {
          'lesson_no': 2,
          'duration_lesson_hours': 1,
          'title': 'Uygulama',
          'objective': 'Uygula',
          'outcome_codes': ['TDE9.1.1'],
          'opening': 'Hatırla',
          'teacher_actions': ['Model ol.'],
          'student_actions': ['Uygula.'],
          'activity_ids': ['A1'],
          'form_ids': ['F1'],
          'assessment': 'Gözlemle.',
          'closure': 'Çıkış bileti.',
          'materials': ['Çalışma kağıdı'],
        },
    ],
    'teacher_notes': ['Takvime bağlı değildir.'],
    'continuation_summary': {
      'planned_now_hours': lessonHours,
      'remaining_block_hours': remainingHours,
      'covered_outcome_codes': ['TDE9.1.1'],
      'used_activity_ids': ['A1'],
      'next_step_hint': 'İkinci pakete geç.',
    },
  };

  await database.insert('lesson_plan_packages', {
    'package_id': packageId,
    'course_id': 'TDE_9',
    'theme_id': 'TEMA_01',
    'block_id': blockId,
    'package_no': packageNo,
    'lesson_hours': lessonHours,
    'plan_title': 'Plan $packageNo',
    'plan_summary': 'Özet $packageNo',
    'remaining_block_hours': remainingHours,
    'schema_version': '1.0.0',
    'validation_status': 'PASS',
    'source_path': 'generated/$packageId.json',
    'payload_sha256': 'sha-$packageId',
    'payload_json': jsonEncode(payload),
  });
}
