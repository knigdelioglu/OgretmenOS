import 'package:flutter/material.dart' hide Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/lesson_plan/lesson_plan_page.dart';
import 'package:ogretmen_os/features/lesson_plan/lesson_plan_panels.dart';

void main() {
  const theme = Theme(
    id: 'TEMA_01',
    order: 1,
    title: 'Sözün İnceliği',
    pageRange: null,
    plannedHours: 43,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );
  const block = Block(
    id: 'BLOCK_A',
    themeId: 'TEMA_01',
    order: 1,
    title: 'Okuma',
    skillDomain: 'okuma',
    learningArea: null,
    plannedHours: 8,
    timeStatus: 'RESOLVED',
    sourceLocators: [],
  );

  testWidgets('haftalık panel doğru saat aralığındaki paketleri gösterir', (
    tester,
  ) async {
    final packages = [
      _package('BLOCK_A_P01', 1, title: 'Başlangıç'),
      _package('BLOCK_A_P02', 2, title: 'Yakın okuma'),
      _package('BLOCK_A_P03', 3, title: 'Metin çözümleme'),
      _package('BLOCK_A_P04', 4, title: 'Değerlendirme'),
    ];
    final repository = _FakeRepository(packages);
    final plan = _annualPlan(theme: theme, block: block);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyLessonPlanPanel(
              repository: repository,
              annualPlan: plan,
              weekNumber: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu haftanın ders planı'), findsOneWidget);
    expect(find.text('P03'), findsOneWidget);
    expect(find.text('P04'), findsOneWidget);
    expect(find.text('P02'), findsNothing);
    expect(find.textContaining('blokta 5–8. saatler'), findsNWidgets(2));

    await tester.tap(find.text('P03'));
    await tester.pumpAndSettle();

    expect(find.text('Ders Planı'), findsOneWidget);
    expect(find.text('Metin çözümleme'), findsWidgets);
    expect(find.text('Ana düşünceyi kanıtlarla belirler.'), findsOneWidget);
  });

  testWidgets('ders planı ekranı önceki ve sonraki pakete ilerler', (
    tester,
  ) async {
    final packages = [
      _package('BLOCK_A_P01', 1, title: 'Başlangıç'),
      _package('BLOCK_A_P02', 2, title: 'Yakın okuma'),
    ];
    final repository = _FakeRepository(packages);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlanPage(
          repository: repository,
          initialPackageId: 'BLOCK_A_P01',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başlangıç'), findsWidgets);
    expect(find.text('Önceki yok'), findsOneWidget);
    expect(find.text('P02'), findsOneWidget);

    await tester.tap(find.text('P02'));
    await tester.pumpAndSettle();

    expect(find.text('Yakın okuma'), findsWidgets);
    expect(find.text('P01'), findsOneWidget);
    expect(find.text('Son paket'), findsOneWidget);
  });
}

AnnualOutcomePlan _annualPlan({required Theme theme, required Block block}) {
  final weeks = [
    _week(1, theme: theme, block: block, hours: 4),
    _week(2, theme: theme, block: block, hours: 4),
  ];
  return AnnualOutcomePlan(
    weeklyPlan: AnnualWeeklyPlan(
      academicYear: '2026-2027',
      courseId: 'TDE_9',
      weeklyLessonHours: 4,
      annualHours: 8,
      weeks: weeks,
      currentWeekNumber: 2,
    ),
    weeks: weeks
        .map((week) => WeeklyOutcomeSummary(week: week, outcomes: const []))
        .toList(growable: false),
  );
}

AcademicWeekPlan _week(
  int number, {
  required Theme theme,
  required Block block,
  required int hours,
}) => AcademicWeekPlan(
  weekNumber: number,
  start: DateTime(2026, 9, 7).add(Duration(days: (number - 1) * 7)),
  end: DateTime(2026, 9, 11).add(Duration(days: (number - 1) * 7)),
  type: AcademicWeekType.instruction,
  label: '$number. Hafta',
  plannedLessonHours: hours,
  segments: [
    WeeklyPlanSegment(
      type: WeeklyPlanSegmentType.block,
      theme: theme,
      hours: hours,
      block: block,
    ),
  ],
  outcomes: const [],
);

LessonPlanPackage _package(
  String packageId,
  int packageNo, {
  required String title,
}) => LessonPlanPackage(
  packageId: packageId,
  courseId: 'TDE_9',
  themeId: 'TEMA_01',
  blockId: 'BLOCK_A',
  packageNo: packageNo,
  lessonHours: 2,
  title: title,
  summary: 'Sınıf içi uygulama özeti',
  remainingBlockHours: (4 - packageNo) * 2,
  schemaVersion: '1.0.0',
  validationStatus: 'PASS',
  sourcePath: 'generated/$packageId.json',
  payloadSha256: 'sha256-$packageId',
  outcomeCodes: const ['TDE9.1.1'],
  usedActivityIds: const [],
  usedFormIds: const [],
  lessons: const [
    LessonPlanLesson(
      lessonNo: 1,
      durationLessonHours: 2,
      title: 'Metin üzerinde çalışma',
      objective: 'Ana düşünceyi kanıtlarla belirler.',
      outcomeCodes: ['TDE9.1.1'],
      opening: 'Ön bilgiyi yoklar.',
      teacherActions: ['Soruyu yöneltir.'],
      studentActions: ['Metinden kanıt sunar.'],
      activityIds: [],
      formIds: [],
      assessment: 'Çıkış sorusunu değerlendirir.',
      closure: 'Dersi özetler.',
      materials: ['Ders kitabı'],
      raw: {},
    ),
  ],
  teacherNotes: null,
  continuation: const LessonPlanContinuation(
    plannedNowHours: 2,
    remainingBlockHours: 0,
    coveredOutcomeCodes: ['TDE9.1.1'],
    usedActivityIds: [],
    nextStepHint: 'Bir sonraki pakette metin kanıtları derinleştirilir.',
    raw: {},
  ),
  rawPayload: const {},
);

class _FakeRepository
    implements CourseKnowledgeRepository, LessonPlanKnowledgeRepository {
  _FakeRepository(this.packages);

  final List<LessonPlanPackage> packages;

  @override
  Future<LessonPlanCapability> getLessonPlanCapability() async =>
      const LessonPlanCapability(
        available: true,
        manifestAdvertised: true,
        tableAvailable: true,
        packageCount: 88,
        instructionHours: 172,
        schemaVersion: '1.0.0',
        validationStatus: 'PASS',
      );

  @override
  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId) async =>
      packages.where((plan) => plan.blockId == blockId).toList(growable: false);

  @override
  Future<LessonPlanPackage?> getLessonPlan(String packageId) async {
    for (final plan in packages) {
      if (plan.packageId == packageId) return plan;
    }
    return null;
  }

  @override
  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) async {
    final index = packages.indexWhere((plan) => plan.packageId == packageId);
    return index <= 0 ? null : packages[index - 1];
  }

  @override
  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) async {
    final index = packages.indexWhere((plan) => plan.packageId == packageId);
    return index < 0 || index >= packages.length - 1 ? null : packages[index + 1];
  }

  @override
  Future<Course> getCourse() async => throw UnimplementedError();

  @override
  Future<RuntimeManifest> getManifest() async => throw UnimplementedError();

  @override
  Future<List<Theme>> getThemes() async => throw UnimplementedError();

  @override
  Future<Theme> getTheme(String themeId) async => throw UnimplementedError();

  @override
  Future<List<Block>> getBlocks(String themeId) async => throw UnimplementedError();

  @override
  Future<BlockDetail> getBlock(String blockId) async => throw UnimplementedError();

  @override
  Future<List<TimelineEntry>> getAnnualSequence() async => throw UnimplementedError();

  @override
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) async =>
      throw UnimplementedError();

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) async =>
      throw UnimplementedError();
}
