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
import 'package:ogretmen_os/features/shared/feature_widgets.dart';

void main() {
  testWidgets('uygulama kazanım takibi ekranında açılır ve durum güncellenir', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    expect(find.text('Kazanım Takibi'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('TEST.1'),
      250,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('TEST.1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Planlı'),
      250,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('Planlı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Test kazanımı'),
      250,
      scrollable: _currentPageScrollable(),
    );
    expect(find.textContaining('Test kazanımı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'İşlendi'),
      250,
      scrollable: _currentPageScrollable(),
    );
    final completedButton = find.widgetWithText(FilledButton, 'İşlendi');
    await tester.ensureVisible(completedButton);
    await tester.pumpAndSettle();
    await tester.tap(completedButton);
    await tester.pumpAndSettle();

    expect(find.text('İşlendi'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Deftere Bakış'),
      300,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('Deftere Bakış'), findsOneWidget);
  });

  testWidgets('kazanım ana ekranı blok saatini ve uzun metin açılımını gösterir', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    await tester.scrollUntilVisible(
      find.text('Bu hafta ilgili blok: 5 saat'),
      300,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('Bu hafta ilgili blok: 5 saat'), findsOneWidget);
    expect(
      find.textContaining('kazanıma atanmış resmî süre değil'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Devamını göster'),
      250,
      scrollable: _currentPageScrollable(),
    );
    final expandButton = find.widgetWithText(TextButton, 'Devamını göster');
    await tester.ensureVisible(expandButton);
    await tester.pumpAndSettle();
    await tester.tap(expandButton);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Kısalt'), findsOneWidget);
  });

  testWidgets('kazanım kartından öğretmen notu eklenebilir', (tester) async {
    _usePhoneViewport(tester);
    final preferences = _FakePreferences();
    final tracking = MemoryOutcomeTrackingRepository();
    final outcomePlanning = OutcomePlanningService(
      repository: _FakeRepository(),
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: tracking,
    );
    await _pumpApp(
      tester,
      preferences: preferences,
      outcomePlanning: outcomePlanning,
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Not'),
      300,
      scrollable: _currentPageScrollable(),
    );
    final noteButton = find.widgetWithText(TextButton, 'Not');
    await tester.ensureVisible(noteButton);
    await tester.pumpAndSettle();
    await tester.tap(noteButton);
    await tester.pumpAndSettle();

    expect(find.text('Öğretmen notu'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Örnek ders notu');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records, hasLength(1));
    expect(records.single.teacherNote, 'Örnek ders notu');

    await _pumpApp(
      tester,
      preferences: preferences,
      outcomePlanning: outcomePlanning,
    );
    await tester.scrollUntilVisible(
      find.text('Not var'),
      300,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('Not var'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Notu düzenle'), findsOneWidget);
  });

  testWidgets('hafta swipe ile değişir ve bu haftaya dön kısayolu çalışır', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    expect(find.text('14 Eylül - 18 Eylül 2026'), findsOneWidget);
    await tester.fling(
      find.text('Kazanım Takibi'),
      const Offset(-420, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('21 Eylül - 25 Eylül 2026'), findsOneWidget);
    expect(find.text('Bu haftaya dön'), findsOneWidget);

    await tester.tap(find.text('Bu haftaya dön'));
    await tester.pumpAndSettle();
    expect(find.text('14 Eylül - 18 Eylül 2026'), findsOneWidget);
  });

  testWidgets('kazanım kartı ders yürütme ayrıntısına açılır', (tester) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    await tester.scrollUntilVisible(
      find.textContaining('Test kazanımı'),
      250,
      scrollable: _currentPageScrollable(),
    );
    final outcomeText = find.textContaining('Test kazanımı');
    await tester.ensureVisible(outcomeText);
    await tester.pumpAndSettle();
    await tester.tap(outcomeText);
    await tester.pumpAndSettle();

    expect(find.text('KAZANIM AYRINTISI'), findsOneWidget);
    expect(find.text('Sınıftaki gerçekleşen durum'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Test Blok'),
      300,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('Test Blok'), findsOneWidget);
  });

  testWidgets('kazanım detayında not yalnız değişince kaydedilebilir', (tester) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    await tester.scrollUntilVisible(
      find.textContaining('Test kazanımı'),
      250,
      scrollable: _currentPageScrollable(),
    );
    await tester.tap(find.textContaining('Test kazanımı'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Not güncel'),
      300,
      scrollable: _currentPageScrollable(),
    );
    final currentButton = find.widgetWithText(FilledButton, 'Not güncel');
    expect(currentButton, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(currentButton).onPressed, isNull);

    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Detay notu');
    await tester.pump();
    expect(find.text('Notu kaydet'), findsOneWidget);
  });

  testWidgets('haftalık plan saat dağılımını öne çıkarır ve kazanım referansı açılır', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    await _tapBottomDestination(tester, Icons.calendar_view_week_outlined);
    await tester.pumpAndSettle();

    expect(find.text('Haftalık Plan'), findsOneWidget);
    expect(find.textContaining('14 Eylül - 18 Eylül 2026'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.text('ders saati'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('1 program çıktısı'),
      300,
      scrollable: _currentPageScrollable(),
    );
    await tester.tap(find.text('1 program çıktısı'));
    await tester.pumpAndSettle();
    expect(find.text('TEST.1'), findsOneWidget);
  });

  testWidgets('yıllık planda manuel plan konumu seçilebilir', (tester) async {
    _usePhoneViewport(tester);
    final preferences = _FakePreferences();
    await _pumpApp(tester, preferences: preferences);

    await _tapBottomDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();

    final sequenceLabel = find.textContaining('Plan sırası: 1 / 1');
    await tester.scrollUntilVisible(
      sequenceLabel,
      300,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('Planlanan öğretim sırası'), findsOneWidget);
    expect(sequenceLabel, findsOneWidget);

    final bookmark = find.widgetWithText(OutlinedButton, 'Burada kaldım');
    await tester.ensureVisible(bookmark);
    await tester.tap(bookmark);
    await tester.pumpAndSettle();
    expect(find.text('Burada kaldım'), findsWidgets);
    expect(await preferences.getManualPositionOverride(), 'TEST_BLOCK');
    expect(find.text('Rotada göster'), findsOneWidget);
  });

  testWidgets('öğretmen paketi ana navigasyondan erişilir', (tester) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    await _tapBottomDestination(tester, Icons.inventory_2_outlined);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tema dosyası'),
      300,
      scrollable: _currentPageScrollable(),
    );
    expect(find.text('Tema dosyası'), findsOneWidget);
    expect(find.text('Kitap'), findsWidgets);
    expect(find.text('Etkinlik'), findsWidgets);
    expect(find.text('Değerlendirme'), findsWidgets);
    expect(find.text('Materyal'), findsWidgets);
  });
}

Finder _currentPageScrollable() => find
    .descendant(
      of: find.byType(AppPage),
      matching: find.byType(Scrollable),
    )
    .first;

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakePreferences preferences,
  OutcomePlanningService? outcomePlanning,
}) async {
  await tester.pumpWidget(
    TeacherOsApp(
      key: UniqueKey(),
      dependencies: AppDependencies(
        repository: _FakeRepository(),
        preferences: preferences,
        weeklyPlanning: _FakeWeeklyPlanning(),
        outcomePlanning: outcomePlanning,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapBottomDestination(
  WidgetTester tester,
  IconData icon,
) async {
  final navigationBar = find.byType(NavigationBar);
  expect(navigationBar, findsOneWidget);
  final target = find.descendant(of: navigationBar, matching: find.byIcon(icon));
  expect(target, findsOneWidget);
  await tester.tap(target);
}

class _FakeRepository implements CourseKnowledgeRepository {
  static const _course = model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Test Course',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );
  static const _theme = model.Theme(
    id: 'TEST_THEME',
    order: 1,
    title: 'Test Tema',
    pageRange: null,
    plannedHours: null,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );
  static const _block = model.Block(
    id: 'TEST_BLOCK',
    themeId: 'TEST_THEME',
    order: 1,
    title: 'Test Blok',
    skillDomain: null,
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );
  static const _outcome = model.Outcome(
    id: 'TEST_OUTCOME',
    themeId: 'TEST_THEME',
    code: 'TEST.1',
    officialText:
        'Test kazanımı; öğrencinin metni bağlam, yapı, anlam ilişkileri ve dil özellikleri bakımından incelemesini, elde ettiği bulguları gerekçelendirmesini ve farklı metinlerle ilişkilendirerek açıklamasını kapsayan uzun bir resmî kazanım metnidir.',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );

  @override
  Future<model.Course> getCourse() async => _course;

  @override
  Future<model.RuntimeManifest> getManifest() async => const model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: 'TDE_9',
    validationStatus: 'PASS',
    canonicalContentFingerprint: 'test',
    rowCounts: {},
    timelineResolution: 'THEME_TIME_RESOLVED',
    timelineUnresolvedFields: {},
  );

  @override
  Future<List<model.Theme>> getThemes() async => const [_theme];

  @override
  Future<model.Theme> getTheme(String themeId) async => _theme;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => const [_block];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async => _detail;

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async => const [
    model.TimelineEntry(
      sequencePosition: 1,
      theme: _theme,
      block: _block,
      officialTotalHours: null,
      coreInstructionHours: null,
      schoolBasedHours: null,
      schoolBasedHoursStatus: null,
    ),
  ];

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(String themeId) async =>
      const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async =>
      const model.TeacherPackage(
        theme: _theme,
        blocks: [_block],
        outcomes: [_outcome],
        textbookSections: [],
        activities: [],
        forms: [],
        assessmentArtifacts: [],
        assessmentGaps: [],
        assessmentTaskBindings: [],
        resourceDecisions: [],
        sourceReferences: [],
      );

  static const _detail = model.BlockDetail(
    theme: _theme,
    block: _block,
    outcomes: [_outcome],
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
            theme: _FakeRepository._theme,
            block: _FakeRepository._block,
            hours: 5,
          ),
        ],
        outcomes: const [_FakeRepository._outcome],
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
            theme: _FakeRepository._theme,
            block: _FakeRepository._block,
            hours: 5,
          ),
        ],
        outcomes: const [_FakeRepository._outcome],
      ),
    ],
  );
}

class _FakePreferences implements UserPreferencesRepository {
  String? _value;

  @override
  Future<void> clearManualPositionOverride() async => _value = null;

  @override
  Future<String?> getManualPositionOverride() async => _value;

  @override
  Future<void> setManualPositionOverride(String blockId) async =>
      _value = blockId;
}
