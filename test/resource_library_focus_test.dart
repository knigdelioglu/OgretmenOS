import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/preferences/continuity_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/planning_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/resources/resource_library_page.dart';

void main() {
  testWidgets('kaynaklar ilk yararlı kaynağı açık gösterir', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(awaitingTextbook: false));
    await tester.pumpAndSettle();

    expect(find.text('TEMA 1'), findsWidgets);
    expect(find.text('1 bölüm'), findsWidgets);
    expect(find.text('1 etkinlik'), findsWidgets);
    expect(find.text('Ders kitabı'), findsOneWidget);
    expect(find.text('Kitap Bölümü 1'), findsOneWidget);
    expect(find.text('Etkinlikler'), findsOneWidget);
    expect(find.text('Etkinlik 1'), findsNothing);
    expect(find.text('Kaynak dayanakları'), findsOneWidget);
    expect(find.text('Kaynak 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('son görüntülenen ders kaynak odağında mevcut haftayı geçer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ResourceRepository();
    final plan = _contextPlan(currentWeekNumber: 1);
    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 2,
        trackingKey: '2026-2027:O2:2',
        outcomeCode: 'T2.1',
        themeTitle: 'TEMA 2',
        blockId: 'B2',
        blockTitle: 'Blok 2',
        updatedAt: DateTime(2026, 10, 1, 10),
      ),
    );

    await tester.pumpWidget(
      _contextApp(
        repository: repository,
        continuity: continuity,
        weeklyPlanning: _StaticWeeklyPlanning(plan.weeklyPlan),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEMA 2'), findsWidgets);
    expect(find.text('Kaynak 2'), findsOneWidget);
    expect(find.text('Kaynak 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus yoksa kaynaklar mevcut haftanın temasını açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ResourceRepository();
    final plan = _contextPlan(currentWeekNumber: 2);

    await tester.pumpWidget(
      _contextApp(
        repository: repository,
        continuity: MemoryContinuityRepository(),
        weeklyPlanning: _StaticWeeklyPlanning(plan.weeklyPlan),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEMA 2'), findsWidgets);
    expect(find.text('Kaynak 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kitap beklenen sınıfta tema seçimi ve dayanak korunur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(awaitingTextbook: true));
    await tester.pumpAndSettle();

    expect(find.text('Ders kitabı bekleniyor'), findsOneWidget);
    expect(
      find.textContaining('TEMA 1 için öğretim programı hazır'),
      findsOneWidget,
    );
    expect(find.text('Kaynak 1'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEMA 2').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('TEMA 2 için öğretim programı hazır'),
      findsOneWidget,
    );
    expect(find.text('TEMA 2'), findsWidgets);
    expect(find.text('Kaynak 2'), findsOneWidget);
    expect(find.text('Kaynak 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kaynak odağı 360px ve iki kat yazıda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_app(awaitingTextbook: false));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final textbook = find.text('Kitap Bölümü 1');
    await tester.scrollUntilVisible(
      textbook,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(textbook, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({required bool awaitingTextbook}) => MaterialApp(
  home: Scaffold(
    body: ResourceLibraryPage(
      repository: _ResourceRepository(),
      awaitingTextbook: awaitingTextbook,
    ),
  ),
);

Widget _contextApp({
  required _ResourceRepository repository,
  required ContinuityRepository continuity,
  required WeeklyPlanningService weeklyPlanning,
}) => MaterialApp(
  home: Scaffold(
    body: ResourceLibraryPage(
      repository: repository,
      awaitingTextbook: false,
      continuity: continuity,
      weeklyPlanning: weeklyPlanning,
      courseId: 'TDE_9',
    ),
  ),
);

AnnualOutcomePlan _contextPlan({required int currentWeekNumber}) {
  final week1 = AcademicWeekPlan(
    weekNumber: 1,
    start: DateTime(2026, 9, 14),
    end: DateTime(2026, 9, 18),
    type: AcademicWeekType.instruction,
    label: '1. Hafta',
    plannedLessonHours: 5,
    segments: const [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: _ResourceRepository.theme1,
        hours: 5,
        block: _ResourceRepository.block,
      ),
    ],
    outcomes: const [_ResourceRepository.outcome1],
  );
  final week2 = AcademicWeekPlan(
    weekNumber: 2,
    start: DateTime(2026, 9, 21),
    end: DateTime(2026, 9, 25),
    type: AcademicWeekType.instruction,
    label: '2. Hafta',
    plannedLessonHours: 5,
    segments: const [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: _ResourceRepository.theme2,
        hours: 5,
        block: _ResourceRepository.block2,
      ),
    ],
    outcomes: const [_ResourceRepository.outcome2],
  );
  return AnnualOutcomePlan(
    weeklyPlan: AnnualWeeklyPlan(
      academicYear: '2026-2027',
      courseId: 'TDE_9',
      weeklyLessonHours: 5,
      annualHours: 180,
      weeks: [week1, week2],
      currentWeekNumber: currentWeekNumber,
    ),
    weeks: [
      WeeklyOutcomeSummary(
        week: week1,
        outcomes: const [
          TrackedOutcome(
            outcome: _ResourceRepository.outcome1,
            academicYear: '2026-2027',
            plannedWeekNumber: 1,
            displayWeekNumber: 1,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext(detail: _ResourceRepository.detail1),
            ],
          ),
        ],
      ),
      WeeklyOutcomeSummary(
        week: week2,
        outcomes: const [
          TrackedOutcome(
            outcome: _ResourceRepository.outcome2,
            academicYear: '2026-2027',
            plannedWeekNumber: 2,
            displayWeekNumber: 2,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext(detail: _ResourceRepository.detail2),
            ],
          ),
        ],
      ),
    ],
  );
}

class _StaticWeeklyPlanning implements WeeklyPlanningService {
  const _StaticWeeklyPlanning(this.plan);

  final AnnualWeeklyPlan plan;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async => plan;
}

class _ResourceRepository
    implements CourseKnowledgeRepository, CoursePlanningKnowledgeRepository {
  static const course = model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );

  static const theme1 = model.Theme(
    id: 'T1',
    order: 1,
    title: 'TEMA 1',
    pageRange: null,
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );

  static const theme2 = model.Theme(
    id: 'T2',
    order: 2,
    title: 'TEMA 2',
    pageRange: null,
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );

  static const block = model.Block(
    id: 'B1',
    themeId: 'T1',
    order: 1,
    title: 'Blok 1',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const block2 = model.Block(
    id: 'B2',
    themeId: 'T2',
    order: 1,
    title: 'Blok 2',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const outcome1 = model.Outcome(
    id: 'O1',
    themeId: 'T1',
    code: 'T1.1',
    officialText: 'Tema 1 kazanımı',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );

  static const outcome2 = model.Outcome(
    id: 'O2',
    themeId: 'T2',
    code: 'T2.1',
    officialText: 'Tema 2 kazanımı',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );

  static const book = model.TextbookSection(
    id: 'S1',
    themeId: 'T1',
    title: 'Kitap Bölümü 1',
    genre: 'Şiir',
    printedPageRange: '10-15',
    pdfPageRange: '12-17',
    sourceId: 'SRC1',
  );

  static const activity = model.Activity(
    id: 'A1',
    sectionId: 'S1',
    themeId: 'T1',
    title: 'Etkinlik 1',
    activityType: null,
    studentAction: null,
    expectedEvidence: null,
    printedPage: '13',
    pdfPage: '15',
    verificationStatus: 'PASS',
  );

  static const source1 = model.SourceReference(
    id: 'SRC1',
    sourceType: 'TEXTBOOK',
    title: 'Kaynak 1',
    locator: 's. 10-15',
    provenanceCategory: null,
    authorityRank: 1,
    verificationStatus: 'PASS',
    entityLocator: null,
  );

  static const source2 = model.SourceReference(
    id: 'SRC2',
    sourceType: 'CURRICULUM',
    title: 'Kaynak 2',
    locator: 'Tema 2',
    provenanceCategory: null,
    authorityRank: 1,
    verificationStatus: 'PASS',
    entityLocator: null,
  );

  static const package1 = model.TeacherPackage(
    theme: theme1,
    blocks: [block],
    outcomes: [outcome1],
    textbookSections: [book],
    activities: [activity],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source1],
  );

  static const package2 = model.TeacherPackage(
    theme: theme2,
    blocks: [block2],
    outcomes: [outcome2],
    textbookSections: [],
    activities: [],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source2],
  );

  static const detail1 = model.BlockDetail(
    theme: theme1,
    block: block,
    outcomes: [outcome1],
    textbookSections: [book],
    activities: [activity],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source1],
    previousBlock: null,
    nextBlock: null,
  );

  static const detail2 = model.BlockDetail(
    theme: theme2,
    block: block2,
    outcomes: [outcome2],
    textbookSections: [],
    activities: [],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source2],
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
  Future<List<model.Theme>> getThemes() async => const [theme1, theme2];

  @override
  Future<model.Theme> getTheme(String themeId) async =>
      themeId == theme2.id ? theme2 : theme1;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async =>
      themeId == theme1.id ? const [block] : const [];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async =>
      blockId == block2.id ? detail2 : detail1;

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async => const [
    model.TimelineEntry(
      sequencePosition: 1,
      theme: theme1,
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
      themeId == theme2.id ? package2 : package1;

  @override
  Future<PlanningDataset> getPlanningDataset() => throw UnimplementedError();

  @override
  Future<String?> getThemeIdForBlock(String blockId) async =>
      blockId == block2.id ? theme2.id : theme1.id;
}
