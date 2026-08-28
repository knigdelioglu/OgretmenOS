import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/resource_navigation.dart';
import '../../domain/models/assignment_lesson_progress_models.dart';
import '../../domain/models/instruction_context_models.dart';
import '../../domain/models/instruction_timeline_models.dart';
import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/assignment_lesson_progress_repository.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/instruction_context_repository.dart';
import '../../domain/services/assignment_lesson_progress_service.dart';
import '../../domain/services/assignment_lesson_timeline_service.dart';
import '../../domain/services/assignment_progress_cursor_service.dart';
import '../../domain/services/lesson_plan_workflow_service.dart';
import '../shared/feature_widgets.dart';
import 'single_lesson_plan_page.dart';

class AssignmentAwareWeeklyLessonPlanSection extends StatefulWidget {
  const AssignmentAwareWeeklyLessonPlanSection({
    super.key,
    required this.repository,
    required this.annualPlan,
    required this.weekNumber,
    required this.courseId,
    required this.instructionContext,
    required this.timeline,
    required this.progressRepository,
    this.onConfigureSchedule,
    this.onOpenResources,
  });

  final CourseKnowledgeRepository repository;
  final AnnualOutcomePlan annualPlan;
  final int weekNumber;
  final String courseId;
  final InstructionContextRepository instructionContext;
  final AssignmentLessonTimelineService timeline;
  final AssignmentLessonProgressRepository progressRepository;
  final VoidCallback? onConfigureSchedule;
  final ResourceNavigationCallback? onOpenResources;

  @override
  State<AssignmentAwareWeeklyLessonPlanSection> createState() =>
      _AssignmentAwareWeeklyLessonPlanSectionState();
}

class _AssignmentAwareWeeklyLessonPlanSectionState
    extends State<AssignmentAwareWeeklyLessonPlanSection> {
  late Future<_AssignmentSectionData> _future;
  String? _manualAssignmentId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AssignmentAwareWeeklyLessonPlanSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.annualPlan != widget.annualPlan ||
        oldWidget.weekNumber != widget.weekNumber ||
        oldWidget.courseId != widget.courseId ||
        oldWidget.instructionContext != widget.instructionContext ||
        oldWidget.timeline != widget.timeline) {
      _manualAssignmentId = null;
      _future = _load();
    }
  }

  Future<_AssignmentSectionData> _load() async {
    final assignments = await widget.instructionContext.getAssignments(
      academicYear: widget.annualPlan.academicYear,
      courseId: widget.courseId,
    );
    final classes = await widget.instructionContext.getClasses(
      widget.annualPlan.academicYear,
    );
    final timeline = await widget.timeline.resolve(
      academicYear: widget.annualPlan.academicYear,
      courseId: widget.courseId,
    );
    return _AssignmentSectionData(
      assignments: assignments,
      classes: classes,
      timeline: timeline,
    );
  }

  void _reload() => setState(() => _future = _load());

  String? _automaticAssignmentId(_AssignmentSectionData data) {
    final current = data.timeline.currentOccurrence?.assignmentId;
    if (current != null && data.assignment(current) != null) return current;

    ScheduledLessonOccurrence? latest;
    for (final assignment in data.assignments) {
      final previous = data.timeline.positionFor(assignment.id)?.previousOccurrence;
      if (previous == null) continue;
      if (latest == null || previous.startsAt.isAfter(latest.startsAt)) {
        latest = previous;
      }
    }
    if (latest != null) return latest.assignmentId;

    final next = data.timeline.nextOccurrence?.assignmentId;
    if (next != null && data.assignment(next) != null) return next;
    return data.assignments.isEmpty ? null : data.assignments.first.id;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AssignmentSectionData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
        return const SizedBox.shrink();
      }
      final data = snapshot.data;
      if (data == null || data.assignments.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu haftanın ders planı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'ŞU AN dersini otomatik bulmak için bu derse girdiğiniz sınıfları ve haftalık programı bir kez tanımlayın.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.onConfigureSchedule != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.tonalIcon(
                      onPressed: widget.onConfigureSchedule,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Sınıfları ve programı ayarla'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }

      final autoId = _automaticAssignmentId(data);
      final selectedId = data.assignment(_manualAssignmentId ?? '') != null
          ? _manualAssignmentId
          : autoId;
      final assignment = selectedId == null ? null : data.assignment(selectedId);
      if (assignment == null) return const SizedBox.shrink();
      final schoolClass = data.classFor(assignment.classId);
      final position = data.timeline.positionFor(assignment.id);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.assignments.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: MenuAnchor(
                  builder: (context, controller, child) => OutlinedButton.icon(
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                    icon: const Icon(Icons.class_outlined),
                    label: Text(schoolClass?.displayName ?? 'Sınıf seç'),
                  ),
                  menuChildren: [
                    for (final item in data.assignments)
                      MenuItemButton(
                        onPressed: () => setState(() => _manualAssignmentId = item.id),
                        leadingIcon: Icon(
                          item.id == assignment.id
                              ? Icons.check_rounded
                              : Icons.class_outlined,
                        ),
                        child: Text(
                          data.classFor(item.classId)?.displayName ?? item.classId,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          _AssignmentWeeklyPlanPanel(
            repository: widget.repository,
            annualPlan: widget.annualPlan,
            weekNumber: widget.weekNumber,
            assignment: assignment,
            schoolClass: schoolClass,
            position: position,
            timelineSnapshot: data.timeline,
            instructionContext: widget.instructionContext,
            progressRepository: widget.progressRepository,
            onChanged: _reload,
            onOpenResources: widget.onOpenResources,
          ),
        ],
      );
    },
  );
}

class _AssignmentWeeklyPlanPanel extends StatefulWidget {
  const _AssignmentWeeklyPlanPanel({
    required this.repository,
    required this.annualPlan,
    required this.weekNumber,
    required this.assignment,
    required this.schoolClass,
    required this.position,
    required this.timelineSnapshot,
    required this.instructionContext,
    required this.progressRepository,
    required this.onChanged,
    this.onOpenResources,
  });

  final CourseKnowledgeRepository repository;
  final AnnualOutcomePlan annualPlan;
  final int weekNumber;
  final TeachingAssignment assignment;
  final SchoolClass? schoolClass;
  final AssignmentTimelinePosition? position;
  final InstructionTimelineSnapshot timelineSnapshot;
  final InstructionContextRepository instructionContext;
  final AssignmentLessonProgressRepository progressRepository;
  final VoidCallback onChanged;
  final ResourceNavigationCallback? onOpenResources;

  @override
  State<_AssignmentWeeklyPlanPanel> createState() =>
      _AssignmentWeeklyPlanPanelState();
}

class _AssignmentWeeklyPlanPanelState extends State<_AssignmentWeeklyPlanPanel> {
  late Future<_AssignmentPanelData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _AssignmentWeeklyPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignment.id != widget.assignment.id ||
        oldWidget.weekNumber != widget.weekNumber ||
        oldWidget.position?.plannedOrdinal != widget.position?.plannedOrdinal ||
        oldWidget.position?.actualOrdinal != widget.position?.actualOrdinal) {
      _future = _load();
    }
  }

  Future<_AssignmentPanelData> _load() async {
    final workflow = LessonPlanWorkflowService(repository: widget.repository);
    final selections = await workflow.plansForWeek(
      widget.annualPlan,
      widget.weekNumber,
    );
    final raw = await widget.progressRepository.getForAssignment(
      widget.assignment.id,
    );
    final rawByKey = {
      for (final record in raw)
        AssignmentLessonProgressKey(
          packageId: record.packageId,
          packageHour: record.packageHour,
        ): record,
    };
    final progressService = AssignmentLessonProgressService(
      repository: widget.progressRepository,
    );
    final resolved = <AssignmentLessonProgressKey, AssignmentLessonProgressResolution>{};
    for (final selection in selections) {
      final key = AssignmentLessonProgressKey(
        packageId: selection.package.packageId,
        packageHour: selection.packageHour,
      );
      resolved[key] = progressService.resolveRecord(
        package: selection.package,
        record: rawByKey[key],
      );
    }
    final actualSelection = widget.position == null
        ? null
        : await workflow.selectionForInstructionOrdinal(
            widget.annualPlan,
            widget.position!.actualOrdinal,
          );
    final plannedSelection = widget.position == null
        ? null
        : await workflow.selectionForInstructionOrdinal(
            widget.annualPlan,
            widget.position!.plannedOrdinal,
          );
    return _AssignmentPanelData(
      selections: selections,
      resolutions: resolved,
      actualSelection: actualSelection,
      plannedSelection: plannedSelection,
    );
  }

  int _instructionOrdinalForSelection(WeeklyLessonPlanSelection selection) {
    var ordinal = selection.weekHour;
    for (final summary in widget.annualPlan.weeks) {
      if (summary.week.weekNumber >= selection.weekNumber) break;
      if (!summary.week.isEventWeek) ordinal += summary.week.plannedLessonHours;
    }
    return ordinal;
  }

  Future<void> _correctPosition(_AssignmentPanelData data) async {
    final position = widget.position;
    if (position == null) return;
    final choice = await showModalBottomSheet<_PositionChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ActualPositionSheet(
        annualPlan: widget.annualPlan,
        repository: widget.repository,
        plannedOrdinal: position.plannedOrdinal,
        actualOrdinal: position.actualOrdinal,
      ),
    );
    if (choice == null) return;
    try {
      final service = AssignmentProgressCursorService(
        repository: widget.instructionContext,
      );
      if (choice.followSchedule) {
        await service.followSchedule(widget.assignment.id);
      } else {
        await service.setActualPosition(
          assignmentId: widget.assignment.id,
          plannedOrdinal: position.plannedOrdinal,
          actualOrdinal: choice.actualOrdinal!,
        );
      }
      if (!mounted) return;
      widget.onChanged();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlerleme konumu kaydedilemedi.')),
      );
    }
  }

  Future<void> _openPlan(WeeklyLessonPlanSelection selection) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SingleLessonPlanPage(
          repository: widget.repository,
          initialPackageId: selection.package.packageId,
          initialPackageHour: selection.packageHour,
          academicYear: widget.annualPlan.academicYear,
          assignmentId: widget.assignment.id,
          assignmentProgressRepository: widget.progressRepository,
          onOpenResources: widget.onOpenResources,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _future = _load());
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AssignmentPanelData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
        return const SizedBox.shrink();
      }
      final data = snapshot.data;
      if (data == null || data.selections.isEmpty) return const SizedBox.shrink();
      final position = widget.position;
      final planned = position?.plannedOrdinal ?? 0;
      final actual = position?.actualOrdinal ?? planned;
      final delta = actual - planned;
      final isCurrentClass =
          widget.timelineSnapshot.currentOccurrence?.assignmentId ==
          widget.assignment.id;
      final scheme = Theme.of(context).colorScheme;

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
                    const Icon(Icons.format_list_bulleted_rounded, size: 20),
                    const SizedBox(width: AppSpacing.sm),
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
                          const SizedBox(height: 2),
                          Text(
                            widget.schoolClass?.displayName ?? 'Sınıf',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${data.selections.length} ders saati',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (position != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: delta == 0
                          ? scheme.primaryContainer.withValues(alpha: 0.32)
                          : scheme.secondaryContainer.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                delta == 0
                                    ? 'Programla uyumlu'
                                    : delta < 0
                                    ? '${-delta} ders saati geride'
                                    : '$delta ders saati ileride',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _positionSummary(data, planned: planned, actual: actual),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _correctPosition(data),
                          child: const Text('Düzelt'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                for (var index = 0; index < data.selections.length; index++)
                  Builder(
                    builder: (context) {
                      final selection = data.selections[index];
                      final ordinal = _instructionOrdinalForSelection(selection);
                      final key = AssignmentLessonProgressKey(
                        packageId: selection.package.packageId,
                        packageHour: selection.packageHour,
                      );
                      final resolution = data.resolutions[key] ??
                          const AssignmentLessonProgressResolution.none();
                      final isActual = ordinal == actual;
                      final isPlanned = ordinal == planned;
                      return _AssignmentPlanRow(
                        selection: selection,
                        resolution: resolution,
                        schedulePassed: ordinal < planned,
                        isCurrentTime: isCurrentClass && isPlanned,
                        isActual: isActual,
                        isPlanned: isPlanned,
                        positionsDiffer: actual != planned,
                        isLast: index == data.selections.length - 1,
                        onOpen: () => _openPlan(selection),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  String _positionSummary(
    _AssignmentPanelData data, {
    required int planned,
    required int actual,
  }) {
    final plannedTitle = _selectionTitle(data.plannedSelection);
    final actualTitle = _selectionTitle(data.actualSelection);
    if (planned == actual) {
      return actualTitle == null
          ? 'Planlanan ve gerçek ders konumu aynı.'
          : 'Güncel konum: $actualTitle';
    }
    return [
      if (plannedTitle != null) 'Planlanan: $plannedTitle',
      if (actualTitle != null) 'Gerçek: $actualTitle',
    ].join(' · ');
  }

  String? _selectionTitle(WeeklyLessonPlanSelection? selection) {
    if (selection == null) return null;
    final lessonTitle = selection.lesson?.title.trim();
    if (lessonTitle != null && lessonTitle.isNotEmpty) return lessonTitle;
    return selection.package.title;
  }
}

class _AssignmentPlanRow extends StatelessWidget {
  const _AssignmentPlanRow({
    required this.selection,
    required this.resolution,
    required this.schedulePassed,
    required this.isCurrentTime,
    required this.isActual,
    required this.isPlanned,
    required this.positionsDiffer,
    required this.isLast,
    required this.onOpen,
  });

  final WeeklyLessonPlanSelection selection;
  final AssignmentLessonProgressResolution resolution;
  final bool schedulePassed;
  final bool isCurrentTime;
  final bool isActual;
  final bool isPlanned;
  final bool positionsDiffer;
  final bool isLast;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lessonTitle = selection.lesson?.title.trim();
    final title = lessonTitle != null && lessonTitle.isNotEmpty
        ? lessonTitle
        : selection.package.title;
    final explicitStatus = resolution.isStale
        ? 'Plan güncellendi · yeniden işaretle'
        : resolution.isCurrent &&
              resolution.record?.status != LessonPlanProgressStatus.notStarted
        ? resolution.record!.status.teacherLabel
        : null;
    final contextualStatus = explicitStatus ??
        (schedulePassed ? 'Programa göre geçildi' : null);
    final emphasized = isCurrentTime || isActual || isPlanned;

    String? badge;
    if (isCurrentTime) {
      badge = 'ŞU AN';
    } else if (positionsDiffer && isActual) {
      badge = 'GERÇEK';
    } else if (positionsDiffer && isPlanned) {
      badge = 'PLANLANAN';
    } else if (isActual) {
      badge = 'GÜNCEL';
    }

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
                        color: emphasized
                            ? scheme.primary
                            : schedulePassed
                            ? scheme.primary.withValues(alpha: 0.16)
                            : scheme.surfaceContainerHighest,
                        border: Border.all(
                          color: emphasized ? scheme.primary : scheme.outline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 142,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${selection.weekHour}. ders saati',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: emphasized
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.35,
                              ),
                            ),
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
                        if (contextualStatus != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            contextualStatus,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: resolution.isStale
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                              fontWeight: resolution.isStale
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
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

class _ActualPositionSheet extends StatefulWidget {
  const _ActualPositionSheet({
    required this.annualPlan,
    required this.repository,
    required this.plannedOrdinal,
    required this.actualOrdinal,
  });

  final AnnualOutcomePlan annualPlan;
  final CourseKnowledgeRepository repository;
  final int plannedOrdinal;
  final int actualOrdinal;

  @override
  State<_ActualPositionSheet> createState() => _ActualPositionSheetState();
}

class _ActualPositionSheetState extends State<_ActualPositionSheet> {
  late Future<List<_PositionOption>> _future = _load();

  Future<List<_PositionOption>> _load() async {
    final workflow = LessonPlanWorkflowService(repository: widget.repository);
    final lower = math.max(1, math.min(widget.actualOrdinal, widget.plannedOrdinal) - 12);
    final upper = math.max(widget.plannedOrdinal + 4, widget.actualOrdinal + 2);
    final options = <_PositionOption>[];
    for (var ordinal = lower; ordinal <= upper; ordinal++) {
      final selection = await workflow.selectionForInstructionOrdinal(
        widget.annualPlan,
        ordinal,
      );
      if (selection == null) continue;
      final lessonTitle = selection.lesson?.title.trim();
      options.add(
        _PositionOption(
          ordinal: ordinal,
          title: lessonTitle != null && lessonTitle.isNotEmpty
              ? lessonTitle
              : selection.package.title,
          subtitle:
              '${selection.weekNumber}. hafta · ${selection.weekHour}. ders saati',
        ),
      );
    }
    return options;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 680),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Şu anda hangi derstesiniz?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Yalnız programdan sapma olduğunda düzeltmeniz yeterli. Sonraki derslerde fark korunur.',
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(
              const _PositionChoice.followSchedule(),
            ),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Programa yeniden eşitle'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: FutureBuilder<List<_PositionOption>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in snapshot.data!)
                      RadioListTile<int>(
                        value: option.ordinal,
                        groupValue: widget.actualOrdinal,
                        onChanged: (_) => Navigator.of(context).pop(
                          _PositionChoice.actual(option.ordinal),
                        ),
                        title: Text(option.title),
                        subtitle: Text(option.subtitle),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PositionChoice {
  const _PositionChoice.actual(this.actualOrdinal) : followSchedule = false;
  const _PositionChoice.followSchedule()
    : actualOrdinal = null,
      followSchedule = true;

  final int? actualOrdinal;
  final bool followSchedule;
}

class _PositionOption {
  const _PositionOption({
    required this.ordinal,
    required this.title,
    required this.subtitle,
  });

  final int ordinal;
  final String title;
  final String subtitle;
}

class _AssignmentSectionData {
  const _AssignmentSectionData({
    required this.assignments,
    required this.classes,
    required this.timeline,
  });

  final List<TeachingAssignment> assignments;
  final List<SchoolClass> classes;
  final InstructionTimelineSnapshot timeline;

  TeachingAssignment? assignment(String id) {
    for (final item in assignments) {
      if (item.id == id) return item;
    }
    return null;
  }

  SchoolClass? classFor(String classId) {
    for (final item in classes) {
      if (item.id == classId) return item;
    }
    return null;
  }
}

class _AssignmentPanelData {
  const _AssignmentPanelData({
    required this.selections,
    required this.resolutions,
    required this.actualSelection,
    required this.plannedSelection,
  });

  final List<WeeklyLessonPlanSelection> selections;
  final Map<AssignmentLessonProgressKey, AssignmentLessonProgressResolution>
  resolutions;
  final WeeklyLessonPlanSelection? actualSelection;
  final WeeklyLessonPlanSelection? plannedSelection;
}
