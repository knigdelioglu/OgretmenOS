import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_progress_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('v1 teacher state v3e yükselirken kazanım kaydını korur', () async {
    final directory = await Directory.systemTemp.createTemp('ogretmen_os_p5_migration_');
    final path = '${directory.path}/teacher_state.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final legacy = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
        await db.execute('''
          CREATE INDEX idx_outcome_tracking_carry
          ON outcome_tracking (academic_year, carried_to_week_number)
        ''');
      },
    );
    await legacy.insert('outcome_tracking', {
      'academic_year': '2026-2027',
      'outcome_id': 'TDE.9.TEST',
      'planned_week_number': 1,
      'status': 'in_progress',
      'updated_at': DateTime.utc(2026, 9, 7, 10).toIso8601String(),
    });
    await legacy.close();

    final database = await OutcomeTrackingDatabase.open(pathOverride: path);
    addTearDown(database.close);

    final versionRows = await database.database.rawQuery('PRAGMA user_version');
    expect(versionRows.single['user_version'], 3);
    final outcomeRows = await database.database.query('outcome_tracking');
    expect(outcomeRows, hasLength(1));
    expect(outcomeRows.single['outcome_id'], 'TDE.9.TEST');

    final columns = await database.database.rawQuery(
      'PRAGMA table_info(lesson_plan_progress)',
    );
    expect(
      columns.map((row) => row['name']),
      contains('payload_sha256'),
    );
  });

  test('v2 progress v3e yükselirken kayıt korunur ve hashesiz stale adayı olur', () async {
    final directory = await Directory.systemTemp.createTemp('ogretmen_os_p5_v2_binding_');
    final path = '${directory.path}/teacher_state.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final legacy = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
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
        await db.execute('''
          CREATE INDEX idx_outcome_tracking_carry
          ON outcome_tracking (academic_year, carried_to_week_number)
        ''');
        await db.execute('''
          CREATE TABLE lesson_plan_progress (
            course_id TEXT NOT NULL,
            academic_year TEXT NOT NULL,
            package_id TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at TEXT,
            completed_at TEXT,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (course_id, academic_year, package_id)
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_lesson_plan_progress_scope
          ON lesson_plan_progress (course_id, academic_year, status)
        ''');
      },
    );
    final timestamp = DateTime.utc(2026, 9, 7, 10);
    await legacy.insert('lesson_plan_progress', {
      'course_id': 'TDE_9',
      'academic_year': '2026-2027',
      'package_id': 'BLOCK_A_P01',
      'status': 'completed',
      'started_at': timestamp.toIso8601String(),
      'completed_at': timestamp.toIso8601String(),
      'updated_at': timestamp.toIso8601String(),
    });
    await legacy.close();

    final database = await OutcomeTrackingDatabase.open(pathOverride: path);
    final repository = SqfliteLessonPlanProgressRepository(database.database);
    addTearDown(database.close);

    final versionRows = await database.database.rawQuery('PRAGMA user_version');
    expect(versionRows.single['user_version'], 3);
    final record = await repository.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: 'BLOCK_A_P01',
    );
    expect(record, isNotNull);
    expect(record!.status, LessonPlanProgressStatus.completed);
    expect(record.payloadSha256, isNull);
  });

  test('lesson plan progress hash ile kalıcı ve ders/yıl bazında izoledir', () async {
    final directory = await Directory.systemTemp.createTemp('ogretmen_os_p5_progress_');
    final path = '${directory.path}/teacher_state.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    var database = await OutcomeTrackingDatabase.open(pathOverride: path);
    var repository = SqfliteLessonPlanProgressRepository(database.database);
    final timestamp = DateTime(2026, 9, 7, 10);
    await repository.save(
      LessonPlanProgressRecord(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: 'BLOCK_A_P01',
        payloadSha256: 'sha256-tde9-p01',
        status: LessonPlanProgressStatus.completed,
        startedAt: timestamp,
        completedAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await repository.save(
      LessonPlanProgressRecord(
        courseId: 'TDE_10',
        academicYear: '2026-2027',
        packageId: 'BLOCK_A_P01',
        payloadSha256: 'sha256-tde10-p01',
        status: LessonPlanProgressStatus.inProgress,
        startedAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await database.close();

    database = await OutcomeTrackingDatabase.open(pathOverride: path);
    repository = SqfliteLessonPlanProgressRepository(database.database);
    final tde9 = await repository.getForCourseAcademicYear(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
    );
    final tde10 = await repository.getForCourseAcademicYear(
      courseId: 'TDE_10',
      academicYear: '2026-2027',
    );
    final nextYear = await repository.getForCourseAcademicYear(
      courseId: 'TDE_9',
      academicYear: '2027-2028',
    );

    expect(tde9, hasLength(1));
    expect(tde9.single.status, LessonPlanProgressStatus.completed);
    expect(tde9.single.payloadSha256, 'sha256-tde9-p01');
    expect(tde10, hasLength(1));
    expect(tde10.single.status, LessonPlanProgressStatus.inProgress);
    expect(tde10.single.payloadSha256, 'sha256-tde10-p01');
    expect(nextYear, isEmpty);
    await database.close();
  });
}
