import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('teacher tracking survives database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('ogretmen_os_tracking_');
    final path = '${directory.path}/teacher_state.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    var database = await OutcomeTrackingDatabase.open(pathOverride: path);
    var repository = SqfliteOutcomeTrackingRepository(database.database);
    final completedAt = DateTime(2026, 9, 18, 12, 30);
    final updatedAt = DateTime(2026, 9, 18, 12, 31);

    await repository.save(
      LearningOutcomeTrackingRecord(
        academicYear: '2026-2027',
        outcomeId: 'TDE.9.TEST',
        plannedWeekNumber: 1,
        status: OutcomeTrackingStatus.carriedOver,
        actualHours: 3,
        teacherNote: 'İki saat sonraki haftaya kaldı.',
        completedAt: completedAt,
        carriedToWeekNumber: 2,
        updatedAt: updatedAt,
      ),
    );
    await database.close();

    database = await OutcomeTrackingDatabase.open(pathOverride: path);
    repository = SqfliteOutcomeTrackingRepository(database.database);
    final records = await repository.getForAcademicYear('2026-2027');

    expect(records, hasLength(1));
    final record = records.single;
    expect(record.outcomeId, 'TDE.9.TEST');
    expect(record.plannedWeekNumber, 1);
    expect(record.status, OutcomeTrackingStatus.carriedOver);
    expect(record.actualHours, 3);
    expect(record.teacherNote, 'İki saat sonraki haftaya kaldı.');
    expect(record.carriedToWeekNumber, 2);
    expect(record.completedAt, isNotNull);

    await repository.delete(
      academicYear: '2026-2027',
      outcomeId: 'TDE.9.TEST',
      plannedWeekNumber: 1,
    );
    expect(await repository.getForAcademicYear('2026-2027'), isEmpty);
    await database.close();
  });
}
