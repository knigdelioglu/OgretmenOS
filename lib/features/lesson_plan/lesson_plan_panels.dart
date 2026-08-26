import 'package:flutter/material.dart';

import '../../domain/models/lesson_plan_models.dart';
import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/services/lesson_plan_progress_service.dart';
import '../../domain/services/lesson_plan_workflow_service.dart';
import '../shared/feature_widgets.dart';
import 'lesson_plan_page.dart';

class WeeklyLessonPlanPanel extends StatefulWidget {
  const WeeklyLessonPlanPanel({
    super.key,
    required this.repository,
    required this.annualPlan,
    required this.weekNumber,
    this.progressRepository,
  });

  final CourseKnowledgeRepository repository;
  final AnnualOutcomePlan annualPlan;
  final int weekNumber;
  final LessonPlanProgressRepository? progressRepository;

  @override
  State<WeeklyLessonPlanPanel> createState() => _WeeklyLessonPlanPanelState();
}

class _WeeklyLessonPlanPanelState extends State<WeeklyLessonPlanPanel> {
  late Future<_WeeklyLessonPlanPanelData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant WeeklyLessonPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekNumber != widget.weekNumber ||
        oldWidget.annualPlan != widget.annualPlan ||
        oldWidget.repository != widget.repository ||
        oldWidget.progressRepository != widget.progressRepository) {
      _future = _load();
    }
  }

  Future<_WeeklyLessonPlanPanelData> _load() async {
    final workflow = LessonPlanWorkflowService(repository: widget.repository);
    final selections = await workflow.plansForWeek(
      widget.annualPlan,
      widget.weekNumber,
    );
    if (selections.isEmpty || widget.progressRepository == null) {
      return _WeeklyLessonPlanPanelData(selections: selections);
    }
    final progress = LessonPlanProgressService(
      repository: widget.progressRepository!,
    );
    final snapshot = await progress.snapshot(
      orderedPackages: selections.map((item) => item.package).toList(growable: false),
      academicYear: widget.annualPlan.academicYear,
    );
    return _WeeklyLessonPlanPanelData(
      selections: selections,
      progress: snapshot,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openPlan(String packageId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LessonPlanPage(
          repository: widget.repository,
          initialPackageId: packageId,
          progressRepository: widget.progressRepository,
          academicYear: widget.annualPlan.academicYear,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_WeeklyLessonPlanPanelData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox.shrink();
      }
      final data = snapshot.data;
      final selections = data?.selections ?? const <WeeklyLessonPlanSelection>[];
      if (selections.isEmpty) return const SizedBox.shrink();

      final totalHours = selections
          .map((item) => item.package.lessonHours)
          .fold<int>(0, (sum, value) => sum + value);
      final progress = data?.progress;
      final current = _selectionByPackageId(
        selections,
        progress?.currentPackageId,
      );
      final next = _selectionByPackageId(selections, progress?.nextPackageId);
      final allCompleted =
          progress != null &&
          selections.every(
            (item) =>
                progress.statusFor(item.package.packageId) ==
                LessonPlanProgressStatus.completed,
          );

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
                          if (progress != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              allCompleted
                                  ? 'Bu haftanın plan paketleri işlendi.'
                                  : [
                                      if (current != null)
                                        'Şu an ${_packageLabel(current.package)}',
                                      if (next != null)
                                        'Sonraki ${_packageLabel(next.package)}',
                                    ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (var index = 0; index < selections.length; index++) ...[
                  _WeeklyPlanRow(
                    selection: selections[index],
                    status: progress?.statusFor(
                      selections[index].package.packageId,
                    ),
                    isCurrent:
                        progress?.currentPackageId ==
                        selections[index].package.packageId,
                    onOpen: () => _openPlan(
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
  const _WeeklyPlanRow({
    required this.selection,
    required this.status,
    required this.isCurrent,
    required this.onOpen,
  });

  final WeeklyLessonPlanSelection selection;
  final LessonPlanProgressStatus? status;
  final bool isCurrent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final plan = selection.package;
    final packageLabel = _packageLabel(plan);
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
                color: isCurrent
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                packageLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isCurrent)
                        Text(
                          'ŞU AN',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${plan.lessonHours} ders saati · $blockRange',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      status!.teacherLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: status == LessonPlanProgressStatus.completed
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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

class _WeeklyLessonPlanPanelData {
  const _WeeklyLessonPlanPanelData({required this.selections, this.progress});

  final List<WeeklyLessonPlanSelection> selections;
  final LessonPlanProgressSnapshot? progress;
}

WeeklyLessonPlanSelection? _selectionByPackageId(
  List<WeeklyLessonPlanSelection> selections,
  String? packageId,
) {
  if (packageId == null) return null;
  for (final selection in selections) {
    if (selection.package.packageId == packageId) return selection;
  }
  return null;
}

String _packageLabel(LessonPlanPackage plan) =>
    'P${plan.packageNo.toString().padLeft(2, '0')}';

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