import 'package:flutter/material.dart';

import '../../app/resource_navigation.dart';
import '../../domain/models/instruction_context_models.dart';
import '../../domain/models/instruction_timeline_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/assignment_lesson_progress_repository.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/instruction_context_repository.dart';
import '../../domain/services/assignment_lesson_timeline_service.dart';
import '../../domain/services/lesson_plan_workflow_service.dart';
import '../lesson_plan/single_lesson_plan_page.dart';
import '../shared/feature_widgets.dart';

class CurrentScheduledLessonCard extends StatefulWidget {
  const CurrentScheduledLessonCard({
    super.key,
    required this.repository,
    required this.annualPlan,
    required this.courseId,
    required this.instructionContext,
    required this.timeline,
    required this.progressRepository,
    this.onOpenResources,
  });

  final CourseKnowledgeRepository repository;
  final AnnualOutcomePlan annualPlan;
  final String courseId;
  final InstructionContextRepository instructionContext;
  final AssignmentLessonTimelineService timeline;
  final AssignmentLessonProgressRepository progressRepository;
  final ResourceNavigationCallback? onOpenResources;

  @override
  State<CurrentScheduledLessonCard> createState() =>
      _CurrentScheduledLessonCardState();
}

class _CurrentScheduledLessonCardState extends State<CurrentScheduledLessonCard> {
  late Future<_CurrentLessonCardData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant CurrentScheduledLessonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.annualPlan != widget.annualPlan ||
        oldWidget.courseId != widget.courseId ||
        oldWidget.instructionContext != widget.instructionContext ||
        oldWidget.timeline != widget.timeline) {
      _future = _load();
    }
  }

  Future<_CurrentLessonCardData?> _load() async {
    final assignments = await widget.instructionContext.getAssignments(
      academicYear: widget.annualPlan.academicYear,
      courseId: widget.courseId,
    );
    if (assignments.isEmpty) return null;
    final classes = await widget.instructionContext.getClasses(
      widget.annualPlan.academicYear,
    );
    final snapshot = await widget.timeline.resolve(
      academicYear: widget.annualPlan.academicYear,
      courseId: widget.courseId,
    );

    ScheduledLessonOccurrence? current;
    TeachingAssignment? currentAssignment;
    for (final assignment in assignments) {
      final occurrence = snapshot.positionFor(assignment.id)?.currentOccurrence;
      if (occurrence == null) continue;
      if (current == null || occurrence.startsAt.isBefore(current.startsAt)) {
        current = occurrence;
        currentAssignment = assignment;
      }
    }

    if (current != null && currentAssignment != null) {
      final position = snapshot.positionFor(currentAssignment.id);
      final actualOrdinal = position?.actualOrdinal ?? current.plannedOrdinal;
      final selection = await LessonPlanWorkflowService(
        repository: widget.repository,
      ).selectionForInstructionOrdinal(widget.annualPlan, actualOrdinal);
      return _CurrentLessonCardData(
        state: _ScheduledCardState.current,
        assignment: currentAssignment,
        schoolClass: _schoolClass(classes, currentAssignment.classId),
        occurrence: current,
        selection: selection,
        actualOrdinal: actualOrdinal,
        delta: position?.delta ?? 0,
      );
    }

    ScheduledLessonOccurrence? next;
    TeachingAssignment? nextAssignment;
    for (final assignment in assignments) {
      final occurrence = snapshot.positionFor(assignment.id)?.nextOccurrence;
      if (occurrence == null) continue;
      if (next == null || occurrence.startsAt.isBefore(next.startsAt)) {
        next = occurrence;
        nextAssignment = assignment;
      }
    }
    if (next == null || nextAssignment == null) return null;

    final position = snapshot.positionFor(nextAssignment.id);
    final actualOrdinal = position == null
        ? next.plannedOrdinal
        : (position.actualOrdinal +
              (next.plannedOrdinal - position.plannedOrdinal));
    final safeActualOrdinal = actualOrdinal < 1 ? 1 : actualOrdinal;
    final selection = await LessonPlanWorkflowService(
      repository: widget.repository,
    ).selectionForInstructionOrdinal(widget.annualPlan, safeActualOrdinal);
    return _CurrentLessonCardData(
      state: _ScheduledCardState.next,
      assignment: nextAssignment,
      schoolClass: _schoolClass(classes, nextAssignment.classId),
      occurrence: next,
      selection: selection,
      actualOrdinal: safeActualOrdinal,
      delta: safeActualOrdinal - next.plannedOrdinal,
    );
  }

  Future<void> _open(_CurrentLessonCardData data) async {
    final selection = data.selection;
    if (selection == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SingleLessonPlanPage(
          repository: widget.repository,
          initialPackageId: selection.package.packageId,
          initialPackageHour: selection.packageHour,
          academicYear: widget.annualPlan.academicYear,
          assignmentId: data.assignment.id,
          assignmentProgressRepository: widget.progressRepository,
          onOpenResources: widget.onOpenResources,
        ),
      ),
    );
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_CurrentLessonCardData?>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final isCurrent = data.state == _ScheduledCardState.current;
      final selection = data.selection;
      final lessonTitle = selection?.lesson?.title.trim();
      final title = lessonTitle != null && lessonTitle.isNotEmpty
          ? lessonTitle
          : selection?.package.title;
      final className = data.schoolClass?.displayName ?? 'Sınıf';
      final timeLabel = isCurrent
          ? '${data.occurrence.slot.periodNumber}. ders saati'
          : '${_weekdayLabel(data.occurrence.date.weekday)} · ${_clock(data.occurrence.startsAt)} · ${data.occurrence.slot.periodNumber}. ders';

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Card(
          color: isCurrent ? scheme.primaryContainer : scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrent ? 'ŞİMDİKİ DERS' : 'SONRAKİ DERS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isCurrent
                        ? scheme.onPrimaryContainer
                        : scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data.delta != 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          data.delta < 0
                              ? '${-data.delta} ders geride'
                              : '${data.delta} ders ileride',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                if (title != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ],
                if (selection == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Bu ders saati okul temelli planlama alanına denk geliyor; açılacak tekil ders planı yok.',
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonalIcon(
                    onPressed: () => _open(data),
                    icon: const Icon(Icons.play_lesson_outlined),
                    label: Text(isCurrent ? 'Ders planını aç' : 'Planına bak'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CurrentLessonCardData {
  const _CurrentLessonCardData({
    required this.state,
    required this.assignment,
    required this.schoolClass,
    required this.occurrence,
    required this.selection,
    required this.actualOrdinal,
    required this.delta,
  });

  final _ScheduledCardState state;
  final TeachingAssignment assignment;
  final SchoolClass? schoolClass;
  final ScheduledLessonOccurrence occurrence;
  final WeeklyLessonPlanSelection? selection;
  final int actualOrdinal;
  final int delta;
}

enum _ScheduledCardState { current, next }

SchoolClass? _schoolClass(List<SchoolClass> classes, String classId) {
  for (final item in classes) {
    if (item.id == classId) return item;
  }
  return null;
}

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _weekdayLabel(int weekday) => switch (weekday) {
  DateTime.monday => 'Pazartesi',
  DateTime.tuesday => 'Salı',
  DateTime.wednesday => 'Çarşamba',
  DateTime.thursday => 'Perşembe',
  DateTime.friday => 'Cuma',
  DateTime.saturday => 'Cumartesi',
  _ => 'Pazar',
};
