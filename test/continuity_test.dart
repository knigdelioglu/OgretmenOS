import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/preferences/continuity_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/outcome_planning_service.dart';
import 'package:ogretmen_os/features/this_week/continuity_this_week_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('last focus survives SharedPreferences round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesContinuityRepository(preferences);
    final state = LastFocusState(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      weekNumber: 4,
      trackingKey: '2026-2027:TEST_OUTCOME:4',
      outcomeCode: 'TDE1.4',
      themeTitle: 'Sözün İnceliği',
      blockId: 'BLOCK_4',
      blockTitle: 'Şiir',
      updatedAt: DateTime(2026, 9, 30, 12),
    );

    await repository.setLastFocus(state);
    final restored = await repository.getLastFocus('TDE_9');

    expect(restored, isNotNull);
    expect(restored!.trackingKey, state.trackingKey);
    expect(restored.weekNumber, 4);
    expect(restored.blockTitle, 'Şiir');

    await repository.clearLastFocus('TDE_9');
    expect(await repository.getLastFocus('TDE_9'), isNull);
  });

  test('malformed continuity state is ignored and removed', () async {
    SharedPreferences.setMockInitialValues({
      'last_focus_v1_TDE_9': '{not-json',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesContinuityRepository(preferences);

    expect(await repository.getLastFocus('TDE_9'), isNull);
    expect(preferences.getString('last_focus_v1_TDE_9'), isNull);
  });

  testWidgets('saved focus is offered as a direct resume path', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 1,
        trackingKey: '2026-2027:TEST_OUTCOME:1',
        outcomeCode: 'TEST.1',
        themeTitle: 'TEST TEMA',
        blockId: 'TEST_BLOCK',
        blockTitle: 'Test Blok',
        updatedAt: DateTime(2026, 9, 14, 10),
      ),
    );
    final repository = _FakeRepository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: MemoryOutcomeTrackingRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinuityThisWeekPage(
            repository: repository,
            service: service,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kaldığın yer'), findsOneWidget);
    expect(
      find.text('1. Hafta · TEST.1 · TEST TEMA · Test Blok'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Devam et'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Devam et'));
    await tester.pumpAndSettle();

    expect(find.text('Derste lazım'), findsOneWidget);
    expect(find.text('TEST.1'), findsWidgets);
  });

  testWidgets('opening outcome stores focus without creating tracking state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final continuity = MemoryContinuityRepository();
    final tracking = MemoryOutcomeTrackingRepository();
    final repository = _FakeRepository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: tracking,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinuityThisWeekPage(
            repository: repository,
            service: service,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await continuity.getLastFocus('TDE_9'), isNull);
    expect(await tracking.getForAcademicYear('2026-2027'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Ders ayrıntısını aç'));
    await tester.pumpAndSettle();

    final stored = await continuity.getLastFocus('TDE_9');
    expect(stored, isNotNull);
    expect(stored!.trackingKey, '2026-2027:TEST_OUTCOME:1');
    expect(stored.outcomeCode, 'TEST.1');
    expect(stored.blockId, 'TEST_BLOCK');
    expect(await tracking.getForAcademicYear('2026-2027'), isEmpty);
  });

  testWidgets('completed tracking does not erase the last viewed focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 1,
        trackingKey: '2026-2027:TEST_OUTCOME:1',
        outcomeCode: 'TEST.1',
        themeTitle: 'TEST TEMA',
        blockId: 'TEST_BLOCK',
        blockTitle: 'Test Blok',
        updatedAt: DateTime(2026, 9, 14, 10),
      ),
    );
    final tracking = MemoryOutcomeTrackingRepository();
    final repository = _FakeRepository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: tracking,
    );
    final plan = await service.buildPlan();
    final item = plan.week(1)!.outcomes.single;
    await service.setStatus(item, OutcomeTrackingStatus.completed);

    final storedBeforeBuild = await continuity.getLastFocus('TDE_9');
    expect(storedBeforeBuild, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinuityThisWeekPage(
            repository: repository,
            service: service,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kaldığın yer'), findsOneWidget);
    expect(
      find.text('1. Hafta · TEST.1 · TEST TEMA · Test Blok'),
      findsOneWidget,
    );
    expect(
      (await continuity.getLastFocus('TDE_9'))?.trackingKey,
      item.trackingKey,
    );
  });

  testWidgets('stale academic-year focus is cleared', (tester) async {
    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2025-2026',
        weekNumber: 1,
        trackingKey: '2025-2026:TEST_OUTCOME:1',
        outcomeCode: 'TEST.1',
        updatedAt: DateTime(2026, 6, 1),
      ),
    );
    final repository = _FakeRepository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: MemoryOutcomeTrackingRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinuityThisWeekPage(
            repository: repository,
            service: service,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kaldığın yer'), findsNothing);
    expect(await continuity.getLastFocus('TDE_9'), isNull);
  });

  test(
    'malformed optional continuity fields are ignored instead of throwing',
    () async {
      SharedPreferences.setMockInitialValues({
        'last_focus_v1_TDE_9':
            '{"course_id":"TDE_9","academic_year":"2026-2027","week_number":1,'
            '"tracking_key":"2026-2027:TEST_OUTCOME:1","outcome_code":"TEST.1",'
            '"theme_title":42,"updated_at":"2026-09-14T10:00:00.000"}',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesContinuityRepository(preferences);

      expect(await repository.getLastFocus('TDE_9'), isNull);
      expect(preferences.getString('last_focus_v1_TDE_9'), isNull);
    },
  );

  testWidgets(
    'continuity read failure does not block the weekly lesson workspace',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeRepository();
      final service = OutcomePlanningService(
        repository: repository,
        weeklyPlanning: _FakeWeeklyPlanning(),
        trackingRepository: MemoryOutcomeTrackingRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContinuityThisWeekPage(
              repository: repository,
              service: service,
              continuity: const _FailingContinuityRepository(),
              courseId: 'TDE_9',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ŞİMDİ'), findsOneWidget);
      expect(find.text('TEST.1'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Ders ayrıntısını aç'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeRepository implements CourseKnowledgeRepository {
  static const course = model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );
  static const theme = model.Theme(
    id: 'TEST_THEME',
    order: 1,
    title: 'TEST TEMA',
    pageRange: null,
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );
  static const block = model.Block(
    id: 'TEST_BLOCK',
    themeId: 'TEST_THEME',
    order: 1,
    title: 'Test Blok',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );
  static const outcome = model.Outcome(
    id: 'TEST_OUTCOME',
    themeId: 'TEST_THEME',
    code: 'TEST.1',
    officialText: 'İlk test kazanımı',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );
  static const detail = model.BlockDetail(
    theme: theme,
    block: block,
    outcomes: [outcome],
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
  Future<model.Course> getCourse() async => course;

  @override
  Future<model.RuntimeManifest> getManifest() async =>
      const model.RuntimeManifest(
        runtimePackageVersion: '1.0.0',
        schemaVersion: '1.0.0',
        courseId: 'TDE_9',
        validationStatus: 'PASS',
        canonicalContentFingerprint: 'test',
        rowCounts: {},
        timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
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
      schoolBasedHoursStatus: 'CONFIRMED',
    ),
  ];

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(
    String themeId,
  ) async => const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async =>
      const model.TeacherPackage(
        theme: theme,
        blocks: [block],
        outcomes: [outcome],
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

class _FakeWeeklyPlanning implements WeeklyPlanningService {
  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async =>
      AnnualWeeklyPlan(
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
                theme: _FakeRepository.theme,
                hours: 5,
                block: _FakeRepository.block,
              ),
            ],
            outcomes: const [_FakeRepository.outcome],
          ),
        ],
      );
}

class _FailingContinuityRepository implements ContinuityRepository {
  const _FailingContinuityRepository();

  @override
  Future<LastFocusState?> getLastFocus(String courseId) =>
      Future<LastFocusState?>.error(StateError('continuity unavailable'));

  @override
  Future<void> setLastFocus(LastFocusState state) =>
      Future<void>.error(StateError('continuity unavailable'));

  @override
  Future<void> clearLastFocus(String courseId) =>
      Future<void>.error(StateError('continuity unavailable'));
}