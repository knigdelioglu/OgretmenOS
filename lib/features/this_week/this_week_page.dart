import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../outcomes/outcome_detail_page.dart';
import '../shared/feature_widgets.dart';

class ThisWeekPage extends StatefulWidget {
  const ThisWeekPage({
    super.key,
    required this.repository,
    required this.service,
  });

  final CourseKnowledgeRepository repository;
  final OutcomePlanningService service;

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

  Future<void> _complete(TrackedOutcome item) async {
    await widget.service.setStatus(item, OutcomeTrackingStatus.completed);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _reload();
  }

  Future<void> _completeAll(WeeklyOutcomeSummary summary) async {
    for (final item in summary.outcomes) {
      if (item.presentationStatus != OutcomeTrackingStatus.completed) {
        await widget.service.setStatus(item, OutcomeTrackingStatus.completed);
      }
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _reload();
  }

  Future<void> _openOutcome(AnnualOutcomePlan plan, TrackedOutcome item) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Defter özeti kopyalandı.')),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnnualOutcomePlan>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
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
        return const Center(child: Text('Gösterilebilir okul haftası bulunmuyor.'));
      }
      final selectedNumber = _selectedWeekNumber ??
          plan.currentWeekNumber ??
          plan.weeks.first.week.weekNumber;
      final summary = plan.week(selectedNumber) ?? plan.weeks.first;
      final focus = _focusOutcome(summary.outcomes);
      final openOthers = summary.outcomes
          .where(
            (item) =>
                item.presentationStatus != OutcomeTrackingStatus.completed &&
                !identical(item, focus),
          )
          .toList(growable: false);
      final completed = summary.outcomes
          .where(
            (item) =>
                item.presentationStatus == OutcomeTrackingStatus.completed,
          )
          .toList(growable: false);

      return AppPage(
        onRefresh: () async {
          _reload();
          await _future;
        },
        children: [
          _WeekToolbar(
            plan: plan,
            selectedWeekNumber: summary.week.weekNumber,
            onChanged: (week) => setState(() => _selectedWeekNumber = week),
          ),
          const SizedBox(height: AppSpacing.md),
          _FocusCard(
            summary: summary,
            academicYear: plan.academicYear,
            focus: focus,
            onContinue: focus == null ? null : () => _openOutcome(plan, focus),
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
              message: 'Bu hafta yalnız okul temelli planlama içeriyor olabilir.',
            ),
          ] else ...[
            const SectionHeading(
              'Sıradaki',
              subtitle: 'Şu anda odaklanılacak tek kazanım',
              icon: Icons.arrow_forward_rounded,
            ),
            if (focus != null)
              _FocusOutcomeCard(
                item: focus,
                onOpen: () => _openOutcome(plan, focus),
                onComplete: () => _complete(focus),
              )
            else
              const StatusPanel(
                icon: Icons.check_circle_outline,
                title: 'Hafta tamamlandı',
                message: 'Bu haftanın tüm kazanımları işlendi.',
                tone: StatusTone.positive,
              ),
            if (openOthers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _OutcomeGroup(
                title: 'Bu haftanın diğerleri',
                subtitle: '${openOthers.length} kazanım',
                icon: Icons.list_alt_outlined,
                items: openOthers,
                onOpen: (item) => _openOutcome(plan, item),
                onComplete: _complete,
              ),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _OutcomeGroup(
                title: 'Tamamlananlar',
                subtitle: '${completed.length} kazanım',
                icon: Icons.check_circle_outline,
                items: completed,
                onOpen: (item) => _openOutcome(plan, item),
                onComplete: _complete,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _WeeklyTools(
              summary: summary,
              onCopyDiary: () => _copyDiary(summary),
              onCompleteAll: summary.completedCount == summary.outcomes.length
                  ? null
                  : () => _completeAll(summary),
            ),
          ],
        ],
      );
    },
  );
}

class _WeekToolbar extends StatelessWidget {
  const _WeekToolbar({
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
    return Row(
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
            key: ValueKey(selectedWeekNumber),
            initialValue: selectedWeekNumber,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Okul haftası',
              isDense: true,
            ),
            items: [
              for (final item in plan.weeks)
                DropdownMenuItem(
                  value: item.week.weekNumber,
                  child: Text(
                    '${item.week.weekNumber}. Hafta · ${_dateRange(item.week.start, item.week.end)}',
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
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.summary,
    required this.academicYear,
    required this.focus,
    required this.onContinue,
  });

  final WeeklyOutcomeSummary summary;
  final String academicYear;
  final TrackedOutcome? focus;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final week = summary.week;
    final segment = _primarySegment(week);
    final blockTitle = segment?.block?.title ??
        (segment == null ? 'Ders akışı' : 'Okul temelli planlama');
    final themeTitle = segment?.theme.title;
    final total = summary.outcomes.length;
    final progress = total == 0 ? 0.0 : summary.completedCount / total;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ŞİMDİ',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
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
            if (!week.isEventWeek && total > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    'Haftalık ilerleme',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${summary.completedCount} / $total işlendi',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
            if (onContinue != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Derse devam et'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FocusOutcomeCard extends StatelessWidget {
  const _FocusOutcomeCard({
    required this.item,
    required this.onOpen,
    required this.onComplete,
  });

  final TrackedOutcome item;
  final VoidCallback onOpen;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.outcome.code,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.outcome.officialText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSecondaryContainer,
                  height: 1.45,
                ),
              ),
              if (item.teacherNote?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.teacherNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
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
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check),
                    label: const Text('İşlendi'),
                  ),
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ayrıntıyı aç'),
                  ),
                ],
              ),
            ],
          ),
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
    required this.onComplete,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<TrackedOutcome> items;
  final ValueChanged<TrackedOutcome> onOpen;
  final Future<void> Function(TrackedOutcome) onComplete;

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
            onComplete: () => onComplete(items[index]),
          ),
          if (index != items.length - 1)
            const SizedBox(height: AppSpacing.xs),
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
      subtitle: const Text('Defter ve toplu işlemler'),
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
                label: const Text('Tümünü işlendi'),
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
    required this.onComplete,
  });

  final TrackedOutcome item;
  final VoidCallback onOpen;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final completed = item.presentationStatus == OutcomeTrackingStatus.completed;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: completed
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
              const SizedBox(width: AppSpacing.sm),
              if (!completed)
                IconButton.filledTonal(
                  tooltip: 'İşlendi',
                  onPressed: onComplete,
                  icon: const Icon(Icons.check),
                ),
            ],
          ),
        ),
      ),
    );
  }
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