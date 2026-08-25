from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


# app.dart — annual plan needs read-only access to optional tracking summary.
path = Path('lib/app/app.dart')
text = path.read_text()
text = replace_once(
    text,
    """      AnnualPlanPage(\n        repository: repository,\n        preferences: widget.dependencies.preferences,\n        continuity: _continuity,\n        courseId: widget.activeCourseId,\n      ),\n""",
    """      AnnualPlanPage(\n        repository: repository,\n        preferences: widget.dependencies.preferences,\n        continuity: _continuity,\n        courseId: widget.activeCourseId,\n        outcomePlanning: _outcomePlanning,\n      ),\n""",
    'app annual planning injection',
)
path.write_text(text)


# annual_plan_page.dart — replace position-as-progress with explicit position semantics
# and show only explicitly teacher-marked tracking states, never a completion percent.
path = Path('lib/features/annual_plan/annual_plan_page.dart')
text = path.read_text()
text = replace_once(
    text,
    """import '../../domain/models/course_models.dart' as model;\nimport '../../domain/repositories/course_knowledge_repository.dart';\n""",
    """import '../../domain/models/course_models.dart' as model;\nimport '../../domain/models/outcome_tracking_models.dart';\nimport '../../domain/repositories/course_knowledge_repository.dart';\nimport '../../domain/services/outcome_planning_service.dart';\n""",
    'annual imports',
)
text = replace_once(
    text,
    """    required this.continuity,\n    required this.courseId,\n  });\n\n  final CourseKnowledgeRepository repository;\n  final UserPreferencesRepository preferences;\n  final ContinuityRepository continuity;\n  final String courseId;\n""",
    """    required this.continuity,\n    required this.courseId,\n    this.outcomePlanning,\n  });\n\n  final CourseKnowledgeRepository repository;\n  final UserPreferencesRepository preferences;\n  final ContinuityRepository continuity;\n  final String courseId;\n  final OutcomePlanningService? outcomePlanning;\n""",
    'annual constructor',
)
text = replace_once(
    text,
    """    final manual = await _getManualPosition();\n    final lastFocus = await widget.continuity.getLastFocus(widget.courseId);\n    var manualBlockId =\n""",
    """    final manual = await _getManualPosition();\n    final lastFocus = await widget.continuity.getLastFocus(widget.courseId);\n    final trackingSummary = await _loadTrackingSummary();\n    var manualBlockId =\n""",
    'annual load tracking summary',
)
text = replace_once(
    text,
    """    return _PlanData(\n      sequence: sequence,\n      manualBlockId: manualBlockId,\n      automaticBlockId: automaticBlockId,\n    );\n  }\n\n  Future<ManualPositionOverrideState?> _getManualPosition() async {\n""",
    """    return _PlanData(\n      sequence: sequence,\n      manualBlockId: manualBlockId,\n      automaticBlockId: automaticBlockId,\n      trackingSummary: trackingSummary,\n    );\n  }\n\n  Future<_OptionalTrackingSummary?> _loadTrackingSummary() async {\n    final service = widget.outcomePlanning;\n    if (service == null) return null;\n    try {\n      final weeklyPlan = await service.weeklyPlanning.buildPlan();\n      final records = await service.trackingRepository.getForAcademicYear(\n        weeklyPlan.academicYear,\n      );\n      final summary = _OptionalTrackingSummary.fromRecords(records);\n      return summary.hasExplicitStatus ? summary : null;\n    } on Object {\n      // Optional tracking summary must never block the annual lesson sequence.\n      return null;\n    }\n  }\n\n  Future<ManualPositionOverrideState?> _getManualPosition() async {\n""",
    'annual tracking helper',
)
text = replace_once(
    text,
    """            isManualPosition: isManualPosition,\n            onClear: _clearPosition,\n          ),\n""",
    """            isManualPosition: isManualPosition,\n            trackingSummary: data.trackingSummary,\n            onClear: _clearPosition,\n          ),\n""",
    'annual summary injection',
)
text = replace_once(
    text,
    """    required this.manualBlockId,\n    required this.automaticBlockId,\n  });\n\n  final List<model.TimelineEntry> sequence;\n  final String? manualBlockId;\n  final String? automaticBlockId;\n}\n""",
    """    required this.manualBlockId,\n    required this.automaticBlockId,\n    required this.trackingSummary,\n  });\n\n  final List<model.TimelineEntry> sequence;\n  final String? manualBlockId;\n  final String? automaticBlockId;\n  final _OptionalTrackingSummary? trackingSummary;\n}\n""",
    'annual plan data',
)
text = replace_once(
    text,
    """    required this.activeEntry,\n    required this.isManualPosition,\n    required this.onClear,\n  });\n\n  final int themeCount;\n  final int blockCount;\n  final int annualHours;\n  final model.TimelineEntry? activeEntry;\n  final bool isManualPosition;\n  final VoidCallback onClear;\n""",
    """    required this.activeEntry,\n    required this.isManualPosition,\n    required this.trackingSummary,\n    required this.onClear,\n  });\n\n  final int themeCount;\n  final int blockCount;\n  final int annualHours;\n  final model.TimelineEntry? activeEntry;\n  final bool isManualPosition;\n  final _OptionalTrackingSummary? trackingSummary;\n  final VoidCallback onClear;\n""",
    'annual summary fields',
)
text = replace_once(
    text,
    """                  const SizedBox(height: AppSpacing.md),\n                  LinearProgressIndicator(\n                    value: activeEntry!.sequencePosition / blockCount,\n                    minHeight: 8,\n                    borderRadius: BorderRadius.circular(999),\n                  ),\n                  const SizedBox(height: AppSpacing.sm),\n                  Text(\n                    '${activeEntry!.sequencePosition} / $blockCount blok',\n                    style: Theme.of(context).textTheme.labelLarge?.copyWith(\n                      fontWeight: FontWeight.w800,\n                    ),\n                  ),\n""",
    """                  const SizedBox(height: AppSpacing.md),\n                  Text(\n                    'Öğretim sırası: ${activeEntry!.sequencePosition}. blok / $blockCount',\n                    style: Theme.of(context).textTheme.labelLarge?.copyWith(\n                      fontWeight: FontWeight.w800,\n                    ),\n                  ),\n                  const SizedBox(height: AppSpacing.xs),\n                  Text(\n                    'Bu konum bir ilerleme veya tamamlanma yüzdesi değildir.',\n                    style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                      color: Theme.of(context).colorScheme.onSurfaceVariant,\n                    ),\n                  ),\n""",
    'annual remove progress bar',
)
text = replace_once(
    text,
    """          ],\n        ],\n      ),\n    ),\n  );\n}\n\nclass _ThemePlanCard extends StatelessWidget {\n""",
    """          ],\n          if (trackingSummary != null) ...[\n            const SizedBox(height: AppSpacing.md),\n            _OptionalTrackingPanel(summary: trackingSummary!),\n          ],\n        ],\n      ),\n    ),\n  );\n}\n\nclass _OptionalTrackingSummary {\n  const _OptionalTrackingSummary({\n    required this.completed,\n    required this.inProgress,\n    required this.partiallyCompleted,\n    required this.carriedOver,\n  });\n\n  factory _OptionalTrackingSummary.fromRecords(\n    List<LearningOutcomeTrackingRecord> records,\n  ) {\n    var completed = 0;\n    var inProgress = 0;\n    var partiallyCompleted = 0;\n    var carriedOver = 0;\n    for (final record in records) {\n      switch (record.status) {\n        case OutcomeTrackingStatus.completed:\n          completed++;\n        case OutcomeTrackingStatus.inProgress:\n          inProgress++;\n        case OutcomeTrackingStatus.partiallyCompleted:\n          partiallyCompleted++;\n        case OutcomeTrackingStatus.carriedOver:\n          carriedOver++;\n        case OutcomeTrackingStatus.planned:\n          break;\n      }\n    }\n    return _OptionalTrackingSummary(\n      completed: completed,\n      inProgress: inProgress,\n      partiallyCompleted: partiallyCompleted,\n      carriedOver: carriedOver,\n    );\n  }\n\n  final int completed;\n  final int inProgress;\n  final int partiallyCompleted;\n  final int carriedOver;\n\n  bool get hasExplicitStatus =>\n      completed + inProgress + partiallyCompleted + carriedOver > 0;\n}\n\nclass _OptionalTrackingPanel extends StatelessWidget {\n  const _OptionalTrackingPanel({required this.summary});\n\n  final _OptionalTrackingSummary summary;\n\n  @override\n  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n    return Container(\n      width: double.infinity,\n      padding: const EdgeInsets.all(AppSpacing.md),\n      decoration: BoxDecoration(\n        color: scheme.surfaceContainerLow,\n        borderRadius: BorderRadius.circular(14),\n      ),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          Text(\n            'İSTEĞE BAĞLI TAKİP',\n            style: Theme.of(context).textTheme.labelMedium?.copyWith(\n              fontWeight: FontWeight.w800,\n              letterSpacing: 0.7,\n            ),\n          ),\n          const SizedBox(height: AppSpacing.sm),\n          Wrap(\n            spacing: AppSpacing.sm,\n            runSpacing: AppSpacing.sm,\n            children: [\n              if (summary.completed > 0)\n                Chip(label: Text('İşlendi ${summary.completed}')),\n              if (summary.inProgress > 0)\n                Chip(label: Text('Devam ediyor ${summary.inProgress}')),\n              if (summary.partiallyCompleted > 0)\n                Chip(label: Text('Kısmen ${summary.partiallyCompleted}')),\n              if (summary.carriedOver > 0)\n                Chip(label: Text('Taşındı ${summary.carriedOver}')),\n            ],\n          ),\n          const SizedBox(height: AppSpacing.sm),\n          Text(\n            'Yalnız senin açıkça işaretlediğin durumları özetler; işaretlenmemiş kazanımlar eksik sayılmaz.',\n            style: Theme.of(context).textTheme.bodySmall?.copyWith(\n              color: scheme.onSurfaceVariant,\n            ),\n          ),\n        ],\n      ),\n    );\n  }\n}\n\nclass _ThemePlanCard extends StatelessWidget {\n""",
    'annual tracking panel insertion',
)
text = replace_once(
    text,
    """              subtitle: Text(\n                '${entries[i].sequencePosition} / $totalBlocks',\n                style: Theme.of(context).textTheme.bodySmall,\n              ),\n""",
    """              subtitle: Text(\n                'Sıra ${entries[i].sequencePosition} / $totalBlocks',\n                style: Theme.of(context).textTheme.bodySmall,\n              ),\n""",
    'annual block sequence label',
)
path.write_text(text)


# this_week_page.dart — default planned state is not presented as teacher progress.
path = Path('lib/features/this_week/this_week_page.dart')
text = path.read_text()
text = replace_once(
    text,
    """                title: 'Tamamlananlar',\n""",
    """                title: 'İşlendi olarak işaretlenenler',\n""",
    'weekly completed group semantics',
)
text = replace_once(
    text,
    """                  _StatusBadge(item: focus!),\n""",
    """                  if (_hasVisibleTrackingStatus(focus!))\n                    _StatusBadge(item: focus!),\n""",
    'weekly planned badge suppression',
)
text = replace_once(
    text,
    """      subtitle: const Text('Defter ve toplu işlemler'),\n""",
    """      subtitle: const Text('Defter ve isteğe bağlı takip'),\n""",
    'weekly tools subtitle',
)
text = replace_once(
    text,
    """                label: const Text('Tümünü işlendi'),\n""",
    """                label: const Text('Tümünü işlendi olarak işaretle'),\n""",
    'weekly bulk tracking label',
)
text = replace_once(
    text,
    """                  const SizedBox(height: AppSpacing.sm),\n                  Text(\n                    _statusLabel(item),\n                    style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                      color: Theme.of(context).colorScheme.onSurfaceVariant,\n                      fontWeight: FontWeight.w700,\n                    ),\n                  ),\n                  if (item.teacherNote?.isNotEmpty == true) ...[\n""",
    """                  if (_hasVisibleTrackingStatus(item)) ...[\n                    const SizedBox(height: AppSpacing.sm),\n                    Text(\n                      _displayStatusLabel(item),\n                      style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                        color: Theme.of(context).colorScheme.onSurfaceVariant,\n                        fontWeight: FontWeight.w700,\n                      ),\n                    ),\n                  ],\n                  if (item.teacherNote?.isNotEmpty == true) ...[\n""",
    'weekly row planned label suppression',
)
text = replace_once(
    text,
    """              label: 'Planlıya döndür',\n""",
    """              label: 'Takip durumunu temizle',\n""",
    'weekly reset tracking label',
)
text = replace_once(
    text,
    """        _statusLabel(item),\n""",
    """        _displayStatusLabel(item),\n""",
    'weekly status badge semantic label',
)
text = replace_once(
    text,
    """  OutcomeTrackingStatus.planned => 'Planlı durumuna döndürüldü.',\n""",
    """  OutcomeTrackingStatus.planned => 'Takip durumu temizlendi.',\n""",
    'weekly reset feedback',
)
text = replace_once(
    text,
    """String _statusLabel(TrackedOutcome item) {\n""",
    """bool _hasVisibleTrackingStatus(TrackedOutcome item) =>\n    item.isCarriedIn ||\n    _isCarriedOut(item) ||\n    item.presentationStatus != OutcomeTrackingStatus.planned;\n\nString _displayStatusLabel(TrackedOutcome item) {\n  final label = _statusLabel(item);\n  if (item.isCarriedIn || _isCarriedOut(item)) return label;\n  return 'Takip: $label';\n}\n\nString _statusLabel(TrackedOutcome item) {\n""",
    'weekly tracking display helpers',
)
text = replace_once(
    text,
    """    OutcomeTrackingStatus.planned => Icons.radio_button_unchecked,\n""",
    """    OutcomeTrackingStatus.planned => Icons.article_outlined,\n""",
    'weekly neutral planned icon',
)
path.write_text(text)


# outcome_detail_page.dart — "planned" is the absence of explicit optional tracking.
path = Path('lib/features/outcomes/outcome_detail_page.dart')
text = path.read_text()
text = replace_once(
    text,
    """        subtitle:\n            'İsteğe bağlı · ${outcomeStatusLabel(_item.presentationStatus)}',\n""",
    """        subtitle: 'İsteğe bağlı · ${_optionalTrackingLabel(_item)}',\n""",
    'detail optional tracking label',
)
text = replace_once(
    text,
    """                label: 'Planlıya döndür',\n""",
    """                label: 'Takip durumunu temizle',\n""",
    'detail reset tracking label',
)
# Insert helper immediately before the existing _uniqueBy helper near file end.
marker = """List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {\n"""
if marker not in text:
    raise SystemExit('detail helper marker not found')
text = text.replace(
    marker,
    """String _optionalTrackingLabel(TrackedOutcome item) =>\n    item.presentationStatus == OutcomeTrackingStatus.planned\n    ? 'Takip yok'\n    : outcomeStatusLabel(item.presentationStatus);\n\nList<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {\n""",
    1,
)
path.write_text(text)


# widget_test.dart — lock the phase-6 semantics and update renamed UI labels.
path = Path('test/widget_test.dart')
text = path.read_text()
text = replace_once(
    text,
    """    expect(find.text('TEST.1'), findsOneWidget);\n    expect(find.text('TEST.2'), findsNothing);\n    expect(find.text('TEST.3'), findsNothing);\n""",
    """    expect(find.text('TEST.1'), findsOneWidget);\n    expect(find.text('TEST.2'), findsNothing);\n    expect(find.text('TEST.3'), findsNothing);\n    expect(find.text('Planlı'), findsNothing);\n    expect(find.textContaining('Takip:'), findsNothing);\n""",
    'widget initial no fake progress status',
)
text = text.replace("find.text('Tamamlananlar')", "find.text('İşlendi olarak işaretlenenler')")
text = replace_once(
    text,
    """    expect(find.text('Kısmen işlendi'), findsOneWidget);\n    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);\n""",
    """    expect(find.text('Takip: Kısmen işlendi'), findsOneWidget);\n    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);\n""",
    'widget explicit tracking prefix',
)
text = replace_once(
    text,
    """    expect(find.text('İsteğe bağlı · Planlı'), findsOneWidget);\n""",
    """    expect(find.text('İsteğe bağlı · Takip yok'), findsOneWidget);\n""",
    'widget detail no tracking state',
)
insert_after = """  testWidgets('yıllık plan tema bazında kompakt gösterilir', (tester) async {\n    _phone(tester);\n    await _pump(tester);\n\n    await _tapNavigation(tester, Icons.view_timeline_outlined);\n    await tester.pumpAndSettle();\n\n    expect(find.textContaining('1 tema · 45 saat · 1 blok'), findsOneWidget);\n    expect(find.text('TEST TEMA'), findsOneWidget);\n    expect(find.text('Test Blok'), findsOneWidget);\n    expect(find.textContaining('Bu blok için ayrı süre bilgisi'), findsNothing);\n  });\n\n"""
if insert_after not in text:
    raise SystemExit('annual compact test insertion point not found')
phase6_test = """  testWidgets('Faz 6 konum ile isteğe bağlı takibi birbirine karıştırmaz', (\n    tester,\n  ) async {\n    _phone(tester);\n    final tracking = MemoryOutcomeTrackingRepository();\n    await _pump(tester, tracking: tracking);\n\n    // Viewing a lesson creates continuity only; it is not teacher progress.\n    await tester.tap(find.text('Ders ayrıntısını aç'));\n    await tester.pumpAndSettle();\n    await tester.pageBack();\n    await tester.pumpAndSettle();\n\n    // An explicit teacher action creates optional tracking.\n    await tester.tap(find.byTooltip('Kazanım işlemleri'));\n    await tester.pumpAndSettle();\n    await tester.tap(find.text('İşlendi olarak işaretle'));\n    await tester.pumpAndSettle();\n\n    await _tapNavigation(tester, Icons.view_timeline_outlined);\n    await tester.pumpAndSettle();\n\n    expect(find.text('ŞU AN BURADASIN'), findsOneWidget);\n    expect(find.text('Öğretim sırası: 1. blok / 1'), findsOneWidget);\n    expect(\n      find.text('Bu konum bir ilerleme veya tamamlanma yüzdesi değildir.'),\n      findsOneWidget,\n    );\n    expect(find.byType(LinearProgressIndicator), findsNothing);\n    expect(find.text('İSTEĞE BAĞLI TAKİP'), findsOneWidget);\n    expect(find.text('İşlendi 1'), findsOneWidget);\n    expect(\n      find.textContaining('işaretlenmemiş kazanımlar eksik sayılmaz'),\n      findsOneWidget,\n    );\n    expect(find.textContaining('%'), findsNothing);\n  });\n\n"""
text = text.replace(insert_after, insert_after + phase6_test, 1)
path.write_text(text)
