from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing patch anchor: {label}")
    return text.replace(old, new, 1)


# 1) Production dependency graph: tracking changes must not own continuity state.
path = Path('lib/app/app_dependencies.dart')
text = path.read_text()
text = text.replace("import '../domain/models/outcome_tracking_models.dart';\n", '')
pattern = re.compile(
    r"    final continuity = SharedPreferencesContinuityRepository\(preferences\);\n"
    r"    final outcomePlanning = OutcomePlanningService\([\s\S]*?\n"
    r"    \);\n\n"
    r"    return AppDependencies\(",
)
replacement = """    final continuity = SharedPreferencesContinuityRepository(preferences);\n    final outcomePlanning = OutcomePlanningService(\n      repository: repository,\n      weeklyPlanning: weeklyPlanning,\n      trackingRepository: trackingRepository,\n    );\n\n    return AppDependencies("""
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('failed to decouple production tracking from continuity')
path.write_text(text)


# 2) ThisWeekPage emits a viewing event before navigation, but never requires it.
path = Path('lib/features/this_week/this_week_page.dart')
text = path.read_text()
text = replace_once(
    text,
    """    required this.repository,\n    required this.service,\n  });\n\n  final CourseKnowledgeRepository repository;\n  final OutcomePlanningService service;\n""",
    """    required this.repository,\n    required this.service,\n    this.onOutcomeViewed,\n  });\n\n  final CourseKnowledgeRepository repository;\n  final OutcomePlanningService service;\n  final Future<void> Function(TrackedOutcome item)? onOutcomeViewed;\n""",
    'ThisWeekPage constructor',
)
text = replace_once(
    text,
    """  Future<void> _openOutcome(AnnualOutcomePlan plan, TrackedOutcome item) async {\n    final changed = await Navigator.of(context).push<bool>(\n""",
    """  Future<void> _openOutcome(AnnualOutcomePlan plan, TrackedOutcome item) async {\n    final onOutcomeViewed = widget.onOutcomeViewed;\n    if (onOutcomeViewed != null) {\n      try {\n        await onOutcomeViewed(item);\n      } on Object {\n        // Continuity is convenience state; it must never block lesson access.\n      }\n    }\n    if (!mounted) return;\n\n    final changed = await Navigator.of(context).push<bool>(\n""",
    'ThisWeekPage open outcome',
)
path.write_text(text)


# 3) Continuity now means last viewed focus, independent of completion/carry status.
path = Path('lib/features/this_week/continuity_this_week_page.dart')
text = path.read_text()
text = replace_once(
    text,
    """    final item = _resolveFocus(plan, stored);\n    if (item == null || !_isRestorable(item)) {\n      await widget.continuity.clearLastFocus(widget.courseId);\n      return _ContinuityData(plan: plan);\n    }\n""",
    """    final item = _resolveFocus(plan, stored);\n    if (item == null) {\n      await widget.continuity.clearLastFocus(widget.courseId);\n      return _ContinuityData(plan: plan);\n    }\n""",
    'continuity load validity',
)
pattern = re.compile(
    r"  TrackedOutcome\? _resolveFocus\(AnnualOutcomePlan plan, LastFocusState stored\) \{[\s\S]*?\n"
    r"  void _reload\(\) \{",
)
replacement = """  TrackedOutcome? _resolveFocus(AnnualOutcomePlan plan, LastFocusState stored) {\n    final preferredWeek = plan.week(stored.weekNumber);\n    if (preferredWeek != null) {\n      for (final item in preferredWeek.outcomes) {\n        if (item.trackingKey == stored.trackingKey) return item;\n      }\n    }\n    for (final summary in plan.weeks) {\n      for (final item in summary.outcomes) {\n        if (item.trackingKey == stored.trackingKey) return item;\n      }\n    }\n    return null;\n  }\n\n  void _reload() {"""
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('failed to replace continuity resolver')
text = replace_once(
    text,
    """  Future<void> _resume(_ContinuityData data) async {\n    final item = data.item;\n    if (item == null) return;\n    final changed = await Navigator.of(context).push<bool>(\n""",
    """  Future<void> _rememberViewed(TrackedOutcome item) =>\n      widget.continuity.setLastFocus(\n        LastFocusState(\n          courseId: widget.courseId,\n          academicYear: item.academicYear,\n          weekNumber: item.displayWeekNumber,\n          trackingKey: item.trackingKey,\n          outcomeCode: item.outcome.code,\n          themeTitle: item.primaryTheme?.title,\n          blockId: item.primaryBlock?.id,\n          blockTitle: item.primaryBlock?.title,\n          updatedAt: DateTime.now(),\n        ),\n      );\n\n  Future<void> _resume(_ContinuityData data) async {\n    final item = data.item;\n    if (item == null) return;\n    try {\n      await _rememberViewed(item);\n    } on Object {\n      // Resume must remain available even if preference persistence fails.\n    }\n    if (!mounted) return;\n    final changed = await Navigator.of(context).push<bool>(\n""",
    'remember viewed focus',
)
text = replace_once(
    text,
    """              repository: widget.repository,\n              service: widget.service,\n            ),\n""",
    """              repository: widget.repository,\n              service: widget.service,\n              onOutcomeViewed: _rememberViewed,\n            ),\n""",
    'continuity callback wiring',
)
path.write_text(text)


# 4) Regression tests: viewing writes focus without tracking; completed focus persists.
path = Path('test/continuity_test.dart')
text = path.read_text()
text = replace_once(
    text,
    "import 'package:ogretmen_os/domain/models/course_models.dart' as model;\n",
    "import 'package:ogretmen_os/domain/models/course_models.dart' as model;\nimport 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';\n",
    'continuity test tracking import',
)
anchor = """  testWidgets('stale academic-year focus is cleared', (tester) async {\n"""
new_tests = r"""  testWidgets('opening outcome stores focus without creating tracking state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final continuity = MemoryContinuityRepository();
    final tracking = MemoryOutcomeTrackingRepository();
    final repository = _FakeRepository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: tracking,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinuityThisWeekPage(
            repository: repository,
            service: service,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await continuity.getLastFocus('TDE_9'), isNull);
    expect(await tracking.getForAcademicYear('2026-2027'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Ders ayrıntısını aç'));
    await tester.pumpAndSettle();

    final stored = await continuity.getLastFocus('TDE_9');
    expect(stored, isNotNull);
    expect(stored!.trackingKey, '2026-2027:TEST_OUTCOME:1');
    expect(stored.outcomeCode, 'TEST.1');
    expect(stored.blockId, 'TEST_BLOCK');
    expect(await tracking.getForAcademicYear('2026-2027'), isEmpty);
  });

  testWidgets('completed tracking does not erase the last viewed focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 1,
        trackingKey: '2026-2027:TEST_OUTCOME:1',
        outcomeCode: 'TEST.1',
        themeTitle: 'TEST TEMA',
        blockId: 'TEST_BLOCK',
        blockTitle: 'Test Blok',
        updatedAt: DateTime(2026, 9, 14, 10),
      ),
    );
    final tracking = MemoryOutcomeTrackingRepository();
    final repository = _FakeRepository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: tracking,
    );
    final plan = await service.buildPlan();
    final item = plan.week(1)!.outcomes.single;
    await service.setStatus(item, OutcomeTrackingStatus.completed);

    final storedBeforeBuild = await continuity.getLastFocus('TDE_9');
    expect(storedBeforeBuild, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinuityThisWeekPage(
            repository: repository,
            service: service,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KALDIĞIN YER'), findsOneWidget);
    expect(find.text('1. Hafta · TEST.1'), findsOneWidget);
    expect((await continuity.getLastFocus('TDE_9'))?.trackingKey, item.trackingKey);
  });

"""
text = replace_once(text, anchor, new_tests + anchor, 'phase 2 continuity tests')
path.write_text(text)
