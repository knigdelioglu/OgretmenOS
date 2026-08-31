import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/instruction_context_repository_impl.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:ogretmen_os/domain/models/instruction_context_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'production SQLite repository academic-year collision ve kapsamı korur',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ogretmen_os_instruction_context_repository_',
      );
      final path = '${directory.path}/teacher_state.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final database = await OutcomeTrackingDatabase.open(pathOverride: path);
      addTearDown(database.close);
      final repository = SqfliteInstructionContextRepository(database.database);
      final now = DateTime.utc(2026, 8, 1);

      await repository.replaceBellPeriods(const [
        BellPeriod(periodNumber: 1, startMinute: 480, endMinute: 520),
        BellPeriod(periodNumber: 2, startMinute: 530, endMinute: 570),
      ]);

      final classA = _class('class-a-26', '2026-2027', '9/A', now);
      final classB = _class('class-b-26', '2026-2027', '9/B', now);
      final classNextYear = _class('class-a-27', '2027-2028', '9/A', now);
      await repository.saveClass(classA);
      await repository.saveClass(classB);
      await repository.saveClass(classNextYear);

      final assignmentA = _assignment('assignment-a-26', classA, 'TDE_9', now);
      final assignmentB = _assignment('assignment-b-26', classB, 'TDE_9', now);
      final assignmentNextYear = _assignment(
        'assignment-a-27',
        classNextYear,
        'TDE_9',
        now,
      );
      await repository.saveAssignment(assignmentA);
      await repository.saveAssignment(assignmentB);
      await repository.saveAssignment(assignmentNextYear);

      final slotA = _slot('slot-a-26', assignmentA.id, 1, 1, now);
      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: assignmentA.id,
        slots: [slotA],
      );

      expect(
        () => repository.replaceScheduleSlotsForAssignment(
          assignmentId: assignmentB.id,
          slots: [_slot('slot-b-26', assignmentB.id, 1, 1, now)],
        ),
        throwsA(isA<ScheduleSlotConflictException>()),
      );
      expect(
        await repository.getScheduleSlotsForAssignment(assignmentB.id),
        isEmpty,
      );

      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: assignmentB.id,
        slots: [_slot('slot-b-26', assignmentB.id, 1, 2, now)],
      );
      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: assignmentNextYear.id,
        slots: [_slot('slot-a-27', assignmentNextYear.id, 1, 1, now)],
      );

      final rows = await database.database.query(
        'lesson_schedule_slots',
        orderBy: 'slot_id ASC',
      );
      expect(rows, hasLength(3));
      final academicYears = rows.map((row) => row['academic_year']).toSet();
      expect(academicYears, hasLength(2));
      expect(academicYears, containsAll(['2026-2027', '2027-2028']));

      // An idempotent write must update the existing row rather than attempting
      // a second insert when SQLite reports no changed values.
      await repository.saveClass(classA);
      await repository.saveAssignment(assignmentA);
      expect(await repository.getClass(classA.id), isNotNull);
      expect(await repository.getAssignment(assignmentA.id), isNotNull);
    },
  );
}

SchoolClass _class(
  String id,
  String academicYear,
  String displayName,
  DateTime now,
) => SchoolClass(
  id: id,
  academicYear: academicYear,
  grade: 9,
  section: displayName.split('/').last,
  displayName: displayName,
  createdAt: now,
  updatedAt: now,
);

TeachingAssignment _assignment(
  String id,
  SchoolClass schoolClass,
  String courseId,
  DateTime now,
) => TeachingAssignment(
  id: id,
  academicYear: schoolClass.academicYear,
  courseId: courseId,
  classId: schoolClass.id,
  isActive: true,
  createdAt: now,
  updatedAt: now,
);

LessonScheduleSlot _slot(
  String id,
  String assignmentId,
  int weekday,
  int periodNumber,
  DateTime now,
) => LessonScheduleSlot(
  id: id,
  assignmentId: assignmentId,
  weekday: weekday,
  periodNumber: periodNumber,
  createdAt: now,
  updatedAt: now,
);
