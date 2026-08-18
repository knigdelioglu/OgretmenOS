import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/shared/feature_widgets.dart';

void main() {
  for (final size in const [
    Size(360, 640),
    Size(360, 800),
    Size(412, 915),
  ]) {
    testWidgets('phone ${size.width.toInt()}x${size.height.toInt()} has no shell overflow', (
      tester,
    ) async {
      await _configureView(tester, size);
      await _pumpApp(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Kazanım Takibi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tablet portrait uses navigation rail without overflow', (
    tester,
  ) async {
    await _configureView(tester, const Size(800, 1280));
    await _pumpApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet landscape uses navigation rail without overflow', (
    tester,
  ) async {
    await _configureView(tester, const Size(1280, 800));
    await _pumpApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2x system text keeps all primary phone destinations usable', (
    tester,
  ) async {
    await _configureView(
      tester,
      const Size(360, 800),
      textScaleFactor: 2,
    );
    await _pumpApp(tester);

    expect(find.text('Kazanım Takibi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapBottomDestination(tester, Icons.calendar_view_week_outlined);
    await tester.pumpAndSettle();
    expect(find.text('Haftalık Plan'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapBottomDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PageHeader),
        matching: find.text('Yıllık Plan'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _tapBottomDestination(tester, Icons.inventory_2_outlined);
    await tester.pumpAndSettle();
    expect(find.text('Öğretmen Paketi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode renders the outcome tracker shell', (tester) async {
    await _configureView(
      tester,
      const Size(412, 915),
      brightness: Brightness.dark,
    );
    await _pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text('Kazanım Takibi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('annual position action keeps a 48dp touch target', (tester) async {
    await _configureView(tester, const Size(360, 800));
    await _pumpApp(tester);

    await _tapBottomDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();
    final bookmark = find.widgetWithText(OutlinedButton, 'Burada kaldım');
    await tester.scrollUntilVisible(
      bookmark,
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(bookmark, findsOneWidget);
    final size = tester.getSize(bookmark);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _configureView(
  WidgetTester tester,
  Size size, {
  double textScaleFactor = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    TeacherOsApp(
      dependencies: AppDependencies(
        repository: _ResponsiveFakeRepository(),
        preferences: _ResponsiveFakePreferences(),
        weeklyPlanning: _ResponsiveFakeWeeklyPlanning(),
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

class _ResponsiveFakeRepository implements CourseKnowledgeRepository {
  static const _theme = model.Theme(
    id: 'TEST_THEME',
    order: 1,
    title: '1. Tema: Sözün İnceliği ve Edebî Anlatım',
    pageRange: '20-64',
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );

  static const _block = model.Block(
    id: 'TEST_BLOCK',
    themeId: 'TEST_THEME',
    order: 1,
    title: 'Okuma Bloğu: Şiir ve Deneme Metinlerini İnceleme',
    skillDomain: null,
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const _outcome = model.Outcome(
    id: 'TEST_OUTCOME',
    themeId: 'TEST_THEME',
    code: 'TDE.TEST.1',
    officialText:
        'Uzun bir doğrulanmış kazanım metni büyük yazı ölçeğinde kartın taşmadan büyümesini doğrular.',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
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

  @override
  Future<model.Course> getCourse() async => const model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );

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
}

class _ResponsiveFakeWeeklyPlanning implements WeeklyPlanningService {
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
            theme: _ResponsiveFakeRepository._theme,
            block: _ResponsiveFakeRepository._block,
            hours: 5,
          ),
        ],
        outcomes: const [_ResponsiveFakeRepository._outcome],
      ),
    ],
  );
}

class _ResponsiveFakePreferences implements UserPreferencesRepository {
  String? _value;

  @override
  Future<void> clearManualPositionOverride() async => _value = null;

  @override
  Future<String?> getManualPositionOverride() async => _value;

  @override
  Future<void> setManualPositionOverride(String blockId) async =>
      _value = blockId;
}
