import 'package:flutter/material.dart' hide Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/instruction_context_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/assignment_lesson_progress_repository.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/instruction_context_repository.dart';
import 'package:ogretmen_os/domain/repositories/school_schedule_exception_repository.dart';
import 'package:ogretmen_os/domain/services/assignment_lesson_timeline_service.dart';
import 'package:ogretmen_os/features/lesson_plan/assignment_weekly_lesson_plan_panel.dart';

void main() {
  testWidgets(
    'tatilde iptal edilen saat sonraki haftanın plan içeriğini bir saat kaydırır',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeCourseRepository(
        List.generate(10, (index) => _package(index + 1)),
      );
      final instructionContext = MemoryInstructionContextRepository();
      final progress = MemoryAssignmentLessonProgressRepository();
      await _seedSchedule(instructionContext);

      final plan = _annualPlan();
      final timeline = AssignmentLessonTimelineService(
        instructionContext: instructionContext,
        weeklyPlanning: _FixedWeeklyPlanningService(plan.weeklyPlan),
        scheduleExceptions: MemorySchoolScheduleExceptionRepository([
          SchoolScheduleException(
            id: 'holiday',
            date: DateTime(2026, 9, 17),
            label: 'Okul kapalı',
          ),
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssignmentAwareWeeklyLessonPlanSection(
                repository: repository,
                annualPlan: plan,
                weekNumber: 2,
                courseId: 'TDE_9',
                instructionContext: instructionContext,
                timeline: timeline,
                progressRepository: progress,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bu haftanın ders planı'), findsOneWidget);
      expect(find.text('5 ders saati'), findsOneWidget);
      expect(find.text('Plan 5'), findsOneWidget);
      expect(find.text('Plan 6'), findsOneWidget);
      expect(find.text('Plan 7'), findsOneWidget);
      expect(find.text('Plan 8'), findsOneWidget);
      expect(find.text('Plan 9'), findsOneWidget);
      expect(find.text('Plan 10'), findsNothing);
      expect(
        find.text('Takvim kayması · plan sırası 1. hafta, 5. ders'),
        findsOneWidget,
      );
      expect(find.text('Pzt · 1. saat'), findsOneWidget);
      expect(find.text('1. ders saati'), findsOneWidget);
      expect(find.text('5. ders saati'), findsOneWidget);
      expect(await progress.getForAssignment('a9a'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test('timeline seçili takvim haftasının exception-adjusted occurrence listesini verir', () async {
    final instructionContext = MemoryInstructionContextRepository();
    await _seedSchedule(instructionContext);
    final plan = _annualPlan();
    final timeline = AssignmentLessonTimelineService(
      instructionContext: instructionContext,
      weeklyPlanning: _FixedWeeklyPlanningService(plan.weeklyPlan),
      scheduleExceptions: MemorySchoolScheduleExceptionRepository([
        SchoolScheduleException(
          id: 'holiday',
          date: DateTime(2026, 9, 17),
          label: 'Okul kapalı',
        ),
      ]),
    );

    final snapshot = await timeline.resolve(
      academicYear: '2026-2027',
      courseId: 'TDE_9',
      now: DateTime(2026, 9, 21, 8, 20),
    );
    final firstWeek = snapshot.occurrencesForAssignmentBetween(
      assignmentId: 'a9a',
      start: DateTime(2026, 9, 14),
      end: DateTime(2026, 9, 18),
    );
    final secondWeek = snapshot.occurrencesForAssignmentBetween(
      assignmentId: 'a9a',
      start: DateTime(2026, 9, 21),
      end: DateTime(2026, 9, 25),
    );

    expect(firstWeek.map((item) => item.plannedOrdinal), [1, 2, 3, 4]);
    expect(firstWeek.map((item) => item.date.weekday), [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.friday,
    ]);
    expect(secondWeek.map((item) => item.plannedOrdinal), [5, 6, 7, 8, 9]);
  });
}

const _theme = Theme(
  id: 'TEMA_01',
  order: 1,
  title: 'Tema',
  pageRange: null,
  plannedHours: 10,
  anlamaHours: null,
  anlatmaHours: null,
  sourceLocator: null,
);

const _block = Block(
  id: 'BLOCK_A',
  themeId: 'TEMA_01',
  order: 1,
  title: 'Blok',
  skillDomain: 'okuma',
  learningArea: null,
  plannedHours: 10,
  timeStatus: 'RESOLVED',
  sourceLocators: [],
);

AnnualOutcomePlan _annualPlan() {
  final weeks = [
    _week(1, DateTime(2026, 9, 14), DateTime(2026, 9, 18)),
    _week(2, DateTime(2026, 9, 21), DateTime(2026, 9, 25)),
  ];
  return AnnualOutcomePlan(
    weeklyPlan: AnnualWeeklyPlan(
      academicYear: '2026-2027',
      courseId: 'TDE_9',
      weeklyLessonHours: 5,
      annualHours: 10,
      weeks: weeks,
      currentWeekNumber: 2,
    ),
    weeks: [
      for (final week in weeks)
        WeeklyOutcomeSummary(week: week, outcomes: const []),
    ],
  );
}

AcademicWeekPlan _week(int number, DateTime start, DateTime end) =>
    AcademicWeekPlan(
      weekNumber: number,
      start: start,
      end: end,
      type: AcademicWeekType.instruction,
      label: '$number. Hafta',
      plannedLessonHours: 5,
      segments: const [
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: _theme,
          hours: 5,
          block: _block,
        ),
      ],
      outcomes: const [],
    );

LessonPlanPackage _package(int ordinal) => LessonPlanPackage(
  packageId: 'P${ordinal.toString().padLeft(2, '0')}',
  courseId: 'TDE_9',
  themeId: 'TEMA_01',
  blockId: 'BLOCK_A',
  packageNo: ordinal,
  lessonHours: 1,
  title: 'Plan $ordinal',
  summary: 'Plan $ordinal özeti',
  remainingBlockHours: 10 - ordinal,
  schemaVersion: '1.0.0',
  validationStatus: 'PASS',
  sourcePath: 'generated/p$ordinal.json',
  payloadSha256: 'sha-$ordinal',
  outcomeCodes: const [],
  usedActivityIds: const [],
  usedFormIds: const [],
  lessons: const [],
  teacherNotes: null,
  continuation: LessonPlanContinuation(
    plannedNowHours: 1,
    remainingBlockHours: 10 - ordinal,
    coveredOutcomeCodes: const [],
    usedActivityIds: const [],
    nextStepHint: null,
    raw: const {},
  ),
  rawPayload: const {},
);

Future<void> _seedSchedule(
  MemoryInstructionContextRepository repository,
) async {
  final now = DateTime(2026, 8, 1);
  await repository.replaceBellPeriods(const [
    BellPeriod(periodNumber: 1, startMinute: 480, endMinute: 520),
  ]);
  await repository.saveClass(
    SchoolClass(
      id: 'c9a',
      academicYear: '2026-2027',
      grade: 9,
      section: 'A',
      displayName: '9/A',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveAssignment(
    TeachingAssignment(
      id: 'a9a',
      academicYear: '2026-2027',
      courseId: 'TDE_9',
      classId: 'c9a',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.replaceScheduleSlotsForAssignment(
    assignmentId: 'a9a',
    slots: [
      for (var weekday = DateTime.monday;
          weekday <= DateTime.friday;
          weekday++)
        LessonScheduleSlot(
          id: 'slot-$weekday',
          assignmentId: 'a9a',
          weekday: weekday,
          periodNumber: 1,
          createdAt: now,
          updatedAt: now,
        ),
    ],
  );
}

class _FixedWeeklyPlanningService implements WeeklyPlanningService {
  const _FixedWeeklyPlanningService(this.plan);

  final AnnualWeeklyPlan plan;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async => plan;
}

class _FakeCourseRepository
    implements CourseKnowledgeRepository, LessonPlanKnowledgeRepository {
  _FakeCourseRepository(this.packages);

  final List<LessonPlanPackage> packages;

  @override
  Future<LessonPlanCapability> getLessonPlanCapability() async =>
      LessonPlanCapability(
        available: true,
        manifestAdvertised: true,
        tableAvailable: true,
        packageCount: packages.length,
        instructionHours: packages.length,
        schemaVersion: '1.0.0',
        validationStatus: 'PASS',
      );

  @override
  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId) async =>
      packages.where((plan) => plan.blockId == blockId).toList(growable: false);

  @override
  Future<LessonPlanPackage?> getLessonPlan(String packageId) async {
    for (final plan in packages) {
      if (plan.packageId == packageId) return plan;
    }
    return null;
  }

  @override
  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) async {
    final index = packages.indexWhere((plan) => plan.packageId == packageId);
    return index <= 0 ? null : packages[index - 1];
  }

  @override
  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) async {
    final index = packages.indexWhere((plan) => plan.packageId == packageId);
    return index < 0 || index >= packages.length - 1
        ? null
        : packages[index + 1];
  }

  @override
  Future<Course> getCourse() async => throw UnimplementedError();

  @override
  Future<RuntimeManifest> getManifest() async => throw UnimplementedError();

  @override
  Future<List<Theme>> getThemes() async => throw UnimplementedError();

  @override
  Future<Theme> getTheme(String themeId) async => throw UnimplementedError();

  @override
  Future<List<Block>> getBlocks(String themeId) async =>
      throw UnimplementedError();

  @override
  Future<BlockDetail> getBlock(String blockId) async =>
      throw UnimplementedError();

  @override
  Future<List<TimelineEntry>> getAnnualSequence() async =>
      throw UnimplementedError();

  @override
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) async =>
      throw UnimplementedError();

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) async =>
      throw UnimplementedError();
}
