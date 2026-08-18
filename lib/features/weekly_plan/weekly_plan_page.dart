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
  int? _selectedWeekNumber;

  @override
  void initState() {
    super.initState();
    _future = widget.planningService.buildPlan();
  }

  void _reload() {
    setState(() {
      _future = widget.planningService.buildPlan();
    });
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

      return AppPage(
        children: [
          PageHeader(
            eyebrow: annualPlan.academicYear,
            title: 'Haftalık Plan',
            description:
                'Akademik takvim ve haftalık ${annualPlan.weeklyLessonHours} ders saati üzerinden TDE 9 bloklarını ve haftanın kazanımlarını görün.',
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
            helperText: 'Haftalar arasında oklarla veya listeden geçiş yapın.',
            onChanged: (value) => setState(() => _selectedWeekNumber = value),
          ),
          const SizedBox(height: AppSpacing.md),
          _WeekHero(week: selectedWeek),
          if (selectedWeek.isEventWeek)
            const _EventWeekContent()
          else ...[
            const SectionHeading(
              'Bu haftanın ders dağılımı',
              subtitle:
                  'Blok süreleri resmî blok saati değil, yıllık saat bütçesini koruyan planlama dağıtımıdır.',
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
              'Bu haftaki kazanımlar',
              subtitle: 'Bu haftaya dağıtılan blokların doğrulanmış program çıktıları',
              icon: Icons.flag_outlined,
            ),
            _Outcomes(week: selectedWeek),
          ],
        ],
      );
    },
  );
}

class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.week});

  final AcademicWeekPlan week;

  @override
  Widget build(BuildContext context) {
    final themes = week.segments.map((segment) => segment.theme.title).toSet().toList();
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
              _dateRange(week.start, week.end),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MetricChip(
                  icon: week.isEventWeek
                      ? Icons.celebration_outlined
                      : Icons.schedule_outlined,
                  value: '${week.plannedLessonHours}',
                  label: 'ders saati',
                ),
                if (!week.isEventWeek)
                  MetricChip(
                    icon: Icons.flag_outlined,
                    value: '${week.outcomes.length}',
                    label: 'kazanım',
                  ),
              ],
            ),
            if (themes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
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

class _EventWeekContent extends StatelessWidget {
  const _EventWeekContent();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: AppSpacing.xl),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: block == null ? null : () => onOpenBlock(block.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${segment.hours}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${segment.theme.title} · ${segment.hours} ders saati',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      schoolBased
                          ? 'Tema için ayrılan 2 saatlik okul temelli planlama bütçesinin bu haftaya düşen bölümü.'
                          : 'Planlama dağıtımı · Resmî programda blok için ayrı ders saati belirtilmemiştir.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (block != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Outcomes extends StatelessWidget {
  const _Outcomes({required this.week});

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
    return Column(
      children: [
        for (var index = 0; index < week.outcomes.length; index++) ...[
          InfoCard(
            title: week.outcomes[index].code,
            subtitle: 'Program çıktısı / kazanım',
            icon: Icons.flag_outlined,
            child: Text(
              week.outcomes[index].officialText,
              style: const TextStyle(height: 1.45),
            ),
          ),
          if (index != week.outcomes.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
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