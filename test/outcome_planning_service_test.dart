import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/outcome_planning_service.dart';

void main() {
  late MemoryOutcomeTrackingRepository tracking;
  late OutcomePlanningService service;

  setUp(() {
    tracking = MemoryOutcomeTrackingRepository();
    service = OutcomePlanningService(
      repository: _Repository(),
      weeklyPlanning: _WeeklyPlanning(),
      trackingRepository: tracking,
    );
  });

  test('missing tracking row defaults to planned', () async {
    final plan = await service.buildPlan();
    final item = plan.week(1)!.outcomes.single;

    expect(item.status, OutcomeTrackingStatus.planned);
    expect(item.presentationStatus, OutcomeTrackingStatus.planned);
    expect(plan.week(1)!.plannedCount, 1);
  });

  test('status and teacher note persist through repository projection', () async {
    var plan = await service.buildPlan();
    var item = plan.week(1)!.outcomes.single;

    await service.setStatus(item, OutcomeTrackingStatus.inProgress);
    plan = await service.buildPlan();
    item = plan.week(1)!.outcomes.single;
    expect(item.status, OutcomeTrackingStatus.inProgress);

    await service.saveTeacherNote(item, 'Son etkinlik sonraki derste.');
    plan = await service.buildPlan();
    item = plan.week(1)!.outcomes.single;
    expect(item.teacherNote, 'Son etkinlik sonraki derste.');

    await service.setStatus(item, OutcomeTrackingStatus.completed);
    plan = await service.buildPlan();
    item = plan.week(1)!.outcomes.single;
    expect(item.status, OutcomeTrackingStatus.completed);
    expect(item.completedAt, isNotNull);
    expect(plan.week(1)!.completedCount, 1);
  });

  test('carry-over preserves source plan and projects into target week', () async {
    var plan = await service.buildPlan();
    final source = plan.week(1)!.outcomes.single;

    await service.carryToWeek(
      item: source,
      targetWeekNumber: 2,
      plan: plan,
    );

    plan = await service.buildPlan();
    final sourceAfter = plan.week(1)!.outcomes.single;
    final carried = plan.week(2)!.outcomes.firstWhere(
      (item) => item.outcome.id == _Repository.outcome1.id && item.isCarriedIn,
    );

    expect(sourceAfter.plannedWeekNumber, 1);
    expect(sourceAfter.carriedToWeekNumber, 2);
    expect(sourceAfter.presentationStatus, OutcomeTrackingStatus.carriedOver);
    expect(carried.displayWeekNumber, 2);
    expect(carried.carriedFromWeekNumber, 1);
    expect(carried.isCarriedIn, isTrue);

    await service.setStatus(carried, OutcomeTrackingStatus.completed);
    plan = await service.buildPlan();
    final completedCarry = plan.week(2)!.outcomes.firstWhere(
      (item) => item.outcome.id == _Repository.outcome1.id && item.isCarriedIn,
    );
    final original = plan.week(1)!.outcomes.single;

    expect(completedCarry.presentationStatus, OutcomeTrackingStatus.completed);
    expect(original.presentationStatus, OutcomeTrackingStatus.carriedOver);
    expect(plan.week(2)!.completedCount, 1);
  });

  test('event week cannot be a carry target', () async {
    final plan = await service.buildPlan();
    final source = plan.week(1)!.outcomes.single;

    expect(
      () => service.carryToWeek(
        item: source,
        targetWeekNumber: 3,
        plan: plan,
      ),
      throwsStateError,
    );
  });

  test('reset removes teacher tracking and returns to planned', () async {
    var plan = await service.buildPlan();
    var item = plan.week(1)!.outcomes.single;
    await service.setStatus(item, OutcomeTrackingStatus.completed);

    plan = await service.buildPlan();
    item = plan.week(1)!.outcomes.single;
    await service.resetTracking(item);

    plan = await service.buildPlan();
    expect(
      plan.week(1)!.outcomes.single.presentationStatus,
      OutcomeTrackingStatus.planned,
    );
  });
}

class _Repository implements CourseKnowledgeRepository {
  static const theme = model.Theme(
    id: 'THEME_1',
    order: 1,
    title: 'Tema 1',
    pageRange: null,
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );

  static const block = model.Block(
    id: 'BLOCK_1',
    themeId: 'THEME_1',
    order: 1,
    title: 'Blok 1',
    skillDomain: null,
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const outcome1 = model.Outcome(
    id: 'OUTCOME_1',
    themeId: 'THEME_1',
    code: 'TDE.1',
    officialText: 'Birinci doğrulanmış kazanım.',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );

  static const outcome2 = model.Outcome(
    id: 'OUTCOME_2',
    themeId: 'THEME_1',
    code: 'TDE.2',
    officialText: 'İkinci doğrulanmış kazanım.',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );

  static const detail = model.BlockDetail(
    theme: theme,
    block: block,
    outcomes: [outcome1, outcome2],
    textbookSections: [],
    activities: [],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [],
    previousBlock: null,
    nextBlock: null,
  );

  @override
  Future<model.Course> getCourse() async => const model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Test',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'fixture',
  );

  @override
  Future<model.RuntimeManifest> getManifest() async => const model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: 'TDE_9',
    validationStatus: 'PASS',
    canonicalContentFingerprint: 'fixture',
    rowCounts: {},
    timelineResolution: 'THEME_TIME_RESOLVED',
    timelineUnresolvedFields: {},
  );

  @override
  Future<List<model.Theme>> getThemes() async => const [theme];

  @override
  Future<model.Theme> getTheme(String themeId) async => theme;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => const [block];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async => detail;

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async => const [
    model.TimelineEntry(
      sequencePosition: 1,
      theme: theme,
      block: block,
      officialTotalHours: 45,
      coreInstructionHours: 43,
      schoolBasedHours: 2,
      schoolBasedHoursStatus: 'RESOLVED',
    ),
  ];

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(String themeId) async =>
      const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async =>
      const model.TeacherPackage(
        theme: theme,
        blocks: [block],
        outcomes: [outcome1, outcome2],
        textbookSections: [],
        activities: [],
        forms: [],
        assessmentArtifacts: [],
        assessmentGaps: [],
        assessmentTaskBindings: [],
        resourceDecisions: [],
        sourceReferences: [],
      );
}

class _WeeklyPlanning implements WeeklyPlanningService {
  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async => AnnualWeeklyPlan(
    academicYear: '2026-2027',
    courseId: 'TDE_9',
    weeklyLessonHours: 5,
    annualHours: 180,
    currentWeekNumber: 1,
    weeks: [
      AcademicWeekPlan(
        weekNumber: 1,
        start: DateTime(2026, 9, 14),
        end: DateTime(2026, 9, 18),
        type: AcademicWeekType.instruction,
        label: '1. Hafta',
        plannedLessonHours: 5,
        segments: const [
          WeeklyPlanSegment(
            type: WeeklyPlanSegmentType.block,
            theme: _Repository.theme,
            block: _Repository.block,
            hours: 5,
          ),
        ],
        outcomes: const [_Repository.outcome1],
      ),
      AcademicWeekPlan(
        weekNumber: 2,
        start: DateTime(2026, 9, 21),
        end: DateTime(2026, 9, 25),
        type: AcademicWeekType.instruction,
        label: '2. Hafta',
        plannedLessonHours: 5,
        segments: const [
          WeeklyPlanSegment(
            type: WeeklyPlanSegmentType.block,
            theme: _Repository.theme,
            block: _Repository.block,
            hours: 5,
          ),
        ],
        outcomes: const [_Repository.outcome2],
      ),
      AcademicWeekPlan(
        weekNumber: 3,
        start: DateTime(2027, 6, 21),
        end: DateTime(2027, 6, 25),
        type: AcademicWeekType.event,
        label: 'Etkinlik Haftası',
        plannedLessonHours: 0,
        segments: const [],
        outcomes: const [],
      ),
    ],
  );
}
