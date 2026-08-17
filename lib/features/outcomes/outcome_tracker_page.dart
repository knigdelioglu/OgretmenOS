import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../shared/feature_widgets.dart';
import 'outcome_detail_page.dart';
import 'outcome_presentation.dart';

enum _OutcomeFilter { all, open, completed, carried }

enum _OutcomeAction { inProgress, partial, carry, reset }

class OutcomeTrackerPage extends StatefulWidget {
  const OutcomeTrackerPage({
    super.key,
    required this.repository,
    required this.service,
  });

  final CourseKnowledgeRepository repository;
  final OutcomePlanningService service;

  @override
  State<OutcomeTrackerPage> createState() => _OutcomeTrackerPageState();
}

class _OutcomeTrackerPageState extends State<OutcomeTrackerPage> {
  late Future<AnnualOutcomePlan> _future;
  int? _selectedWeekNumber;
  _OutcomeFilter _filter = _OutcomeFilter.all;

  @override
  void initState() {
    super.initState();
    _future = widget.service.buildPlan();
  }

  void _reload() {
    setState(() => _future = widget.service.buildPlan());
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    bool strongFeedback = false,
  }) async {
    try {
      await action();
      if (!mounted) return;
      if (strongFeedback) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
      if (!mounted) return;
      _reload();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Değişiklik kaydedilemedi: $error')),
      );
    }
  }

  void _selectWeek(AnnualOutcomePlan plan, int number) {
    final current = _selectedWeekNumber ??
        plan.currentWeekNumber ??
        plan.weeks.first.week.weekNumber;
    if (current == number || plan.week(number) == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedWeekNumber = number;
      _filter = _OutcomeFilter.all;
    });
  }

  void _moveWeek(AnnualOutcomePlan plan, int selectedWeekNumber, int delta) {
    final index = plan.weeks.indexWhere(
      (item) => item.week.weekNumber == selectedWeekNumber,
    );
    final targetIndex = index + delta;
    if (index < 0 || targetIndex < 0 || targetIndex >= plan.weeks.length) return;
    _selectWeek(plan, plan.weeks[targetIndex].week.weekNumber);
  }

  void _handleHorizontalSwipe(
    AnnualOutcomePlan plan,
    int selectedWeekNumber,
    DragEndDetails details,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 280) return;
    _moveWeek(plan, selectedWeekNumber, velocity < 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnnualOutcomePlan>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView(label: 'Haftanın kazanımları hazırlanıyor…');
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Kazanım takip görünümü yüklenemedi.',
          onRetry: _reload,
        );
      }

      final plan = snapshot.data!;
      if (plan.weeks.isEmpty) {
        return const Center(
          child: UnresolvedText(label: 'Gösterilebilir okul haftası bulunmuyor.'),
        );
      }
      final selectedNumber = _selectedWeekNumber ??
          plan.currentWeekNumber ??
          plan.weeks.first.week.weekNumber;
      final summary = plan.week(selectedNumber) ?? plan.weeks.first;
      final visibleOutcomes = _applyFilter(summary.outcomes);

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) =>
            _handleHorizontalSwipe(plan, summary.week.weekNumber, details),
        child: AppPage(
          onRefresh: () async {
            _reload();
            await _future;
          },
          children: [
            PageHeader(
              eyebrow: plan.academicYear,
              title: 'Kazanım Takibi',
              description:
                  'Derse girerken bu haftanın kazanımlarına bakın, işlenme durumunu takip edin ve defter için doğrulanmış programa tek yerden ulaşın.',
            ),
            _WeekNavigator(
              plan: plan,
              selectedWeekNumber: summary.week.weekNumber,
              onChanged: (number) => _selectWeek(plan, number),
              onPrevious: () => _moveWeek(plan, summary.week.weekNumber, -1),
              onNext: () => _moveWeek(plan, summary.week.weekNumber, 1),
              onCurrent: plan.currentWeekNumber != null &&
                      plan.currentWeekNumber != summary.week.weekNumber
                  ? () => _selectWeek(plan, plan.currentWeekNumber!)
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            _WeekHero(summary: summary),
            if (summary.week.isEventWeek)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: StatusPanel(
                  icon: Icons.celebration_outlined,
                  title: 'Etkinlik Haftası',
                  message:
                      'Bu hafta yeni program kazanımı atanmaz. 180 saatlik TDE 9 öğretim bütçesi önceki 36 öğretim haftasında tamamlanmıştır.',
                  tone: StatusTone.positive,
                ),
              )
            else ...[
              const SizedBox(height: AppSpacing.lg),
              _SummaryMetrics(summary: summary),
              const SectionHeading(
                'Deftere Bakış',
                subtitle:
                    'Tema, blok ve resmî kazanım metinlerinden oluşan kopyalanabilir haftalık özet',
                icon: Icons.menu_book_outlined,
              ),
              _DiaryGlance(summary: summary),
              SectionHeading(
                'Bu haftanın kazanımları',
                subtitle:
                    '${summary.outcomes.length} kazanım · Planlanan program ile öğretmen takip durumu ayrı tutulur.',
                icon: Icons.flag_outlined,
              ),
              _FilterBar(
                summary: summary,
                selected: _filter,
                onChanged: (filter) {
                  if (_filter == filter) return;
                  HapticFeedback.selectionClick();
                  setState(() => _filter = filter);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (visibleOutcomes.isEmpty)
                const StatusPanel(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Bu filtrede kazanım yok',
                  message: 'Başka bir filtre seçerek haftanın diğer kazanımlarını görün.',
                )
              else
                for (var index = 0; index < visibleOutcomes.length; index++) ...[
                  _OutcomeCard(
                    key: ValueKey(
                      '${visibleOutcomes[index].trackingKey}:${visibleOutcomes[index].displayWeekNumber}',
                    ),
                    item: visibleOutcomes[index],
                    relatedBlockHours: _relatedBlockHours(
                      summary,
                      visibleOutcomes[index],
                    ),
                    onOpen: () => _openDetail(plan, visibleOutcomes[index]),
                    onComplete: () => _runMutation(
                      () => widget.service.setStatus(
                        visibleOutcomes[index],
                        OutcomeTrackingStatus.completed,
                      ),
                      strongFeedback: true,
                    ),
                    onNote: () => _editTeacherNote(visibleOutcomes[index]),
                    onAction: (action) =>
                        _handleAction(plan, visibleOutcomes[index], action),
                  ),
                  if (index != visibleOutcomes.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
            ],
          ],
        ),
      );
    },
  );

  int _relatedBlockHours(WeeklyOutcomeSummary summary, TrackedOutcome item) {
    final blockIds = item.contexts.map((context) => context.block.id).toSet();
    if (blockIds.isEmpty) return 0;
    return summary.week.segments
        .where(
          (segment) =>
              segment.type == WeeklyPlanSegmentType.block &&
              segment.block != null &&
              blockIds.contains(segment.block!.id),
        )
        .fold(0, (total, segment) => total + segment.hours);
  }

  List<TrackedOutcome> _applyFilter(List<TrackedOutcome> items) => switch (_filter) {
    _OutcomeFilter.all => items,
    _OutcomeFilter.open => items
        .where((item) => item.presentationStatus != OutcomeTrackingStatus.completed)
        .toList(growable: false),
    _OutcomeFilter.completed => items
        .where((item) => item.presentationStatus == OutcomeTrackingStatus.completed)
        .toList(growable: false),
    _OutcomeFilter.carried => items
        .where(
          (item) =>
              item.isCarriedIn ||
              item.carriedToWeekNumber != null ||
              item.presentationStatus == OutcomeTrackingStatus.carriedOver,
        )
        .toList(growable: false),
  };

  Future<void> _openDetail(AnnualOutcomePlan plan, TrackedOutcome item) async {
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

  Future<void> _editTeacherNote(TrackedOutcome item) async {
    final controller = TextEditingController(text: item.teacherNote ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Öğretmen notu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: 'Bu kazanım için kısa bir ders notu…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (item.teacherNote?.isNotEmpty == true)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Notu sil'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await _runMutation(() => widget.service.saveTeacherNote(item, result));
  }

  Future<void> _handleAction(
    AnnualOutcomePlan plan,
    TrackedOutcome item,
    _OutcomeAction action,
  ) async {
    switch (action) {
      case _OutcomeAction.inProgress:
        await _runMutation(
          () => widget.service.setStatus(item, OutcomeTrackingStatus.inProgress),
        );
        return;
      case _OutcomeAction.partial:
        await _runMutation(
          () => widget.service.setStatus(
            item,
            OutcomeTrackingStatus.partiallyCompleted,
          ),
        );
        return;
      case _OutcomeAction.carry:
        final target = await _pickCarryWeek(plan, item);
        if (target == null) return;
        await _runMutation(
          () => widget.service.carryToWeek(
            item: item,
            targetWeekNumber: target,
            plan: plan,
          ),
        );
        return;
      case _OutcomeAction.reset:
        await _runMutation(() => widget.service.resetTracking(item));
        return;
    }
  }

  Future<int?> _pickCarryWeek(AnnualOutcomePlan plan, TrackedOutcome item) {
    final targets = plan.weeks
        .where(
          (summary) =>
              !summary.week.isEventWeek &&
              summary.week.weekNumber > item.plannedWeekNumber,
        )
        .toList(growable: false);
    if (targets.isEmpty) return Future.value(null);
    var selected = targets.first.week.weekNumber;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sonraki haftaya taşı'),
          content: DropdownButtonFormField<int>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Hedef öğretim haftası'),
            items: [
              for (final summary in targets)
                DropdownMenuItem<int>(
                  value: summary.week.weekNumber,
                  child: Text(
                    '${summary.week.weekNumber}. Hafta · ${outcomeDateRange(summary.week.start, summary.week.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Taşı'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.plan,
    required this.selectedWeekNumber,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    this.onCurrent,
  });

  final AnnualOutcomePlan plan;
  final int selectedWeekNumber;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onCurrent;

  @override
  Widget build(BuildContext context) {
    final index = plan.weeks.indexWhere(
      (item) => item.week.weekNumber == selectedWeekNumber,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Önceki hafta',
                  onPressed: index > 0 ? onPrevious : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(selectedWeekNumber),
                    initialValue: selectedWeekNumber,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Okul haftası',
                      isDense: true,
                    ),
                    items: [
                      for (final summary in plan.weeks)
                        DropdownMenuItem<int>(
                          value: summary.week.weekNumber,
                          child: Text(
                            '${summary.week.weekNumber}. Hafta · ${outcomeDateRange(summary.week.start, summary.week.end)}${summary.week.isEventWeek ? ' · Etkinlik' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onChanged(value);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Sonraki hafta',
                  onPressed: index >= 0 && index < plan.weeks.length - 1
                      ? onNext
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Haftayı değiştirmek için sağa veya sola kaydırabilirsiniz.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (onCurrent != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: onCurrent,
                    icon: const Icon(Icons.today_outlined, size: 18),
                    label: const Text('Bu haftaya dön'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.summary});

  final WeeklyOutcomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final week = summary.week;
    final themes = week.segments.map((item) => item.theme.title).toSet();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              week.isEventWeek ? week.label : '${week.weekNumber}. Hafta',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              outcomeDateRange(week.start, week.end),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            if (themes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                themes.join(' · '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (week.segments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final segment in week.segments)
                    Chip(
                      avatar: Icon(
                        segment.type == WeeklyPlanSegmentType.block
                            ? Icons.view_agenda_outlined
                            : Icons.school_outlined,
                        size: 17,
                      ),
                      label: Text(
                        segment.type == WeeklyPlanSegmentType.block
                            ? '${segment.block?.title ?? 'Blok'} · ${segment.hours} saat'
                            : 'Okul temelli planlama · ${segment.hours} saat',
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

class _SummaryMetrics extends StatelessWidget {
  const _SummaryMetrics({required this.summary});

  final WeeklyOutcomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final activeCount = summary.outcomes
        .where(
          (item) => item.presentationStatus == OutcomeTrackingStatus.inProgress,
        )
        .length;
    final partialCount = summary.outcomes
        .where(
          (item) =>
              item.presentationStatus == OutcomeTrackingStatus.partiallyCompleted,
        )
        .length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        MetricChip(
          icon: Icons.schedule_outlined,
          value: '${summary.week.plannedLessonHours}',
          label: 'ders saati',
        ),
        MetricChip(
          icon: Icons.pending_actions_outlined,
          value: '${summary.plannedCount}',
          label: 'planlı',
        ),
        if (activeCount > 0)
          MetricChip(
            icon: Icons.play_circle_outline,
            value: '$activeCount',
            label: 'devam ediyor',
          ),
        if (partialCount > 0)
          MetricChip(
            icon: Icons.timelapse_outlined,
            value: '$partialCount',
            label: 'kısmen işlendi',
          ),
        MetricChip(
          icon: Icons.check_circle_outline,
          value: '${summary.completedCount}',
          label: 'işlendi',
        ),
        if (summary.carriedCount > 0)
          MetricChip(
            icon: Icons.redo_outlined,
            value: '${summary.carriedCount}',
            label: 'sarkan',
          ),
      ],
    );
  }
}

class _DiaryGlance extends StatelessWidget {
  const _DiaryGlance({required this.summary});

  final WeeklyOutcomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final week = summary.week;
    final themes = week.segments.map((item) => item.theme.title).toSet().toList();
    final blocks = week.segments
        .map((item) => item.block?.title)
        .whereType<String>()
        .toSet()
        .toList();
    final canonical = summary.outcomes.where((item) => !item.isCarriedIn).toList();
    final copyText = StringBuffer()
      ..writeln('${week.weekNumber}. Hafta · ${outcomeDateRange(week.start, week.end)}')
      ..writeln('Tema: ${themes.join(' · ')}')
      ..writeln('Blok: ${blocks.join(' · ')}')
      ..writeln('Kazanımlar:');
    for (final item in canonical) {
      copyText.writeln('${item.outcome.code} — ${item.outcome.officialText}');
    }

    return InfoCard(
      title: '${week.weekNumber}. hafta defter özeti',
      subtitle: 'Yalnız doğrulanmış program ve planlama verisi',
      icon: Icons.content_paste_outlined,
      trailing: IconButton(
        tooltip: 'Özeti kopyala',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: copyText.toString().trim()));
          await HapticFeedback.selectionClick();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Defter özeti panoya kopyalandı.')),
          );
        },
        icon: const Icon(Icons.copy_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (themes.isNotEmpty) Text('Tema: ${themes.join(' · ')}'),
          if (blocks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Blok: ${blocks.join(' · ')}'),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final item in canonical) Chip(label: Text(item.outcome.code)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.summary,
    required this.selected,
    required this.onChanged,
  });

  final WeeklyOutcomeSummary summary;
  final _OutcomeFilter selected;
  final ValueChanged<_OutcomeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final openCount = summary.outcomes
        .where((item) => item.presentationStatus != OutcomeTrackingStatus.completed)
        .length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ChoiceChip(
          label: Text('Tümü (${summary.outcomes.length})'),
          selected: selected == _OutcomeFilter.all,
          onSelected: (_) => onChanged(_OutcomeFilter.all),
        ),
        ChoiceChip(
          label: Text('Açık ($openCount)'),
          selected: selected == _OutcomeFilter.open,
          onSelected: (_) => onChanged(_OutcomeFilter.open),
        ),
        ChoiceChip(
          label: Text('İşlenen (${summary.completedCount})'),
          selected: selected == _OutcomeFilter.completed,
          onSelected: (_) => onChanged(_OutcomeFilter.completed),
        ),
        ChoiceChip(
          label: Text('Sarkan (${summary.carriedCount})'),
          selected: selected == _OutcomeFilter.carried,
          onSelected: (_) => onChanged(_OutcomeFilter.carried),
        ),
      ],
    );
  }
}

class _OutcomeCard extends StatefulWidget {
  const _OutcomeCard({
    super.key,
    required this.item,
    required this.relatedBlockHours,
    required this.onOpen,
    required this.onComplete,
    required this.onNote,
    required this.onAction,
  });

  final TrackedOutcome item;
  final int relatedBlockHours;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  final VoidCallback onNote;
  final ValueChanged<_OutcomeAction> onAction;

  @override
  State<_OutcomeCard> createState() => _OutcomeCardState();
}

class _OutcomeCardState extends State<_OutcomeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final block = item.primaryBlock;
    final theme = item.primaryTheme;
    final pageHint = _pageHint(item);
    final canExpand = item.outcome.officialText.length > 180;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.outcome.code,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutcomeStatusChip(status: item.presentationStatus),
                ],
              ),
              if (item.isCarriedIn) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Geçen haftadan · ${item.carriedFromWeekNumber}. haftadan taşındı',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (item.carriedToWeekNumber != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${item.carriedToWeekNumber}. haftaya taşındı',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: Text(
                  item.outcome.officialText,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.45),
                ),
              ),
              if (canExpand) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _expanded = !_expanded);
                  },
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(_expanded ? 'Kısalt' : 'Devamını göster'),
                ),
              ],
              if (theme != null || block != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        [theme?.title, block?.title].whereType<String>().join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (widget.relatedBlockHours > 0)
                    Chip(
                      avatar: const Icon(Icons.schedule_outlined, size: 17),
                      label: Text(
                        'Bu hafta ilgili blok: ${widget.relatedBlockHours} saat',
                      ),
                    ),
                  if (pageHint != null)
                    Chip(
                      avatar: const Icon(Icons.menu_book_outlined, size: 17),
                      label: Text(pageHint),
                    ),
                  if (item.teacherNote?.isNotEmpty == true)
                    const Chip(
                      avatar: Icon(Icons.sticky_note_2_outlined, size: 17),
                      label: Text('Not var'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.presentationStatus != OutcomeTrackingStatus.completed)
                    FilledButton.tonalIcon(
                      onPressed: widget.onComplete,
                      icon: const Icon(Icons.check),
                      label: const Text('İşlendi'),
                    ),
                  TextButton.icon(
                    onPressed: widget.onNote,
                    icon: const Icon(Icons.sticky_note_2_outlined),
                    label: Text(
                      item.teacherNote?.isNotEmpty == true ? 'Notu düzenle' : 'Not',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Detay'),
                  ),
                  PopupMenuButton<_OutcomeAction>(
                    tooltip: 'Diğer işlemler',
                    onSelected: widget.onAction,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _OutcomeAction.inProgress,
                        child: Text('Devam ediyor'),
                      ),
                      PopupMenuItem(
                        value: _OutcomeAction.partial,
                        child: Text('Kısmen işlendi'),
                      ),
                      PopupMenuItem(
                        value: _OutcomeAction.carry,
                        child: Text('Sonraki haftaya taşı'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: _OutcomeAction.reset,
                        child: Text('Takibi sıfırla'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.more_horiz),
                          SizedBox(width: AppSpacing.xs),
                          Text('Diğer'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _pageHint(TrackedOutcome item) {
    for (final context in item.contexts) {
      for (final section in context.detail.textbookSections) {
        final page = section.printedPageRange;
        if (page != null && page.isNotEmpty) return 'Kitap s. $page';
      }
    }
    return null;
  }
}
