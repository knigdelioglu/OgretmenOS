import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/instruction_context_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/instruction_context_repository.dart';
import 'package:ogretmen_os/domain/repositories/school_schedule_exception_repository.dart';
import 'package:ogretmen_os/domain/services/assignment_lesson_timeline_service.dart';

void main() {
  test(
    'schedule exception authority okunamazsa düzenli programdan sahte ŞU AN üretilmez',
    () async {
      final repository = MemoryInstructionContextRepository();
      final createdAt = DateTime(2026, 8, 1);
      await repository.saveClass(
        SchoolClass(
          id: 'c9a',
          academicYear: '2026-2027',
          grade: 9,
          section: 'A',
          displayName: '9/A',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      await repository.saveAssignment(
        TeachingAssignment(
          id: 'a9a',
          academicYear: '2026-2027',
          courseId: 'TDE_9',
          classId: 'c9a',
          isActive: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      await repository.replaceBellPeriods(const [
        BellPeriod(periodNumber: 1, startMinute: 480, endMinute: 520),
      ]);
      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: 'a9a',
        slots: [
          for (var weekday = DateTime.monday; weekday <= DateTime.friday; weekday++)
            LessonScheduleSlot(
              id: 'a9a-$weekday',
              assignmentId: 'a9a',
              weekday: weekday,
              periodNumber: 1,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
        ],
      );

      final plan = AnnualWeeklyPlan(
        academicYear: '2026-2027',
        courseId: 'TDE_9',
        weeklyLessonHours: 5,
        annualHours: 180,
        weeks: [
          AcademicWeekPlan(
            weekNumber: 1,
            start: DateTime(2026, 9, 14),
            end: DateTime(2026, 9, 18),
            type: AcademicWeekType.instruction,
            label: '1. Hafta',
            plannedLessonHours: 5,
            segments: const [],
            outcomes: const [],
          ),
        ],
        currentWeekNumber: 1,
      );
      final timeline = AssignmentLessonTimelineService(
        instructionContext: repository,
        weeklyPlanning: _FixedWeeklyPlanningService(plan),
        scheduleExceptions: const _ThrowingScheduleExceptionRepository(),
      );

      final snapshot = await timeline.resolve(
        academicYear: '2026-2027',
        courseId: 'TDE_9',
        now: DateTime(2026, 9, 14, 8, 20),
      );

      expect(snapshot.currentOccurrence, isNull);
      expect(snapshot.nextOccurrence, isNull);
      expect(snapshot.positions, isEmpty);
    },
  );
}

class _FixedWeeklyPlanningService implements WeeklyPlanningService {
  const _FixedWeeklyPlanningService(this.plan);

  final AnnualWeeklyPlan plan;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async => plan;
}

class _ThrowingScheduleExceptionRepository
    implements SchoolScheduleExceptionRepository {
  const _ThrowingScheduleExceptionRepository();

  @override
  Future<List<SchoolScheduleException>> getForAcademicYear(
    String academicYear,
  ) async {
    throw StateError('calendar exception asset unavailable');
  }
}
