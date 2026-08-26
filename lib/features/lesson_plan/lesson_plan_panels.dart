import 'package:flutter/material.dart';

import '../../domain/models/lesson_plan_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/lesson_plan_workflow_service.dart';
import '../shared/feature_widgets.dart';
import 'lesson_plan_page.dart';

class WeeklyLessonPlanPanel extends StatelessWidget {
  const WeeklyLessonPlanPanel({
    super.key,
    required this.repository,
    required this.annualPlan,
    required this.weekNumber,
  });

  final CourseKnowledgeRepository repository;
  final AnnualOutcomePlan annualPlan;
  final int weekNumber;

  @override
  Widget build(BuildContext context) {
    final service = LessonPlanWorkflowService(repository: repository);
    return FutureBuilder<List<WeeklyLessonPlanSelection>>(
      future: service.plansForWeek(annualPlan, weekNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final selections = snapshot.data ?? const <WeeklyLessonPlanSelection>[];
        if (selections.isEmpty) return const SizedBox.shrink();

        final totalHours = selections
            .map((item) => item.package.lessonHours)
            .fold<int>(0, (sum, value) => sum + value);
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bu haftanın ders planı',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${selections.length} paket · $totalHours paket saati',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var index = 0; index < selections.length; index++) ...[
                    _WeeklyPlanRow(
                      selection: selections[index],
                      onOpen: () => _openPlan(
                        context,
                        repository,
                        selections[index].package.packageId,
                      ),
                    ),
                    if (index != selections.length - 1)
                      const Divider(height: AppSpacing.lg),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class BlockLessonPlanPanel extends StatelessWidget {
  const BlockLessonPlanPanel({
    super.key,
    required this.repository,
    required this.blockId,
  });

  final CourseKnowledgeRepository repository;
  final String blockId;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<LessonPlanPackage>>(
    future: repository.getLessonPlansForBlock(blockId),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox.shrink();
      }
      final plans = snapshot.data ?? const <LessonPlanPackage>[];
      if (plans.isEmpty) return const SizedBox.shrink();
      final hours = plans.fold<int>(0, (sum, plan) => sum + plan.lessonHours);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            'Ders planları',
            subtitle: 'Bu blok için doğrulanmış uygulama paketleri',
            icon: Icons.description_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plans.length} paket · $hours ders saati',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final plan in plans)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openPlan(context, repository, plan.packageId),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            'P${plan.packageNo.toString().padLeft(2, '0')} · ${plan.lessonHours} sa.',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _WeeklyPlanRow extends StatelessWidget {
  const _WeeklyPlanRow({required this.selection, required this.onOpen});

  final WeeklyLessonPlanSelection selection;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final plan = selection.package;
    final packageLabel = 'P${plan.packageNo.toString().padLeft(2, '0')}';
    final blockRange = selection.segmentStartHour == selection.segmentEndHour
        ? 'blokta ${selection.segmentStartHour}. saat'
        : 'blokta ${selection.segmentStartHour}–${selection.segmentEndHour}. saatler';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                packageLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${plan.lessonHours} ders saati · $blockRange',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (plan.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      plan.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openPlan(
  BuildContext context,
  CourseKnowledgeRepository repository,
  String packageId,
) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => LessonPlanPage(
      repository: repository,
      initialPackageId: packageId,
    ),
  ),
);
