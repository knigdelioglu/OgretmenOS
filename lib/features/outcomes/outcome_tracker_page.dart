import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../shared/feature_widgets.dart';
import '../shared/week_navigator.dart';
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
  final ScrollController _scrollController = ScrollController();
  int? _selectedWeekNumber;
  _OutcomeFilter _filter = _OutcomeFilter.all;

  @override
  void initState() {
    super.initState();
    _future = widget.service.buildPlan();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.service.buildPlan());
  }

  void _scrollToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    bool strongFeedback = false,
  }) async {
    try {
      await action();
      if (!mounted) return;
      _reload();
      if (strongFeedback) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
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
    _scrollToStart();
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
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
        return const LoadingView(label: 'Haftanın kazanımları hazırlanıyor…');
      }
      if (!snapshot.hasData) {
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
          controller: _scrollController,
          onRefresh: () async {
            _reload();
            await _future;
          },
          children: [
            PageHeader(
              eyebrow: plan.academicYear,
              title: 'Kazanım Takibi',
              description:
                  'Bu hafta ne işleyeceğinizi görün; durum ve kısa ders notunu doğrudan karttan güncelleyin.',
            ),
            AppWeekNavigator(
              options: [
                for (final item in plan.weeks)
                  WeekNavigatorOption(
                    weekNumber: item.week.weekNumber,
                    label:
                        '${item.week.weekNumber}. Hafta · ${outcomeDateRange(item.week.start, item.week.end)}${item.week.isEventWeek ? ' · Etkinlik' : ''}',
                  ),
              ],
              selectedWeekNumber: summary.week.weekNumber,
              currentWeekNumber: plan.currentWeekNumber,
              helperText: 'Sağa veya sola kaydırarak da hafta değiştirebilirsiniz.',
              onChanged: (number) => _selectWeek(plan, number),
            ),
            const SizedBox(height: AppSpacing.md),
            _WeekContext(summary: summary),
            if (summary.week.isEventWeek)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.lg),
                child: StatusPanel(
                  icon: Icons.celebration_outlined,
                  title: 'Etkinlik Haftası',
                  message:
                      'Bu hafta yeni program kazanımı atanmaz. 180 saatlik TDE 9 öğretim bütçesi önceki 36 öğretim haftasında tamamlanmıştır.',
                  tone: StatusTone.positive,
                ),
              )
            else ...[
              SectionHeading(
                'Bu haftanın kazanımları',
                subtitle:
                    '${summary.outcomes.length} kazanım · Planlanan program ile sınıftaki gerçekleşen takip ayrı tutulur.',
                icon: Icons.flag_outlined,
              ),
              _FilterBar(
                summary: summary,
                selected: _filter,
                onChanged: (filter) {
                  if (_filter == filter) return;
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
              const SectionHeading(
                'Deftere Bakış',
                subtitle:
                    'Doğrulanmış tema, blok ve resmî kazanım metinlerini gerektiğinde açın veya kopyalayın.',
                icon: Icons.menu_book_outlined,
              ),
              _DiaryGlance(summary: summary),
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
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TeacherNoteDialog(initialNote: item.teacherNote),
    );
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
          scrollable: true,
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

class _TeacherNoteDialog extends StatefulWidget {
  const _TeacherNoteDialog({this.initialNote});

  final String? initialNote;

  @override
  State<_TeacherNoteDialog> createState() => _TeacherNoteDialogState();
}

class _TeacherNoteDialogState extends State<_TeacherNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Öğretmen notu'),
    content: TextField(
      controller: _controller,
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
      if (widget.initialNote?.isNotEmpty == true)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Notu sil'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Kaydet'),
      ),
    ],
  );
}

class _WeekContext extends StatelessWidget {
  const _WeekContext({required this.summary});

  final WeeklyOutcomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final week = summary.week;
    final themes = week.segments.map((item) => item.theme.title).toSet();
    final blocks = week.segments
        .map((item) => item.block?.title)
        .whereType<String>()
        .toSet();

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        week.isEventWeek ? week.label : '${week.weekNumber}. Hafta',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        outcomeDateRange(week.start, week.end),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                MetricChip(
                  icon: Icons.schedule_outlined,
                  value: '${week.plannedLessonHours}',
                  label: 'ders saati',
                ),
              ],
            ),
            if (themes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                themes.join(' · '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (blocks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                blocks.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            if (!week.isEventWeek) ...[
              const SizedBox(height: AppSpacing.md),
              _SummaryMetrics(summary: summary),
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
          icon: Icons.pending_actions_outlined,
          value: '${summary.plannedCount}',
          label: 'planlı',
        ),
        if (activeCount > 0)
          MetricChip(
            icon: Icons.play_circle_outline,
            value: '$activeCount',
            label: 'devam',
          ),
        if (partialCount > 0)
          MetricChip(
            icon: Icons.timelapse_outlined,
            value: '$partialCount',
            label: 'kısmen',
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.content_paste_outlined),
        title: Text('${week.weekNumber}. hafta defter özeti'),
        subtitle: const Text('Yalnız doğrulanmış program ve planlama verisi'),
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
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
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
              if (item.isCarriedIn || item.carriedToWeekNumber != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _CarryLabel(item: item),
              ],
              const SizedBox(height: AppSpacing.md),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: Text(
                  item.outcome.officialText,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
              ),
              if (canExpand) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
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
              if (widget.relatedBlockHours > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu hafta ilgili blok: ${widget.relatedBlockHours} saat',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Bu değer kazanıma atanmış resmî süre değil, haftalık blok planlama payıdır.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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

class _CarryLabel extends StatelessWidget {
  const _CarryLabel({required this.item});

  final TrackedOutcome item;

  @override
  Widget build(BuildContext context) {
    final text = item.isCarriedIn
        ? 'Geçen haftadan · ${item.carriedFromWeekNumber}. haftadan taşındı'
        : '${item.carriedToWeekNumber}. haftaya taşındı';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.redo_outlined, size: 17, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
