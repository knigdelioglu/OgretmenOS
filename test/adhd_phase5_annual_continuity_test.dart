import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/preferences/continuity_repository.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/annual_plan/annual_plan_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'yeni ders odağı eski manuel yıllık işareti otomatik geçersiz kılar',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final raw = await SharedPreferences.getInstance();
      final preferences = SharedPreferencesUserPreferences(raw);
      await preferences.setManualPositionOverrideForCourse('TDE_9', 'B1');
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: 'TDE_9|O2',
          outcomeCode: 'TEST.2',
          themeTitle: 'Test Tema',
          blockId: 'B2',
          blockTitle: 'İkinci Blok',
          updatedAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnualPlanPage(
              repository: const _Repository(),
              preferences: preferences,
              continuity: continuity,
              courseId: 'TDE_9',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Test Tema · İkinci Blok'), findsOneWidget);
      expect(find.text('Son görüntülenen ders odağı'), findsOneWidget);
      expect(find.textContaining('Elle işaretlendi'), findsNothing);
      expect(
        await preferences.getManualPositionOverrideForCourse('TDE_9'),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('daha yeni manuel işaret geçici istisna olarak korunur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final raw = await SharedPreferences.getInstance();
    final preferences = SharedPreferencesUserPreferences(raw);
    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 1,
        trackingKey: 'TDE_9|O2',
        outcomeCode: 'TEST.2',
        themeTitle: 'Test Tema',
        blockId: 'B2',
        blockTitle: 'İkinci Blok',
        updatedAt: _oldFocusTime,
      ),
    );
    await preferences.setManualPositionOverrideForCourse('TDE_9', 'B1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnualPlanPage(
            repository: const _Repository(),
            preferences: preferences,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Test Tema · Birinci Blok'), findsOneWidget);
    expect(find.textContaining('Elle işaretlendi'), findsOneWidget);
    expect(
      (await preferences.getManualPositionOverrideForCourse('TDE_9'))?.blockId,
      'B1',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('convenience preference failures do not block the annual plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnnualPlanPage(
            repository: _Repository(),
            preferences: _FailingPreferences(),
            continuity: _FailingAnnualContinuity(),
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 tema · 45 saat · 2 blok'), findsOneWidget);
    expect(find.text('Test Tema'), findsOneWidget);
    expect(find.text('ŞU AN BURADASIN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mounted AnnualPlanPage continuity değiştiğinde ŞU AN BURADASIN konumunu günceller',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final raw = await SharedPreferences.getInstance();
      final preferences = SharedPreferencesUserPreferences(raw);
      final continuity = MemoryContinuityRepository();

      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: 'TDE_9|O1',
          outcomeCode: 'TEST.1',
          themeTitle: 'Test Tema',
          blockId: 'B1',
          blockTitle: 'Birinci Blok',
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnualPlanPage(
              repository: const _Repository(),
              preferences: preferences,
              continuity: continuity,
              courseId: 'TDE_9',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Test Tema · Birinci Blok'), findsOneWidget);

      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 2,
          trackingKey: 'TDE_9|O2',
          outcomeCode: 'TEST.2',
          themeTitle: 'Test Tema',
          blockId: 'B2',
          blockTitle: 'İkinci Blok',
          updatedAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Test Tema · İkinci Blok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'yıllık plan continuity refresh latest focus tamamlanma sırasını korur',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final raw = await SharedPreferences.getInstance();
      final preferences = SharedPreferencesUserPreferences(raw);
      final continuity = _ControlledAnnualContinuity();
      final repository = _AnnualRaceRepository();
      final focusB1 = _annualFocus('B1');
      final focusB2 = _annualFocus('B2');
      final focusB3 = _annualFocus('B3');
      await continuity.setLastFocus(focusB1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnualPlanPage(
              repository: repository,
              preferences: preferences,
              continuity: continuity,
              courseId: 'TDE_9',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Test Tema · Birinci Blok'), findsOneWidget);

      final refreshA = continuity.holdNextRead();
      await continuity.setLastFocus(focusB2);
      await tester.pump();
      final refreshB = continuity.holdNextRead();
      await continuity.setLastFocus(focusB3);
      await tester.pump();

      refreshB.complete(focusB3);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Test Tema · Üçüncü Blok'), findsOneWidget);

      refreshA.complete(focusB2);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Test Tema · Üçüncü Blok'), findsOneWidget);
      expect(find.textContaining('Test Tema · İkinci Blok'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

LastFocusState _annualFocus(String blockId) => LastFocusState(
  courseId: 'TDE_9',
  academicYear: '2026-2027',
  weekNumber: int.parse(blockId.substring(1)),
  trackingKey: 'TDE_9|$blockId',
  outcomeCode: 'TEST.$blockId',
  themeTitle: 'Test Tema',
  blockId: blockId,
  blockTitle:
      '${switch (blockId) {
        'B1' => 'Birinci',
        'B2' => 'İkinci',
        _ => 'Üçüncü',
      }} Blok',
  updatedAt: DateTime.now(),
);

final _oldFocusTime = DateTime.utc(2020, 1, 1);

class _Repository implements CourseKnowledgeRepository {
  const _Repository();

  static const theme = model.Theme(
    id: 'T1',
    order: 1,
    title: 'Test Tema',
    pageRange: null,
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );

  static const block1 = model.Block(
    id: 'B1',
    themeId: 'T1',
    order: 1,
    title: 'Birinci Blok',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const block2 = model.Block(
    id: 'B2',
    themeId: 'T1',
    order: 2,
    title: 'İkinci Blok',
    skillDomain: 'Yazma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
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
  Future<List<model.Block>> getBlocks(String themeId) async => const [
    block1,
    block2,
  ];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async => model.BlockDetail(
    theme: theme,
    block: blockId == 'B1' ? block1 : block2,
    outcomes: const [],
    textbookSections: const [],
    activities: const [],
    forms: const [],
    assessmentArtifacts: const [],
    assessmentGaps: const [],
    assessmentTaskBindings: const [],
    resourceDecisions: const [],
    sourceReferences: const [],
    previousBlock: null,
    nextBlock: null,
  );

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async => const [
    model.TimelineEntry(
      sequencePosition: 1,
      theme: theme,
      block: block1,
      officialTotalHours: 45,
      coreInstructionHours: 43,
      schoolBasedHours: 2,
      schoolBasedHoursStatus: 'CONFIRMED',
    ),
    model.TimelineEntry(
      sequencePosition: 2,
      theme: theme,
      block: block2,
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
        blocks: [block1, block2],
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
}

class _AnnualRaceRepository extends _Repository {
  static const block3 = model.Block(
    id: 'B3',
    themeId: 'T1',
    order: 3,
    title: 'Üçüncü Blok',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async => const [
    model.TimelineEntry(
      sequencePosition: 1,
      theme: _Repository.theme,
      block: _Repository.block1,
      officialTotalHours: 45,
      coreInstructionHours: 43,
      schoolBasedHours: 2,
      schoolBasedHoursStatus: 'CONFIRMED',
    ),
    model.TimelineEntry(
      sequencePosition: 2,
      theme: _Repository.theme,
      block: _Repository.block2,
      officialTotalHours: 45,
      coreInstructionHours: 43,
      schoolBasedHours: 2,
      schoolBasedHoursStatus: 'CONFIRMED',
    ),
    model.TimelineEntry(
      sequencePosition: 3,
      theme: _Repository.theme,
      block: block3,
      officialTotalHours: 45,
      coreInstructionHours: 43,
      schoolBasedHours: 2,
      schoolBasedHoursStatus: 'CONFIRMED',
    ),
  ];
}

class _FailingPreferences implements UserPreferencesRepository {
  const _FailingPreferences();

  @override
  Future<String?> getManualPositionOverride() =>
      Future<String?>.error(StateError('preferences unavailable'));

  @override
  Future<void> setManualPositionOverride(String blockId) =>
      Future<void>.error(StateError('preferences unavailable'));

  @override
  Future<void> clearManualPositionOverride() =>
      Future<void>.error(StateError('preferences unavailable'));
}

class _FailingAnnualContinuity implements ContinuityRepository {
  const _FailingAnnualContinuity();

  @override
  Future<LastFocusState?> getLastFocus(String courseId) =>
      Future<LastFocusState?>.error(StateError('continuity unavailable'));

  @override
  Future<void> setLastFocus(LastFocusState state) =>
      Future<void>.error(StateError('continuity unavailable'));

  @override
  Future<void> clearLastFocus(String courseId) =>
      Future<void>.error(StateError('continuity unavailable'));

  @override
  void addChangeListener(ContinuityChangeListener listener) {}

  @override
  void removeChangeListener(ContinuityChangeListener listener) {}
}

class _ControlledAnnualContinuity implements ContinuityRepository {
  final Map<String, LastFocusState> _states = {};
  final List<ContinuityChangeListener> _listeners = [];
  final List<Completer<LastFocusState?>> _heldReads = [];

  Completer<LastFocusState?> holdNextRead() {
    final completer = Completer<LastFocusState?>();
    _heldReads.add(completer);
    return completer;
  }

  @override
  Future<LastFocusState?> getLastFocus(String courseId) {
    if (_heldReads.isNotEmpty) return _heldReads.removeAt(0).future;
    return Future.value(_states[courseId]);
  }

  @override
  Future<void> setLastFocus(LastFocusState state) async {
    _states[state.courseId] = state;
    for (final listener in List<ContinuityChangeListener>.of(_listeners)) {
      listener(state.courseId);
    }
  }

  @override
  Future<void> clearLastFocus(String courseId) async {
    _states.remove(courseId);
    for (final listener in List<ContinuityChangeListener>.of(_listeners)) {
      listener(courseId);
    }
  }

  @override
  void addChangeListener(ContinuityChangeListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeChangeListener(ContinuityChangeListener listener) {
    _listeners.remove(listener);
  }
}
