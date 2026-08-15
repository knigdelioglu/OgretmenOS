import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';

void main() {
  testWidgets('phone portrait uses bottom navigation without overflow', (
    tester,
  ) async {
    await _configureView(tester, const Size(360, 800));
    await _pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('large system text remains usable on phone', (tester) async {
    await _configureView(
      tester,
      const Size(360, 800),
      textScaleFactor: 2,
    );
    await _pumpApp(tester);

    expect(find.text('Türk Dili ve Edebiyatı'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.view_timeline_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Planlanan öğretim sırası'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Planlanan öğretim sırası'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode renders the product shell', (tester) async {
    await _configureView(
      tester,
      const Size(412, 915),
      brightness: Brightness.dark,
    );
    await _pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookmark action keeps a 48dp touch target', (tester) async {
    await _configureView(tester, const Size(360, 800));
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.view_timeline_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Burada kaldım'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    final bookmark = find.byTooltip('Burada kaldım');
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ResponsiveFakeRepository implements CourseKnowledgeRepository {
  static const _course = model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );

  static const _theme = model.Theme(
    id: 'TEST_THEME',
    order: 1,
    title: '1. Tema: Sözün İnceliği ve Edebî Anlatım',
    pageRange: '20-64',
    plannedHours: 43,
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
      officialTotalHours: 43,
      coreInstructionHours: 43,
      schoolBasedHours: null,
      schoolBasedHoursStatus: 'UNRESOLVED',
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
        outcomes: [],
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
    outcomes: [],
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
