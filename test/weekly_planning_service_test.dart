import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/calendar/asset_weekly_planning_service.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CalendarFakeRepository repository;
  late AssetWeeklyPlanningService service;

  setUp(() {
    repository = _CalendarFakeRepository();
    service = AssetWeeklyPlanningService(repository: repository);
  });

  test('2026-2027 takvimi 37 aktif okul haftası ve 36 ders haftası üretir', () async {
    final plan = await service.buildPlan(today: DateTime(2026, 9, 14));

    expect(plan.academicYear, '2026-2027');
    expect(plan.weeklyLessonHours, 5);
    expect(plan.annualHours, 180);
    expect(plan.weeks, hasLength(37));
    expect(plan.weeks.where((week) => !week.isEventWeek), hasLength(36));
    expect(plan.weeks.where((week) => week.isEventWeek), hasLength(1));
    expect(plan.currentWeekNumber, 1);
  });

  test('3. hafta blok sınırını 2 saat + 3 saat olarak taşır ve iki bloğun kazanımlarını gösterir', () async {
    final plan = await service.buildPlan(today: DateTime(2026, 9, 30));
    final week = plan.week(3)!;

    expect(week.start, DateTime(2026, 9, 28));
    expect(week.end, DateTime(2026, 10, 2));
    expect(week.plannedLessonHours, 5);
    expect(week.segments, hasLength(2));
    expect(week.segments[0].block?.id, 'T1_B1');
    expect(week.segments[0].hours, 2);
    expect(week.segments[1].block?.id, 'T1_B2');
    expect(week.segments[1].hours, 3);
    expect(week.outcomes.map((outcome) => outcome.code), containsAll(['T1.B1', 'T1.B2']));
  });

  test('9. hafta temayı 3 saat son blok + 2 saat okul temelli planlama ile kapatır', () async {
    final plan = await service.buildPlan();
    final week = plan.week(9)!;

    expect(week.start, DateTime(2026, 11, 9));
    expect(week.end, DateTime(2026, 11, 13));
    expect(week.segments, hasLength(2));
    expect(week.segments[0].block?.id, 'T1_B4');
    expect(week.segments[0].hours, 3);
    expect(week.segments[1].type, WeeklyPlanSegmentType.schoolBasedPlanning);
    expect(week.segments[1].block, isNull);
    expect(week.segments[1].hours, 2);
  });

  test('ara tatil ders bütçesi tüketmez; 10. aktif hafta 23 Kasımda başlar', () async {
    final plan = await service.buildPlan();
    final week = plan.week(10)!;

    expect(week.start, DateTime(2026, 11, 23));
    expect(week.end, DateTime(2026, 11, 27));
    expect(week.segments.first.block?.id, 'T2_B1');
  });

  test('37. aktif hafta Etkinlik Haftasıdır ve yeni ders/kazanım atanmaz', () async {
    final plan = await service.buildPlan(today: DateTime(2027, 6, 23));
    final week = plan.week(37)!;

    expect(week.start, DateTime(2027, 6, 21));
    expect(week.end, DateTime(2027, 6, 25));
    expect(week.type, AcademicWeekType.event);
    expect(week.label, 'Etkinlik Haftası');
    expect(week.plannedLessonHours, 0);
    expect(week.segments, isEmpty);
    expect(week.outcomes, isEmpty);
    expect(plan.currentWeekNumber, 37);
  });

  test('180 saatlik course budget ilk 36 haftada tam korunur', () async {
    final plan = await service.buildPlan();
    final total = plan.weeks.fold<int>(
      0,
      (sum, week) => sum + week.plannedLessonHours,
    );
    final schoolBased = plan.weeks
        .expand((week) => week.segments)
        .where((segment) => segment.type == WeeklyPlanSegmentType.schoolBasedPlanning)
        .fold<int>(0, (sum, segment) => sum + segment.hours);

    expect(total, 180);
    expect(schoolBased, 8);
  });
}

class _CalendarFakeRepository implements CourseKnowledgeRepository {
  _CalendarFakeRepository() {
    for (var themeIndex = 1; themeIndex <= 4; themeIndex++) {
      final theme = model.Theme(
        id: 'T$themeIndex',
        order: themeIndex,
        title: '$themeIndex. Tema',
        pageRange: null,
        plannedHours: 45,
        anlamaHours: 23,
        anlatmaHours: 20,
        sourceLocator: null,
      );
      _themes.add(theme);
      for (var blockIndex = 1; blockIndex <= 4; blockIndex++) {
        final block = model.Block(
          id: 'T${themeIndex}_B$blockIndex',
          themeId: theme.id,
          order: blockIndex,
          title: '$themeIndex. Tema $blockIndex. Blok',
          skillDomain: null,
          learningArea: null,
          plannedHours: null,
          timeStatus: 'ORDER_ONLY',
          sourceLocators: const [],
        );
        _blocks[block.id] = block;
        _sequence.add(
          model.TimelineEntry(
            sequencePosition: _sequence.length + 1,
            theme: theme,
            block: block,
            officialTotalHours: 45,
            coreInstructionHours: 43,
            schoolBasedHours: 2,
            schoolBasedHoursStatus: 'PLANNED_PROFILE',
          ),
        );
        _details[block.id] = model.BlockDetail(
          theme: theme,
          block: block,
          outcomes: [
            model.Outcome(
              id: '${block.id}_OUTCOME',
              themeId: theme.id,
              code: 'T$themeIndex.B$blockIndex',
              officialText: '$blockIndex. blok test kazanımı',
              processComponents: null,
              sourceLocator: null,
              verificationStatus: 'PASS',
            ),
          ],
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
      }
    }
  }

  final List<model.Theme> _themes = [];
  final Map<String, model.Block> _blocks = {};
  final List<model.TimelineEntry> _sequence = [];
  final Map<String, model.BlockDetail> _details = {};

  @override
  Future<model.Course> getCourse() async => const model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Türk Dili ve Edebiyatı 9',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'fixture',
  );

  @override
  Future<model.RuntimeManifest> getManifest() async => const model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: 'TDE_9',
    validationStatus: 'PASS',
    canonicalContentFingerprint: 'fixture',
    rowCounts: {},
    timelineResolution: 'THEME_TIME_RESOLVED',
    timelineUnresolvedFields: {},
  );

  @override
  Future<List<model.Theme>> getThemes() async => List.unmodifiable(_themes);

  @override
  Future<model.Theme> getTheme(String themeId) async =>
      _themes.firstWhere((theme) => theme.id == themeId);

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => _blocks.values
      .where((block) => block.themeId == themeId)
      .toList(growable: false);

  @override
  Future<model.BlockDetail> getBlock(String blockId) async => _details[blockId]!;

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async =>
      List.unmodifiable(_sequence);

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(String themeId) async =>
      const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async =>
      throw UnimplementedError();
}
