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
import 'package:ogretmen_os/features/outcomes/outcome_detail_page.dart';
import 'package:ogretmen_os/features/shared/interaction_polish.dart';

void main() {
  testWidgets('boş alana dokunmak aktif metin odağını kapatır', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppFocusDismissRegion(
          child: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                const Expanded(child: Center(child: Text('Boş alan'))),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Boş alan'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('değişmemiş not kaydetme eylemi üretmez', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracking = MemoryOutcomeTrackingRepository();
    final service = OutcomePlanningService(
      repository: _P2Repository(),
      weeklyPlanning: const _P2WeeklyPlanning(),
      trackingRepository: tracking,
    );
    final plan = await service.buildPlan();
    final item = plan.weeks.single.outcomes.single;

    await tester.pumpWidget(
      MaterialApp(
        home: OutcomeDetailPage(
          repository: _P2Repository(),
          service: service,
          initialPlan: plan,
          initialItem: item,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).last;
    final more = find.text('Daha fazla bilgi');
    await tester.scrollUntilVisible(more, 200, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    final noteSection = find.text('Öğretmen notu');
    await tester.scrollUntilVisible(noteSection, 200, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(noteSection);
    await tester.pumpAndSettle();

    final saveFinder = find.widgetWithText(FilledButton, 'Notu kaydet');
    await tester.scrollUntilVisible(saveFinder, 160, scrollable: scrollable);
    await tester.pumpAndSettle();

    var save = tester.widget<FilledButton>(saveFinder);
    expect(save.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Yarın buradan devam.');
    await tester.pump();

    save = tester.widget<FilledButton>(saveFinder);
    expect(save.onPressed, isNotNull);

    await tester.tap(saveFinder);
    await tester.pumpAndSettle();

    expect(find.text('Not kaydedildi.'), findsOneWidget);
    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records.single.teacherNote, 'Yarın buradan devam.');

    save = tester.widget<FilledButton>(saveFinder);
    expect(save.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('başlangıç yükleme hatası yeniden denenebilir', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _P2Repository();
    final weeklyPlanning = const _P2WeeklyPlanning();
    final tracking = MemoryOutcomeTrackingRepository();
    final dependencies = AppDependencies(
      repository: repository,
      preferences: _P2Preferences(),
      weeklyPlanning: weeklyPlanning,
      outcomePlanning: OutcomePlanningService(
        repository: repository,
        weeklyPlanning: weeklyPlanning,
        trackingRepository: tracking,
      ),
    );
    var attempts = 0;

    await tester.pumpWidget(
      TeacherOsApp(
        courseLoader: (courseId) async {
          attempts += 1;
          if (attempts == 1) throw StateError('fixture failure');
          return dependencies;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ders verileri açılamadı.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Ders verileri açılamadı.'), findsNothing);
    expect(find.text('Bu Hafta'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _P2Preferences implements UserPreferencesRepository {
  String? value;

  @override
  Future<void> clearManualPositionOverride() async => value = null;

  @override
  Future<String?> getManualPositionOverride() async => value;

  @override
  Future<void> setManualPositionOverride(String blockId) async => value = blockId;
}

class _P2WeeklyPlanning implements WeeklyPlanningService {
  const _P2WeeklyPlanning();

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
            theme: _P2Repository.theme,
            hours: 5,
            block: _P2Repository.block,
          ),
        ],
        outcomes: const [_P2Repository.outcome],
      ),
    ],
  );
}

class _P2Repository implements CourseKnowledgeRepository {
  static const course = model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );

  static const theme = model.Theme(
    id: 'T1',
    order: 1,
    title: 'TEMA 1',
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

  static const outcome = model.Outcome(
    id: 'O1',
    themeId: 'T1',
    code: 'TEST.1',
    officialText: 'Test kazanımı',
    processComponents: null,
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
