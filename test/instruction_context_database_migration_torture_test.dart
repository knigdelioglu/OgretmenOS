import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  for (final version in [1, 2, 3, 4]) {
    test('v$version → v6 migration tüm legacy veriyi korur', () async {
      final directory = await Directory.systemTemp.createTemp(
        'ogretmen_os_teacher_state_v${version}_',
      );
      final path = '${directory.path}/teacher_state.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final legacy = await _openLegacy(path, version);
      final timestamp = DateTime.utc(2026, 8, 1).toIso8601String();
      await legacy.insert('outcome_tracking', {
        'academic_year': '2026-2027',
        'outcome_id': 'TDE9.1',
        'planned_week_number': 2,
        'status': 'in_progress',
        'actual_hours': 1,
        'teacher_note': 'korunmalı not',
        'completed_at': null,
        'carried_to_week_number': null,
        'updated_at': timestamp,
      });
      if (version >= 2) {
        final row = <String, Object?>{
          'course_id': 'TDE_9',
          'academic_year': '2026-2027',
          'package_id': 'pkg-1',
          'status': 'started',
          'started_at': timestamp,
          'completed_at': null,
          'updated_at': timestamp,
        };
        if (version >= 3) row['payload_sha256'] = 'sha-legacy';
        await legacy.insert('lesson_plan_progress', row);
      }
      if (version == 4) {
        await _seedLegacySchedule(legacy, timestamp);
        await legacy.insert('assignment_lesson_progress', {
          'assignment_id': 'assignment-1',
          'package_id': 'pkg-1',
          'package_hour': 2,
          'payload_sha256': 'stale-payload-hash',
          'status': 'completed',
          'started_at': timestamp,
          'completed_at': timestamp,
          'updated_at': timestamp,
        });
        await legacy.insert('assignment_outcome_tracking', {
          'assignment_id': 'assignment-1',
          'outcome_id': 'TDE9.1',
          'planned_week_number': 2,
          'status': 'completed',
          'actual_hours': 2,
          'teacher_note': 'şube notu korunmalı',
          'completed_at': timestamp,
          'carried_to_week_number': null,
          'updated_at': timestamp,
        });
        await legacy.insert('assignment_progress_cursor', {
          'assignment_id': 'assignment-1',
          'mode': 'manual_offset',
          'planned_ordinal_at_anchor': 4,
          'actual_ordinal_at_anchor': 3,
          'anchored_at': timestamp,
          'updated_at': timestamp,
        });
      }
      await legacy.close();

      final migrated = await OutcomeTrackingDatabase.open(pathOverride: path);
      addTearDown(migrated.close);

      expect(
        (await migrated.database.rawQuery(
          'PRAGMA user_version',
        )).single['user_version'],
        6,
      );
      final outcomes = await migrated.database.query('outcome_tracking');
      expect(outcomes, hasLength(1));
      expect(outcomes.single['academic_year'], '2026-2027');
      expect(outcomes.single['teacher_note'], 'korunmalı not');
      if (version >= 2) {
        final progress = await migrated.database.query('lesson_plan_progress');
        expect(progress, hasLength(1));
        expect(progress.single['package_id'], 'pkg-1');
        expect(
          progress.single['payload_sha256'],
          version >= 3 ? 'sha-legacy' : isNull,
        );
      }
      if (version == 4) {
        final slots = await migrated.database.query('lesson_schedule_slots');
        expect(slots, hasLength(5));
        expect(
          slots.where((row) => row['academic_year'] == '2026-2027'),
          hasLength(4),
        );
        expect(
          slots.where((row) => row['academic_year'] == '2027-2028'),
          hasLength(1),
        );
        final lessonProgress = await migrated.database.query(
          'assignment_lesson_progress',
        );
        expect(lessonProgress, hasLength(1));
        expect(lessonProgress.single['payload_sha256'], 'stale-payload-hash');
        final outcomeProgress = await migrated.database.query(
          'assignment_outcome_tracking',
        );
        expect(outcomeProgress, hasLength(1));
        expect(outcomeProgress.single['teacher_note'], 'şube notu korunmalı');
        final cursor = await migrated.database.query(
          'assignment_progress_cursor',
        );
        expect(cursor, hasLength(1));
        expect(cursor.single['actual_ordinal_at_anchor'], 3);
      }
    });
  }

  test(
    'v4 → v6 orphan schedule kaydını silmek yerine migrationı durdurur',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ogretmen_os_teacher_state_orphan_',
      );
      final path = '${directory.path}/teacher_state.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final legacy = await _openLegacy(path, 4, enableForeignKeys: false);
      final timestamp = DateTime.utc(2026, 8, 1).toIso8601String();
      await legacy.insert('bell_periods', {
        'period_number': 1,
        'start_minute': 480,
        'end_minute': 520,
      });
      await legacy.insert('lesson_schedule_slots', {
        'slot_id': 'orphan-slot',
        'assignment_id': 'missing-assignment',
        'weekday': DateTime.monday,
        'period_number': 1,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await legacy.close();

      expect(
        () => OutcomeTrackingDatabase.open(pathOverride: path),
        throwsA(isA<StateError>()),
      );

      final unchanged = await openDatabase(path, version: 4);
      addTearDown(unchanged.close);
      expect(
        (await unchanged.rawQuery(
          'PRAGMA user_version',
        )).single['user_version'],
        4,
      );
      expect(await unchanged.query('lesson_schedule_slots'), hasLength(1));
      expect(
        (await unchanged.query('lesson_schedule_slots')).single['slot_id'],
        'orphan-slot',
      );
    },
  );
}

Future<Database> _openLegacy(
  String path,
  int version, {
  bool enableForeignKeys = true,
}) => openDatabase(
  path,
  version: version,
  onConfigure: (db) async {
    await db.execute('PRAGMA foreign_keys = ${enableForeignKeys ? 1 : 0}');
  },
  onCreate: (db, _) async {
    await db.execute('''
      CREATE TABLE outcome_tracking (
        academic_year TEXT NOT NULL,
        outcome_id TEXT NOT NULL,
        planned_week_number INTEGER NOT NULL,
        status TEXT NOT NULL,
        actual_hours INTEGER,
        teacher_note TEXT,
        completed_at TEXT,
        carried_to_week_number INTEGER,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (academic_year, outcome_id, planned_week_number)
      )
    ''');
    if (version >= 2) {
      await db.execute('''
        CREATE TABLE lesson_plan_progress (
          course_id TEXT NOT NULL,
          academic_year TEXT NOT NULL,
          package_id TEXT NOT NULL,
          ${version >= 3 ? 'payload_sha256 TEXT,' : ''}
          status TEXT NOT NULL,
          started_at TEXT,
          completed_at TEXT,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (course_id, academic_year, package_id)
        )
      ''');
    }
    if (version == 4) {
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
      await db.execute('''
        CREATE TABLE assignment_progress_cursor (
          assignment_id TEXT PRIMARY KEY,
          mode TEXT NOT NULL,
          planned_ordinal_at_anchor INTEGER NOT NULL,
          actual_ordinal_at_anchor INTEGER NOT NULL,
          anchored_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
            ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE assignment_lesson_progress (
          assignment_id TEXT NOT NULL,
          package_id TEXT NOT NULL,
          package_hour INTEGER NOT NULL,
          payload_sha256 TEXT,
          status TEXT NOT NULL,
          started_at TEXT,
          completed_at TEXT,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (assignment_id, package_id, package_hour),
          FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
            ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE assignment_outcome_tracking (
          assignment_id TEXT NOT NULL,
          outcome_id TEXT NOT NULL,
          planned_week_number INTEGER NOT NULL,
          status TEXT NOT NULL,
          actual_hours INTEGER,
          teacher_note TEXT,
          completed_at TEXT,
          carried_to_week_number INTEGER,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (assignment_id, outcome_id, planned_week_number),
          FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
            ON DELETE CASCADE
        )
      ''');
    }
  },
);

Future<void> _seedLegacySchedule(Database db, String timestamp) async {
  await db.insert('school_classes', {
    'class_id': 'class-1',
    'academic_year': '2026-2027',
    'grade': 9,
    'section': 'A',
    'display_name': '9/A',
    'created_at': timestamp,
    'updated_at': timestamp,
  });
  await db.insert('teaching_assignments', {
    'assignment_id': 'assignment-1',
    'academic_year': '2026-2027',
    'course_id': 'TDE_9',
    'class_id': 'class-1',
    'is_active': 1,
    'created_at': timestamp,
    'updated_at': timestamp,
  });
  const additional = [
    {
      'class_id': 'class-b-1',
      'academic_year': '2026-2027',
      'grade': 9,
      'section': 'B',
      'display_name': '9/B',
      'assignment_id': 'assignment-b-1',
      'course_id': 'TDE_9',
    },
    {
      'class_id': 'class-c-1',
      'academic_year': '2026-2027',
      'grade': 9,
      'section': 'C',
      'display_name': '9/C',
      'assignment_id': 'assignment-c-1',
      'course_id': 'TDE_9',
    },
    {
      'class_id': 'class-tde10-1',
      'academic_year': '2026-2027',
      'grade': 10,
      'section': 'A',
      'display_name': '10/A',
      'assignment_id': 'assignment-tde10-1',
      'course_id': 'TDE_10',
    },
    {
      'class_id': 'class-a-2',
      'academic_year': '2027-2028',
      'grade': 9,
      'section': 'A',
      'display_name': '9/A',
      'assignment_id': 'assignment-a-2',
      'course_id': 'TDE_9',
    },
  ];
  for (final item in additional) {
    await db.insert('school_classes', {
      'class_id': item['class_id'],
      'academic_year': item['academic_year'],
      'grade': item['grade'],
      'section': item['section'],
      'display_name': item['display_name'],
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await db.insert('teaching_assignments', {
      'assignment_id': item['assignment_id'],
      'academic_year': item['academic_year'],
      'course_id': item['course_id'],
      'class_id': item['class_id'],
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }
  await db.insert('bell_periods', {
    'period_number': 1,
    'start_minute': 480,
    'end_minute': 520,
  });
  await db.insert('bell_periods', {
    'period_number': 2,
    'start_minute': 530,
    'end_minute': 570,
  });
  await db.insert('lesson_schedule_slots', {
    'slot_id': 'slot-1',
    'assignment_id': 'assignment-1',
    'weekday': DateTime.monday,
    'period_number': 1,
    'created_at': timestamp,
    'updated_at': timestamp,
  });
  const additionalSlots = [
    ('slot-2', 'assignment-b-1', DateTime.tuesday, 1),
    ('slot-3', 'assignment-c-1', DateTime.wednesday, 1),
    ('slot-4', 'assignment-tde10-1', DateTime.thursday, 1),
    ('slot-5', 'assignment-a-2', DateTime.friday, 2),
  ];
  for (final item in additionalSlots) {
    await db.insert('lesson_schedule_slots', {
      'slot_id': item.$1,
      'assignment_id': item.$2,
      'weekday': item.$3,
      'period_number': item.$4,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }
}
