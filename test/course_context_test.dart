import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';

void main() {
  testWidgets('sınıf değiştirirken öğretmenin bulunduğu ana iş korunur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final loadedCourses = <String>[];
    await tester.pumpWidget(
      TeacherOsApp(
        courseLoader: (courseId) async {
          loadedCourses.add(courseId);
          return _dependencies(courseId);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sınıf seç'), findsOneWidget);
    expect(find.text('9. Sınıf'), findsOneWidget);

    await _tapBottomDestination(tester, Icons.library_books_outlined);
    await tester.pumpAndSettle();

    var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 2);
    expect(find.text('Kaynaklar'), findsWidgets);

    await tester.tap(find.byTooltip('Sınıf seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10. Sınıf'));
    await tester.pumpAndSettle();

    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 2);
    expect(find.text('Kaynaklar'), findsWidgets);
    expect(find.text('10. Sınıf'), findsOneWidget);
    expect(find.text('Bu Hafta'), findsOneWidget);
    expect(loadedCourses, ['TDE_9', 'TDE_10']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('görünür sınıf seçici büyük yazıda app barı taşırmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      TeacherOsApp(courseLoader: (courseId) async => _dependencies(courseId)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sınıf seç'), findsOneWidget);
    expect(find.text('9. Sınıf'), findsOneWidget);
    expect(find.text('Türk Dili ve Edebiyatı'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapBottomDestination(WidgetTester tester, IconData icon) async {
  final bar = find.byType(NavigationBar);
  expect(bar, findsOneWidget);
  final target = find.descendant(of: bar, matching: find.byIcon(icon));
  expect(target, findsOneWidget);
  await tester.tap(target);
}

AppDependencies _dependencies(String courseId) {
  final repository = _CourseContextRepository(courseId);
  return AppDependencies(
    repository: repository,
    preferences: _CourseContextPreferences(),
    weeklyPlanning: _CourseContextWeeklyPlanning(courseId),
  );
}

class _CourseContextPreferences implements UserPreferencesRepository {
  String? _value;

  @override
  Future<void> clearManualPositionOverride() async => _value = null;

  @override
  Future<String?> getManualPositionOverride() async => _value;

  @override
  Future<void> setManualPositionOverride(String blockId) async =>
      _value = blockId;
}

class _CourseContextRepository implements CourseKnowledgeRepository {
  _CourseContextRepository(this.courseId);

  final String courseId;

  static const theme = model.Theme(
    id: 'COURSE_CONTEXT_THEME',
    order: 1,
    title: 'Test Tema',
    pageRange: null,
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );

  static const block = model.Block(
    id: 'COURSE_CONTEXT_BLOCK',
    themeId: 'COURSE_CONTEXT_THEME',
    order: 1,
    title: 'Test Blok',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const outcome = model.Outcome(
    id: 'COURSE_CONTEXT_OUTCOME',
    themeId: 'COURSE_CONTEXT_THEME',
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

  int get grade => switch (courseId) {
    'TDE_10' => 10,
    'TDE_11' => 11,
    'TDE_12' => 12,
    _ => 9,
  };

  @override
  Future<model.Course> getCourse() async => model.Course(
    courseId: courseId,
    grade: grade,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );

  @override
  Future<model.RuntimeManifest> getManifest() async => model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: courseId,
    validationStatus: 'PASS',
    canonicalContentFingerprint: 'test',
    rowCounts: const {},
    timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
    timelineUnresolvedFields: const {},
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
  Future<List<model.ResourceDecision>> getResourceDecisions(
    String themeId,
  ) async => const [];

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

class _CourseContextWeeklyPlanning implements WeeklyPlanningService {
  const _CourseContextWeeklyPlanning(this.courseId);

  final String courseId;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async =>
      AnnualWeeklyPlan(
        academicYear: '2026-2027',
        courseId: courseId,
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
                theme: _CourseContextRepository.theme,
                block: _CourseContextRepository.block,
                hours: 5,
              ),
            ],
            outcomes: const [_CourseContextRepository.outcome],
          ),
        ],
      );
}
