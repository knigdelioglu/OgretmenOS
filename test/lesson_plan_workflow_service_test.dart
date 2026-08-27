import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/services/lesson_plan_workflow_service.dart';

void main() {
  const theme = Theme(
    id: 'TEMA_01',
    order: 1,
    title: 'Tema 1',
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

  test('haftalık seçim paket yerine tek ders saatleri döndürür', () async {
    final repository = _FakeRepository({
      block.id: [
        _package('BLOCK_A_P01', block.id, 1, 2),
        _package('BLOCK_A_P02', block.id, 2, 2),
        _package('BLOCK_A_P03', block.id, 3, 2),
        _package('BLOCK_A_P04', block.id, 4, 2),
      ],
    });
    final service = LessonPlanWorkflowService(repository: repository);
    final annualPlan = _annualPlan([
      _week(1, const [
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: theme,
          hours: 4,
          block: block,
        ),
      ]),
      _week(2, const [
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: theme,
          hours: 4,
          block: block,
        ),
      ]),
    ]);

    final selections = await service.plansForWeek(annualPlan, 2);

    expect(selections, hasLength(4));
    expect(
      selections.map((item) => item.package.packageId),
      orderedEquals([
        'BLOCK_A_P03',
        'BLOCK_A_P03',
        'BLOCK_A_P04',
        'BLOCK_A_P04',
      ]),
    );
    expect(
      selections.map((item) => item.blockHour),
      orderedEquals([5, 6, 7, 8]),
    );
    expect(
      selections.map((item) => item.packageHour),
      orderedEquals([1, 2, 1, 2]),
    );
    expect(
      selections.map((item) => item.lesson?.lessonNo),
      orderedEquals([1, 2, 1, 2]),
    );
    expect(selections.first.segmentStartHour, 5);
    expect(selections.first.segmentEndHour, 8);
    expect(selections.first.packageStartHour, 5);
    expect(selections.first.packageEndHour, 6);
  });

  test('5 saatlik hafta tam 5 ders gösterir ve sınırdaki paket dersi tekrarlanmaz', () async {
    final repository = _FakeRepository({
      block.id: [
        _package('BLOCK_A_P01', block.id, 1, 2),
        _package('BLOCK_A_P02', block.id, 2, 2),
        _package('BLOCK_A_P03', block.id, 3, 2),
        _package('BLOCK_A_P04', block.id, 4, 2),
      ],
    });
    final service = LessonPlanWorkflowService(repository: repository);
    final annualPlan = _annualPlan([
      _week(1, const [
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: theme,
          hours: 5,
          block: block,
        ),
      ]),
      _week(2, const [
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: theme,
          hours: 3,
          block: block,
        ),
      ]),
    ]);

    final week1 = await service.plansForWeek(annualPlan, 1);
    final week2 = await service.plansForWeek(annualPlan, 2);

    expect(week1, hasLength(5));
    expect(
      week1.map((item) => item.package.packageId),
      orderedEquals([
        'BLOCK_A_P01',
        'BLOCK_A_P01',
        'BLOCK_A_P02',
        'BLOCK_A_P02',
        'BLOCK_A_P03',
      ]),
    );
    expect(
      week1.map((item) => item.blockHour),
      orderedEquals([1, 2, 3, 4, 5]),
    );
    expect(week1.last.packageHour, 1);
    expect(week1.last.lesson?.lessonNo, 1);

    expect(week2, hasLength(3));
    expect(
      week2.map((item) => item.package.packageId),
      orderedEquals(['BLOCK_A_P03', 'BLOCK_A_P04', 'BLOCK_A_P04']),
    );
    expect(
      week2.map((item) => item.blockHour),
      orderedEquals([6, 7, 8]),
    );
    expect(week2.first.packageHour, 2);
    expect(week2.first.lesson?.lessonNo, 2);
    expect(week2.any((item) => item.blockHour == 5), isFalse);
  });

  test('aynı blok haftada iki segmente bölünürse saatler yinelenmez', () async {
    final repository = _FakeRepository({
      block.id: [
        _package('BLOCK_A_P01', block.id, 1, 2),
        _package('BLOCK_A_P02', block.id, 2, 2),
        _package('BLOCK_A_P03', block.id, 3, 2),
      ],
    });
    final service = LessonPlanWorkflowService(repository: repository);
    final annualPlan = _annualPlan([
      _week(1, const [
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: theme,
          hours: 2,
          block: block,
        ),
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: theme,
          hours: 3,
          block: block,
        ),
      ]),
    ]);

    final selections = await service.plansForWeek(annualPlan, 1);

    expect(selections, hasLength(5));
    expect(
      selections.map((item) => item.blockHour),
      orderedEquals([1, 2, 3, 4, 5]),
    );
  });

  test('validation dışı veya eksik paket saat kapsamı fail closed olur', () async {
    final repository = _FakeRepository({
      block.id: [
        _package('BLOCK_A_P01', block.id, 1, 2),
        _package('BLOCK_A_P02', block.id, 2, 2),
      ],
    });
    final service = LessonPlanWorkflowService(repository: repository);
    final annualPlan = _annualPlan([
      _week(1, const [
        WeeklyPlanSegment(
          type: WeeklyPlanSegmentType.block,
          theme: theme,
          hours: 5,
          block: block,
        ),
      ]),
    ]);

    expect(await service.plansForWeek(annualPlan, 1), isEmpty);
  });
}

AcademicWeekPlan _week(int number, List<WeeklyPlanSegment> segments) =>
    AcademicWeekPlan(
      weekNumber: number,
      start: DateTime(2026, 9, 7).add(Duration(days: (number - 1) * 7)),
      end: DateTime(2026, 9, 11).add(Duration(days: (number - 1) * 7)),
      type: AcademicWeekType.instruction,
      label: '$number. Hafta',
      plannedLessonHours: segments.fold(0, (sum, item) => sum + item.hours),
      segments: segments,
      outcomes: const [],
    );

AnnualOutcomePlan _annualPlan(List<AcademicWeekPlan> weeks) {
  final weeklyPlan = AnnualWeeklyPlan(
    academicYear: '2026-2027',
    courseId: 'TDE_9',
    weeklyLessonHours: 5,
    annualHours: weeks.fold(0, (sum, item) => sum + item.plannedLessonHours),
    weeks: weeks,
    currentWeekNumber: weeks.first.weekNumber,
  );
  return AnnualOutcomePlan(
    weeklyPlan: weeklyPlan,
    weeks: weeks
        .map((week) => WeeklyOutcomeSummary(week: week, outcomes: const []))
        .toList(growable: false),
  );
}

LessonPlanPackage _package(
  String packageId,
  String blockId,
  int packageNo,
  int hours,
) => LessonPlanPackage(
  packageId: packageId,
  courseId: 'TDE_9',
  themeId: 'TEMA_01',
  blockId: blockId,
  packageNo: packageNo,
  lessonHours: hours,
  title: 'Plan $packageNo',
  summary: 'Özet',
  remainingBlockHours: 0,
  schemaVersion: '1.0.0',
  validationStatus: 'PASS',
  sourcePath: 'generated/$packageId.json',
  payloadSha256: 'sha256-$packageId',
  outcomeCodes: const [],
  usedActivityIds: const [],
  usedFormIds: const [],
  lessons: List<LessonPlanLesson>.generate(
    hours,
    (index) => LessonPlanLesson(
      lessonNo: index + 1,
      durationLessonHours: 1,
      title: 'Plan $packageNo · ${index + 1}. ders',
      objective: 'Amaç',
      outcomeCodes: const [],
      opening: null,
      teacherActions: const [],
      studentActions: const [],
      activityIds: const [],
      formIds: const [],
      assessment: null,
      closure: null,
      materials: const [],
      raw: const {},
    ),
    growable: false,
  ),
  teacherNotes: null,
  continuation: const LessonPlanContinuation(
    plannedNowHours: 0,
    remainingBlockHours: 0,
    coveredOutcomeCodes: [],
    usedActivityIds: [],
    nextStepHint: null,
    raw: {},
  ),
  rawPayload: const {},
);

class _FakeRepository
    implements CourseKnowledgeRepository, LessonPlanKnowledgeRepository {
  _FakeRepository(this.packagesByBlock);

  final Map<String, List<LessonPlanPackage>> packagesByBlock;

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
      packagesByBlock[blockId] ?? const [];

  @override
  Future<LessonPlanPackage?> getLessonPlan(String packageId) async {
    for (final plans in packagesByBlock.values) {
      for (final plan in plans) {
        if (plan.packageId == packageId) return plan;
      }
    }
    return null;
  }

  @override
  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) async => null;

  @override
  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) async => null;

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
  Future<List<TimelineEntry>> getAnnualSequence() async =>
      throw UnimplementedError();

  @override
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) async =>
      throw UnimplementedError();

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) async =>
      throw UnimplementedError();
}
