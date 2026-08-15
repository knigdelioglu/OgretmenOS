import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late CourseDatabaseDataSource dataSource;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createRuntimeContractFixture(database);
    dataSource = CourseDatabaseDataSource(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('runtime fixture course ve 4 temayı gerçek SQLite sorgusuyla map eder', () async {
    final course = await dataSource.getCourse();
    final themes = await dataSource.getThemes();

    expect(course.courseId, 'TDE_9');
    expect(course.schemaVersion, '1.0.0');
    expect(themes, hasLength(4));
    expect(themes.map((theme) => theme.id), [
      'TEMA_01',
      'TEMA_02',
      'TEMA_03',
      'TEMA_04',
    ]);
  });

  test('annual sequence 16 blok ve tema sınırı komşuluğunu korur', () async {
    final sequence = await dataSource.getAnnualSequence();

    expect(sequence, hasLength(16));
    expect(sequence.first.sequencePosition, 1);
    expect(sequence.last.sequencePosition, 16);
    expect(sequence.first.block.id, 'TEMA_01_BLOK_01');
    expect(sequence.last.block.id, 'TEMA_04_BLOK_04');

    final firstTheme2Block = sequence[4].block;
    expect((await dataSource.getPreviousBlock(firstTheme2Block))?.id, 'TEMA_01_BLOK_04');
    expect(
      (await dataSource.getNextBlock(sequence[3].block))?.id,
      'TEMA_02_BLOK_01',
    );
  });
}

Future<void> _createRuntimeContractFixture(Database database) async {
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

  await database.insert('courses', {
    'course_id': 'TDE_9',
    'grade': 9,
    'title': 'Türk Dili ve Edebiyatı 9',
    'schema_version': '1.0.0',
    'source_manifest_fingerprint': 'fixture-fingerprint',
  });

  for (var themeOrder = 1; themeOrder <= 4; themeOrder++) {
    final themeId = 'TEMA_0$themeOrder';
    await database.insert('themes', {
      'theme_id': themeId,
      'theme_order': themeOrder,
      'title': 'Tema $themeOrder',
      'planned_hours': 45,
    });
    await database.insert('timeline_themes', {
      'theme_id': themeId,
      'official_total_hours': 45,
      'core_instruction_hours': 43,
      'school_based_hours': 2,
      'school_based_hours_status': 'RESOLVED',
    });

    for (var blockOrder = 1; blockOrder <= 4; blockOrder++) {
      final blockId = '${themeId}_BLOK_0$blockOrder';
      await database.insert('blocks', {
        'block_id': blockId,
        'theme_id': themeId,
        'block_order': blockOrder,
        'title': 'Blok $blockOrder',
        'time_status': 'ORDER_ONLY',
        'source_locators_json': '[]',
      });
      await database.insert('timeline_blocks', {
        'block_id': blockId,
        'theme_id': themeId,
        'block_order': blockOrder,
        'time_status': 'ORDER_ONLY',
        'source_locators_json': '[]',
      });
    }
  }
}
