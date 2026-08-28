import 'package:flutter/material.dart';

import '../../domain/models/lesson_plan_models.dart';
import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/services/lesson_plan_workflow_service.dart';
import '../shared/feature_widgets.dart';
import 'lesson_plan_teacher_presentation.dart';
import 'single_lesson_plan_page.dart';

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

    final allRecords = await widget.progressRepository!
        .getForCourseAcademicYear(
          courseId: selections.first.package.courseId,
          academicYear: widget.annualPlan.academicYear,
        );
    final progress = _buildLessonHourProgressSnapshot(
      selections: selections,
      allRecords: allRecords,
    );
    return _WeeklyLessonPlanPanelData(
      selections: selections,
      progress: progress,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openPlan(WeeklyLessonPlanSelection selection) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SingleLessonPlanPage(
          repository: widget.repository,
          initialPackageId: selection.package.packageId,
          initialPackageHour: selection.packageHour,
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
      final currentIndex = progress == null
          ? -1
          : selections.indexWhere(
              (selection) =>
                  _lessonHourProgressId(selection) == progress.currentKey,
            );
      final current = currentIndex >= 0 ? selections[currentIndex] : null;
      final nextIndex = progress == null
          ? -1
          : selections.indexWhere(
              (selection) => _lessonHourProgressId(selection) == progress.nextKey,
            );
      final next = nextIndex >= 0 ? selections[nextIndex] : null;
      final staleCount = progress == null
          ? 0
          : selections.where(progress.isStale).length;
      final allCompleted =
          progress != null &&
          staleCount == 0 &&
          selections.every(
            (item) =>
                progress.statusFor(item) == LessonPlanProgressStatus.completed,
          );

      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Bu haftanın ders planı',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '$totalHours ders saati',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (staleCount > 0 || allCompleted) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    staleCount > 0
                        ? '$staleCount ders güncellendi; durumu yeniden işaretlenmeli.'
                        : 'Bu haftanın dersleri işlendi.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: staleCount > 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                for (var index = 0; index < selections.length; index++)
                  _WeeklyPlanRow(
                    selection: selections[index],
                    status: progress?.statusFor(selections[index]),
                    stale: progress?.isStale(selections[index]) ?? false,
                    isCurrent:
                        current != null &&
                        _sameSelection(current, selections[index]),
                    isNext:
                        next != null && _sameSelection(next, selections[index]),
                    isLast: index == selections.length - 1,
                    onOpen: () => _openPlan(selections[index]),
                  ),
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
              onPressed: () => _openPlan(
                context,
                repository,
                plan.packageId,
                packageHour: offset + 1,
              ),
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
    required this.isNext,
    required this.isLast,
    required this.onOpen,
  });

  final WeeklyLessonPlanSelection selection;
  final LessonPlanProgressStatus? status;
  final bool stale;
  final bool isCurrent;
  final bool isNext;
  final bool isLast;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = selection.package;
    final lessonTitle = selection.lesson?.title.trim();
    final title = lessonTitle != null && lessonTitle.isNotEmpty
        ? lessonTitle
        : plan.title;
    final hourLabel = _selectionLabel(selection);
    final statusLabel = status?.teacherLabel ?? 'Başlanmadı';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!isLast)
              Positioned(
                left: 7,
                top: 29,
                bottom: -16,
                child: Container(width: 1, color: scheme.outlineVariant),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? scheme.primary
                            : isNext
                            ? scheme.surface
                            : scheme.surfaceContainerHighest,
                        border: Border.all(
                          color: isCurrent || isNext
                              ? scheme.primary
                              : scheme.outline,
                          width: isNext ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 132,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          hourLabel,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isCurrent)
                          _TimelineBadge(label: 'ŞU AN', color: scheme.primary),
                        if (!isCurrent && isNext)
                          _TimelineBadge(
                            label: 'SONRAKİ',
                            color: scheme.secondary,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: 0,
                          runSpacing: 2,
                          children: [
                            Text(
                              '1 ders saati',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '  ·  ',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              stale
                                  ? 'Plan güncellendi · yeniden işaretle'
                                  : statusLabel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: stale ? scheme.error : scheme.onSurfaceVariant,
                                fontWeight: stale ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Positioned(
                left: 32,
                right: 0,
                bottom: 0,
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineBadge extends StatelessWidget {
  const _TimelineBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _WeeklyLessonPlanPanelData {
  const _WeeklyLessonPlanPanelData({required this.selections, this.progress});

  final List<WeeklyLessonPlanSelection> selections;
  final _LessonHourProgressSnapshot? progress;
}

class _LessonHourProgressSnapshot {
  const _LessonHourProgressSnapshot({
    required this.records,
    required this.staleKeys,
    required this.currentKey,
    required this.nextKey,
  });

  final Map<String, LessonPlanProgressRecord> records;
  final Set<String> staleKeys;
  final String? currentKey;
  final String? nextKey;

  LessonPlanProgressStatus statusFor(WeeklyLessonPlanSelection selection) =>
      records[_lessonHourProgressId(selection)]?.status ??
      LessonPlanProgressStatus.notStarted;

  bool isStale(WeeklyLessonPlanSelection selection) =>
      staleKeys.contains(_lessonHourProgressId(selection));
}

_LessonHourProgressSnapshot _buildLessonHourProgressSnapshot({
  required List<WeeklyLessonPlanSelection> selections,
  required List<LessonPlanProgressRecord> allRecords,
}) {
  final byId = {for (final record in allRecords) record.packageId: record};
  final records = <String, LessonPlanProgressRecord>{};
  final staleKeys = <String>{};

  for (final selection in selections) {
    final key = _lessonHourProgressId(selection);
    final record = byId[key];
    if (record == null) continue;
    final packageHash = selection.package.payloadSha256.trim();
    final recordHash = record.payloadSha256?.trim() ?? '';
    if (packageHash.isEmpty || recordHash.isEmpty || packageHash != recordHash) {
      staleKeys.add(key);
    } else {
      records[key] = record;
    }
  }

  String? currentKey;
  for (final selection in selections) {
    final key = _lessonHourProgressId(selection);
    if (records[key]?.status == LessonPlanProgressStatus.inProgress) {
      currentKey = key;
      break;
    }
  }
  currentKey ??= _firstOpenLessonKey(selections, records);

  String? nextKey;
  if (currentKey != null) {
    final currentIndex = selections.indexWhere(
      (selection) => _lessonHourProgressId(selection) == currentKey,
    );
    for (var index = currentIndex + 1; index < selections.length; index++) {
      final key = _lessonHourProgressId(selections[index]);
      if (records[key]?.status != LessonPlanProgressStatus.completed) {
        nextKey = key;
        break;
      }
    }
  }

  return _LessonHourProgressSnapshot(
    records: Map<String, LessonPlanProgressRecord>.unmodifiable(records),
    staleKeys: Set<String>.unmodifiable(staleKeys),
    currentKey: currentKey,
    nextKey: nextKey,
  );
}

String? _firstOpenLessonKey(
  List<WeeklyLessonPlanSelection> selections,
  Map<String, LessonPlanProgressRecord> records,
) {
  for (final selection in selections) {
    final key = _lessonHourProgressId(selection);
    if (records[key]?.status != LessonPlanProgressStatus.completed) return key;
  }
  return null;
}

String _lessonHourProgressId(WeeklyLessonPlanSelection selection) =>
    '${selection.package.packageId}::lesson-hour:${selection.packageHour}';

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
  String packageId, {
  required int packageHour,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => SingleLessonPlanPage(
      repository: repository,
      initialPackageId: packageId,
      initialPackageHour: packageHour,
    ),
  ),
);
