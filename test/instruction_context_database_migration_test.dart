import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('v4 → v5 migration program satırını korur ve çakışmayı akademik yıl bazına taşır', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ogretmen_os_instruction_context_v4_v5_',
    );
    final path = '${directory.path}/teacher_state.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final legacy = await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE school_classes (
            class_id TEXT PRIMARY KEY,
            academic_year TEXT NOT NULL,
            grade INTEGER NOT NULL,
            section TEXT NOT NULL,
            display_name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE (academic_year, display_name)
          )
        ''');
        await db.execute('''
          CREATE TABLE teaching_assignments (
            assignment_id TEXT PRIMARY KEY,
            academic_year TEXT NOT NULL,
            course_id TEXT NOT NULL,
            class_id TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE (academic_year, course_id, class_id),
            FOREIGN KEY (class_id) REFERENCES school_classes(class_id)
              ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE bell_periods (
            period_number INTEGER PRIMARY KEY,
            start_minute INTEGER NOT NULL,
            end_minute INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE lesson_schedule_slots (
            slot_id TEXT PRIMARY KEY,
            assignment_id TEXT NOT NULL,
            weekday INTEGER NOT NULL,
            period_number INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE (weekday, period_number),
            FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
              ON DELETE CASCADE,
            FOREIGN KEY (period_number) REFERENCES bell_periods(period_number)
              ON DELETE RESTRICT
          )
        ''');
      },
    );

    final timestamp = DateTime.utc(2026, 8, 1).toIso8601String();
    await legacy.insert('school_classes', {
      'class_id': 'c26',
      'academic_year': '2026-2027',
      'grade': 9,
      'section': 'A',
      'display_name': '9/A',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await legacy.insert('teaching_assignments', {
      'assignment_id': 'a26',
      'academic_year': '2026-2027',
      'course_id': 'TDE_9',
      'class_id': 'c26',
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await legacy.insert('bell_periods', {
      'period_number': 1,
      'start_minute': 480,
      'end_minute': 520,
    });
    await legacy.insert('lesson_schedule_slots', {
      'slot_id': 'slot26',
      'assignment_id': 'a26',
      'weekday': DateTime.monday,
      'period_number': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await legacy.close();

    final migrated = await OutcomeTrackingDatabase.open(pathOverride: path);
    addTearDown(migrated.close);

    final versionRows = await migrated.database.rawQuery('PRAGMA user_version');
    expect(versionRows.single['user_version'], 5);

    final rows = await migrated.database.query('lesson_schedule_slots');
    expect(rows, hasLength(1));
    expect(rows.single['slot_id'], 'slot26');
    expect(rows.single['academic_year'], '2026-2027');
    expect(rows.single['assignment_id'], 'a26');

    final tableSql = await migrated.database.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'lesson_schedule_slots'",
    );
    expect(
      (tableSql.single['sql'] as String).replaceAll(RegExp(r'\s+'), ' '),
      contains('UNIQUE (academic_year, weekday, period_number)'),
    );

    await migrated.database.insert('school_classes', {
      'class_id': 'c27',
      'academic_year': '2027-2028',
      'grade': 9,
      'section': 'A',
      'display_name': '9/A',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await migrated.database.insert('teaching_assignments', {
      'assignment_id': 'a27',
      'academic_year': '2027-2028',
      'course_id': 'TDE_9',
      'class_id': 'c27',
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await migrated.database.insert('lesson_schedule_slots', {
      'slot_id': 'slot27',
      'assignment_id': 'a27',
      'academic_year': '2027-2028',
      'weekday': DateTime.monday,
      'period_number': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });

    expect(await migrated.database.query('lesson_schedule_slots'), hasLength(2));

    await migrated.database.insert('school_classes', {
      'class_id': 'c26b',
      'academic_year': '2026-2027',
      'grade': 9,
      'section': 'B',
      'display_name': '9/B',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await migrated.database.insert('teaching_assignments', {
      'assignment_id': 'a26b',
      'academic_year': '2026-2027',
      'course_id': 'TDE_9',
      'class_id': 'c26b',
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });

    expect(
      () => migrated.database.insert('lesson_schedule_slots', {
        'slot_id': 'slot26b',
        'assignment_id': 'a26b',
        'academic_year': '2026-2027',
        'weekday': DateTime.monday,
        'period_number': 1,
        'created_at': timestamp,
        'updated_at': timestamp,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
