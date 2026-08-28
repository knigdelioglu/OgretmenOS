import 'package:flutter/material.dart' hide Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_progress_models.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/lesson_plan_progress_repository.dart';
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
    plannedHours: 10,
    timeStatus: 'RESOLVED',
    sourceLocators: [],
  );

  testWidgets('5 saatlik haftalık panel dersleri tek tek ve tekrarsız gösterir', (
    tester,
  ) async {
    final packages = [
      _package('BLOCK_A_P01', 1, title: 'Başlangıç'),
      _package('BLOCK_A_P02', 2, title: 'Yakın okuma'),
      _package('BLOCK_A_P03', 3, title: 'Metin çözümleme'),
      _package('BLOCK_A_P04', 4, title: 'Değerlendirme'),
      _package('BLOCK_A_P05', 5, title: 'Pekiştirme'),
    ];
    final repository = _FakeRepository(packages);
    final plan = _fiveHourAnnualPlan(theme: theme, block: block);

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
    expect(find.text('5 ders saati'), findsOneWidget);
    expect(find.text('5. ders saati'), findsNothing);
    for (final hour in [6, 7, 8, 9, 10]) {
      expect(find.text('$hour. ders saati'), findsOneWidget);
    }
    expect(find.textContaining('ders saatleri'), findsNothing);
    expect(find.text('Metin çözümleme · 2. ders'), findsOneWidget);
    expect(find.text('Değerlendirme · 1. ders'), findsOneWidget);
    expect(find.text('Değerlendirme · 2. ders'), findsOneWidget);
    expect(find.text('Pekiştirme · 1. ders'), findsOneWidget);
    expect(find.text('Pekiştirme · 2. ders'), findsOneWidget);
    expect(find.text('P03'), findsNothing);
    expect(find.text('P04'), findsNothing);

    await tester.tap(find.text('6. ders saati'));
    await tester.pumpAndSettle();

    expect(find.text('Ders Planı'), findsOneWidget);
    expect(find.text('6. DERS SAATİ'), findsOneWidget);
    expect(find.textContaining('DERS SAATLERİ'), findsNothing);
    expect(find.textContaining('2 DERS SAATİ'), findsNothing);
    expect(find.text('Metin çözümleme · 2. ders'), findsOneWidget);
    expect(find.text('Metin kanıtlarını karşılaştırır.'), findsNothing);

    await tester.tap(find.text('Metin çözümleme · 2. ders'));
    await tester.pumpAndSettle();

    expect(find.text('Metin kanıtlarını karşılaştırır.'), findsOneWidget);
  });

  testWidgets('tekil ders durumu komşu saati otomatik tamamlamaz', (
    tester,
  ) async {
    final packages = [
      _package('BLOCK_A_P01', 1, title: 'Başlangıç'),
      _package('BLOCK_A_P02', 2, title: 'Yakın okuma'),
      _package('BLOCK_A_P03', 3, title: 'Metin çözümleme'),
      _package('BLOCK_A_P04', 4, title: 'Değerlendirme'),
      _package('BLOCK_A_P05', 5, title: 'Pekiştirme'),
    ];
    final progress = MemoryLessonPlanProgressRepository();
    final repository = _FakeRepository(packages);
    final plan = _fiveHourAnnualPlan(theme: theme, block: block);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyLessonPlanPanel(
              repository: repository,
              annualPlan: plan,
              weekNumber: 2,
              progressRepository: progress,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('6. ders saati'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'İşlendi'));
    await tester.pumpAndSettle();

    expect(
      (await progress.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: 'BLOCK_A_P03::lesson-hour:2',
      ))?.status,
      LessonPlanProgressStatus.completed,
    );
    expect(
      await progress.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: 'BLOCK_A_P03::lesson-hour:1',
      ),
      isNull,
    );
  });

  testWidgets('ders planı ekranı önceki ve sonraki plana ilerler', (
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
    expect(find.textContaining('1–2. DERS SAATLERİ'), findsWidgets);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Önceki yok'), findsOneWidget);
    expect(find.text('Sonraki plan'), findsOneWidget);

    await tester.tap(find.text('Sonraki plan'));
    await tester.pumpAndSettle();

    expect(find.text('Önceki plan'), findsOneWidget);
    expect(find.text('Son plan'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Yakın okuma'), findsWidgets);
    expect(find.textContaining('3–4. DERS SAATLERİ'), findsWidgets);
  });

  testWidgets('haftalık panel stale tekil ders kaydını tamamlanmış saymaz', (
    tester,
  ) async {
    final packages = [
      _package('BLOCK_A_P01', 1, title: 'Başlangıç'),
      _package('BLOCK_A_P02', 2, title: 'Yakın okuma'),
      _package('BLOCK_A_P03', 3, title: 'Metin çözümleme'),
      _package('BLOCK_A_P04', 4, title: 'Değerlendirme'),
    ];
    final progress = MemoryLessonPlanProgressRepository();
    final timestamp = DateTime(2026, 9, 14, 10);
    await progress.save(
      LessonPlanProgressRecord(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: '${packages[2].packageId}::lesson-hour:2',
        payloadSha256: 'sha256-old-p03',
        status: LessonPlanProgressStatus.completed,
        startedAt: timestamp,
        completedAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await progress.save(
      LessonPlanProgressRecord(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: '${packages[3].packageId}::lesson-hour:1',
        payloadSha256: packages[3].payloadSha256,
        status: LessonPlanProgressStatus.completed,
        startedAt: timestamp,
        completedAt: timestamp,
        updatedAt: timestamp,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyLessonPlanPanel(
              repository: _FakeRepository(packages),
              annualPlan: _annualPlan(theme: theme, block: block),
              weekNumber: 2,
              progressRepository: progress,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('1 ders güncellendi; durumu yeniden işaretlenmeli.'),
      findsOneWidget,
    );
    expect(find.text('Plan güncellendi · yeniden işaretle'), findsOneWidget);
    expect(find.text('Bu haftanın dersleri işlendi.'), findsNothing);
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

AnnualOutcomePlan _fiveHourAnnualPlan({
  required Theme theme,
  required Block block,
}) {
  final weeks = [
    _week(1, theme: theme, block: block, hours: 5),
    _week(2, theme: theme, block: block, hours: 5),
  ];
  return AnnualOutcomePlan(
    weeklyPlan: AnnualWeeklyPlan(
      academicYear: '2026-2027',
      courseId: 'TDE_9',
      weeklyLessonHours: 5,
      annualHours: 10,
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
  remainingBlockHours: (5 - packageNo) * 2,
  schemaVersion: '1.0.0',
  validationStatus: 'PASS',
  sourcePath: 'generated/$packageId.json',
  payloadSha256: 'sha256-$packageId',
  outcomeCodes: const ['TDE9.1.1'],
  usedActivityIds: const [],
  usedFormIds: const [],
  lessons: [
    LessonPlanLesson(
      lessonNo: 1,
      durationLessonHours: 1,
      title: '$title · 1. ders',
      objective: 'Ana düşünceyi kanıtlarla belirler.',
      outcomeCodes: const ['TDE9.1.1'],
      opening: 'Ön bilgiyi yoklar.',
      teacherActions: const ['Soruyu yöneltir.'],
      studentActions: const ['Metinden kanıt sunar.'],
      activityIds: const [],
      formIds: const [],
      assessment: 'Çıkış sorusunu değerlendirir.',
      closure: 'Dersi özetler.',
      materials: const ['Ders kitabı'],
      raw: const {},
    ),
    LessonPlanLesson(
      lessonNo: 2,
      durationLessonHours: 1,
      title: '$title · 2. ders',
      objective: 'Metin kanıtlarını karşılaştırır.',
      outcomeCodes: const ['TDE9.1.1'],
      opening: 'Önceki dersi hatırlatır.',
      teacherActions: const ['Karşılaştırma sorusunu yöneltir.'],
      studentActions: const ['Kanıtları karşılaştırır.'],
      activityIds: const [],
      formIds: const [],
      assessment: 'Karşılaştırmayı değerlendirir.',
      closure: 'Sonucu özetler.',
      materials: const ['Ders kitabı'],
      raw: const {},
    ),
  ],
  teacherNotes: null,
  continuation: const LessonPlanContinuation(
    plannedNowHours: 2,
    remainingBlockHours: 0,
    coveredOutcomeCodes: ['TDE9.1.1'],
    usedActivityIds: [],
    nextStepHint: 'Bir sonraki plan bölümünde metin kanıtları derinleştirilir.',
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
