import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/continuity_repository.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/planning_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/outcome_planning_service.dart';
import 'package:ogretmen_os/features/annual_plan/annual_plan_page.dart';
import 'package:ogretmen_os/features/resources/resource_library_page.dart';

void main() {
  testWidgets(
    'tracking buildPlan uzun sürse bile yıllık plan ana içeriği önce görünür',
    (tester) async {
      _phone(tester);
      final repository = _TabRepository('TDE_9');
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: _planFor(repository),
        delay: const Duration(seconds: 5),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnualPlanPage(
              repository: repository,
              preferences: _Preferences(),
              continuity: MemoryContinuityRepository(),
              courseId: repository.courseId,
              outcomePlanning: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 tema · 45 saat · 1 blok'), findsOneWidget);
      expect(find.text('Yıllık plan hazırlanıyor…'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('1 tema · 45 saat · 1 blok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tracking summary hatası ana yıllık planı bozmaz', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
      failure: StateError('tracking intentionally failed'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnualPlanPage(
            repository: repository,
            preferences: _Preferences(),
            continuity: MemoryContinuityRepository(),
            courseId: repository.courseId,
            outcomePlanning: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 tema · 45 saat · 1 blok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plan sekmesine dönüşte full loader yeniden başlamaz', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
    );

    await tester.pumpWidget(
      TeacherOsApp(dependencies: _dependencies(repository, service)),
    );
    await tester.pumpAndSettle();
    final initialPlanCalls = service.buildPlanCalls;

    await _tapDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();
    final annualSequenceCalls = repository.annualSequenceCalls;
    final firstPlanCalls = service.buildPlanCalls;

    await _tapDestination(tester, Icons.today_outlined);
    await tester.pumpAndSettle();
    await _tapDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();

    expect(initialPlanCalls, 1);
    expect(repository.annualSequenceCalls, annualSequenceCalls);
    expect(service.buildPlanCalls, firstPlanCalls);
    expect(repository.annualSequenceCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kaynaklar ilk açılışında OutcomePlanningService çağrılmaz', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceLibraryPage(
            repository: repository,
            awaitingTextbook: false,
            continuity: MemoryContinuityRepository(),
            weeklyPlanning: _FixedWeeklyPlanning(
              _planFor(repository).weeklyPlan,
            ),
            courseId: repository.courseId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.buildPlanCalls, 0);
    expect(repository.teacherPackageCalls, 1);
    expect(find.text('TDE_9 Tema kaynak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kaynaklar sekmesine dönüşte teacher package yeniden yüklenmez', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
    );

    await tester.pumpWidget(
      TeacherOsApp(dependencies: _dependencies(repository, service)),
    );
    await tester.pumpAndSettle();
    final initialPlanCalls = service.buildPlanCalls;

    await _tapDestination(tester, Icons.library_books_outlined);
    await tester.pumpAndSettle();
    final firstPackageCalls = repository.teacherPackageCalls;
    final outcomeCallsBeforeReturn = service.buildPlanCalls;

    await _tapDestination(tester, Icons.today_outlined);
    await tester.pumpAndSettle();
    await _tapDestination(tester, Icons.library_books_outlined);
    await tester.pumpAndSettle();

    expect(initialPlanCalls, 1);
    expect(repository.teacherPackageCalls, firstPackageCalls);
    expect(service.buildPlanCalls, outcomeCallsBeforeReturn);
    expect(repository.teacherPackageCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uygulama Bu Hafta ile açıldığında Plan ve Kaynaklar lazy kalır',
    (tester) async {
      _phone(tester);
      final repository = _TabRepository('TDE_9');
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: _planFor(repository),
      );

      await tester.pumpWidget(
        TeacherOsApp(dependencies: _dependencies(repository, service)),
      );
      await tester.pumpAndSettle();

      expect(repository.annualSequenceCalls, 0);
      expect(repository.getThemesCalls, 0);
      expect(repository.teacherPackageCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'courseId değiştiğinde lazy tab state yeni course için yenilenir',
    (tester) async {
      _phone(tester);
      final repositories = <String, _TabRepository>{};
      final services = <String, _CountingOutcomePlanningService>{};

      AppDependencies dependenciesFor(String courseId) {
        final repository = _TabRepository(courseId);
        final service = _CountingOutcomePlanningService(
          repository: repository,
          plan: _planFor(repository),
        );
        repositories[courseId] = repository;
        services[courseId] = service;
        return _dependencies(repository, service);
      }

      await tester.pumpWidget(
        TeacherOsApp(
          courseLoader: (courseId) async => dependenciesFor(courseId),
        ),
      );
      await tester.pumpAndSettle();
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      expect(repositories['TDE_9']!.teacherPackageCalls, 1);
      await tester.tap(find.byTooltip('Sınıf seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10. Sınıf'));
      await tester.pumpAndSettle();

      expect(find.text('TDE_10 Tema kaynak'), findsOneWidget);
      expect(repositories['TDE_10']!.teacherPackageCalls, 1);
      expect(services['TDE_9']!.buildPlanCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'lightweight planning context çıktıyı korur ve full block hydration yapmaz',
    () async {
      final legacyRepository = _TabRepository('TDE_9');
      final projectionRepository = _TabRepository('TDE_9');
      final legacy = await OutcomePlanningService(
        repository: legacyRepository,
        weeklyPlanning: _ProjectionWeeklyPlanning(
          legacyRepository,
          includeProjection: false,
        ),
        trackingRepository: MemoryOutcomeTrackingRepository(),
      ).buildPlan();
      final projected = await OutcomePlanningService(
        repository: projectionRepository,
        weeklyPlanning: _ProjectionWeeklyPlanning(
          projectionRepository,
          includeProjection: true,
        ),
        trackingRepository: MemoryOutcomeTrackingRepository(),
      ).buildPlan();

      final legacyItem = legacy.week(1)!.outcomes.single;
      final projectedItem = projected.week(1)!.outcomes.single;
      expect(projectedItem.outcome.id, legacyItem.outcome.id);
      expect(projectedItem.status, legacyItem.status);
      expect(projectedItem.primaryTheme?.id, legacyItem.primaryTheme?.id);
      expect(projectedItem.primaryBlock?.id, legacyItem.primaryBlock?.id);
      expect(projectedItem.contexts.single.detail, isNull);
      expect(legacyRepository.getBlockCalls, 1);
      expect(projectionRepository.getBlockCalls, 0);
    },
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapDestination(WidgetTester tester, IconData icon) async {
  final bar = find.byType(NavigationBar);
  expect(bar, findsOneWidget);
  await tester.tap(find.descendant(of: bar, matching: find.byIcon(icon)));
}

AppDependencies _dependencies(
  _TabRepository repository,
  _CountingOutcomePlanningService service,
) => AppDependencies(
  repository: repository,
  preferences: _Preferences(),
  weeklyPlanning: _FixedWeeklyPlanning(_planFor(repository).weeklyPlan),
  outcomePlanning: service,
  continuity: MemoryContinuityRepository(),
);

AnnualOutcomePlan _planFor(_TabRepository repository) {
  final planningBlock = PlanningBlock(
    theme: repository.theme,
    block: repository.block,
    outcomes: [repository.outcome],
  );
  final week = AcademicWeekPlan(
    weekNumber: 1,
    start: DateTime(2026, 9, 14),
    end: DateTime(2026, 9, 18),
    type: AcademicWeekType.instruction,
    label: '1. Hafta',
    plannedLessonHours: 5,
    segments: [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: repository.theme,
        hours: 5,
        block: repository.block,
        planningBlock: planningBlock,
      ),
    ],
    outcomes: [repository.outcome],
  );
  final weeklyPlan = AnnualWeeklyPlan(
    academicYear: '2026-2027',
    courseId: repository.courseId,
    weeklyLessonHours: 5,
    annualHours: 45,
    currentWeekNumber: 1,
    weeks: [week],
  );
  return AnnualOutcomePlan(
    weeklyPlan: weeklyPlan,
    weeks: [
      WeeklyOutcomeSummary(
        week: week,
        outcomes: [
          TrackedOutcome(
            outcome: repository.outcome,
            academicYear: '2026-2027',
            plannedWeekNumber: 1,
            displayWeekNumber: 1,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext.lightweight(
                theme: repository.theme,
                block: repository.block,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _CountingOutcomePlanningService extends OutcomePlanningService {
  _CountingOutcomePlanningService({
    required super.repository,
    required this.plan,
    this.delay,
    this.failure,
  }) : super(
         weeklyPlanning: _ThrowingWeeklyPlanning(),
         trackingRepository: MemoryOutcomeTrackingRepository(),
       );

  final AnnualOutcomePlan plan;
  final Duration? delay;
  final Object? failure;
  int buildPlanCalls = 0;

  @override
  Future<AnnualOutcomePlan> buildPlan({DateTime? today}) {
    buildPlanCalls++;
    final failure = this.failure;
    if (failure != null) {
      return Future<AnnualOutcomePlan>.error(failure);
    }
    final delay = this.delay;
    if (delay != null) {
      return Future<AnnualOutcomePlan>.delayed(delay, () => plan);
    }
    return Future.value(plan);
  }
}

class _ThrowingWeeklyPlanning implements WeeklyPlanningService {
  const _ThrowingWeeklyPlanning();

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) =>
      Future<AnnualWeeklyPlan>.error(StateError('not used'));
}

class _FixedWeeklyPlanning implements WeeklyPlanningService {
  const _FixedWeeklyPlanning(this.plan);

  final AnnualWeeklyPlan plan;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async => plan;
}

class _ProjectionWeeklyPlanning implements WeeklyPlanningService {
  _ProjectionWeeklyPlanning(this.repository, {required this.includeProjection});

  final _TabRepository repository;
  final bool includeProjection;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async {
    final segment = WeeklyPlanSegment(
      type: WeeklyPlanSegmentType.block,
      theme: repository.theme,
      hours: 5,
      block: repository.block,
      planningBlock: includeProjection
          ? PlanningBlock(
              theme: repository.theme,
              block: repository.block,
              outcomes: [repository.outcome],
            )
          : null,
    );
    final week = AcademicWeekPlan(
      weekNumber: 1,
      start: DateTime(2026, 9, 14),
      end: DateTime(2026, 9, 18),
      type: AcademicWeekType.instruction,
      label: '1. Hafta',
      plannedLessonHours: 5,
      segments: [segment],
      outcomes: [repository.outcome],
    );
    return AnnualWeeklyPlan(
      academicYear: '2026-2027',
      courseId: repository.courseId,
      weeklyLessonHours: 5,
      annualHours: 45,
      currentWeekNumber: 1,
      weeks: [week],
    );
  }
}

class _Preferences implements UserPreferencesRepository {
  String? value;

  @override
  Future<String?> getManualPositionOverride() async => value;

  @override
  Future<void> setManualPositionOverride(String blockId) async {
    value = blockId;
  }

  @override
  Future<void> clearManualPositionOverride() async {
    value = null;
  }
}

class _TabRepository implements CourseKnowledgeRepository {
  _TabRepository(this.courseId)
    : theme = model.Theme(
        id: '$courseId-T1',
        order: 1,
        title: '$courseId Tema',
        pageRange: null,
        plannedHours: 45,
        anlamaHours: null,
        anlatmaHours: null,
        sourceLocator: null,
      ),
      block = model.Block(
        id: '$courseId-B1',
        themeId: '$courseId-T1',
        order: 1,
        title: '$courseId Blok',
        skillDomain: 'Okuma',
        learningArea: null,
        plannedHours: null,
        timeStatus: 'ORDER_ONLY',
        sourceLocators: const [],
      ),
      outcome = model.Outcome(
        id: '$courseId-O1',
        themeId: '$courseId-T1',
        code: '$courseId.1',
        officialText: '$courseId kazanımı',
        processComponents: null,
        sourceLocator: null,
        verificationStatus: 'PASS',
      );

  final String courseId;
  final model.Theme theme;
  final model.Block block;
  final model.Outcome outcome;
  int annualSequenceCalls = 0;
  int getThemesCalls = 0;
  int teacherPackageCalls = 0;
  int getBlockCalls = 0;

  model.BlockDetail get detail => model.BlockDetail(
    theme: theme,
    block: block,
    outcomes: [outcome],
    textbookSections: [
      model.TextbookSection(
        id: '$courseId-S1',
        themeId: theme.id,
        title: '$courseId Tema kaynak',
        genre: 'Metin',
        printedPageRange: '1-2',
        pdfPageRange: null,
        sourceId: null,
      ),
    ],
    activities: const [],
    forms: const [],
    assessmentArtifacts: const [],
    assessmentGaps: const [],
    assessmentTaskBindings: const [],
    resourceDecisions: const [],
    sourceReferences: const [],
    previousBlock: null,
    nextBlock: null,
  );

  @override
  Future<model.Course> getCourse() async => model.Course(
    courseId: courseId,
    grade: courseId == 'TDE_10' ? 10 : 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: courseId,
  );

  @override
  Future<model.RuntimeManifest> getManifest() async => model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: courseId,
    validationStatus: 'PASS',
    canonicalContentFingerprint: courseId,
    rowCounts: const {},
    timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
    timelineUnresolvedFields: const {},
  );

  @override
  Future<List<model.Theme>> getThemes() async {
    getThemesCalls++;
    return [theme];
  }

  @override
  Future<model.Theme> getTheme(String themeId) async => theme;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => [block];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async {
    getBlockCalls++;
    return detail;
  }

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async {
    annualSequenceCalls++;
    return [
      model.TimelineEntry(
        sequencePosition: 1,
        theme: theme,
        block: block,
        officialTotalHours: 45,
        coreInstructionHours: 45,
        schoolBasedHours: 0,
        schoolBasedHoursStatus: 'CONFIRMED',
      ),
    ];
  }

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(
    String themeId,
  ) async => const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async {
    teacherPackageCalls++;
    return model.TeacherPackage(
      theme: theme,
      blocks: [block],
      outcomes: [outcome],
      textbookSections: detail.textbookSections,
      activities: const [],
      forms: const [],
      assessmentArtifacts: const [],
      assessmentGaps: const [],
      assessmentTaskBindings: const [],
      resourceDecisions: const [],
      sourceReferences: const [],
    );
  }
}
