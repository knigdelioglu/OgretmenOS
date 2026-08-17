import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/outcome_tracking_models.dart';
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

  Future<void> _runMutation(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      _reload();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Değişiklik kaydedilemedi: $error')),
      );
    }
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

      return AppPage(
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
            onChanged: (number) => setState(() => _selectedWeekNumber = number),
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
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
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
                  item: visibleOutcomes[index],
                  onOpen: () => _openDetail(plan, visibleOutcomes[index]),
                  onComplete: () => _runMutation(
                    () => widget.service.setStatus(
                      visibleOutcomes[index],
                      OutcomeTrackingStatus.completed,
                    ),
                  ),
                  onAction: (action) =>
                      _handleAction(plan, visibleOutcomes[index], action),
                ),
                if (index != visibleOutcomes.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
          ],
        ],
      );
    },
  );

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
  });

  final AnnualOutcomePlan plan;
  final int selectedWeekNumber;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = plan.weeks.indexWhere(
      (item) => item.week.weekNumber == selectedWeekNumber,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Önceki hafta',
              onPressed: index > 0
                  ? () => onChanged(plan.weeks[index - 1].week.weekNumber)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: DropdownButtonFormField<int>(
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
                  ? () => onChanged(plan.weeks[index + 1].week.weekNumber)
                  : null,
              icon: const Icon(Icons.chevron_right),
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
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      MetricChip(
        icon: Icons.schedule_outlined,
        value: '${summary.week.plannedLessonHours}',
        label: 'ders saati',
      ),
      MetricChip(
        icon: Icons.flag_outlined,
        value: '${summary.outcomes.length}',
        label: 'kazanım',
      ),
      MetricChip(
        icon: Icons.check_circle_outline,
        value: '${summary.completedCount}',
        label: 'işlendi',
      ),
      if (summary.inProgressCount > 0)
        MetricChip(
          icon: Icons.timelapse_outlined,
          value: '${summary.inProgressCount}',
          label: 'devam',
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
  const _FilterBar({required this.selected, required this.onChanged});

  final _OutcomeFilter selected;
  final ValueChanged<_OutcomeFilter> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      ChoiceChip(
        label: const Text('Tümü'),
        selected: selected == _OutcomeFilter.all,
        onSelected: (_) => onChanged(_OutcomeFilter.all),
      ),
      ChoiceChip(
        label: const Text('Açık'),
        selected: selected == _OutcomeFilter.open,
        onSelected: (_) => onChanged(_OutcomeFilter.open),
      ),
      ChoiceChip(
        label: const Text('İşlenen'),
        selected: selected == _OutcomeFilter.completed,
        onSelected: (_) => onChanged(_OutcomeFilter.completed),
      ),
      ChoiceChip(
        label: const Text('Sarkan'),
        selected: selected == _OutcomeFilter.carried,
        onSelected: (_) => onChanged(_OutcomeFilter.carried),
      ),
    ],
  );
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.item,
    required this.onOpen,
    required this.onComplete,
    required this.onAction,
  });

  final TrackedOutcome item;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  final ValueChanged<_OutcomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final block = item.primaryBlock;
    final theme = item.primaryTheme;
    final pageHint = _pageHint(item);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
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
              Text(
                item.outcome.officialText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.45),
              ),
              if (theme != null || block != null) ...[
                const SizedBox(height: AppSpacing.md),
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
              if (pageHint != null || item.teacherNote?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
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
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.presentationStatus != OutcomeTrackingStatus.completed)
                    FilledButton.tonalIcon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check),
                      label: const Text('İşlendi'),
                    ),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Detay'),
                  ),
                  PopupMenuButton<_OutcomeAction>(
                    tooltip: 'Diğer işlemler',
                    onSelected: onAction,
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
