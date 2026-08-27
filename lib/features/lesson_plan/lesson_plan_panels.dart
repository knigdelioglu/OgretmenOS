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
import 'lesson_plan_teacher_presentation.dart';

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
    final orderedPackages = <LessonPlanPackage>[];
    final seenPackageIds = <String>{};
    for (final selection in selections) {
      if (seenPackageIds.add(selection.package.packageId)) {
        orderedPackages.add(selection.package);
      }
    }
    final snapshot = await progress.snapshot(
      orderedPackages: orderedPackages,
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

      final totalHours = selections.length;
      final progress = data?.progress;
      final current = _selectionByPackageId(
        selections,
        progress?.currentPackageId,
      );
      final currentIndex = current == null ? -1 : selections.indexOf(current);
      final next = currentIndex >= 0 && currentIndex + 1 < selections.length
          ? selections[currentIndex + 1]
          : _selectionByPackageId(selections, progress?.nextPackageId);
      final stalePackageIds = progress == null
          ? const <String>{}
          : selections
                .where((item) => progress.isStale(item.package.packageId))
                .map((item) => item.package.packageId)
                .toSet();
      final staleCount = stalePackageIds.length;
      final allCompleted =
          progress != null &&
          staleCount == 0 &&
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '$totalHours ders saati',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          if (progress != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              staleCount > 0
                                  ? '$staleCount ders planı güncellendi; durumu yeniden işaretlenmeli.'
                                  : allCompleted
                                  ? 'Bu haftanın ders planı işlendi.'
                                  : [
                                      if (current != null)
                                        'Şu an ${_selectionLabel(current)}',
                                      if (next != null)
                                        'Sonraki ${_selectionLabel(next)}',
                                    ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: staleCount > 0
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context).colorScheme.primary,
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
                    stale:
                        progress?.isStale(selections[index].package.packageId) ??
                        false,
                    isCurrent:
                        current != null &&
                        _sameSelection(current, selections[index]),
                    onOpen: () =>
                        _openPlan(selections[index].package.packageId),
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
      final buttons = <Widget>[];
      var startHour = 1;
      for (final plan in plans) {
        for (var offset = 0; offset < plan.lessonHours; offset++) {
          final hour = startHour + offset;
          buttons.add(
            OutlinedButton.icon(
              onPressed: () => _openPlan(context, repository, plan.packageId),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(teacherLessonHourRange(hour, hour)),
            ),
          );
        }
        startHour += plan.lessonHours;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            'Ders planları',
            subtitle: 'Bu bölüm için doğrulanmış sınıf akışı',
            icon: Icons.description_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$hours ders saati',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: buttons,
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
    required this.stale,
    required this.isCurrent,
    required this.onOpen,
  });

  final WeeklyLessonPlanSelection selection;
  final LessonPlanProgressStatus? status;
  final bool stale;
  final bool isCurrent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final plan = selection.package;
    final lessonTitle = selection.lesson?.title.trim();
    final title = lessonTitle != null && lessonTitle.isNotEmpty
        ? lessonTitle
        : plan.title;
    final hourLabel = _selectionLabel(selection);

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
                hourLabel,
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
                        title,
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
                    '1 ders saati',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (stale) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Plan güncellendi · yeniden işaretle',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else if (status != null) ...[
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

bool _sameSelection(
  WeeklyLessonPlanSelection left,
  WeeklyLessonPlanSelection right,
) =>
    left.package.packageId == right.package.packageId &&
    left.blockId == right.blockId &&
    left.blockHour == right.blockHour;

String _selectionLabel(WeeklyLessonPlanSelection selection) =>
    teacherLessonHourRange(selection.blockHour, selection.blockHour);

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
