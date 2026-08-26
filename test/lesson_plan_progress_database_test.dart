import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_progress_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('v1 teacher state v2ye yükselirken kazanım kaydını korur', () async {
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
    expect(versionRows.single['user_version'], 2);
    final outcomeRows = await database.database.query('outcome_tracking');
    expect(outcomeRows, hasLength(1));
    expect(outcomeRows.single['outcome_id'], 'TDE.9.TEST');

    final tables = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='lesson_plan_progress'",
    );
    expect(tables, hasLength(1));
  });

  test('lesson plan progress kalıcı ve ders/yıl bazında izoledir', () async {
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
    expect(tde10, hasLength(1));
    expect(tde10.single.status, LessonPlanProgressStatus.inProgress);
    expect(nextYear, isEmpty);
    await database.close();
  });
}
