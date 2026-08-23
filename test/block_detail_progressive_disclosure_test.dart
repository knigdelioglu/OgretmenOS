import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/block/block_detail_page.dart';

void main() {
  testWidgets('blok ayrıntısı sınıf içi bilgiyi önce gösterir', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BlockDetailPage(
          repository: _BlockDetailRepository(),
          blockId: _BlockDetailRepository.block.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ders Bloğu'), findsOneWidget);
    expect(find.text('Derste lazım'), findsOneWidget);
    expect(find.text('Plan sırası'), findsOneWidget);
    expect(find.text('Daha fazla bilgi'), findsOneWidget);
    expect(find.text('TEST.1'), findsOneWidget);
    expect(find.text('TEST SÜREÇ BİLEŞENİ'), findsNothing);
    expect(find.text('Program çıktıları'), findsNothing);

    final more = find.text('Daha fazla bilgi');
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(find.text('Program çıktıları'), findsOneWidget);
    expect(find.text('Kitap ve etkinlik ayrıntıları'), findsOneWidget);
    expect(find.text('Değerlendirme'), findsOneWidget);
    expect(find.text('Materyal kararları'), findsOneWidget);
    expect(find.text('Kaynak referansları'), findsOneWidget);
    expect(find.text('TEST SÜREÇ BİLEŞENİ'), findsNothing);

    final outcomes = find.text('Program çıktıları');
    await tester.ensureVisible(outcomes);
    await tester.pumpAndSettle();
    await tester.tap(outcomes);
    await tester.pumpAndSettle();

    expect(find.text('TEST SÜREÇ BİLEŞENİ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blok ayrıntısı büyük yazıda taşma üretmez', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: BlockDetailPage(
          repository: _BlockDetailRepository(),
          blockId: _BlockDetailRepository.block.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Derste lazım'), findsOneWidget);
    expect(find.text('Daha fazla bilgi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _BlockDetailRepository implements CourseKnowledgeRepository {
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
