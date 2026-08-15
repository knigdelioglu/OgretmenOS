import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';

void main() {
  testWidgets('uygulama ana navigasyonu yüklenir', (tester) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    expect(find.text('Test Course'), findsOneWidget);
    expect(find.text('Kaldığınız yeri seçin'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Test Tema'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Test Tema'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Test Blok'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Test Blok'), findsOneWidget);

    await tester.tap(find.text('Test Blok'));
    await tester.pumpAndSettle();
    expect(find.text('Ders Bloğu'), findsOneWidget);
  });

  testWidgets('yıllık planda manuel plan konumu seçilebilir', (tester) async {
    _usePhoneViewport(tester);
    final preferences = _FakePreferences();
    await _pumpApp(tester, preferences: preferences);

    await _tapBottomDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Planlanan öğretim sırası'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Planlanan öğretim sırası'), findsOneWidget);
    expect(find.textContaining('Plan sırası: 1 / 1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('Burada kaldım'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Burada kaldım'));
    await tester.pumpAndSettle();
    expect(find.text('Burada kaldım'), findsOneWidget);
    expect(await preferences.getManualPositionOverride(), 'TEST_BLOCK');
  });

  testWidgets('kitap ve materyal ile öğretmen paketi ekranlarına erişilir', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await _pumpApp(tester, preferences: _FakePreferences());

    expect(find.text('Bugünkü Ders'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Kitap ve materyal'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Kitap ve materyal'));
    await tester.pumpAndSettle();
    expect(find.text('Bu tema için ne kullanacağım?'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tapBottomDestination(tester, Icons.inventory_2_outlined);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tema dosyası'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Tema dosyası'), findsOneWidget);
  });
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakePreferences preferences,
}) async {
  await tester.pumpWidget(
    TeacherOsApp(
      dependencies: AppDependencies(
        repository: _FakeRepository(),
        preferences: preferences,
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
