import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';

void main() {
  testWidgets('uygulama ana navigasyonu yüklenir', (tester) async {
    await tester.pumpWidget(
      TeacherOsApp(
        dependencies: AppDependencies(
          repository: _FakeRepository(),
          preferences: _FakePreferences(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Course'), findsOneWidget);
    expect(find.text('Seçili Plan Konumu'), findsOneWidget);
    expect(find.text('Test Tema'), findsOneWidget);

    await tester.tap(find.text('Test Tema'));
    await tester.pumpAndSettle();
    expect(find.text('Test Blok'), findsOneWidget);

    await tester.tap(find.text('Test Blok'));
    await tester.pumpAndSettle();
    expect(find.text('Blok Özeti'), findsOneWidget);
  });

  testWidgets('yıllık planda manuel plan konumu seçilebilir', (tester) async {
    final preferences = _FakePreferences();
    await tester.pumpWidget(
      TeacherOsApp(
        dependencies: AppDependencies(
          repository: _FakeRepository(),
          preferences: preferences,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yıllık Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Planlanan öğretim sırası'), findsOneWidget);
    expect(find.textContaining('Plan sırası: 1 / 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Burada kaldım'));
    await tester.pumpAndSettle();
    expect(find.text('Seçili plan konumu kaydedildi.'), findsOneWidget);
    expect(await preferences.getManualPositionOverride(), 'TEST_BLOCK');
  });

  testWidgets('kitap-önce ve öğretmen paketi ekranlarına erişilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      TeacherOsApp(
        dependencies: AppDependencies(
          repository: _FakeRepository(),
          preferences: _FakePreferences(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bugünkü Ders'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Kitap-Önce'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Kitap-Önce'));
    await tester.pumpAndSettle();
    expect(find.text('Runtime kaynak kararları'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Öğretmen Paketi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Seçili temanın doğrulanmış öğretmen paketi'),
      findsOneWidget,
    );
  });
}

class _FakeRepository implements CourseKnowledgeRepository {
  final _course = const Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Test Course',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );
  final _theme = const Theme(
    id: 'TEST_THEME',
    order: 1,
    title: 'Test Tema',
    pageRange: null,
    plannedHours: null,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );
  final _block = const Block(
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
  Future<Course> getCourse() async => _course;

  @override
  Future<RuntimeManifest> getManifest() async => const RuntimeManifest(
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
  Future<List<Theme>> getThemes() async => [_theme];

  @override
  Future<Theme> getTheme(String themeId) async => _theme;

  @override
  Future<List<Block>> getBlocks(String themeId) async => [_block];

  @override
  Future<BlockDetail> getBlock(String blockId) async => _detail;

  @override
  Future<List<TimelineEntry>> getAnnualSequence() async => [
    TimelineEntry(
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
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) async =>
      const [];

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) async =>
      const TeacherPackage(
        theme: Theme(
          id: 'TEST_THEME',
          order: 1,
          title: 'Test Tema',
          pageRange: null,
          plannedHours: null,
          anlamaHours: null,
          anlatmaHours: null,
          sourceLocator: null,
        ),
        blocks: [],
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

  BlockDetail get _detail => const BlockDetail(
    theme: Theme(
      id: 'TEST_THEME',
      order: 1,
      title: 'Test Tema',
      pageRange: null,
      plannedHours: null,
      anlamaHours: null,
      anlatmaHours: null,
      sourceLocator: null,
    ),
    block: Block(
      id: 'TEST_BLOCK',
      themeId: 'TEST_THEME',
      order: 1,
      title: 'Test Blok',
      skillDomain: null,
      learningArea: null,
      plannedHours: null,
      timeStatus: 'ORDER_ONLY',
      sourceLocators: [],
    ),
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
