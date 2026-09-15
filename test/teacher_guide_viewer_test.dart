import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/resource_navigation.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/teacher_guide_models.dart';
import 'package:ogretmen_os/domain/models/teacher_guide_note_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/teacher_guide_notes_repository.dart';
import 'package:ogretmen_os/features/resources/resource_library_page.dart';
import 'package:ogretmen_os/features/resources/teacher_guide_relation_action.dart';
import 'package:ogretmen_os/features/resources/teacher_guide_viewer_page.dart';

void main() {
  testWidgets(
    'generic FIZIK_10 guide native viewer renders structured content',
    (tester) async {
      _useSize(tester, const Size(412, 915));

      await tester.pumpWidget(_viewerApp());
      await tester.pumpAndSettle();

      expect(find.text('Beklenen cevap / öğrenci tepkisi'), findsOneWidget);
      expect(find.text('observations'), findsOneWidget);
      expect(find.text('hız değişimi'), findsOneWidget);
      expect(find.text('Öğretmen incelemesi gerekli'), findsOneWidget);
      expect(find.text('Gözlem kaydı'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local search finds guidance/response and keeps the target item',
    (tester) async {
      _useSize(tester, const Size(412, 915));

      await tester.pumpWidget(_viewerApp());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'grafik');
      await tester.pump();

      expect(find.text('1 sonuç'), findsOneWidget);
      expect(find.text('Modeli değiştir'), findsWidgets);
      await tester.tap(find.text('Modeli değiştir').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Pedagojik öneri; kitabın zorunlu yönergesi değildir.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wide layout exposes master-detail outline', (tester) async {
    _useSize(tester, const Size(1100, 800));

    await tester.pumpWidget(_viewerApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.view_agenda_outlined), findsOneWidget);
    expect(find.text('Bölüm'), findsNothing);
    expect(find.text('Deneysel süreç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone and large text layout has no overflow exception', (
    tester,
  ) async {
    _useSize(tester, const Size(360, 800));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _viewerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bölüm'), findsOneWidget);
    expect(find.text('Ünite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assignment note autosaves and stale hash remains visible', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));
    final notes = _MemoryNotes()
      ..values['assignment-A/ITEM_OBSERVATION'] = TeacherGuideNote(
        assignmentId: 'assignment-A',
        guideItemId: 'ITEM_OBSERVATION',
        note: 'Eski sınıf notu',
        canonicalPayloadSha256: 'old-hash',
        updatedAt: DateTime(2026, 9, 14),
      );

    await tester.pumpWidget(
      _viewerApp(assignmentId: 'assignment-A', notes: notes),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Rehber maddesi güncellendi · notunu gözden geçir'),
      findsOneWidget,
    );
    final noteField = find.byType(TextField).last;
    await tester.enterText(noteField, 'Bu sınıf için yeni not');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(notes.saved.single.note, 'Bu sınıf için yeni not');
    expect(notes.saved.single.assignmentId, 'assignment-A');
    expect(notes.saved.single.guideItemId, 'ITEM_OBSERVATION');
    expect(tester.takeException(), isNull);
  });

  testWidgets('capability true shows Resources category and false hides it', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));

    await tester.pumpWidget(_resourcesApp(available: true));
    await tester.pumpAndSettle();
    expect(find.text('Öğretmen Rehberi'), findsOneWidget);

    await tester.pumpWidget(_resourcesApp(available: false));
    await tester.pumpAndSettle();
    expect(find.text('Öğretmen Rehberi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit activity relation opens the generic guide context', (
    tester,
  ) async {
    ResourceNavigationContext? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherGuideRelationAction(
            repository: _GuideRepository(),
            themeId: 'THEME_FORCE',
            targetType: 'activity',
            targetId: 'ACTIVITY_FORCE',
            onOpenResources: (context) => opened = context,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Öğretmen rehberinde aç'), findsOneWidget);
    await tester.tap(find.text('Öğretmen rehberinde aç'));
    expect(opened?.category, ResourceCategory.teacherGuide);
    expect(opened?.itemId, 'ITEM_OBSERVATION');
    expect(opened?.guideItemIds, ['ITEM_OBSERVATION']);
  });

  testWidgets('relation olmayan entity için guide action uydurulmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherGuideRelationAction(
            repository: _GuideRepository(),
            themeId: 'THEME_FORCE',
            targetType: 'activity',
            targetId: 'ACTIVITY_NOT_LINKED',
            onOpenResources: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Öğretmen rehberinde aç'), findsNothing);
  });

  testWidgets('unit switch saves dirty note against the previous guide item', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));
    final notes = _MemoryNotes();

    await tester.pumpWidget(
      _viewerApp(assignmentId: 'assignment-A', notes: notes),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Gözlem notu');
    await tester.pump(const Duration(milliseconds: 100));

    final unitDropdown = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.tap(unitDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modelleme').last);
    await tester.pumpAndSettle();

    expect(notes.saved, isNotEmpty);
    expect(notes.saved.first.guideItemId, 'ITEM_OBSERVATION');
    expect(notes.saved.first.note, 'Gözlem notu');
    expect(find.text('Modeli değiştir'), findsWidgets);
    final noteField = tester.widget<TextField>(find.byType(TextField).last);
    expect(noteField.controller?.text ?? '', isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose flushes a pending note before debounce fires', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));
    final notes = _MemoryNotes();

    await tester.pumpWidget(
      _viewerApp(assignmentId: 'assignment-A', notes: notes),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Kapanış notu');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(notes.saved, isNotEmpty);
    expect(notes.saved.last.guideItemId, 'ITEM_OBSERVATION');
    expect(notes.saved.last.note, 'Kapanış notu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed note save is visible instead of silent loss', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));
    final notes = _MemoryNotes(failSaves: true);

    await tester.pumpWidget(
      _viewerApp(assignmentId: 'assignment-A', notes: notes),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Kaydedilemeyen not');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.textContaining('Not kaydedilemedi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _viewerApp({String? assignmentId, _MemoryNotes? notes}) => MaterialApp(
  home: TeacherGuideViewerPage(
    repository: _GuideRepository(),
    scopeType: 'theme',
    scopeId: 'THEME_FORCE',
    guideId: 'GUIDE_PHYSICS',
    assignmentId: assignmentId,
    notesRepository: notes,
  ),
);

Widget _resourcesApp({required bool available}) => MaterialApp(
  home: Scaffold(
    body: ResourceLibraryPage(
      repository: _GuideRepository(guideAvailable: available),
      courseId: 'FIZIK_10',
      awaitingTextbook: false,
    ),
  ),
);

class _GuideRepository
    implements CourseKnowledgeRepository, TeacherGuideKnowledgeRepository {
  _GuideRepository({this.guideAvailable = true});

  final bool guideAvailable;

  static const course = model.Course(
    courseId: 'FIZIK_10',
    grade: 10,
    title: 'Fizik',
    schemaVersion: '1.3.0',
    sourceManifestFingerprint: 'physics-fingerprint',
  );

  static const theme = model.Theme(
    id: 'THEME_FORCE',
    order: 1,
    title: 'Kuvvet ve Hareket',
    pageRange: '1-42',
    plannedHours: 8,
    anlamaHours: 4,
    anlatmaHours: 4,
    sourceLocator: 'physics_textbook#1',
  );

  static const guide = TeacherGuide(
    guideId: 'GUIDE_PHYSICS',
    courseId: 'FIZIK_10',
    scopeType: 'theme',
    scopeId: 'THEME_FORCE',
    title: 'Kuvvet ve Hareket Öğretmen Rehberi',
    contentStatus: 'REVIEW_REQUIRED',
    schemaVersion: '1.0.0',
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 42'],
      contentClass: 'OFFICIAL_TEXTBOOK',
    ),
  );

  static const section = TeacherGuideSection(
    sectionId: 'SECTION_EXPERIMENT',
    guideId: 'GUIDE_PHYSICS',
    order: 1,
    title: 'Deneysel süreç',
    sectionType: 'EXPERIMENT',
    pageLocator: '42',
    sourceLocator: 'physics_textbook#42',
    contentStatus: 'REVIEW_REQUIRED',
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 42'],
      contentClass: 'OFFICIAL_TEXTBOOK',
    ),
  );

  static const unit = TeacherGuideUnit(
    unitId: 'UNIT_OBSERVATION',
    sectionId: 'SECTION_EXPERIMENT',
    order: 1,
    title: 'Gözlem ve model',
    pageLocator: '42',
    sourceLocator: 'physics_textbook#42',
    contentStatus: 'REVIEW_REQUIRED',
    purpose: ['Gözle', 'Kaydet', 'Yorumla'],
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 42'],
      contentClass: 'OFFICIAL_TEXTBOOK',
    ),
  );

  static const modelUnit = TeacherGuideUnit(
    unitId: 'UNIT_MODEL',
    sectionId: 'SECTION_EXPERIMENT',
    order: 2,
    title: 'Modelleme',
    pageLocator: '43',
    sourceLocator: 'physics_textbook#43',
    contentStatus: 'VERIFIED',
    purpose: ['Modelle', 'Karşılaştır'],
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 43'],
      contentClass: 'PEDAGOGICAL_ENRICHMENT',
    ),
  );

  static const observation = TeacherGuideItem(
    itemId: 'ITEM_OBSERVATION',
    unitId: 'UNIT_OBSERVATION',
    order: 1,
    title: 'Gözlem kaydı',
    label: 'Gözlem kaydı',
    itemType: 'OBSERVATION',
    pageLocator: '42',
    sourceLocator: 'physics_textbook#42',
    contentStatus: 'REVIEW_REQUIRED',
    expectedResponse: {
      'observations': ['hız değişimi'],
      'claim': null,
    },
    acceptanceCriteria: ['Veri kaydı bulunur.'],
    teacherGuidance: 'Değişkenleri sabit tut.',
    commonMisconceptions: {'force': 'speed'},
    assessmentEvidence: ['öğrenci kaydı'],
    differentiation: TeacherGuideDifferentiation(
      support: ['Hazır tablo ver.'],
      enrichment: {'prompt': 'Grafik çiz.'},
    ),
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 42'],
      contentClass: 'OFFICIAL_TEXTBOOK',
    ),
    canonicalPayloadSha256: 'observation-hash',
    relations: [
      TeacherGuideRelation(
        itemId: 'ITEM_OBSERVATION',
        targetType: 'activity',
        targetId: 'ACTIVITY_FORCE',
        relationType: 'supports',
        order: 1,
      ),
    ],
  );

  static const modelItem = TeacherGuideItem(
    itemId: 'ITEM_MODEL',
    unitId: 'UNIT_MODEL',
    order: 2,
    title: 'Modeli değiştir',
    label: 'Modeli değiştir',
    itemType: 'INVESTIGATION',
    pageLocator: '43',
    sourceLocator: 'physics_textbook#43',
    contentStatus: 'VERIFIED',
    expectedResponse: {'model': 'değişken'},
    acceptanceCriteria: ['Yeni model açıklanır.'],
    teacherGuidance: 'Grafik ile değişkeni karşılaştır.',
    commonMisconceptions: null,
    assessmentEvidence: ['model açıklaması'],
    differentiation: TeacherGuideDifferentiation(
      support: ['Örnek grafik ver.'],
      enrichment: ['İkinci değişken ekle.'],
    ),
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 43'],
      contentClass: 'PEDAGOGICAL_ENRICHMENT',
    ),
    canonicalPayloadSha256: 'model-hash',
  );

  static const teacherPackage = model.TeacherPackage(
    theme: theme,
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

  @override
  Future<model.Course> getCourse() async => course;

  @override
  Future<model.RuntimeManifest> getManifest() async =>
      model.RuntimeManifest.fromJson({
        'course_id': 'FIZIK_10',
        'schema_version': '1.3.0',
        'runtime_package_version': '1.4.0',
        'validation_status': 'PASS',
        'canonical_content_fingerprint': 'physics-fingerprint',
        'row_counts': const {},
        'capabilities': {'teacher_guide': guideAvailable},
        'timeline_resolution': 'THEME_AND_BLOCK_ORDER_RESOLVED',
      });

  @override
  Future<List<model.Theme>> getThemes() async => const [theme];

  @override
  Future<model.Theme> getTheme(String themeId) async => theme;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => const [];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async =>
      const model.BlockDetail(
        theme: theme,
        block: model.Block(
          id: 'BLOCK_FORCE',
          themeId: 'THEME_FORCE',
          order: 1,
          title: 'Kuvvet bloğu',
          skillDomain: 'physics',
          learningArea: null,
          plannedHours: 8,
          timeStatus: 'CONFIRMED',
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

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async => const [];

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(
    String themeId,
  ) async => const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async =>
      teacherPackage;

  @override
  Future<TeacherGuideCapability> getTeacherGuideCapability() async =>
      guideAvailable
      ? const TeacherGuideCapability(
          available: true,
          manifestAdvertised: true,
          tablesAvailable: true,
          canonicalEntityCount: 5,
          guideCount: 1,
          sectionCount: 1,
          unitCount: 2,
          itemCount: 2,
          relationCount: 0,
          schemaVersion: '1.0.0',
          validationStatus: 'PASS',
        )
      : const TeacherGuideCapability.unavailable(
          reason: 'TEACHER_GUIDE_NOT_ADVERTISED',
        );

  @override
  Future<TeacherGuide?> getTeacherGuideForScope({
    required String scopeType,
    required String scopeId,
  }) async =>
      guideAvailable && scopeType == guide.scopeType && scopeId == guide.scopeId
      ? guide
      : null;

  @override
  Future<List<TeacherGuideSection>> getTeacherGuideSections(
    String guideId,
  ) async => guideId == guide.guideId && guideAvailable ? const [section] : [];

  @override
  Future<TeacherGuideSection?> getTeacherGuideSection(String sectionId) async =>
      sectionId == section.sectionId && guideAvailable ? section : null;

  @override
  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async =>
      sectionId == section.sectionId && guideAvailable
      ? const [unit, modelUnit]
      : [];

  @override
  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId) async {
    if (!guideAvailable) return null;
    if (unitId == unit.unitId) return unit;
    if (unitId == modelUnit.unitId) return modelUnit;
    return null;
  }

  @override
  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async {
    if (!guideAvailable) return const [];
    if (unitId == unit.unitId) return const [observation];
    if (unitId == modelUnit.unitId) return const [modelItem];
    return const [];
  }

  @override
  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId) async =>
      guideAvailable ? _itemById(itemId) : null;

  @override
  Future<List<TeacherGuideItem>> getTeacherGuideItemsForEntity({
    required String targetType,
    required String targetId,
    String? relationType,
  }) async {
    if (targetType == 'activity' && targetId == 'ACTIVITY_FORCE') {
      return const [observation];
    }
    return const [];
  }

  TeacherGuideItem? _itemById(String itemId) {
    for (final item in const [observation, modelItem]) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }
}

class _MemoryNotes implements TeacherGuideNotesRepository {
  _MemoryNotes({this.failSaves = false});

  final bool failSaves;
  final Map<String, TeacherGuideNote> values = {};
  final List<TeacherGuideNote> saved = [];

  @override
  Future<TeacherGuideNote?> get({
    required String assignmentId,
    required String guideItemId,
  }) async => values['$assignmentId/$guideItemId'];

  @override
  Future<void> save(TeacherGuideNote note) async {
    if (failSaves) throw StateError('fixture write failed');
    saved.add(note);
    values['${note.assignmentId}/${note.guideItemId}'] = note;
  }
}
