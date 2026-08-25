import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/outcome_planning_service.dart';
import 'package:ogretmen_os/features/this_week/this_week_page.dart';

void main() {
  testWidgets('odak akışı tek ana eylem gösterir ve takip seçenekleri tekrar etmez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: const _WeeklyPlanning(),
      trackingRepository: MemoryOutcomeTrackingRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThisWeekPage(repository: repository, service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Başla'), findsOneWidget);
    expect(find.text('Ayrıntıyı aç'), findsNothing);

    await tester.tap(find.text('TEST.1'));
    await tester.pumpAndSettle();

    expect(find.text('Derste lazım'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Başla'), findsOneWidget);

    final more = find.text('Daha fazla bilgi');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();

    final tracking = find.text('Takip seçenekleri');
    await tester.ensureVisible(tracking);
    await tester.tap(tracking);
    await tester.pumpAndSettle();

    expect(find.text('Kısmen işlendi'), findsOneWidget);
    expect(find.text('Devam ediyor'), findsNothing);
    expect(find.text('İşlendi'), findsNothing);
    expect(find.text('Planlı'), findsOneWidget);
    expect(find.text('Başka haftaya taşı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _WeeklyPlanning implements WeeklyPlanningService {
  const _WeeklyPlanning();

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
            theme: _Repository.theme,
            hours: 5,
            block: _Repository.block,
          ),
        ],
        outcomes: const [_Repository.outcome],
      ),
    ],
  );
}

class _Repository implements CourseKnowledgeRepository {
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
