import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
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

    expect(find.text('BU TEMADA HAZIR'), findsOneWidget);
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
    expect(find.textContaining('TEMA 1 için öğretim programı hazır'), findsOneWidget);
    expect(find.text('Kaynak 1'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEMA 2').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('TEMA 2 için öğretim programı hazır'), findsOneWidget);
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

    expect(find.text('BU TEMADA HAZIR'), findsOneWidget);
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

class _ResourceRepository implements CourseKnowledgeRepository {
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
    outcomes: [],
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
    blocks: [],
    outcomes: [],
    textbookSections: [],
    activities: [],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source2],
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
  Future<List<model.Theme>> getThemes() async => const [theme1, theme2];

  @override
  Future<model.Theme> getTheme(String themeId) async =>
      themeId == theme2.id ? theme2 : theme1;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async =>
      themeId == theme1.id ? const [block] : const [];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async => const model.BlockDetail(
    theme: theme1,
    block: block,
    outcomes: [],
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
  Future<List<model.ResourceDecision>> getResourceDecisions(String themeId) async =>
      const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async =>
      themeId == theme2.id ? package2 : package1;
}
