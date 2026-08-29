import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/assignment_lesson_progress_models.dart';
import 'package:ogretmen_os/domain/models/assignment_outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/instruction_context_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_progress_models.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/assignment_lesson_progress_repository.dart';
import 'package:ogretmen_os/domain/repositories/assignment_outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/repositories/instruction_context_repository.dart';
import 'package:ogretmen_os/domain/repositories/lesson_plan_progress_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/assignment_lesson_timeline_service.dart';
import 'package:ogretmen_os/domain/services/assignment_progress_cursor_service.dart';
import 'package:ogretmen_os/domain/services/legacy_teacher_state_migration_service.dart';

void main() {
  group('assignment schedule progression', () {
    test(
      'Pazartesi 2 + Çarşamba 2 + Cuma 1 programında Cuma dersi 5. konumu otomatik çözer',
      () async {
        final instructionContext = MemoryInstructionContextRepository();
        final lessonProgress = MemoryAssignmentLessonProgressRepository();
        await _seedAssignment(
          instructionContext,
          academicYear: _academicYear,
          assignmentId: 'a9a',
          classId: 'c9a',
          courseId: 'TDE_9',
          grade: 9,
          displayName: '9/A',
        );
        await instructionContext.replaceBellPeriods(const [
          BellPeriod(periodNumber: 1, startMinute: 8 * 60, endMinute: 8 * 60 + 40),
          BellPeriod(periodNumber: 2, startMinute: 8 * 60 + 50, endMinute: 9 * 60 + 30),
        ]);
        await instructionContext.replaceScheduleSlotsForAssignment(
          assignmentId: 'a9a',
          slots: _slots('a9a', const [
            (DateTime.monday, 1),
            (DateTime.monday, 2),
            (DateTime.wednesday, 1),
            (DateTime.wednesday, 2),
            (DateTime.friday, 1),
          ]),
        );

        final timeline = AssignmentLessonTimelineService(
          instructionContext: instructionContext,
          weeklyPlanning: _FixedWeeklyPlanningService(
            _oneWeekPlan(
              courseId: 'TDE_9',
              start: DateTime(2026, 9, 14),
              end: DateTime(2026, 9, 18),
            ),
          ),
        );

        final before = await lessonProgress.getForAssignment('a9a');
        final snapshot = await timeline.resolve(
          academicYear: _academicYear,
          courseId: 'TDE_9',
          now: DateTime(2026, 9, 18, 8, 20),
        );
        final after = await lessonProgress.getForAssignment('a9a');

        expect(before, isEmpty);
        expect(snapshot.currentOccurrence?.assignmentId, 'a9a');
        expect(snapshot.currentOccurrence?.plannedOrdinal, 5);
        expect(snapshot.positionFor('a9a')?.plannedOrdinal, 5);
        expect(snapshot.positionFor('a9a')?.actualOrdinal, 5);
        expect(after, isEmpty, reason: 'Takvim ilerlemesi explicit İşlendi kaydı yazmamalı.');
      },
    );

    test('manual offset sonraki derslerde korunur ve yeniden eşitlenebilir', () async {
      final repository = MemoryInstructionContextRepository();
      await _seedAssignment(
        repository,
        academicYear: _academicYear,
        assignmentId: 'a9a',
        classId: 'c9a',
        courseId: 'TDE_9',
        grade: 9,
        displayName: '9/A',
      );
      final service = AssignmentProgressCursorService(repository: repository);

      final cursor = await service.setActualPosition(
        assignmentId: 'a9a',
        plannedOrdinal: 5,
        actualOrdinal: 3,
        now: DateTime(2026, 9, 18, 9),
      );

      expect(cursor.mode, AssignmentProgressMode.manualOffset);
      expect(cursor.actualOrdinalForPlanned(6), 4);
      expect((await repository.getProgressCursor('a9a'))?.actualOrdinalForPlanned(7), 5);

      await service.followSchedule('a9a');
      expect(await repository.getProgressCursor('a9a'), isNull);
    });

    test('program düzenlemesi manual offset gerçek konumunu zıplatmaz', () async {
      final repository = MemoryInstructionContextRepository();
      await _seedAssignment(
        repository,
        academicYear: _academicYear,
        assignmentId: 'a9a',
        classId: 'c9a',
        courseId: 'TDE_9',
        grade: 9,
        displayName: '9/A',
      );
      final service = AssignmentProgressCursorService(repository: repository);
      await service.setActualPosition(
        assignmentId: 'a9a',
        plannedOrdinal: 5,
        actualOrdinal: 3,
        now: DateTime(2026, 9, 18, 9),
      );

      final reanchored = await service.reanchorForScheduleChange(
        assignmentId: 'a9a',
        oldPlannedOrdinal: 5,
        newPlannedOrdinal: 4,
        now: DateTime(2026, 9, 18, 10),
      );

      expect(reanchored, isNotNull);
      expect(reanchored!.actualOrdinalAtAnchor, 3);
      expect(reanchored.plannedOrdinalAtAnchor, 4);
      expect(reanchored.actualOrdinalForPlanned(5), 4);
    });
  });

  group('schedule collision scope', () {
    test('aynı akademik yılda aynı gün/saat iki assignment tarafından kullanılamaz', () async {
      final repository = MemoryInstructionContextRepository();
      await repository.replaceBellPeriods(const [
        BellPeriod(periodNumber: 1, startMinute: 480, endMinute: 520),
      ]);
      await _seedAssignment(
        repository,
        academicYear: _academicYear,
        assignmentId: 'a9a',
        classId: 'c9a',
        courseId: 'TDE_9',
        grade: 9,
        displayName: '9/A',
      );
      await _seedAssignment(
        repository,
        academicYear: _academicYear,
        assignmentId: 'a10a',
        classId: 'c10a',
        courseId: 'TDE_10',
        grade: 10,
        displayName: '10/A',
      );
      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: 'a9a',
        slots: _slots('a9a', const [(DateTime.monday, 1)]),
      );

      expect(
        () => repository.replaceScheduleSlotsForAssignment(
          assignmentId: 'a10a',
          slots: _slots('a10a', const [(DateTime.monday, 1)]),
        ),
        throwsA(isA<ScheduleSlotConflictException>()),
      );
    });

    test('farklı akademik yıllar aynı haftalık hücreyi kullanabilir', () async {
      final repository = MemoryInstructionContextRepository();
      await repository.replaceBellPeriods(const [
        BellPeriod(periodNumber: 1, startMinute: 480, endMinute: 520),
      ]);
      await _seedAssignment(
        repository,
        academicYear: _academicYear,
        assignmentId: 'a9a-26',
        classId: 'c9a-26',
        courseId: 'TDE_9',
        grade: 9,
        displayName: '9/A',
      );
      await _seedAssignment(
        repository,
        academicYear: '2027-2028',
        assignmentId: 'a9a-27',
        classId: 'c9a-27',
        courseId: 'TDE_9',
        grade: 9,
        displayName: '9/A',
      );

      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: 'a9a-26',
        slots: _slots('a9a-26', const [(DateTime.monday, 1)]),
      );
      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: 'a9a-27',
        slots: _slots('a9a-27', const [(DateTime.monday, 1)]),
      );

      expect(await repository.getScheduleSlotsForAssignment('a9a-26'), hasLength(1));
      expect(await repository.getScheduleSlotsForAssignment('a9a-27'), hasLength(1));
    });
  });

  group('assignment state isolation', () {
    test('lesson progress aynı package/hour için şubeler arasında sızmaz', () async {
      final repository = MemoryAssignmentLessonProgressRepository();
      final now = DateTime(2026, 9, 18, 10);
      await repository.save(
        AssignmentLessonProgressRecord(
          assignmentId: 'a9a',
          packageId: 'p1',
          packageHour: 2,
          payloadSha256: 'hash',
          status: LessonPlanProgressStatus.completed,
          completedAt: now,
          updatedAt: now,
        ),
      );

      expect(
        (await repository.get(
          assignmentId: 'a9a',
          packageId: 'p1',
          packageHour: 2,
        ))?.status,
        LessonPlanProgressStatus.completed,
      );
      expect(
        await repository.get(
          assignmentId: 'a9b',
          packageId: 'p1',
          packageHour: 2,
        ),
        isNull,
      );
    });

    test('outcome tracking aynı outcome/week için şubeler arasında sızmaz', () async {
      final repository = MemoryAssignmentOutcomeTrackingRepository();
      final now = DateTime(2026, 9, 18, 10);
      await repository.save(
        AssignmentOutcomeTrackingRecord(
          assignmentId: 'a9a',
          outcomeId: 'o1',
          plannedWeekNumber: 1,
          status: OutcomeTrackingStatus.completed,
          updatedAt: now,
        ),
      );

      expect(
        (await repository.get(
          assignmentId: 'a9a',
          outcomeId: 'o1',
          plannedWeekNumber: 1,
        ))?.status,
        OutcomeTrackingStatus.completed,
      );
      expect(
        await repository.get(
          assignmentId: 'a9b',
          outcomeId: 'o1',
          plannedWeekNumber: 1,
        ),
        isNull,
      );
    });
  });

  group('legacy teacher-state migration', () {
    test('explicit target zorunlu; kaynak korunur ve mevcut hedef overwrite edilmez', () async {
      final legacyLessons = MemoryLessonPlanProgressRepository();
      final legacyOutcomes = MemoryOutcomeTrackingRepository();
      final targetLessons = MemoryAssignmentLessonProgressRepository();
      final targetOutcomes = MemoryAssignmentOutcomeTrackingRepository();
      final service = LegacyTeacherStateMigrationService(
        legacyLessonProgress: legacyLessons,
        legacyOutcomeTracking: legacyOutcomes,
        assignmentLessonProgress: targetLessons,
        assignmentOutcomeTracking: targetOutcomes,
      );
      final now = DateTime(2026, 9, 18, 10);

      await legacyLessons.save(
        LessonPlanProgressRecord(
          courseId: 'TDE_9',
          academicYear: _academicYear,
          packageId: 'p1::lesson-hour:2',
          payloadSha256: 'legacy-hash-1',
          status: LessonPlanProgressStatus.completed,
          completedAt: now,
          updatedAt: now,
        ),
      );
      await legacyLessons.save(
        LessonPlanProgressRecord(
          courseId: 'TDE_9',
          academicYear: _academicYear,
          packageId: 'p2::lesson-hour:1',
          payloadSha256: 'legacy-hash-2',
          status: LessonPlanProgressStatus.inProgress,
          startedAt: now,
          updatedAt: now,
        ),
      );
      await legacyLessons.save(
        LessonPlanProgressRecord(
          courseId: 'TDE_9',
          academicYear: _academicYear,
          packageId: 'malformed',
          status: LessonPlanProgressStatus.completed,
          updatedAt: now,
        ),
      );
      await legacyOutcomes.save(
        LearningOutcomeTrackingRecord(
          academicYear: _academicYear,
          outcomeId: 'o1',
          plannedWeekNumber: 1,
          status: OutcomeTrackingStatus.completed,
          updatedAt: now,
        ),
      );
      await legacyOutcomes.save(
        LearningOutcomeTrackingRecord(
          academicYear: _academicYear,
          outcomeId: 'o2',
          plannedWeekNumber: 1,
          status: OutcomeTrackingStatus.inProgress,
          updatedAt: now,
        ),
      );
      await legacyOutcomes.save(
        LearningOutcomeTrackingRecord(
          academicYear: _academicYear,
          outcomeId: 'outside',
          plannedWeekNumber: 1,
          status: OutcomeTrackingStatus.completed,
          updatedAt: now,
        ),
      );

      await targetLessons.save(
        AssignmentLessonProgressRecord(
          assignmentId: 'a9a',
          packageId: 'p1',
          packageHour: 2,
          payloadSha256: 'target-hash',
          status: LessonPlanProgressStatus.inProgress,
          updatedAt: now,
        ),
      );
      await targetOutcomes.save(
        AssignmentOutcomeTrackingRecord(
          assignmentId: 'a9a',
          outcomeId: 'o1',
          plannedWeekNumber: 1,
          status: OutcomeTrackingStatus.partiallyCompleted,
          updatedAt: now,
        ),
      );

      expect(
        () => service.migrateToAssignment(
          assignmentId: '   ',
          courseId: 'TDE_9',
          academicYear: _academicYear,
          allowedOutcomeIds: const {'o1', 'o2'},
        ),
        throwsArgumentError,
      );

      final report = await service.migrateToAssignment(
        assignmentId: 'a9a',
        courseId: 'TDE_9',
        academicYear: _academicYear,
        allowedOutcomeIds: const {'o1', 'o2'},
      );

      expect(report.lessonsCopied, 1);
      expect(report.lessonsSkippedMalformed, 1);
      expect(report.lessonsSkippedExisting, 1);
      expect(report.outcomesCopied, 1);
      expect(report.outcomesSkippedOutsideCourse, 1);
      expect(report.outcomesSkippedExisting, 1);
      expect(
        (await targetLessons.get(
          assignmentId: 'a9a',
          packageId: 'p1',
          packageHour: 2,
        ))?.payloadSha256,
        'target-hash',
      );
      expect(
        (await targetOutcomes.get(
          assignmentId: 'a9a',
          outcomeId: 'o1',
          plannedWeekNumber: 1,
        ))?.status,
        OutcomeTrackingStatus.partiallyCompleted,
      );
      expect(
        await targetLessons.get(
          assignmentId: 'a9a',
          packageId: 'p2',
          packageHour: 1,
        ),
        isNotNull,
      );
      expect(
        await targetOutcomes.get(
          assignmentId: 'a9a',
          outcomeId: 'o2',
          plannedWeekNumber: 1,
        ),
        isNotNull,
      );
      expect(
        await legacyLessons.get(
          courseId: 'TDE_9',
          academicYear: _academicYear,
          packageId: 'p1::lesson-hour:2',
        ),
        isNotNull,
      );
      expect(await legacyOutcomes.getForAcademicYear(_academicYear), hasLength(3));
    });
  });
}

const _academicYear = '2026-2027';

class _FixedWeeklyPlanningService implements WeeklyPlanningService {
  const _FixedWeeklyPlanningService(this.plan);

  final AnnualWeeklyPlan plan;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async => plan;
}

AnnualWeeklyPlan _oneWeekPlan({
  required String courseId,
  required DateTime start,
  required DateTime end,
}) => AnnualWeeklyPlan(
  academicYear: _academicYear,
  courseId: courseId,
  weeklyLessonHours: 5,
  annualHours: 180,
  weeks: [
    AcademicWeekPlan(
      weekNumber: 1,
      start: start,
      end: end,
      type: AcademicWeekType.instruction,
      label: '1. Hafta',
      plannedLessonHours: 5,
      segments: const [],
      outcomes: const [],
    ),
  ],
  currentWeekNumber: 1,
);

Future<void> _seedAssignment(
  MemoryInstructionContextRepository repository, {
  required String academicYear,
  required String assignmentId,
  required String classId,
  required String courseId,
  required int grade,
  required String displayName,
}) async {
  final now = DateTime(2026, 8, 1);
  final section = displayName.contains('/') ? displayName.split('/').last : 'A';
  await repository.saveClass(
    SchoolClass(
      id: classId,
      academicYear: academicYear,
      grade: grade,
      section: section,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveAssignment(
    TeachingAssignment(
      id: assignmentId,
      academicYear: academicYear,
      courseId: courseId,
      classId: classId,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

List<LessonScheduleSlot> _slots(
  String assignmentId,
  List<(int, int)> values,
) {
  final now = DateTime(2026, 8, 1);
  return [
    for (var index = 0; index < values.length; index++)
      LessonScheduleSlot(
        id: '${assignmentId}_$index',
        assignmentId: assignmentId,
        weekday: values[index].$1,
        periodNumber: values[index].$2,
        createdAt: now,
        updatedAt: now,
      ),
  ];
}
