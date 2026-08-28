import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/data/course/course_knowledge_repository_impl.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/planning_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FailingPlanningDataSource extends CourseDatabaseDataSource {
  _FailingPlanningDataSource(super.database);

  int calls = 0;
  bool shouldFail = true;

  @override
  Future<PlanningDataset> getPlanningDataset({required String courseId}) async {
    calls++;
    if (shouldFail) {
      throw StateError('Simulated planning dataset read failure');
    }
    return super.getPlanningDataset(courseId: courseId);
  }
}

void main() {
  sqfliteFfiInit();

  late Database database;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createMinimalFixture(database);
  });

  tearDown(() async {
    if (database.isOpen) {
      await database.close();
    }
  });

  test(
    'CourseKnowledgeRepositoryImpl getPlanningDataset failure sonrasında retry ile yeniden dener',
    () async {
      final dataSource = _FailingPlanningDataSource(database);
      final repository = CourseKnowledgeRepositoryImpl(
        dataSource: dataSource,
        manifest: const RuntimeManifest(
          runtimePackageVersion: '1.0.0',
          schemaVersion: '1.0.0',
          courseId: 'TDE_9',
          validationStatus: 'PASS',
          canonicalContentFingerprint: 'TDE_9',
          rowCounts: {},
          timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
          timelineUnresolvedFields: {},
        ),
      );

      // 1. çağrı hata fırlatır
      dataSource.shouldFail = true;
      await expectLater(
        () => repository.getPlanningDataset(),
        throwsA(isA<StateError>()),
      );
      expect(dataSource.calls, 1);

      // 2. çağrıda hata düzeldiğinde cached failed Future yerine dataSource tekrar çağrılır
      dataSource.shouldFail = false;
      final dataset = await repository.getPlanningDataset();
      expect(dataSource.calls, 2);
      expect(dataset.courseId, 'TDE_9');

      // 3. çağrıda başarılı sonuç cache'ten döner
      final cachedDataset = await repository.getPlanningDataset();
      expect(dataSource.calls, 2);
      expect(cachedDataset.courseId, dataset.courseId);
    },
  );

  test(
    'CourseDatabaseDataSource getAnnualSequence failure sonrasında retry ile yeniden dener',
    () async {
      final dataSource = CourseDatabaseDataSource(database);

      await database.execute(
        'ALTER TABLE timeline_blocks RENAME TO timeline_blocks_bak',
      );

      // 1. çağrı tablo olmadığı için hata verir
      await expectLater(
        () => dataSource.getAnnualSequence(),
        throwsA(isA<Exception>()),
      );

      // Tabloyu geri getir
      await database.execute(
        'ALTER TABLE timeline_blocks_bak RENAME TO timeline_blocks',
      );

      // 2. çağrıda cached failure yerine tekrar sorgu atıp başarılı olmalı
      final sequence = await dataSource.getAnnualSequence();
      expect(sequence, isNotEmpty);
      expect(sequence.first.theme.id, 'T1');

      // 3. çağrı başarılı cache'ten döner
      final cachedSequence = await dataSource.getAnnualSequence();
      expect(identical(cachedSequence, sequence), isTrue);
    },
  );
}

Future<void> _createMinimalFixture(Database database) async {
  await database.execute('''
    CREATE TABLE courses (
      course_id TEXT PRIMARY KEY,
      grade INTEGER NOT NULL,
      title TEXT NOT NULL,
      schema_version TEXT NOT NULL,
      source_manifest_fingerprint TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE themes (
      theme_id TEXT PRIMARY KEY,
      theme_order INTEGER NOT NULL,
      title TEXT NOT NULL,
      page_range TEXT,
      planned_hours INTEGER,
      anlama_hours INTEGER,
      anlatma_hours INTEGER,
      source_locator TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE blocks (
      block_id TEXT PRIMARY KEY,
      theme_id TEXT NOT NULL,
      block_order INTEGER NOT NULL,
      title TEXT NOT NULL,
      skill_domain TEXT,
      learning_area TEXT,
      planned_hours INTEGER,
      time_status TEXT,
      source_locators_json TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE timeline_blocks (
      block_id TEXT PRIMARY KEY,
      theme_id TEXT NOT NULL,
      block_order INTEGER NOT NULL,
      planned_hours INTEGER,
      time_status TEXT,
      source_locators_json TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE timeline_themes (
      theme_id TEXT PRIMARY KEY,
      official_total_hours INTEGER,
      core_instruction_hours INTEGER,
      school_based_hours INTEGER,
      school_based_hours_status TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE block_outcomes (
      block_id TEXT NOT NULL,
      outcome_id TEXT NOT NULL,
      PRIMARY KEY (block_id, outcome_id)
    )
  ''');
  await database.execute('''
    CREATE TABLE outcomes (
      outcome_id TEXT PRIMARY KEY,
      theme_id TEXT NOT NULL,
      outcome_code TEXT NOT NULL,
      official_text TEXT NOT NULL,
      process_components TEXT,
      source_locator TEXT,
      verification_status TEXT
    )
  ''');

  await database.insert('courses', {
    'course_id': 'TDE_9',
    'grade': 9,
    'title': 'Türk Dili ve Edebiyatı 9',
    'schema_version': '1.0.0',
    'source_manifest_fingerprint': 'fixture-fingerprint',
  });

  await database.insert('themes', {
    'theme_id': 'T1',
    'theme_order': 1,
    'title': 'Tema 1',
    'planned_hours': 45,
  });
  await database.insert('timeline_themes', {
    'theme_id': 'T1',
    'official_total_hours': 45,
    'core_instruction_hours': 45,
    'school_based_hours': 0,
    'school_based_hours_status': 'RESOLVED',
  });
  await database.insert('blocks', {
    'block_id': 'B1',
    'theme_id': 'T1',
    'block_order': 1,
    'title': 'Blok 1',
    'time_status': 'ORDER_ONLY',
    'source_locators_json': '[]',
  });
  await database.insert('timeline_blocks', {
    'block_id': 'B1',
    'theme_id': 'T1',
    'block_order': 1,
    'time_status': 'ORDER_ONLY',
    'source_locators_json': '[]',
  });
  await database.insert('outcomes', {
    'outcome_id': 'O1',
    'theme_id': 'T1',
    'outcome_code': 'TDE.1',
    'official_text': 'Kazanım 1',
    'verification_status': 'PASS',
  });
  await database.insert('block_outcomes', {
    'block_id': 'B1',
    'outcome_id': 'O1',
  });
}
