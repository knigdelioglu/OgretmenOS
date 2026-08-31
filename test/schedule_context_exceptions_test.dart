import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/instruction_context_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/instruction_context_repository.dart';
import 'package:ogretmen_os/domain/repositories/school_schedule_exception_repository.dart';
import 'package:ogretmen_os/domain/services/assignment_lesson_timeline_service.dart';
import 'package:ogretmen_os/domain/services/teaching_course_context_service.dart';

void main() {
  group('schedule exceptions', () {
    test('exception repository akademik yıl kapsamını korur', () async {
      final repository = MemorySchoolScheduleExceptionRepository([
        SchoolScheduleException(
          id: 'current-year',
          academicYear: '2026-2027',
          date: DateTime(2026, 10, 29),
          label: 'Bu yıl',
        ),
        SchoolScheduleException(
          id: 'next-year',
          academicYear: '2027-2028',
          date: DateTime(2027, 10, 29),
          label: 'Sonraki yıl',
        ),
      ]);

      expect(
        (await repository.getForAcademicYear(
          '2026-2027',
        )).map((item) => item.id),
        ['current-year'],
      );
      expect(
        (await repository.getForAcademicYear(
          '2027-2028',
        )).map((item) => item.id),
        ['next-year'],
      );
    });

    test(
      'full-day exception removes the lesson from assignment ordinal',
      () async {
        final repository = MemoryInstructionContextRepository();
        final now = DateTime(2026, 10, 29, 8, 20);
        await _seedSingleAssignment(
          repository,
          courseId: 'TDE_9',
          assignmentId: 'a9',
          classId: 'c9',
          slots: const [
            (DateTime.monday, 1),
            (DateTime.tuesday, 1),
            (DateTime.wednesday, 1),
            (DateTime.thursday, 1),
            (DateTime.friday, 1),
          ],
          periods: const [
            BellPeriod(periodNumber: 1, startMinute: 480, endMinute: 520),
          ],
        );
        final plan = _plan(
          courseId: 'TDE_9',
          start: DateTime(2026, 10, 26),
          end: DateTime(2026, 10, 30),
        );
        final timeline = AssignmentLessonTimelineService(
          instructionContext: repository,
          weeklyPlanning: _FixedWeeklyPlanningService(plan),
          scheduleExceptions: MemorySchoolScheduleExceptionRepository([
            SchoolScheduleException(
              id: 'republic-day',
              date: DateTime(2026, 10, 29),
              label: 'Cumhuriyet Bayramı',
            ),
          ]),
        );

        final snapshot = await timeline.resolve(
          academicYear: _academicYear,
          courseId: 'TDE_9',
          now: now,
        );
        final position = snapshot.positionFor('a9');

        expect(snapshot.currentOccurrence, isNull);
        expect(position, isNotNull);
        expect(position!.plannedOrdinal, 3);
        expect(position.previousOccurrence?.date, DateTime(2026, 10, 28));
        expect(position.nextOccurrence?.date, DateTime(2026, 10, 30));
        expect(position.nextOccurrence?.plannedOrdinal, 4);
      },
    );

    test(
      'partial-day exception cancels only overlapping bell periods',
      () async {
        final repository = MemoryInstructionContextRepository();
        await _seedSingleAssignment(
          repository,
          courseId: 'TDE_9',
          assignmentId: 'a9',
          classId: 'c9',
          slots: const [
            (DateTime.monday, 1),
            (DateTime.tuesday, 1),
            (DateTime.wednesday, 1),
            (DateTime.wednesday, 2),
            (DateTime.friday, 1),
          ],
          periods: const [
            BellPeriod(periodNumber: 1, startMinute: 540, endMinute: 580),
            BellPeriod(periodNumber: 2, startMinute: 810, endMinute: 850),
          ],
        );
        final timeline = AssignmentLessonTimelineService(
          instructionContext: repository,
          weeklyPlanning: _FixedWeeklyPlanningService(
            _plan(
              courseId: 'TDE_9',
              start: DateTime(2026, 10, 26),
              end: DateTime(2026, 10, 30),
            ),
          ),
          scheduleExceptions: MemorySchoolScheduleExceptionRepository([
            SchoolScheduleException(
              id: 'republic-day-eve',
              date: DateTime(2026, 10, 28),
              label: 'Cumhuriyet Bayramı arifesi',
              startMinute: 13 * 60,
              endMinute: 24 * 60,
            ),
          ]),
        );

        final snapshot = await timeline.resolve(
          academicYear: _academicYear,
          courseId: 'TDE_9',
          now: DateTime(2026, 10, 28, 13, 40),
        );
        final position = snapshot.positionFor('a9')!;

        expect(snapshot.currentOccurrence, isNull);
        expect(position.plannedOrdinal, 3);
        expect(position.previousOccurrence?.period.periodNumber, 1);
        expect(position.nextOccurrence?.date, DateTime(2026, 10, 30));
        expect(position.nextOccurrence?.plannedOrdinal, 4);
      },
    );

    test('başka akademik yıl istisnası mevcut planı iptal etmez', () async {
      final repository = MemoryInstructionContextRepository();
      await _seedSingleAssignment(
        repository,
        courseId: 'TDE_9',
        assignmentId: 'a9',
        classId: 'c9',
        slots: const [(DateTime.wednesday, 1)],
        periods: const [
          BellPeriod(periodNumber: 1, startMinute: 480, endMinute: 520),
        ],
      );
      final timeline = AssignmentLessonTimelineService(
        instructionContext: repository,
        weeklyPlanning: _FixedWeeklyPlanningService(
          _plan(
            courseId: 'TDE_9',
            start: DateTime(2026, 10, 26),
            end: DateTime(2026, 10, 30),
            scheduleExceptions: [
              SchoolScheduleException(
                id: 'next-year',
                academicYear: '2027-2028',
                date: DateTime(2026, 10, 28),
                label: 'Başka yıl',
              ),
            ],
          ),
        ),
      );

      final snapshot = await timeline.resolve(
        academicYear: _academicYear,
        courseId: 'TDE_9',
        now: DateTime(2026, 10, 28, 8, 10),
      );

      expect(snapshot.currentOccurrence, isNotNull);
      expect(snapshot.currentOccurrence!.plannedOrdinal, 1);
    });
  });

  group('automatic cross-course context', () {
    test(
      'before a lesson, preferred course is the next scheduled course',
      () async {
        final repository = MemoryInstructionContextRepository();
        await _seedTwoCourses(repository);
        final service = TeachingCourseContextService(
          instructionContext: repository,
          weeklyPlanning: _FixedWeeklyPlanningService(
            _plan(
              courseId: 'TDE_9',
              start: DateTime(2026, 10, 26),
              end: DateTime(2026, 10, 30),
            ),
          ),
        );

        final snapshot = await service.resolve(
          now: DateTime(2026, 10, 28, 13, 0),
        );

        expect(snapshot.hasCurrentLesson, isFalse);
        expect(snapshot.nextCourseId, 'TDE_10');
        expect(snapshot.nextAssignmentId, 'a10');
        expect(snapshot.preferredCourseId, 'TDE_10');
        expect(snapshot.nextStartsAt, DateTime(2026, 10, 28, 13, 30));
      },
    );

    test(
      'full-day exception suppresses current and next course for that day',
      () async {
        final repository = MemoryInstructionContextRepository();
        await _seedTwoCourses(repository);
        final service = TeachingCourseContextService(
          instructionContext: repository,
          weeklyPlanning: _FixedWeeklyPlanningService(
            _plan(
              courseId: 'TDE_9',
              start: DateTime(2026, 10, 26),
              end: DateTime(2026, 10, 30),
            ),
          ),
          scheduleExceptions: MemorySchoolScheduleExceptionRepository([
            SchoolScheduleException(
              id: 'closed',
              date: DateTime(2026, 10, 28),
              label: 'Okul kapalı',
            ),
          ]),
        );

        final snapshot = await service.resolve(
          now: DateTime(2026, 10, 28, 8, 30),
        );

        expect(snapshot.currentCourseId, isNull);
        expect(snapshot.nextCourseId, isNull);
        expect(snapshot.preferredCourseId, isNull);
      },
    );

    test('incomplete assignment schedule is ignored', () async {
      final repository = MemoryInstructionContextRepository();
      await repository.replaceBellPeriods(const [
        BellPeriod(periodNumber: 1, startMinute: 810, endMinute: 850),
      ]);
      final now = DateTime(2026, 8, 1);
      await repository.saveClass(
        SchoolClass(
          id: 'c10',
          academicYear: _academicYear,
          grade: 10,
          section: 'A',
          displayName: '10/A',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.saveAssignment(
        TeachingAssignment(
          id: 'a10',
          academicYear: _academicYear,
          courseId: 'TDE_10',
          classId: 'c10',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.replaceScheduleSlotsForAssignment(
        assignmentId: 'a10',
        slots: _slots('a10', const [
          (DateTime.monday, 1),
          (DateTime.tuesday, 1),
          (DateTime.wednesday, 1),
          (DateTime.thursday, 1),
        ]),
      );
      final service = TeachingCourseContextService(
        instructionContext: repository,
        weeklyPlanning: _FixedWeeklyPlanningService(
          _plan(
            courseId: 'TDE_9',
            start: DateTime(2026, 10, 26),
            end: DateTime(2026, 10, 30),
          ),
        ),
      );

      final snapshot = await service.resolve(
        now: DateTime(2026, 10, 28, 13, 20),
      );

      expect(snapshot.preferredCourseId, isNull);
      expect(snapshot.hasCurrentLesson, isFalse);
      expect(snapshot.hasNextLesson, isFalse);
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

AnnualWeeklyPlan _plan({
  required String courseId,
  required DateTime start,
  required DateTime end,
  List<SchoolScheduleException> scheduleExceptions = const [],
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
  scheduleExceptions: scheduleExceptions,
);

Future<void> _seedSingleAssignment(
  MemoryInstructionContextRepository repository, {
  required String courseId,
  required String assignmentId,
  required String classId,
  required List<(int, int)> slots,
  required List<BellPeriod> periods,
}) async {
  final now = DateTime(2026, 8, 1);
  await repository.replaceBellPeriods(periods);
  await repository.saveClass(
    SchoolClass(
      id: classId,
      academicYear: _academicYear,
      grade: 9,
      section: 'A',
      displayName: '9/A',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveAssignment(
    TeachingAssignment(
      id: assignmentId,
      academicYear: _academicYear,
      courseId: courseId,
      classId: classId,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.replaceScheduleSlotsForAssignment(
    assignmentId: assignmentId,
    slots: _slots(assignmentId, slots),
  );
}

Future<void> _seedTwoCourses(
  MemoryInstructionContextRepository repository,
) async {
  final now = DateTime(2026, 8, 1);
  await repository.replaceBellPeriods(const [
    BellPeriod(periodNumber: 1, startMinute: 540, endMinute: 580),
    BellPeriod(periodNumber: 2, startMinute: 810, endMinute: 850),
  ]);
  await repository.saveClass(
    SchoolClass(
      id: 'c9',
      academicYear: _academicYear,
      grade: 9,
      section: 'A',
      displayName: '9/A',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveClass(
    SchoolClass(
      id: 'c10',
      academicYear: _academicYear,
      grade: 10,
      section: 'A',
      displayName: '10/A',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveAssignment(
    TeachingAssignment(
      id: 'a9',
      academicYear: _academicYear,
      courseId: 'TDE_9',
      classId: 'c9',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveAssignment(
    TeachingAssignment(
      id: 'a10',
      academicYear: _academicYear,
      courseId: 'TDE_10',
      classId: 'c10',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.replaceScheduleSlotsForAssignment(
    assignmentId: 'a9',
    slots: _slots('a9', const [
      (DateTime.monday, 1),
      (DateTime.tuesday, 1),
      (DateTime.wednesday, 1),
      (DateTime.thursday, 1),
      (DateTime.friday, 1),
    ]),
  );
  await repository.replaceScheduleSlotsForAssignment(
    assignmentId: 'a10',
    slots: _slots('a10', const [
      (DateTime.monday, 2),
      (DateTime.tuesday, 2),
      (DateTime.wednesday, 2),
      (DateTime.thursday, 2),
      (DateTime.friday, 2),
    ]),
  );
}

List<LessonScheduleSlot> _slots(String assignmentId, List<(int, int)> values) {
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
