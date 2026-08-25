from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def sub(path: str, pattern: str, replacement: str, *, count: int = 1) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    updated, n = re.subn(pattern, replacement, text, count=count, flags=re.S)
    if n != count:
        raise SystemExit(f"{path}: expected {count} replacement(s), got {n}: {pattern[:80]}")
    file.write_text(updated, encoding="utf-8")


def replace(path: str, old: str, new: str, *, count: int = 1) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    actual = text.count(old)
    if actual < count:
        raise SystemExit(f"{path}: expected at least {count} occurrence(s), got {actual}: {old[:80]}")
    file.write_text(text.replace(old, new, count), encoding="utf-8")


weekly = "lib/features/this_week/this_week_page.dart"

# Tracking is no longer the primary weekly workflow.
sub(
    weekly,
    r"\n  Future<void> _runPrimaryAction\(TrackedOutcome item\) async \{.*?\n  \}\n\n  Future<void> _completeAll",
    "\n\n  Future<void> _completeAll",
)

replace(
    weekly,
    """      case _OutcomeAction.inProgress:\n        await _setStatus(item, OutcomeTrackingStatus.inProgress);\n      case _OutcomeAction.partiallyCompleted:""",
    """      case _OutcomeAction.inProgress:\n        await _setStatus(item, OutcomeTrackingStatus.inProgress);\n      case _OutcomeAction.completed:\n        await _setStatus(\n          item,\n          OutcomeTrackingStatus.completed,\n          completionHaptic: true,\n        );\n      case _OutcomeAction.partiallyCompleted:""",
)

# Merge the duplicate weekly focus surfaces into the single ŞİMDİ card.
replace(
    weekly,
    """          _FocusCard(\n            summary: summary,\n            academicYear: plan.academicYear,\n            focus: focus,\n            isCurrentWeek: isCurrentWeek,\n            onChooseWeek: () => _chooseWeek(plan, summary.week.weekNumber),\n            onReturnToCurrent: !isCurrentWeek && plan.currentWeekNumber != null\n                ? () => setState(\n                    () => _selectedWeekNumber = plan.currentWeekNumber,\n                  )\n                : null,\n            onContinue: focus == null ? null : () => _openOutcome(plan, focus),\n            continueLabel: isCurrentWeek ? 'Derse devam et' : 'Kazanımı aç',\n          ),""",
    """          _FocusCard(\n            summary: summary,\n            academicYear: plan.academicYear,\n            focus: focus,\n            isCurrentWeek: isCurrentWeek,\n            onChooseWeek: () => _chooseWeek(plan, summary.week.weekNumber),\n            onReturnToCurrent: !isCurrentWeek && plan.currentWeekNumber != null\n                ? () => setState(\n                    () => _selectedWeekNumber = plan.currentWeekNumber,\n                  )\n                : null,\n            onContinue: focus == null ? null : () => _openOutcome(plan, focus),\n            canCarryNext: focus != null && _canCarryToNextWeek(plan, focus),\n            onAction: focus == null\n                ? null\n                : (action) => _handleOutcomeAction(plan, focus, action),\n          ),""",
)

sub(
    weekly,
    r"          \] else \.\.\.\[\n            SectionHeading\(.*?\n            if \(openOthers\.isNotEmpty\) \.\.\.\[",
    """          ] else ...[\n            if (openOthers.isNotEmpty) ...[""",
)

replace(
    weekly,
    """                onOpen: (item) => _openOutcome(plan, item),\n                onPrimary: _runPrimaryAction,\n                canCarryNext: (item) => _canCarryToNextWeek(plan, item),""",
    """                onOpen: (item) => _openOutcome(plan, item),\n                canCarryNext: (item) => _canCarryToNextWeek(plan, item),""",
)
replace(
    weekly,
    """                onOpen: (item) => _openOutcome(plan, item),\n                onPrimary: null,\n                canCarryNext: (_) => false,""",
    """                onOpen: (item) => _openOutcome(plan, item),\n                canCarryNext: (_) => false,""",
    count=2,
)

# Single dominant weekly focus card: lesson context + one detail CTA + optional tracking menu.
sub(
    weekly,
    r"class _FocusCard extends StatelessWidget \{.*?\n\}\n\nclass _FocusOutcomeCard extends StatelessWidget \{.*?\n\}\n\nclass _OutcomeGroup",
    r'''class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.summary,
    required this.academicYear,
    required this.focus,
    required this.isCurrentWeek,
    required this.onChooseWeek,
    required this.onReturnToCurrent,
    required this.onContinue,
    required this.canCarryNext,
    required this.onAction,
  });

  final WeeklyOutcomeSummary summary;
  final String academicYear;
  final TrackedOutcome? focus;
  final bool isCurrentWeek;
  final VoidCallback onChooseWeek;
  final VoidCallback? onReturnToCurrent;
  final VoidCallback? onContinue;
  final bool canCarryNext;
  final ValueChanged<_OutcomeAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final week = summary.week;
    final segment = _primarySegment(week);
    final blockTitle = segment?.block?.title ??
        (segment == null ? 'Ders akışı' : 'Okul temelli planlama');
    final themeTitle = segment?.theme.title;
    final total = summary.outcomes.length;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  isCurrentWeek ? 'ŞİMDİ' : 'İNCELEDİĞİN HAFTA',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                TextButton.icon(
                  onPressed: onChooseWeek,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Hafta değiştir'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              week.isEventWeek ? week.label : '${week.weekNumber}. Hafta',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$academicYear · ${_dateRange(week.start, week.end)} · ${week.plannedLessonHours} ders saati',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (onReturnToCurrent != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onReturnToCurrent,
                icon: const Icon(Icons.today),
                label: const Text('Bu haftaya dön'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onPrimaryContainer,
                  side: BorderSide(color: scheme.onPrimaryContainer),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              blockTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (themeTitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                themeTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
            if (focus != null) ...[
              const Divider(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    focus!.outcome.code,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _StatusBadge(item: focus!),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                focus!.outcome.officialText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  height: 1.45,
                ),
              ),
              if (focus!.teacherNote?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        focus!.teacherNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Ders ayrıntısını aç'),
                  ),
                  if (onAction != null)
                    _OutcomeActionMenu(
                      item: focus!,
                      canCarryNext: canCarryNext,
                      onSelected: onAction!,
                    ),
                ],
              ),
            ] else if (!week.isEventWeek && total > 0) ...[
              const Divider(height: AppSpacing.xl),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: scheme.onPrimaryContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Bu haftada açık kazanım kalmadı.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutcomeGroup''',
)

# Secondary outcome groups open details on row tap; tracking lives only in overflow.
sub(
    weekly,
    r"class _OutcomeGroup extends StatelessWidget \{.*?\n\}\n\nclass _WeeklyTools",
    r'''class _OutcomeGroup extends StatelessWidget {
  const _OutcomeGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.onOpen,
    required this.canCarryNext,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<TrackedOutcome> items;
  final ValueChanged<TrackedOutcome> onOpen;
  final bool Function(TrackedOutcome) canCarryNext;
  final void Function(TrackedOutcome, _OutcomeAction) onAction;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _OutcomeRow(
            item: items[index],
            onOpen: () => onOpen(items[index]),
            canCarryNext: canCarryNext(items[index]),
            onAction: (action) => onAction(items[index], action),
          ),
          if (index != items.length - 1)
            const SizedBox(height: AppSpacing.xs),
        ],
      ],
    ),
  );
}

class _WeeklyTools''',
)

sub(
    weekly,
    r"class _OutcomeRow extends StatelessWidget \{.*?\n\}\n\nclass _OutcomeActionMenu",
    r'''class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.item,
    required this.onOpen,
    required this.canCarryNext,
    required this.onAction,
  });

  final TrackedOutcome item;
  final VoidCallback onOpen;
  final bool canCarryNext;
  final ValueChanged<_OutcomeAction> onAction;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                _statusIcon(item),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.outcome.code,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.outcome.officialText),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _statusLabel(item),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.teacherNote?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.teacherNote!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _OutcomeActionMenu(
              item: item,
              canCarryNext: canCarryNext,
              onSelected: onAction,
            ),
          ],
        ),
      ),
    ),
  );
}

class _OutcomeActionMenu''',
)

# Optional tracking options are complete and explicit in the overflow menu.
replace(
    weekly,
    """      itemBuilder: (context) => [\n        if (!carriedOut &&\n            status != OutcomeTrackingStatus.completed &&\n            status != OutcomeTrackingStatus.partiallyCompleted)""",
    """      itemBuilder: (context) => [\n        if (!carriedOut && status == OutcomeTrackingStatus.planned)\n          const PopupMenuItem(\n            value: _OutcomeAction.inProgress,\n            child: _ActionMenuItem(\n              icon: Icons.play_circle_outline,\n              label: 'Devam ediyor olarak işaretle',\n            ),\n          ),\n        if (!carriedOut && status != OutcomeTrackingStatus.completed)\n          const PopupMenuItem(\n            value: _OutcomeAction.completed,\n            child: _ActionMenuItem(\n              icon: Icons.check_circle_outline,\n              label: 'İşlendi olarak işaretle',\n            ),\n          ),\n        if (!carriedOut &&\n            status != OutcomeTrackingStatus.completed &&\n            status != OutcomeTrackingStatus.partiallyCompleted)""",
)

replace(
    weekly,
    """enum _OutcomeAction {\n  inProgress,\n  partiallyCompleted,""",
    """enum _OutcomeAction {\n  inProgress,\n  completed,\n  partiallyCompleted,""",
)

sub(
    weekly,
    r"\nString _primaryActionLabel\(TrackedOutcome item\).*?\n\nString _statusChangeMessage",
    "\nString _statusChangeMessage",
)

# Update the main widget regression tests to the optional-tracking contract.
widget_test = "test/widget_test.dart"
sub(
    widget_test,
    r"  testWidgets\('ana deneyim Başla ve İşlendi akışını tek odakta yürütür'.*?(?=\n  testWidgets\('başka hafta)",
    r'''  testWidgets('ana deneyim tracking gerektirmeden tek odakta yürür', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    expect(find.text('Bu Hafta'), findsWidgets);
    expect(find.text('ŞİMDİ'), findsOneWidget);
    expect(find.text('Sıradaki'), findsNothing);
    expect(find.text('Ders ayrıntısını aç'), findsOneWidget);
    expect(find.text('Hafta değiştir'), findsOneWidget);
    expect(find.text('1. Hafta'), findsOneWidget);
    expect(find.text('TEST.1'), findsOneWidget);
    expect(find.text('TEST.2'), findsNothing);
    expect(find.text('TEST.3'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Başla'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);
    expect(await tracking.getForAcademicYear('2026-2027'), isEmpty);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    expect(find.text('Devam ediyor olarak işaretle'), findsOneWidget);
    expect(find.text('İşlendi olarak işaretle'), findsOneWidget);
    expect(find.text('Kısmen işlendi'), findsOneWidget);

    await tester.tap(find.text('İşlendi olarak işaretle'));
    await tester.pumpAndSettle();

    final records = await tracking.getForAcademicYear('2026-2027');
    expect(records, hasLength(1));
    expect(records.single.status.storageValue, 'completed');
    expect(find.text('TEST.2'), findsOneWidget);
    expect(find.text('Ders ayrıntısını aç'), findsOneWidget);
  });
''',
)

# The week browser keeps the same dominant detail CTA regardless of selected week.
widget_path = ROOT / widget_test
text = widget_path.read_text(encoding="utf-8")
text = text.replace("'Derse devam et'", "'Ders ayrıntısını aç'")
widget_path.write_text(text, encoding="utf-8")

sub(
    widget_test,
    r"  testWidgets\('tamamlanan kazanımlar varsayılan olarak geri planda kalır'.*?(?=\n  testWidgets\('hızlı not)",
    r'''  testWidgets('tamamlanan kazanımlar varsayılan olarak geri planda kalır', (
    tester,
  ) async {
    _phone(tester);
    final tracking = MemoryOutcomeTrackingRepository();
    await _pump(tester, tracking: tracking);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşlendi olarak işaretle'));
    await tester.pumpAndSettle();

    expect(find.text('TEST.1'), findsNothing);

    final completedGroup = find.text('Tamamlananlar');
    await tester.scrollUntilVisible(
      completedGroup,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(completedGroup, findsOneWidget);

    await tester.tap(completedGroup);
    await tester.pumpAndSettle();

    expect(find.text('TEST.1'), findsOneWidget);
  });
''',
)

replace(
    widget_test,
    """    expect(find.text('Kısmen işlendi'), findsOneWidget);\n    expect(find.text('İşlendi'), findsOneWidget);""",
    """    expect(find.text('Kısmen işlendi'), findsOneWidget);\n    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);""",
)

# Faz 0 still protects a real consequential tracking action with Undo.
sub(
    "test/adhd_phase0_ux_test.dart",
    r"    final start = find\.widgetWithText\(FilledButton, 'Başla'\);.*?expect\(tester\.takeException\(\), isNull\);",
    r'''    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşlendi olarak işaretle'));
    await tester.pumpAndSettle();

    expect(find.text('İşlendi olarak işaretlendi.'), findsOneWidget);
    expect(find.text('Geri al'), findsOneWidget);

    var plan = await service.buildPlan();
    expect(
      plan.week(1)!.outcomes.single.status,
      OutcomeTrackingStatus.completed,
    );

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    plan = await service.buildPlan();
    expect(plan.week(1)!.outcomes.single.status, OutcomeTrackingStatus.planned);
    expect(find.text('Değişiklik geri alındı.'), findsOneWidget);
    expect(tester.takeException(), isNull);''',
)

# Faz 1 acceptance: weekly use works without status mutation; tracking is clearly secondary.
sub(
    "test/adhd_phase1_action_density_test.dart",
    r"  testWidgets\('odak akışı tek ana eylem gösterir ve takip seçenekleri tekrar etmez'.*?(?=\n\}\n\nclass _WeeklyPlanning)",
    r'''  testWidgets('odak akışı tracking gerektirmeden tek ŞİMDİ kartında yürür', (
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

    expect(find.text('ŞİMDİ'), findsOneWidget);
    expect(find.text('Sıradaki'), findsNothing);
    expect(find.text('TEST.1'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ders ayrıntısını aç'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Başla'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);

    await tester.tap(find.byTooltip('Kazanım işlemleri'));
    await tester.pumpAndSettle();
    expect(find.text('Devam ediyor olarak işaretle'), findsOneWidget);
    expect(find.text('İşlendi olarak işaretle'), findsOneWidget);
    expect(find.text('Kısmen işlendi'), findsOneWidget);
    expect(find.text('Gelecek haftaya taşı'), findsNothing);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Ders ayrıntısını aç'));
    await tester.pumpAndSettle();

    expect(find.text('Derste lazım'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Başla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
''',
)

print("ADHD Phase 1 focus patch applied")
