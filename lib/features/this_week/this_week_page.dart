import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../lesson_plan/lesson_plan_panels.dart';
import '../outcomes/outcome_detail_page.dart';
import '../shared/feature_widgets.dart';
import '../shared/interaction_polish.dart';

class ThisWeekPage extends StatefulWidget {
  const ThisWeekPage({
    super.key,
    required this.repository,
    required this.service,
    this.topTrailing,
    this.lessonPlanProgress,
    this.onOutcomeViewed,
  });

  final CourseKnowledgeRepository repository;
  final OutcomePlanningService service;
  final Widget? topTrailing;
  final LessonPlanProgressRepository? lessonPlanProgress;
  final Future<void> Function(TrackedOutcome item)? onOutcomeViewed;

  @override
  State<ThisWeekPage> createState() => _ThisWeekPageState();
}

class _ThisWeekPageState extends State<ThisWeekPage> {
  late Future<AnnualOutcomePlan> _future;
  int? _selectedWeekNumber;

  @override
  void initState() {
    super.initState();
    _future = widget.service.buildPlan();
  }

  void _reload() {
    setState(() {
      _future = widget.service.buildPlan();
    });
  }

  Future<void> _chooseWeek(
    AnnualOutcomePlan plan,
    int selectedWeekNumber,
  ) async {
    final weekNumber = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _WeekPickerSheet(plan: plan, selectedWeekNumber: selectedWeekNumber),
    );
    if (weekNumber == null || !mounted) return;
    setState(() => _selectedWeekNumber = weekNumber);
  }

  Future<void> _setStatus(
    TrackedOutcome item,
    OutcomeTrackingStatus status, {
    bool completionHaptic = false,
  }) async {
    try {
      final before = await widget.service.captureTracking(item);
      await widget.service.setStatus(item, status);
      if (!mounted) return;
      if (completionHaptic) HapticFeedback.mediumImpact();
      _reload();
      showTeacherUndoFeedback(
        context,
        _statusChangeMessage(status),
        onUndo: () => _undoTracking(item, before),
      );
    } on Object {
      _showError();
    }
  }

  Future<void> _completeAll(WeeklyOutcomeSummary summary) async {
    final undoEntries = <_TrackingUndoEntry>[];
    try {
      for (final item in summary.outcomes) {
        if (_isCarriedOut(item)) continue;
        if (item.presentationStatus != OutcomeTrackingStatus.completed) {
          undoEntries.add(
            _TrackingUndoEntry(
              item: item,
              record: await widget.service.captureTracking(item),
            ),
          );
          await widget.service.setStatus(item, OutcomeTrackingStatus.completed);
        }
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _reload();
      showTeacherUndoFeedback(
        context,
        '${undoEntries.length} kazanım işlendi olarak işaretlendi.',
        onUndo: () => _undoMany(undoEntries),
      );
    } on Object {
      for (final entry in undoEntries.reversed) {
        try {
          await widget.service.restoreTracking(entry.item, entry.record);
        } on Object {
          // Best-effort rollback; the visible error below remains authoritative.
        }
      }
      _showError();
    }
  }

  Future<void> _openOutcome(AnnualOutcomePlan plan, TrackedOutcome item) async {
    final onOutcomeViewed = widget.onOutcomeViewed;
    if (onOutcomeViewed != null) {
      try {
        await onOutcomeViewed(item);
      } on Object {
        // Continuity is convenience state; it must never block lesson access.
      }
    }
    if (!mounted) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OutcomeDetailPage(
          repository: widget.repository,
          service: widget.service,
          initialPlan: plan,
          initialItem: item,
        ),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _editQuickNote(TrackedOutcome item) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuickNoteSheet(initialText: item.teacherNote ?? ''),
    );
    if (note == null) return;

    try {
      final before = await widget.service.captureTracking(item);
      await widget.service.saveTeacherNote(item, note);
      if (!mounted) return;
      _reload();
      showTeacherUndoFeedback(
        context,
        'Not kaydedildi.',
        onUndo: () => _undoTracking(item, before),
      );
    } on Object {
      _showError();
    }
  }

  Future<void> _carryToNextWeek(
    AnnualOutcomePlan plan,
    TrackedOutcome item,
  ) async {
    final target = _nextInstructionWeekNumber(plan, item);
    if (target == null) {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Taşınabilecek sonraki öğretim haftası yok.',
      );
      return;
    }

    try {
      final before = await widget.service.captureTracking(item);
      await widget.service.carryToWeek(
        item: item,
        targetWeekNumber: target,
        plan: plan,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _reload();
      showTeacherUndoFeedback(
        context,
        '$target. haftaya taşındı.',
        onUndo: () => _undoTracking(item, before),
      );
    } on Object {
      _showError();
    }
  }

  Future<void> _undoTracking(
    TrackedOutcome item,
    LearningOutcomeTrackingRecord? record,
  ) async {
    try {
      await widget.service.restoreTracking(
        item,
        record,
        displayWeekNumber: item.displayWeekNumber,
      );
      if (!mounted) return;
      _reload();
      showTeacherFeedback(context, 'Değişiklik geri alındı.');
    } on Object {
      _showError();
    }
  }

  Future<void> _undoMany(List<_TrackingUndoEntry> entries) async {
    try {
      for (final entry in entries) {
        await widget.service.restoreTracking(
          entry.item,
          entry.record,
          displayWeekNumber: entry.item.displayWeekNumber,
        );
      }
      if (!mounted) return;
      _reload();
      showTeacherFeedback(context, 'Toplu işlem geri alındı.');
    } on Object {
      _showError();
    }
  }

  Future<void> _handleOutcomeAction(
    AnnualOutcomePlan plan,
    TrackedOutcome item,
    _OutcomeAction action,
  ) async {
    switch (action) {
      case _OutcomeAction.inProgress:
        await _setStatus(item, OutcomeTrackingStatus.inProgress);
      case _OutcomeAction.completed:
        await _setStatus(
          item,
          OutcomeTrackingStatus.completed,
          completionHaptic: true,
        );
      case _OutcomeAction.partiallyCompleted:
        await _setStatus(item, OutcomeTrackingStatus.partiallyCompleted);
      case _OutcomeAction.planned:
        await _setStatus(item, OutcomeTrackingStatus.planned);
      case _OutcomeAction.carryNext:
        await _carryToNextWeek(plan, item);
      case _OutcomeAction.quickNote:
        await _editQuickNote(item);
    }
  }

  Future<void> _copyDiary(WeeklyOutcomeSummary summary) async {
    final themes = summary.week.segments
        .map((segment) => segment.theme.title)
        .toSet()
        .join(' · ');
    final blocks = summary.week.segments
        .where((segment) => segment.block != null)
        .map((segment) => segment.block!.title)
        .toSet()
        .join(' · ');
    final codes = summary.outcomes.map((item) => item.outcome.code).join(', ');
    final text = [
      if (themes.isNotEmpty) 'Tema: $themes',
      if (blocks.isNotEmpty) 'Blok: $blocks',
      if (codes.isNotEmpty) 'Kazanımlar: $codes',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showTeacherFeedback(context, 'Defter özeti kopyalandı.');
  }

  void _showError() {
    if (!mounted) return;
    showTeacherFeedback(
      context,
      'İşlem kaydedilemedi. Tekrar deneyin.',
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnnualOutcomePlan>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const LoadingView(label: 'Bu hafta hazırlanıyor…');
      }
      if (!snapshot.hasData) {
        return FeatureErrorView(
          message: 'Haftalık çalışma görünümü yüklenemedi.',
          onRetry: _reload,
        );
      }

      final plan = snapshot.data!;
      if (plan.weeks.isEmpty) {
        return const FeatureEmptyView(
          icon: Icons.calendar_month_outlined,
          title: 'Okul haftası bulunmuyor',
          message: 'Bu ders için gösterilebilir bir okul haftası henüz yok.',
        );
      }

      final defaultWeekNumber =
          plan.currentWeekNumber ?? plan.weeks.first.week.weekNumber;
      final selectedNumber = _selectedWeekNumber ?? defaultWeekNumber;
      final summary = plan.week(selectedNumber) ?? plan.weeks.first;
      final isCurrentWeek =
          plan.currentWeekNumber != null &&
          summary.week.weekNumber == plan.currentWeekNumber;
      final actionable = summary.outcomes
          .where(_isActionable)
          .toList(growable: false);
      final focus = _focusOutcome(actionable);
      final openOthers = actionable
          .where((item) => !identical(item, focus))
          .toList(growable: false);
      final carriedOut = summary.outcomes
          .where(_isCarriedOut)
          .toList(growable: false);
      final completed = summary.outcomes
          .where(
            (item) =>
                item.presentationStatus == OutcomeTrackingStatus.completed,
          )
          .toList(growable: false);
      final hasCompletable = summary.outcomes.any(
        (item) =>
            !_isCarriedOut(item) &&
            item.presentationStatus != OutcomeTrackingStatus.completed,
      );

      return AppPage(
        topTrailing: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (widget.topTrailing != null) widget.topTrailing!,
            TextButton.icon(
              onPressed: () => _chooseWeek(plan, summary.week.weekNumber),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Hafta değiştir'),
            ),
          ],
        ),
        onRefresh: () async {
          _reload();
          await _future;
        },
        children: [
          _FocusCard(
            summary: summary,
            academicYear: plan.academicYear,
            focus: focus,
            isCurrentWeek: isCurrentWeek,
            onReturnToCurrent: !isCurrentWeek && plan.currentWeekNumber != null
                ? () => setState(
                    () => _selectedWeekNumber = plan.currentWeekNumber,
                  )
                : null,
            onContinue: focus == null ? null : () => _openOutcome(plan, focus),
            canCarryNext: focus != null && _canCarryToNextWeek(plan, focus),
            onAction: focus == null
                ? null
                : (action) => _handleOutcomeAction(plan, focus, action),
          ),
          WeeklyLessonPlanPanel(
            repository: widget.repository,
            annualPlan: plan,
            weekNumber: summary.week.weekNumber,
            progressRepository: widget.lessonPlanProgress,
          ),
          if (summary.week.isEventWeek) ...[
            const SizedBox(height: AppSpacing.lg),
            const StatusPanel(
              icon: Icons.celebration_outlined,
              title: 'Etkinlik haftası',
              message: 'Bu hafta yeni program kazanımı planlanmıyor.',
              tone: StatusTone.positive,
            ),
          ] else if (summary.outcomes.isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const StatusPanel(
              icon: Icons.info_outline,
              title: 'Bu hafta kazanım yok',
              message:
                  'Bu hafta yalnız okul temelli planlama içeriyor olabilir.',
            ),
          ] else ...[
            if (openOthers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _OutcomeGroup(
                title: 'Bu haftanın diğerleri',
                subtitle: '${openOthers.length} kazanım',
                icon: Icons.list_alt_outlined,
                items: openOthers,
                onOpen: (item) => _openOutcome(plan, item),
                canCarryNext: (item) => _canCarryToNextWeek(plan, item),
                onAction: (item, action) =>
                    _handleOutcomeAction(plan, item, action),
              ),
            ],
            if (carriedOut.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _OutcomeGroup(
                title: 'Sonraki haftaya taşınanlar',
                subtitle: '${carriedOut.length} kazanım',
                icon: Icons.redo_outlined,
                items: carriedOut,
                onOpen: (item) => _openOutcome(plan, item),
                canCarryNext: (_) => false,
                onAction: (item, action) =>
                    _handleOutcomeAction(plan, item, action),
              ),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _OutcomeGroup(
                title: 'İşlendi olarak işaretlenenler',
                subtitle: '${completed.length} kazanım',
                icon: Icons.check_circle_outline,
                items: completed,
                onOpen: (item) => _openOutcome(plan, item),
                canCarryNext: (_) => false,
                onAction: (item, action) =>
                    _handleOutcomeAction(plan, item, action),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _WeeklyTools(
              summary: summary,
              onCopyDiary: () => _copyDiary(summary),
              onCompleteAll: hasCompletable
                  ? () => _completeAll(summary)
                  : null,
            ),
          ],
        ],
      );
    },
  );
}

class _WeekPickerSheet extends StatelessWidget {
  const _WeekPickerSheet({
    required this.plan,
    required this.selectedWeekNumber,
  });

  final AnnualOutcomePlan plan;
  final int selectedWeekNumber;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.8,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Haftaya git',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.lg,
            ),
            itemCount: plan.weeks.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final summary = plan.weeks[index];
              final week = summary.week;
              final isSelected = week.weekNumber == selectedWeekNumber;
              final isCurrent = week.weekNumber == plan.currentWeekNumber;
              return ListTile(
                selected: isSelected,
                leading: Icon(
                  isCurrent ? Icons.today : Icons.calendar_today_outlined,
                ),
                title: Text(
                  week.isEventWeek ? week.label : '${week.weekNumber}. Hafta',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    _dateRange(week.start, week.end),
                    if (isCurrent) 'Bu hafta',
                  ].join(' · '),
                ),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, week.weekNumber),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.summary,
    required this.academicYear,
    required this.focus,
    required this.isCurrentWeek,
    required this.onReturnToCurrent,
    required this.onContinue,
    required this.canCarryNext,
    required this.onAction,
  });

  final WeeklyOutcomeSummary summary;
  final String academicYear;
  final TrackedOutcome? focus;
  final bool isCurrentWeek;
  final VoidCallback? onReturnToCurrent;
  final VoidCallback? onContinue;
  final bool canCarryNext;
  final ValueChanged<_OutcomeAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final week = summary.week;
    final segment = _primarySegment(week);
    final blockTitle =
        segment?.block?.title ??
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
                  if (_hasVisibleTrackingStatus(focus!))
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
                  Icon(
                    Icons.check_circle_outline,
                    color: scheme.onPrimaryContainer,
                  ),
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

class _OutcomeGroup extends StatelessWidget {
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
          if (index != items.length - 1) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    ),
  );
}

class _WeeklyTools extends StatelessWidget {
  const _WeeklyTools({
    required this.summary,
    required this.onCopyDiary,
    required this.onCompleteAll,
  });

  final WeeklyOutcomeSummary summary;
  final VoidCallback onCopyDiary;
  final VoidCallback? onCompleteAll;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const Icon(Icons.more_horiz),
      title: const Text(
        'Haftalık araçlar',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: const Text('Defter ve isteğe bağlı takip'),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: summary.outcomes.isEmpty ? null : onCopyDiary,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Deftere kopyala'),
              ),
              FilledButton.tonalIcon(
                onPressed: onCompleteAll,
                icon: const Icon(Icons.done_all),
                label: const Text('Tümünü işlendi olarak işaretle'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OutcomeRow extends StatelessWidget {
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
                  if (_hasVisibleTrackingStatus(item)) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _displayStatusLabel(item),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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

class _OutcomeActionMenu extends StatelessWidget {
  const _OutcomeActionMenu({
    required this.item,
    required this.canCarryNext,
    required this.onSelected,
  });

  final TrackedOutcome item;
  final bool canCarryNext;
  final ValueChanged<_OutcomeAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final status = item.presentationStatus;
    final carriedOut = _isCarriedOut(item);
    return PopupMenuButton<_OutcomeAction>(
      tooltip: 'Kazanım işlemleri',
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (!carriedOut && status == OutcomeTrackingStatus.planned)
          const PopupMenuItem(
            value: _OutcomeAction.inProgress,
            child: _ActionMenuItem(
              icon: Icons.play_circle_outline,
              label: 'Devam ediyor olarak işaretle',
            ),
          ),
        if (!carriedOut && status != OutcomeTrackingStatus.completed)
          const PopupMenuItem(
            value: _OutcomeAction.completed,
            child: _ActionMenuItem(
              icon: Icons.check_circle_outline,
              label: 'İşlendi olarak işaretle',
            ),
          ),
        if (!carriedOut &&
            status != OutcomeTrackingStatus.completed &&
            status != OutcomeTrackingStatus.partiallyCompleted)
          const PopupMenuItem(
            value: _OutcomeAction.partiallyCompleted,
            child: _ActionMenuItem(
              icon: Icons.timelapse_outlined,
              label: 'Kısmen işlendi',
            ),
          ),
        if (!carriedOut && status == OutcomeTrackingStatus.partiallyCompleted)
          const PopupMenuItem(
            value: _OutcomeAction.inProgress,
            child: _ActionMenuItem(
              icon: Icons.play_circle_outline,
              label: 'Devam ediyor',
            ),
          ),
        if (status != OutcomeTrackingStatus.planned)
          const PopupMenuItem(
            value: _OutcomeAction.planned,
            child: _ActionMenuItem(
              icon: Icons.restart_alt,
              label: 'Takip durumunu temizle',
            ),
          ),
        if (canCarryNext)
          const PopupMenuItem(
            value: _OutcomeAction.carryNext,
            child: _ActionMenuItem(
              icon: Icons.redo_outlined,
              label: 'Gelecek haftaya taşı',
            ),
          ),
        const PopupMenuItem(
          value: _OutcomeAction.quickNote,
          child: _ActionMenuItem(
            icon: Icons.sticky_note_2_outlined,
            label: 'Hızlı not',
          ),
        ),
      ],
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.item});

  final TrackedOutcome item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _displayStatusLabel(item),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuickNoteSheet extends StatefulWidget {
  const _QuickNoteSheet({required this.initialText});

  final String initialText;

  @override
  State<_QuickNoteSheet> createState() => _QuickNoteSheetState();
}

class _QuickNoteSheetState extends State<_QuickNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Hızlı not',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Kapat',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: 'Örn. son etkinlik gelecek derste tamamlanacak',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Boş kaydedersen mevcut not silinir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _controller.text),
          icon: const Icon(Icons.check),
          label: const Text('Kaydet'),
        ),
      ],
    ),
  );
}

class _TrackingUndoEntry {
  const _TrackingUndoEntry({required this.item, required this.record});

  final TrackedOutcome item;
  final LearningOutcomeTrackingRecord? record;
}

enum _OutcomeAction {
  inProgress,
  completed,
  partiallyCompleted,
  planned,
  carryNext,
  quickNote,
}

TrackedOutcome? _focusOutcome(List<TrackedOutcome> outcomes) {
  for (final status in const [
    OutcomeTrackingStatus.inProgress,
    OutcomeTrackingStatus.partiallyCompleted,
    OutcomeTrackingStatus.carriedOver,
    OutcomeTrackingStatus.planned,
  ]) {
    for (final item in outcomes) {
      if (item.presentationStatus == status) return item;
    }
  }
  return null;
}

bool _isCarriedOut(TrackedOutcome item) =>
    !item.isCarriedIn && item.carriedToWeekNumber != null;

bool _isActionable(TrackedOutcome item) =>
    item.presentationStatus != OutcomeTrackingStatus.completed &&
    !_isCarriedOut(item);

bool _canCarryToNextWeek(AnnualOutcomePlan plan, TrackedOutcome item) =>
    !_isCarriedOut(item) && _nextInstructionWeekNumber(plan, item) != null;

int? _nextInstructionWeekNumber(AnnualOutcomePlan plan, TrackedOutcome item) {
  for (final summary in plan.weeks) {
    if (summary.week.weekNumber > item.displayWeekNumber &&
        !summary.week.isEventWeek) {
      return summary.week.weekNumber;
    }
  }
  return null;
}

String _statusChangeMessage(OutcomeTrackingStatus status) => switch (status) {
  OutcomeTrackingStatus.planned => 'Takip durumu temizlendi.',
  OutcomeTrackingStatus.inProgress => 'Devam ediyor olarak işaretlendi.',
  OutcomeTrackingStatus.completed => 'İşlendi olarak işaretlendi.',
  OutcomeTrackingStatus.partiallyCompleted =>
    'Kısmen işlendi olarak işaretlendi.',
  OutcomeTrackingStatus.carriedOver => 'Taşındı olarak işaretlendi.',
};

bool _hasVisibleTrackingStatus(TrackedOutcome item) =>
    item.isCarriedIn ||
    _isCarriedOut(item) ||
    item.presentationStatus != OutcomeTrackingStatus.planned;

String _displayStatusLabel(TrackedOutcome item) {
  final label = _statusLabel(item);
  if (item.isCarriedIn || _isCarriedOut(item)) return label;
  return 'Takip: $label';
}

String _statusLabel(TrackedOutcome item) {
  if (item.isCarriedIn) return 'Geçen haftadan';
  if (_isCarriedOut(item)) return 'Sonraki haftaya taşındı';
  return switch (item.presentationStatus) {
    OutcomeTrackingStatus.planned => 'Planlı',
    OutcomeTrackingStatus.inProgress => 'Devam ediyor',
    OutcomeTrackingStatus.completed => 'İşlendi',
    OutcomeTrackingStatus.partiallyCompleted => 'Kısmen işlendi',
    OutcomeTrackingStatus.carriedOver => 'Taşındı',
  };
}

IconData _statusIcon(TrackedOutcome item) {
  if (item.isCarriedIn || _isCarriedOut(item)) return Icons.redo_outlined;
  return switch (item.presentationStatus) {
    OutcomeTrackingStatus.planned => Icons.article_outlined,
    OutcomeTrackingStatus.inProgress => Icons.play_circle_outline,
    OutcomeTrackingStatus.completed => Icons.check_circle,
    OutcomeTrackingStatus.partiallyCompleted => Icons.timelapse_outlined,
    OutcomeTrackingStatus.carriedOver => Icons.redo_outlined,
  };
}

WeeklyPlanSegment? _primarySegment(AcademicWeekPlan week) {
  for (final segment in week.segments) {
    if (segment.block != null) return segment;
  }
  return week.segments.isEmpty ? null : week.segments.first;
}

String _dateRange(DateTime start, DateTime end) =>
    '${start.day} ${_month(start.month)} - ${end.day} ${_month(end.month)} ${end.year}';

String _month(int month) => switch (month) {
  1 => 'Ocak',
  2 => 'Şubat',
  3 => 'Mart',
  4 => 'Nisan',
  5 => 'Mayıs',
  6 => 'Haziran',
  7 => 'Temmuz',
  8 => 'Ağustos',
  9 => 'Eylül',
  10 => 'Ekim',
  11 => 'Kasım',
  12 => 'Aralık',
  _ => '',
};
