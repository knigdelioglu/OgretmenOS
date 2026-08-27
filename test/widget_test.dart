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
  testWidgets('ana deneyim tracking gerektirmeden tek odakta yürür', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    expect(find.text('Bu Hafta'), findsWidgets);
    expect(find.text('ŞİMDİ'), findsOneWidget);
    expect(find.text('Sıradaki'), findsNothing);
    expect(find.text('Ders ayrıntısını aç'), findsOneWidget);
    expect(find.text('Hafta değiştir'), findsOneWidget);
    expect(find.text('1. Hafta'), findsOneWidget);
    expect(find.text('TEST.1'), findsOneWidget);
    expect(find.text('TEST.2'), findsNothing);
    expect(find.text('TEST.3'), findsNothing);
    expect(find.text('Planlı'), findsNothing);
    expect(find.textContaining('Takip:'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Başla'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);
    expect(await tracking.getForAcademicYear('2026-2027'), isEmpty);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    expect(find.text('Devam ediyor olarak işaretle'), findsOneWidget);
    expect(find.text('İşlendi olarak işaretle'), findsOneWidget);
    expect(find.text('Kısmen işlendi'), findsOneWidget);

    await tester.tap(find.text('İşlendi olarak işaretle'));
    await tester.pumpAndSettle();

    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records, hasLength(1));
    expect(records.single.status.storageValue, 'completed');
    expect(find.text('TEST.2'), findsOneWidget);
    expect(find.text('Ders ayrıntısını aç'), findsOneWidget);
  });

  testWidgets('başka hafta isteğe bağlı açılır ve bu haftaya dönüş nettir', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);

    expect(find.text('ŞİMDİ'), findsOneWidget);
    expect(find.text('İNCELEDİĞİN HAFTA'), findsNothing);
    expect(find.text('Bu haftaya dön'), findsNothing);

    await tester.tap(find.text('Hafta değiştir'));
    await tester.pumpAndSettle();

    expect(find.text('Haftaya git'), findsOneWidget);
    expect(find.text('2. Hafta'), findsOneWidget);
    expect(find.textContaining('Bu hafta'), findsWidgets);

    await tester.tap(find.text('2. Hafta'));
    await tester.pumpAndSettle();

    expect(find.text('İNCELEDİĞİN HAFTA'), findsOneWidget);
    expect(find.text('ŞİMDİ'), findsNothing);
    expect(find.text('2. Hafta'), findsOneWidget);
    expect(find.text('Bu haftaya dön'), findsOneWidget);
    expect(find.text('Ders ayrıntısını aç'), findsNothing);

    await tester.tap(find.text('Bu haftaya dön'));
    await tester.pumpAndSettle();

    expect(find.text('ŞİMDİ'), findsOneWidget);
    expect(find.text('1. Hafta'), findsOneWidget);
    expect(find.text('Bu haftaya dön'), findsNothing);
    expect(find.text('Ders ayrıntısını aç'), findsOneWidget);
  });

  testWidgets('diğer açık kazanımlar varsayılan olarak kapalıdır', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);

    expect(find.text('TEST.1'), findsOneWidget);
    expect(find.text('TEST.2'), findsNothing);
    expect(find.text('TEST.3'), findsNothing);

    final group = find.text('Bu haftanın diğerleri');
    await tester.scrollUntilVisible(
      group,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(group, findsOneWidget);
    expect(find.text('2 kazanım'), findsOneWidget);

    await tester.tap(group);
    await tester.pumpAndSettle();

    expect(find.text('TEST.2'), findsOneWidget);
    expect(find.text('TEST.3'), findsOneWidget);
  });

  testWidgets('tamamlanan kazanımlar varsayılan olarak geri planda kalır', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşlendi olarak işaretle'));
    await tester.pumpAndSettle();

    expect(find.text('TEST.1'), findsNothing);

    final completedGroup = find.text('İşlendi olarak işaretlenenler');
    await tester.scrollUntilVisible(
      completedGroup,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(completedGroup, findsOneWidget);

    await tester.tap(completedGroup);
    await tester.pumpAndSettle();

    expect(find.text('TEST.1'), findsOneWidget);
  });

  testWidgets('hızlı not ana ekrandan kaydedilir ve odakta görünür', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hızlı not'));
    await tester.pumpAndSettle();

    expect(find.text('Hızlı not'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'Son etkinlik gelecek derste tamamlanacak.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records, hasLength(1));
    expect(
      records.single.teacherNote,
      'Son etkinlik gelecek derste tamamlanacak.',
    );
    expect(
      find.text('Son etkinlik gelecek derste tamamlanacak.'),
      findsOneWidget,
    );
  });

  testWidgets('kısmen işlendi ikincil menüden seçilebilir', (tester) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kısmen işlendi'));
    await tester.pumpAndSettle();

    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records, hasLength(1));
    expect(records.single.status.storageValue, 'partially_completed');
    expect(find.text('Takip: Kısmen işlendi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);
  });

  testWidgets('gelecek haftaya taşı kaynak haftanın odağını serbest bırakır', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelecek haftaya taşı'));
    await tester.pumpAndSettle();

    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records, hasLength(1));
    expect(records.single.status.storageValue, 'carried_over');
    expect(records.single.carriedToWeekNumber, 2);
    expect(find.text('TEST.1'), findsNothing);
    expect(find.text('TEST.2'), findsOneWidget);

    final carriedGroup = find.text('Sonraki haftaya taşınanlar');
    await tester.scrollUntilVisible(
      carriedGroup,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(carriedGroup, findsOneWidget);
  });

  testWidgets('kazanım ayrıntısı derste lazım bilgisini öne çıkarır', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);

    await tester.tap(find.text('Ders ayrıntısını aç'));
    await tester.pumpAndSettle();

    expect(find.text('Derste lazım'), findsOneWidget);
    expect(find.text('Daha fazla bilgi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Başla'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);
    expect(find.text('Planlı'), findsNothing);
    expect(find.text('Deftere kopyala'), findsOneWidget);
    expect(find.text('TEST SÜREÇ BİLEŞENİ'), findsNothing);
    expect(find.text('Notu kaydet'), findsNothing);
    expect(find.byTooltip('Blok ayrıntısını aç'), findsNothing);

    final more = find.text('Daha fazla bilgi');
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(find.text('Öğretmen notu'), findsOneWidget);
    expect(find.text('Takip seçenekleri'), findsOneWidget);
    expect(find.text('İsteğe bağlı · Takip yok'), findsOneWidget);
    expect(find.text('Süreç bileşenleri'), findsOneWidget);
    expect(find.text('Plan ve blok bağlamı'), findsOneWidget);
    expect(find.text('TEST SÜREÇ BİLEŞENİ'), findsNothing);

    final process = find.text('Süreç bileşenleri');
    await tester.ensureVisible(process);
    await tester.pumpAndSettle();
    await tester.tap(process);
    await tester.pumpAndSettle();

    expect(find.text('TEST SÜREÇ BİLEŞENİ'), findsOneWidget);
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

  testWidgets('Faz 6 konum ile isteğe bağlı takibi birbirine karıştırmaz', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    // Viewing a lesson creates continuity only; it is not teacher progress.
    await tester.tap(find.text('Ders ayrıntısını aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();

    // An explicit teacher action creates optional tracking.
    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşlendi olarak işaretle'));
    await tester.pumpAndSettle();

    await _tapNavigation(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();

    expect(find.text('ŞU AN BURADASIN'), findsOneWidget);
    expect(find.text('Öğretim sırası: 1. blok / 1'), findsOneWidget);
    expect(
      find.text('Bu konum bir ilerleme veya tamamlanma yüzdesi değildir.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('İSTEĞE BAĞLI TAKİP'), findsOneWidget);
    expect(find.text('İşlendi 1'), findsOneWidget);
    expect(
      find.textContaining('işaretlenmemiş kazanımlar eksik sayılmaz'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('ana navigasyon yalnız üç öğretmen işini gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Bu Hafta'), findsWidgets);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Yıllık'), findsNothing);
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
    expect(find.text('Tema değiştir'), findsOneWidget);
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
  Future<void> setManualPositionOverride(String blockId) async =>
      value = blockId;
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
    processComponents: 'TEST SÜREÇ BİLEŞENİ',
    sourceLocator: null,
    verificationStatus: 'PASS',
  );
  static const outcome2 = model.Outcome(
    id: 'TEST_OUTCOME_2',
    themeId: 'TEST_THEME',
    code: 'TEST.2',
    officialText: 'İkinci test kazanımı',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );
  static const outcome3 = model.Outcome(
    id: 'TEST_OUTCOME_3',
    themeId: 'TEST_THEME',
    code: 'TEST.3',
    officialText: 'Üçüncü test kazanımı',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );

  static const detail = model.BlockDetail(
    theme: theme,
    block: block,
    outcomes: [outcome, outcome2, outcome3],
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
        outcomes: [outcome, outcome2, outcome3],
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
            outcomes: const [
              _FakeRepository.outcome,
              _FakeRepository.outcome2,
              _FakeRepository.outcome3,
            ],
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
                theme: _FakeRepository.theme,
                hours: 5,
                block: _FakeRepository.block,
              ),
            ],
            outcomes: const [],
          ),
        ],
      );
}