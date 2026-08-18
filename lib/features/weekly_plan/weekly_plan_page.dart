import 'package:flutter/material.dart';

import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';
import '../shared/week_navigator.dart';

class WeeklyPlanPage extends StatefulWidget {
  const WeeklyPlanPage({
    super.key,
    required this.repository,
    required this.planningService,
  });

  final CourseKnowledgeRepository repository;
  final WeeklyPlanningService planningService;

  @override
  State<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends State<WeeklyPlanPage> {
  late Future<AnnualWeeklyPlan> _future;
  final ScrollController _scrollController = ScrollController();
  int? _selectedWeekNumber;

  @override
  void initState() {
    super.initState();
    _future = widget.planningService.buildPlan();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.planningService.buildPlan());
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

  void _selectWeek(AnnualWeeklyPlan plan, int weekNumber) {
    final current = _selectedWeekNumber ??
        plan.currentWeekNumber ??
        plan.weeks.first.weekNumber;
    if (current == weekNumber || plan.week(weekNumber) == null) return;
    setState(() => _selectedWeekNumber = weekNumber);
    _scrollToStart();
  }

  void _moveWeek(AnnualWeeklyPlan plan, int selectedWeekNumber, int delta) {
    final index = plan.weeks.indexWhere(
      (week) => week.weekNumber == selectedWeekNumber,
    );
    final targetIndex = index + delta;
    if (index < 0 || targetIndex < 0 || targetIndex >= plan.weeks.length) return;
    _selectWeek(plan, plan.weeks[targetIndex].weekNumber);
  }

  void _handleHorizontalSwipe(
    AnnualWeeklyPlan plan,
    int selectedWeekNumber,
    DragEndDetails details,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 280) return;
    _moveWeek(plan, selectedWeekNumber, velocity < 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnnualWeeklyPlan>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView(label: 'Haftalık ders planı hazırlanıyor…');
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Akademik takvime bağlı haftalık plan yüklenemedi.',
          onRetry: _reload,
        );
      }

      final annualPlan = snapshot.data!;
      if (annualPlan.weeks.isEmpty) {
        return const Center(
          child: UnresolvedText(label: 'Gösterilebilir okul haftası bulunmuyor.'),
        );
      }

      final selectedNumber = _selectedWeekNumber ??
          annualPlan.currentWeekNumber ??
          annualPlan.weeks.first.weekNumber;
      final selectedWeek = annualPlan.week(selectedNumber) ?? annualPlan.weeks.first;

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) =>
            _handleHorizontalSwipe(annualPlan, selectedWeek.weekNumber, details),
        child: AppPage(
          controller: _scrollController,
          children: [
            PageHeader(
              eyebrow: annualPlan.academicYear,
              title: 'Haftalık Plan',
              description:
                  'Haftanın ${annualPlan.weeklyLessonHours} ders saatinin bloklara ve okul temelli planlamaya nasıl dağıldığını görün.',
            ),
            AppWeekNavigator(
              options: [
                for (final week in annualPlan.weeks)
                  WeekNavigatorOption(
                    weekNumber: week.weekNumber,
                    label:
                        '${week.weekNumber}. Hafta · ${_dateRange(week.start, week.end)}${week.isEventWeek ? ' · Etkinlik Haftası' : ''}',
                  ),
              ],
              selectedWeekNumber: selectedWeek.weekNumber,
              currentWeekNumber: annualPlan.currentWeekNumber,
              helperText: 'Sağa veya sola kaydırarak da hafta değiştirebilirsiniz.',
              onChanged: (value) => _selectWeek(annualPlan, value),
            ),
            const SizedBox(height: AppSpacing.md),
            _ScheduleHero(week: selectedWeek),
            if (selectedWeek.isEventWeek)
              const _EventWeekContent()
            else ...[
              const SectionHeading(
                'Bu haftanın ders dağılımı',
                subtitle:
                    'Gösterilen süreler yıllık saat bütçesinin planlama dağıtımıdır; resmî blok süresi olarak sunulmaz.',
                icon: Icons.calendar_view_week_outlined,
              ),
              _Segments(
                week: selectedWeek,
                onOpenBlock: (blockId) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlockDetailPage(
                      repository: widget.repository,
                      blockId: blockId,
                    ),
                  ),
                ),
              ),
              const SectionHeading(
                'Kazanım referansı',
                subtitle:
                    'Takip ve durum güncelleme Kazanımlar sekmesindedir; burada yalnız haftanın program referansı gösterilir.',
                icon: Icons.flag_outlined,
              ),
              _OutcomeReference(week: selectedWeek),
            ],
          ],
        ),
      );
    },
  );
}

class _ScheduleHero extends StatelessWidget {
  const _ScheduleHero({required this.week});

  final AcademicWeekPlan week;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themes = week.segments.map((segment) => segment.theme.title).toSet();

    return Card(
      color: scheme.primaryContainer,
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
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _dateRange(week.start, week.end),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${week.plannedLessonHours}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'ders saati',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (themes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                themes.join(' · '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (week.segments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _HoursDistributionBar(segments: week.segments),
              const SizedBox(height: AppSpacing.md),
              for (final segment in week.segments) ...[
                _SegmentSummaryLine(segment: segment),
                if (segment != week.segments.last)
                  const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HoursDistributionBar extends StatelessWidget {
  const _HoursDistributionBar({required this.segments});

  final List<WeeklyPlanSegment> segments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.primary, scheme.secondary, scheme.tertiary];

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (var index = 0; index < segments.length; index++)
              Expanded(
                flex: segments[index].hours,
                child: ColoredBox(
                  color: segments[index].type == WeeklyPlanSegmentType.schoolBasedPlanning
                      ? scheme.surfaceContainerHighest
                      : colors[index % colors.length],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentSummaryLine extends StatelessWidget {
  const _SegmentSummaryLine({required this.segment});

  final WeeklyPlanSegment segment;

  @override
  Widget build(BuildContext context) {
    final schoolBased = segment.type == WeeklyPlanSegmentType.schoolBasedPlanning;
    final label = schoolBased
        ? 'Okul temelli planlama'
        : segment.block?.title ?? 'Öğretim bloğu';

    return Row(
      children: [
        Icon(
          schoolBased ? Icons.school_outlined : Icons.view_agenda_outlined,
          size: 17,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${segment.hours} saat',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EventWeekContent extends StatelessWidget {
  const _EventWeekContent();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: AppSpacing.lg),
    child: StatusPanel(
      icon: Icons.celebration_outlined,
      title: 'Etkinlik Haftası',
      message:
          'Bu hafta 180 saatlik TDE 9 öğretim bütçesinin dışındadır. Yeni blok veya kazanım atanmaz; okul etkinlikleri için ayrılmıştır.',
      tone: StatusTone.positive,
    ),
  );
}

class _Segments extends StatelessWidget {
  const _Segments({required this.week, required this.onOpenBlock});

  final AcademicWeekPlan week;
  final ValueChanged<String> onOpenBlock;

  @override
  Widget build(BuildContext context) {
    if (week.segments.isEmpty) {
      return const StatusPanel(
        icon: Icons.info_outline,
        title: 'Ders dağılımı bulunmuyor',
        message: 'Bu hafta için planlanmış TDE 9 ders segmenti bulunmuyor.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < week.segments.length; index++) ...[
          _SegmentCard(
            segment: week.segments[index],
            onOpenBlock: onOpenBlock,
          ),
          if (index != week.segments.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment, required this.onOpenBlock});

  final WeeklyPlanSegment segment;
  final ValueChanged<String> onOpenBlock;

  @override
  Widget build(BuildContext context) {
    final block = segment.block;
    final schoolBased = segment.type == WeeklyPlanSegmentType.schoolBasedPlanning;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: block == null ? null : () => onOpenBlock(block.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${segment.hours}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'saat',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolBased ? 'Okul temelli planlama' : block!.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      segment.theme.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      schoolBased
                          ? 'Tema içindeki okul temelli planlama bütçesinin bu haftaya düşen kısmı.'
                          : 'Yıllık saat bütçesindeki haftalık planlama payı.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (block != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeReference extends StatelessWidget {
  const _OutcomeReference({required this.week});

  final AcademicWeekPlan week;

  @override
  Widget build(BuildContext context) {
    if (week.outcomes.isEmpty) {
      return const StatusPanel(
        icon: Icons.info_outline,
        title: 'Kazanım bulunmuyor',
        message:
            'Bu haftada yalnız okul temelli planlama varsa yeni program çıktısı atanmaz.',
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text('${week.outcomes.length} program çıktısı'),
        subtitle: const Text('Kod ve resmî metinleri gerektiğinde açın'),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          for (var index = 0; index < week.outcomes.length; index++) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    week.outcomes[index].code,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    week.outcomes[index].officialText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (index != week.outcomes.length - 1) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
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
