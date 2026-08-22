import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../block/block_detail_page.dart';
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
      final completed = summary.completedCount;
      final total = summary.outcomes.length;

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
          _WeekOverview(summary: summary, academicYear: plan.academicYear),
          if (summary.week.isEventWeek) ...[
            const SizedBox(height: AppSpacing.lg),
            const StatusPanel(
              icon: Icons.celebration_outlined,
              title: 'Etkinlik haftası',
              message: 'Bu hafta yeni program kazanımı planlanmıyor.',
              tone: StatusTone.positive,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            _LessonFlow(
              week: summary.week,
              onOpenBlock: (blockId) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlockDetailPage(
                    repository: widget.repository,
                    blockId: blockId,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bu haftanın kazanımları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text('$completed / $total işlendi'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: total == 0 ? null : () => _copyDiary(summary),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Deftere kopyala'),
                ),
                FilledButton.tonalIcon(
                  onPressed: total == 0 || completed == total
                      ? null
                      : () => _completeAll(summary),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Tümünü işlendi'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (summary.outcomes.isEmpty)
              const StatusPanel(
                icon: Icons.info_outline,
                title: 'Bu hafta kazanım yok',
                message: 'Bu hafta yalnız okul temelli planlama içeriyor olabilir.',
              )
            else
              for (var index = 0; index < summary.outcomes.length; index++) ...[
                _OutcomeRow(
                  item: summary.outcomes[index],
                  onOpen: () => _openOutcome(plan, summary.outcomes[index]),
                  onComplete: () => _complete(summary.outcomes[index]),
                ),
                if (index != summary.outcomes.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
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

class _WeekOverview extends StatelessWidget {
  const _WeekOverview({required this.summary, required this.academicYear});

  final WeeklyOutcomeSummary summary;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    final week = summary.week;
    final themes = week.segments.map((segment) => segment.theme.title).toSet();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              week.isEventWeek ? week.label : '${week.weekNumber}. Hafta',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$academicYear · ${_dateRange(week.start, week.end)} · ${week.plannedLessonHours} ders saati',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            if (themes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                themes.join(' · '),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonFlow extends StatelessWidget {
  const _LessonFlow({required this.week, required this.onOpenBlock});

  final AcademicWeekPlan week;
  final ValueChanged<String> onOpenBlock;

  @override
  Widget build(BuildContext context) {
    if (week.segments.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < week.segments.length; index++) ...[
            ListTile(
              leading: CircleAvatar(child: Text('${week.segments[index].hours}')),
              title: Text(
                week.segments[index].block?.title ?? 'Okul temelli planlama',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(week.segments[index].theme.title),
              trailing: week.segments[index].block == null
                  ? null
                  : const Icon(Icons.chevron_right),
              onTap: week.segments[index].block == null
                  ? null
                  : () => onOpenBlock(week.segments[index].block!.id),
            ),
            if (index != week.segments.length - 1)
              const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                FilledButton.tonal(
                  onPressed: onComplete,
                  child: const Text('İşlendi'),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('İşlendi'),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
