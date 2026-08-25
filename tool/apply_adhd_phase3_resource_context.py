from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# ResourceLibraryPage: context-aware initial theme + current lesson focus.
path = Path('lib/features/resources/resource_library_page.dart')
text = path.read_text()

text = replace_once(
    text,
    "import 'package:flutter/material.dart';\n\nimport '../../domain/models/course_models.dart' as model;\nimport '../../domain/repositories/course_knowledge_repository.dart';\n",
    "import 'package:flutter/material.dart';\n\nimport '../../data/preferences/continuity_repository.dart';\nimport '../../domain/models/course_models.dart' as model;\nimport '../../domain/models/outcome_tracking_models.dart';\nimport '../../domain/repositories/course_knowledge_repository.dart';\nimport '../../domain/services/outcome_planning_service.dart';\n",
    'resource imports',
)

text = replace_once(
    text,
    "    required this.repository,\n    required this.awaitingTextbook,\n  });\n\n  final CourseKnowledgeRepository repository;\n  final bool awaitingTextbook;\n",
    "    required this.repository,\n    required this.awaitingTextbook,\n    this.continuity,\n    this.outcomePlanning,\n    this.courseId,\n    this.active = true,\n  });\n\n  final CourseKnowledgeRepository repository;\n  final bool awaitingTextbook;\n  final ContinuityRepository? continuity;\n  final OutcomePlanningService? outcomePlanning;\n  final String? courseId;\n  final bool active;\n",
    'resource constructor',
)

old_load = """  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ResourceData> _load() async {
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) return const _ResourceData(themes: [], package: null);
    final selected = _selectedThemeId != null &&
            themes.any((theme) => theme.id == _selectedThemeId)
        ? _selectedThemeId!
        : themes.first.id;
    return _ResourceData(
      themes: themes,
      package: await widget.repository.getTeacherPackage(selected),
    );
  }
"""
new_load = """  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ResourceLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _selectedThemeId = null;
      _future = _load();
    }
  }

  Future<_ResourceData> _load() async {
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) return const _ResourceData(themes: [], package: null);

    final explicitThemeId = _selectedThemeId;
    if (explicitThemeId != null &&
        themes.any((theme) => theme.id == explicitThemeId)) {
      final package = await widget.repository.getTeacherPackage(explicitThemeId);
      return _ResourceData(
        themes: themes,
        package: package,
        context: _LessonResourceContext(
          kind: _ResourceContextKind.manual,
          themeId: package.theme.id,
          themeTitle: package.theme.title,
        ),
      );
    }

    final resolvedContext = await _resolveLessonContext(themes);
    final selectedThemeId = resolvedContext?.themeId ?? themes.first.id;
    final package = await widget.repository.getTeacherPackage(selectedThemeId);
    return _ResourceData(
      themes: themes,
      package: package,
      context: resolvedContext ??
          _LessonResourceContext(
            kind: _ResourceContextKind.fallback,
            themeId: package.theme.id,
            themeTitle: package.theme.title,
          ),
    );
  }

  Future<_LessonResourceContext?> _resolveLessonContext(
    List<model.Theme> themes,
  ) async {
    final continuity = widget.continuity;
    final outcomePlanning = widget.outcomePlanning;
    final courseId = widget.courseId;
    if (continuity == null || outcomePlanning == null || courseId == null) {
      return null;
    }

    try {
      final plan = await outcomePlanning.buildPlan();
      LastFocusState? stored;
      try {
        stored = await continuity.getLastFocus(courseId);
      } on Object {
        stored = null;
      }

      if (stored != null && stored.academicYear == plan.academicYear) {
        final item = _findTrackedOutcome(plan, stored.trackingKey);
        final theme = item?.primaryTheme;
        if (item != null &&
            theme != null &&
            themes.any((candidate) => candidate.id == theme.id)) {
          return _LessonResourceContext(
            kind: _ResourceContextKind.lastViewed,
            themeId: theme.id,
            themeTitle: theme.title,
            blockTitle: item.primaryBlock?.title ?? stored.blockTitle,
            outcomeCode: item.outcome.code,
            weekNumber: item.displayWeekNumber,
          );
        }
      }

      final currentWeek = plan.currentWeek;
      if (currentWeek == null) return null;

      for (final item in currentWeek.outcomes) {
        final theme = item.primaryTheme;
        if (theme != null &&
            themes.any((candidate) => candidate.id == theme.id)) {
          return _LessonResourceContext(
            kind: _ResourceContextKind.currentWeek,
            themeId: theme.id,
            themeTitle: theme.title,
            blockTitle: item.primaryBlock?.title,
            outcomeCode: item.outcome.code,
            weekNumber: currentWeek.week.weekNumber,
          );
        }
      }

      for (final segment in currentWeek.week.segments) {
        if (themes.any((candidate) => candidate.id == segment.theme.id)) {
          return _LessonResourceContext(
            kind: _ResourceContextKind.currentWeek,
            themeId: segment.theme.id,
            themeTitle: segment.theme.title,
            blockTitle: segment.block?.title,
            weekNumber: currentWeek.week.weekNumber,
          );
        }
      }
    } on Object {
      // Context is a convenience layer; resource access must still work.
    }
    return null;
  }

  TrackedOutcome? _findTrackedOutcome(AnnualOutcomePlan plan, String key) {
    for (final summary in plan.weeks) {
      for (final item in summary.outcomes) {
        if (item.trackingKey == key) return item;
      }
    }
    return null;
  }
"""
text = replace_once(text, old_load, new_load, 'resource load block')

old_awaiting = """      if (widget.awaitingTextbook) {
        return AppPage(
          children: [
            _ThemeSelector(
              themes: data.themes,
              selectedThemeId: package.theme.id,
              enabled: !loading,
              onChanged: _selectTheme,
            ),
            if (loading) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpacing.lg),
            StatusPanel(
"""
new_awaiting = """      if (widget.awaitingTextbook) {
        return AppPage(
          children: [
            _ThemeResourceFocus(
              package: package,
              primary: package.sourceReferences.isNotEmpty
                  ? _ResourceKind.sources
                  : null,
              context: data.context!,
            ),
            const SizedBox(height: AppSpacing.md),
            _ThemeSelector(
              themes: data.themes,
              selectedThemeId: package.theme.id,
              enabled: !loading,
              onChanged: _selectTheme,
            ),
            if (loading) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpacing.lg),
            StatusPanel(
"""
text = replace_once(text, old_awaiting, new_awaiting, 'awaiting layout')

old_normal = """      return AppPage(
        children: [
          _ThemeSelector(
            themes: data.themes,
            selectedThemeId: package.theme.id,
            enabled: !loading,
            onChanged: _selectTheme,
          ),
          if (loading) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpacing.lg),
          _ThemeResourceFocus(package: package, primary: primary),
          const SectionHeading(
"""
new_normal = """      return AppPage(
        children: [
          _ThemeResourceFocus(
            package: package,
            primary: primary,
            context: data.context!,
          ),
          const SizedBox(height: AppSpacing.md),
          _ThemeSelector(
            themes: data.themes,
            selectedThemeId: package.theme.id,
            enabled: !loading,
            onChanged: _selectTheme,
          ),
          if (loading) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpacing.lg),
          const SectionHeading(
"""
text = replace_once(text, old_normal, new_normal, 'normal layout')

old_data = """class _ResourceData {
  const _ResourceData({required this.themes, required this.package});

  final List<model.Theme> themes;
  final model.TeacherPackage? package;
}
"""
new_data = """enum _ResourceContextKind { lastViewed, currentWeek, manual, fallback }

class _LessonResourceContext {
  const _LessonResourceContext({
    required this.kind,
    required this.themeId,
    required this.themeTitle,
    this.blockTitle,
    this.outcomeCode,
    this.weekNumber,
  });

  final _ResourceContextKind kind;
  final String themeId;
  final String themeTitle;
  final String? blockTitle;
  final String? outcomeCode;
  final int? weekNumber;

  String get eyebrow => switch (kind) {
    _ResourceContextKind.lastViewed || _ResourceContextKind.currentWeek =>
      'ŞU ANKİ DERS',
    _ResourceContextKind.manual => 'SEÇİLİ TEMA',
    _ResourceContextKind.fallback => 'BU TEMADA HAZIR',
  };

  String? get detailLine {
    final parts = <String>[
      if (blockTitle?.trim().isNotEmpty == true) blockTitle!.trim(),
      if (outcomeCode?.trim().isNotEmpty == true) outcomeCode!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? get sourceLabel => switch (kind) {
    _ResourceContextKind.lastViewed => 'Son görüntülenen ders',
    _ResourceContextKind.currentWeek => weekNumber == null
        ? 'Bu haftanın planı'
        : '$weekNumber. hafta planı',
    _ResourceContextKind.manual || _ResourceContextKind.fallback => null,
  };
}

class _ResourceData {
  const _ResourceData({
    required this.themes,
    required this.package,
    this.context,
  });

  final List<model.Theme> themes;
  final model.TeacherPackage? package;
  final _LessonResourceContext? context;
}
"""
text = replace_once(text, old_data, new_data, 'resource data/context types')

text = replace_once(
    text,
    "      labelText: 'Tema',\n",
    "      labelText: 'Tema değiştir',\n",
    'theme selector label',
)

old_focus_header = """class _ThemeResourceFocus extends StatelessWidget {
  const _ThemeResourceFocus({required this.package, required this.primary});

  final model.TeacherPackage package;
  final _ResourceKind? primary;
"""
new_focus_header = """class _ThemeResourceFocus extends StatelessWidget {
  const _ThemeResourceFocus({
    required this.package,
    required this.primary,
    required this.context,
  });

  final model.TeacherPackage package;
  final _ResourceKind? primary;
  final _LessonResourceContext context;
"""
text = replace_once(text, old_focus_header, new_focus_header, 'focus constructor')

text = replace_once(
    text,
    "              'BU TEMADA HAZIR',\n",
    "              context.eyebrow,\n",
    'focus eyebrow',
)

old_focus_title_tail = """            Text(
              package.theme.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _focusMessage(primary),
"""
new_focus_title_tail = """            Text(
              package.theme.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (this.context.detailLine != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                this.context.detailLine!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (this.context.sourceLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                this.context.sourceLabel!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              _focusMessage(primary),
"""
text = replace_once(text, old_focus_title_tail, new_focus_title_tail, 'focus lesson context details')

path.write_text(text)


# App shell: provide continuity/planning context and active-tab signal.
path = Path('lib/app/app.dart')
text = path.read_text()
old_resource_page = """      ResourceLibraryPage(
        repository: repository,
        awaitingTextbook: activeCourse.isAwaitingTextbook,
      ),
"""
new_resource_page = """      ResourceLibraryPage(
        repository: repository,
        awaitingTextbook: activeCourse.isAwaitingTextbook,
        continuity: _continuity,
        outcomePlanning: _outcomePlanning,
        courseId: widget.activeCourseId,
        active: widget.selectedIndex == 2,
      ),
"""
text = replace_once(text, old_resource_page, new_resource_page, 'app resource wiring')
path.write_text(text)


# Regression coverage for last-viewed/current-week resource context.
path = Path('test/resource_library_focus_test.dart')
text = path.read_text()
text = replace_once(
    text,
    "import 'package:flutter_test/flutter_test.dart';\nimport 'package:ogretmen_os/domain/models/course_models.dart' as model;\nimport 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';\nimport 'package:ogretmen_os/features/resources/resource_library_page.dart';\n",
    "import 'package:flutter_test/flutter_test.dart';\nimport 'package:ogretmen_os/data/preferences/continuity_repository.dart';\nimport 'package:ogretmen_os/domain/models/course_models.dart' as model;\nimport 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';\nimport 'package:ogretmen_os/domain/models/weekly_plan_models.dart';\nimport 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';\nimport 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';\nimport 'package:ogretmen_os/domain/services/outcome_planning_service.dart';\nimport 'package:ogretmen_os/features/resources/resource_library_page.dart';\n",
    'test imports',
)

insert_after_first_test = """  testWidgets('kaynaklar ilk yararlı kaynağı açık gösterir', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(awaitingTextbook: false));
    await tester.pumpAndSettle();

    expect(find.text('BU TEMADA HAZIR'), findsOneWidget);
    expect(find.text('TEMA 1'), findsWidgets);
    expect(find.text('1 bölüm'), findsWidgets);
    expect(find.text('1 etkinlik'), findsWidgets);
    expect(find.text('Ders kitabı'), findsOneWidget);
    expect(find.text('Kitap Bölümü 1'), findsOneWidget);
    expect(find.text('Etkinlikler'), findsOneWidget);
    expect(find.text('Etkinlik 1'), findsNothing);
    expect(find.text('Kaynak dayanakları'), findsOneWidget);
    expect(find.text('Kaynak 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
"""
new_context_tests = insert_after_first_test + """

  testWidgets('son görüntülenen ders kaynak odağında mevcut haftayı geçer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ResourceRepository();
    final plan = _contextPlan(currentWeekNumber: 1);
    final service = _StaticOutcomePlanningService(repository, plan);
    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 2,
        trackingKey: '2026-2027:O2:2',
        outcomeCode: 'T2.1',
        themeTitle: 'TEMA 2',
        blockId: 'B2',
        blockTitle: 'Blok 2',
        updatedAt: DateTime(2026, 10, 1, 10),
      ),
    );

    await tester.pumpWidget(
      _contextApp(
        repository: repository,
        continuity: continuity,
        service: service,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ŞU ANKİ DERS'), findsOneWidget);
    expect(find.text('Son görüntülenen ders'), findsOneWidget);
    expect(find.text('Blok 2 · T2.1'), findsOneWidget);
    expect(find.text('TEMA 2'), findsWidgets);
    expect(find.text('Kaynak 2'), findsOneWidget);
    expect(find.text('Kaynak 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus yoksa kaynaklar mevcut haftanın temasını açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ResourceRepository();
    final plan = _contextPlan(currentWeekNumber: 2);

    await tester.pumpWidget(
      _contextApp(
        repository: repository,
        continuity: MemoryContinuityRepository(),
        service: _StaticOutcomePlanningService(repository, plan),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ŞU ANKİ DERS'), findsOneWidget);
    expect(find.text('2. hafta planı'), findsOneWidget);
    expect(find.text('Blok 2 · T2.1'), findsOneWidget);
    expect(find.text('TEMA 2'), findsWidgets);
    expect(find.text('Kaynak 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
"""
text = replace_once(text, insert_after_first_test, new_context_tests, 'context tests')

# Add context-aware fixture widgets/helpers before repository class.
repo_anchor = """class _ResourceRepository implements CourseKnowledgeRepository {
"""
helpers = """Widget _contextApp({
  required _ResourceRepository repository,
  required ContinuityRepository continuity,
  required OutcomePlanningService service,
}) => MaterialApp(
  home: Scaffold(
    body: ResourceLibraryPage(
      repository: repository,
      awaitingTextbook: false,
      continuity: continuity,
      outcomePlanning: service,
      courseId: 'TDE_9',
    ),
  ),
);

AnnualOutcomePlan _contextPlan({required int currentWeekNumber}) {
  final week1 = AcademicWeekPlan(
    weekNumber: 1,
    start: DateTime(2026, 9, 14),
    end: DateTime(2026, 9, 18),
    type: AcademicWeekType.instruction,
    label: '1. Hafta',
    plannedLessonHours: 5,
    segments: const [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: _ResourceRepository.theme1,
        hours: 5,
        block: _ResourceRepository.block,
      ),
    ],
    outcomes: const [_ResourceRepository.outcome1],
  );
  final week2 = AcademicWeekPlan(
    weekNumber: 2,
    start: DateTime(2026, 9, 21),
    end: DateTime(2026, 9, 25),
    type: AcademicWeekType.instruction,
    label: '2. Hafta',
    plannedLessonHours: 5,
    segments: const [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: _ResourceRepository.theme2,
        hours: 5,
        block: _ResourceRepository.block2,
      ),
    ],
    outcomes: const [_ResourceRepository.outcome2],
  );
  return AnnualOutcomePlan(
    weeklyPlan: AnnualWeeklyPlan(
      academicYear: '2026-2027',
      courseId: 'TDE_9',
      weeklyLessonHours: 5,
      annualHours: 180,
      weeks: [week1, week2],
      currentWeekNumber: currentWeekNumber,
    ),
    weeks: [
      WeeklyOutcomeSummary(
        week: week1,
        outcomes: const [
          TrackedOutcome(
            outcome: _ResourceRepository.outcome1,
            academicYear: '2026-2027',
            plannedWeekNumber: 1,
            displayWeekNumber: 1,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext(detail: _ResourceRepository.detail1),
            ],
          ),
        ],
      ),
      WeeklyOutcomeSummary(
        week: week2,
        outcomes: const [
          TrackedOutcome(
            outcome: _ResourceRepository.outcome2,
            academicYear: '2026-2027',
            plannedWeekNumber: 2,
            displayWeekNumber: 2,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext(detail: _ResourceRepository.detail2),
            ],
          ),
        ],
      ),
    ],
  );
}

class _StaticOutcomePlanningService extends OutcomePlanningService {
  _StaticOutcomePlanningService(
    CourseKnowledgeRepository repository,
    this.plan,
  ) : super(
        repository: repository,
        weeklyPlanning: _UnusedWeeklyPlanning(),
        trackingRepository: MemoryOutcomeTrackingRepository(),
      );

  final AnnualOutcomePlan plan;

  @override
  Future<AnnualOutcomePlan> buildPlan({DateTime? today}) async => plan;
}

class _UnusedWeeklyPlanning implements WeeklyPlanningService {
  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) =>
      throw UnimplementedError();
}

""" + repo_anchor
text = replace_once(text, repo_anchor, helpers, 'test helper insertion')

# Expand repository fixture with Theme 2 block/outcomes/details.
block_anchor = """  static const block = model.Block(
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
"""
block_expansion = block_anchor + """

  static const block2 = model.Block(
    id: 'B2',
    themeId: 'T2',
    order: 1,
    title: 'Blok 2',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const outcome1 = model.Outcome(
    id: 'O1',
    themeId: 'T1',
    code: 'T1.1',
    officialText: 'Tema 1 kazanımı',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );

  static const outcome2 = model.Outcome(
    id: 'O2',
    themeId: 'T2',
    code: 'T2.1',
    officialText: 'Tema 2 kazanımı',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'PASS',
  );
"""
text = replace_once(text, block_anchor, block_expansion, 'fixture blocks/outcomes')

package1_anchor = """  static const package1 = model.TeacherPackage(
    theme: theme1,
    blocks: [block],
    outcomes: [],
"""
text = replace_once(
    text,
    package1_anchor,
    """  static const package1 = model.TeacherPackage(
    theme: theme1,
    blocks: [block],
    outcomes: [outcome1],
""",
    'package1 outcome',
)

package2_anchor = """  static const package2 = model.TeacherPackage(
    theme: theme2,
    blocks: [],
    outcomes: [],
"""
text = replace_once(
    text,
    package2_anchor,
    """  static const package2 = model.TeacherPackage(
    theme: theme2,
    blocks: [block2],
    outcomes: [outcome2],
""",
    'package2 block/outcome',
)

# Insert reusable block details before getCourse override.
override_anchor = """  @override
  Future<model.Course> getCourse() async => course;
"""
details = """  static const detail1 = model.BlockDetail(
    theme: theme1,
    block: block,
    outcomes: [outcome1],
    textbookSections: [book],
    activities: [activity],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source1],
    previousBlock: null,
    nextBlock: null,
  );

  static const detail2 = model.BlockDetail(
    theme: theme2,
    block: block2,
    outcomes: [outcome2],
    textbookSections: [],
    activities: [],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source2],
    previousBlock: null,
    nextBlock: null,
  );

""" + override_anchor
text = replace_once(text, override_anchor, details, 'fixture details')

old_get_block = """  @override
  Future<model.BlockDetail> getBlock(String blockId) async => const model.BlockDetail(
    theme: theme1,
    block: block,
    outcomes: [],
    textbookSections: [book],
    activities: [activity],
    forms: [],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [source1],
    previousBlock: null,
    nextBlock: null,
  );
"""
new_get_block = """  @override
  Future<model.BlockDetail> getBlock(String blockId) async =>
      blockId == block2.id ? detail2 : detail1;
"""
text = replace_once(text, old_get_block, new_get_block, 'fixture getBlock')

path.write_text(text)
