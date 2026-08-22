import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/outcome_planning_service.dart';

void main() {
  testWidgets('ana deneyim Bu Hafta ekranında açılır ve kazanım işlenir', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    expect(find.text('Bu Hafta'), findsWidgets);
    expect(find.text('1. Hafta'), findsOneWidget);
    expect(find.text('TEST.1'), findsOneWidget);
    expect(find.text('Paket'), findsNothing);
    expect(find.text('Haftalık Plan'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'İşlendi'));
    await tester.pumpAndSettle();

    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records, hasLength(1));
    expect(records.single.status.storageValue, 'completed');
    expect(find.text('1 / 1 işlendi'), findsOneWidget);
  });

  testWidgets('yıllık plan tema bazında kompakt gösterilir', (tester) async {
    _phone(tester);
    await _pump(tester);

    await _tapNavigation(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();

    expect(find.textContaining('1 tema · 45 saat · 1 blok'), findsOneWidget);
    expect(find.text('TEST TEMA'), findsOneWidget);
    expect(find.text('Test Blok'), findsOneWidget);
    expect(find.textContaining('Bu blok için ayrı süre bilgisi'), findsNothing);
  });

  testWidgets('ana navigasyon yalnız üç öğretmen işini gösterir', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Bu Hafta'), findsWidgets);
    expect(find.text('Yıllık'), findsOneWidget);
    expect(find.text('Kaynaklar'), findsOneWidget);
    expect(find.text('Kazanımlar'), findsNothing);
    expect(find.text('Haftalık'), findsNothing);
    expect(find.text('Paket'), findsNothing);
  });

  testWidgets('kaynaklar ekranı program verisini tekrar etmez', (tester) async {
    _phone(tester);
    await _pump(tester);

    await _tapNavigation(tester, Icons.library_books_outlined);
    await tester.pumpAndSettle();

    expect(find.text('Kaynaklar'), findsWidgets);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Öğretim blokları'), findsNothing);
    expect(find.text('Program çıktıları'), findsNothing);
    expect(find.text('0 etkinlik'), findsNothing);
    expect(find.text('0 form'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  MemoryOutcomeTrackingRepository? tracking,
}) async {
  final repository = _FakeRepository();
  final weekly = _FakeWeeklyPlanning();
  final outcomePlanning = OutcomePlanningService(
    repository: repository,
    weeklyPlanning: weekly,
    trackingRepository: tracking ?? MemoryOutcomeTrackingRepository(),
  );
  await tester.pumpWidget(
    TeacherOsApp(
      dependencies: AppDependencies(
        repository: repository,
        preferences: _FakePreferences(),
        weeklyPlanning: weekly,
        outcomePlanning: outcomePlanning,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapNavigation(WidgetTester tester, IconData icon) async {
  final bar = find.byType(NavigationBar);
  expect(bar, findsOneWidget);
  final target = find.descendant(of: bar, matching: find.byIcon(icon));
  expect(target, findsOneWidget);
  await tester.tap(target);
}

class _FakePreferences implements UserPreferencesRepository {
  String? value;

  @override
  Future<void> clearManualPositionOverride() async => value = null;

  @override
  Future<String?> getManualPositionOverride() async => value;

  @override
  Future<void> setManualPositionOverride(String blockId) async => value = blockId;
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
    officialText: 'Test kazanımı',
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
  Future<model.RuntimeManifest> getManifest() async => const model.RuntimeManifest(
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
  Future<List<model.ResourceDecision>> getResourceDecisions(String themeId) async =>
      const [];

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
