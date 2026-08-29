import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/resource_navigation.dart';
import '../../data/preferences/continuity_repository.dart';
import '../../domain/models/instruction_context_models.dart';
import '../../domain/models/instruction_timeline_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/assignment_lesson_progress_repository.dart';
import '../../domain/repositories/assignment_outcome_tracking_adapter.dart';
import '../../domain/repositories/assignment_outcome_tracking_repository.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/instruction_context_repository.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/repositories/selected_assignment_instruction_context_repository.dart';
import '../../domain/services/assignment_lesson_timeline_service.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../outcomes/outcome_detail_page.dart';
import '../shared/feature_widgets.dart';
import 'current_scheduled_lesson_card.dart';
import 'this_week_page.dart';

class ContinuityThisWeekPage extends StatefulWidget {
  const ContinuityThisWeekPage({
    super.key,
    required this.repository,
    required this.service,
    required this.continuity,
    required this.courseId,
    this.topTrailing,
    this.lessonPlanProgress,
    this.instructionContext,
    this.assignmentLessonProgress,
    this.assignmentOutcomeTracking,
    this.assignmentTimeline,
    this.onConfigureSchedule,
    this.onOpenResources,
  });

  final CourseKnowledgeRepository repository;
  final OutcomePlanningService service;
  final ContinuityRepository continuity;
  final LessonPlanProgressRepository? lessonPlanProgress;
  final InstructionContextRepository? instructionContext;
  final AssignmentLessonProgressRepository? assignmentLessonProgress;
  final AssignmentOutcomeTrackingRepository? assignmentOutcomeTracking;
  final AssignmentLessonTimelineService? assignmentTimeline;
  final String courseId;
  final Widget? topTrailing;
  final VoidCallback? onConfigureSchedule;
  final ResourceNavigationCallback? onOpenResources;

  @override
  State<ContinuityThisWeekPage> createState() => _ContinuityThisWeekPageState();
}

class _ContinuityThisWeekPageState extends State<ContinuityThisWeekPage> {
  static const _automaticSelectionValue = '__automatic_assignment__';

  late Future<_ContinuityData> _future;
  int _workspaceRevision = 0;
  String? _selectedAssignmentId;
  bool _assignmentSelectionPinned = false;
  Timer? _timelineRefreshTimer;
  DateTime? _scheduledTimelineRefreshAt;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ContinuityThisWeekPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.service != widget.service ||
        oldWidget.continuity != widget.continuity ||
        oldWidget.lessonPlanProgress != widget.lessonPlanProgress ||
        oldWidget.instructionContext != widget.instructionContext ||
        oldWidget.assignmentLessonProgress != widget.assignmentLessonProgress ||
        oldWidget.assignmentOutcomeTracking != widget.assignmentOutcomeTracking ||
        oldWidget.assignmentTimeline != widget.assignmentTimeline ||
        oldWidget.courseId != widget.courseId) {
      _cancelTimelineRefresh();
      _workspaceRevision++;
      _selectedAssignmentId = null;
      _assignmentSelectionPinned = false;
      _future = _load();
    }
  }

  @override
  void dispose() {
    _timelineRefreshTimer?.cancel();
    super.dispose();
  }

  Future<_ContinuityData> _load() async {
    final basePlan = await widget.service.buildPlan();
    var activeService = widget.service;
    var activePlan = basePlan;
    var selectedContext = widget.instructionContext;
    var continuityScopeId = widget.courseId;
    var choices = const <_AssignmentChoice>[];
    var scheduleReady = false;
    DateTime? timelineRefreshAt;

    final instructionContext = widget.instructionContext;
    final timeline = widget.assignmentTimeline;
    if (instructionContext != null && timeline != null) {
      final assignments = await instructionContext.getAssignments(
        academicYear: basePlan.academicYear,
        courseId: widget.courseId,
      );
      if (assignments.isNotEmpty) {
        final classes = await instructionContext.getClasses(basePlan.academicYear);
        final snapshot = await timeline.resolve(
          academicYear: basePlan.academicYear,
          courseId: widget.courseId,
        );
        timelineRefreshAt = _nextTimelineRefresh(snapshot);
        final selectedId = _resolveAssignmentId(assignments, snapshot);
        _selectedAssignmentId = selectedId;
        if (selectedId != null) {
          selectedContext = SelectedAssignmentInstructionContextRepository(
            delegate: instructionContext,
            assignmentId: selectedId,
          );
          continuityScopeId = '${widget.courseId}::$selectedId';
          final periods = await instructionContext.getBellPeriods();
          final slots = await instructionContext.getScheduleSlotsForAssignment(
            selectedId,
          );
          scheduleReady =
              periods.isNotEmpty &&
              slots.length == basePlan.weeklyPlan.weeklyLessonHours;
          final assignmentTracking = widget.assignmentOutcomeTracking;
          if (assignmentTracking != null) {
            activeService = OutcomePlanningService(
              repository: widget.repository,
              weeklyPlanning: widget.service.weeklyPlanning,
              trackingRepository: AssignmentOutcomeTrackingAdapter(
                repository: assignmentTracking,
                assignmentId: selectedId,
                academicYear: basePlan.academicYear,
              ),
              onInteraction: widget.service.onInteraction,
            );
            activePlan = await activeService.buildPlan();
          }
        }
        choices = [
          for (final assignment in assignments)
            _AssignmentChoice(
              assignmentId: assignment.id,
              label: _className(classes, assignment.classId),
            ),
        ];
      }
    }

    final stored = await _readLastFocusBestEffort(continuityScopeId);
    if (stored == null) {
      return _ContinuityData(
        plan: activePlan,
        service: activeService,
        instructionContext: selectedContext,
        continuityScopeId: continuityScopeId,
        choices: choices,
        selectedAssignmentId: _selectedAssignmentId,
        scheduleReady: scheduleReady,
        timelineRefreshAt: timelineRefreshAt,
      );
    }
    if (stored.academicYear != activePlan.academicYear) {
      await _clearLastFocusBestEffort(continuityScopeId);
      return _ContinuityData(
        plan: activePlan,
        service: activeService,
        instructionContext: selectedContext,
        continuityScopeId: continuityScopeId,
        choices: choices,
        selectedAssignmentId: _selectedAssignmentId,
        scheduleReady: scheduleReady,
        timelineRefreshAt: timelineRefreshAt,
      );
    }

    final item = _resolveFocus(activePlan, stored);
    if (item == null) {
      await _clearLastFocusBestEffort(continuityScopeId);
      return _ContinuityData(
        plan: activePlan,
        service: activeService,
        instructionContext: selectedContext,
        continuityScopeId: continuityScopeId,
        choices: choices,
        selectedAssignmentId: _selectedAssignmentId,
        scheduleReady: scheduleReady,
        timelineRefreshAt: timelineRefreshAt,
      );
    }
    return _ContinuityData(
      plan: activePlan,
      service: activeService,
      instructionContext: selectedContext,
      continuityScopeId: continuityScopeId,
      choices: choices,
      selectedAssignmentId: _selectedAssignmentId,
      scheduleReady: scheduleReady,
      timelineRefreshAt: timelineRefreshAt,
      stored: stored,
      item: item,
    );
  }

  DateTime? _nextTimelineRefresh(InstructionTimelineSnapshot snapshot) {
    final candidates = <DateTime>[
      if (snapshot.currentOccurrence?.endsAt case final end?) end,
      if (snapshot.nextOccurrence?.startsAt case final start?) start,
    ].where((item) => item.isAfter(snapshot.now)).toList(growable: false)
      ..sort();
    return candidates.isEmpty ? null : candidates.first;
  }

  void _scheduleTimelineRefresh(DateTime? target) {
    if (target == null) {
      _cancelTimelineRefresh();
      return;
    }
    if (_scheduledTimelineRefreshAt == target &&
        _timelineRefreshTimer?.isActive == true) {
      return;
    }
    _timelineRefreshTimer?.cancel();
    _scheduledTimelineRefreshAt = target;
    final rawDelay = target.difference(DateTime.now());
    final delay = rawDelay.isNegative || rawDelay == Duration.zero
        ? const Duration(milliseconds: 250)
        : rawDelay + const Duration(milliseconds: 150);
    _timelineRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      _scheduledTimelineRefreshAt = null;
      setState(() {
        _workspaceRevision += 1;
        _future = _load();
      });
    });
  }

  void _cancelTimelineRefresh() {
    _timelineRefreshTimer?.cancel();
    _timelineRefreshTimer = null;
    _scheduledTimelineRefreshAt = null;
  }

  String? _resolveAssignmentId(
    List<TeachingAssignment> assignments,
    InstructionTimelineSnapshot snapshot,
  ) {
    final selected = _selectedAssignmentId;
    if (_assignmentSelectionPinned &&
        selected != null &&
        assignments.any((item) => item.id == selected)) {
      return selected;
    }

    final currentId = snapshot.currentOccurrence?.assignmentId;
    if (currentId != null && assignments.any((item) => item.id == currentId)) {
      return currentId;
    }

    final nextId = snapshot.nextOccurrence?.assignmentId;
    if (nextId != null && assignments.any((item) => item.id == nextId)) {
      return nextId;
    }

    DateTime? latestAt;
    String? latestId;
    for (final assignment in assignments) {
      final previous = snapshot.positionFor(assignment.id)?.previousOccurrence;
      if (previous == null) continue;
      if (latestAt == null || previous.startsAt.isAfter(latestAt)) {
        latestAt = previous.startsAt;
        latestId = assignment.id;
      }
    }
    return latestId ?? assignments.first.id;
  }

  String _className(List<SchoolClass> classes, String classId) {
    for (final item in classes) {
      if (item.id == classId) return item.displayName;
    }
    return classId;
  }

  Future<LastFocusState?> _readLastFocusBestEffort(String scopeId) async {
    try {
      return await widget.continuity.getLastFocus(scopeId);
    } on Object {
      return null;
    }
  }

  Future<void> _clearLastFocusBestEffort(String scopeId) async {
    try {
      await widget.continuity.clearLastFocus(scopeId);
    } on Object {
      // Stale continuity cleanup must never block the weekly workspace.
    }
  }

  TrackedOutcome? _resolveFocus(AnnualOutcomePlan plan, LastFocusState stored) {
    final preferredWeek = plan.week(stored.weekNumber);
    if (preferredWeek != null) {
      for (final item in preferredWeek.outcomes) {
        if (item.trackingKey == stored.trackingKey) return item;
      }
    }
    for (final summary in plan.weeks) {
      for (final item in summary.outcomes) {
        if (item.trackingKey == stored.trackingKey) return item;
      }
    }
    return null;
  }

  void _reload() {
    setState(() {
      _workspaceRevision += 1;
      _future = _load();
    });
  }

  void _handleAssignmentSelection(String value) {
    _cancelTimelineRefresh();
    if (value == _automaticSelectionValue) {
      setState(() {
        _assignmentSelectionPinned = false;
        _selectedAssignmentId = null;
        _workspaceRevision += 1;
        _future = _load();
      });
      return;
    }
    if (_assignmentSelectionPinned && _selectedAssignmentId == value) return;
    setState(() {
      _assignmentSelectionPinned = true;
      _selectedAssignmentId = value;
      _workspaceRevision += 1;
      _future = _load();
    });
  }

  Future<void> _rememberViewed(
    TrackedOutcome item,
    String continuityScopeId,
  ) async {
    final now = DateTime.now();
    final scopedState = LastFocusState(
      courseId: continuityScopeId,
      academicYear: item.academicYear,
      weekNumber: item.displayWeekNumber,
      trackingKey: item.trackingKey,
      outcomeCode: item.outcome.code,
      themeTitle: item.primaryTheme?.title,
      themeId: item.primaryTheme?.id,
      blockId: item.primaryBlock?.id,
      blockTitle: item.primaryBlock?.title,
      updatedAt: now,
    );
    await widget.continuity.setLastFocus(scopedState);

    // Resources and Annual remain course-scoped. Mirror only the last-viewed
    // context; this is convenience state and never copies tracking status.
    if (continuityScopeId != widget.courseId) {
      try {
        await widget.continuity.setLastFocus(
          LastFocusState(
            courseId: widget.courseId,
            academicYear: item.academicYear,
            weekNumber: item.displayWeekNumber,
            trackingKey: item.trackingKey,
            outcomeCode: item.outcome.code,
            themeTitle: item.primaryTheme?.title,
            themeId: item.primaryTheme?.id,
            blockId: item.primaryBlock?.id,
            blockTitle: item.primaryBlock?.title,
            updatedAt: now,
          ),
        );
      } on Object {
        // Course-wide convenience context must never block lesson navigation.
      }
    }
  }

  Future<void> _resume(_ContinuityData data) async {
    final item = data.item;
    if (item == null) return;
    try {
      await _rememberViewed(item, data.continuityScopeId);
    } on Object {
      // Resume must remain available even if preference persistence fails.
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OutcomeDetailPage(
          repository: widget.repository,
          service: data.service,
          initialPlan: data.plan,
          initialItem: item,
        ),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Widget _assignmentSelector(_ContinuityData data) {
    if (data.choices.isEmpty) return const SizedBox.shrink();
    final selected = data.selectedAssignmentId;
    var selectedLabel = data.choices.first.label;
    for (final choice in data.choices) {
      if (choice.assignmentId == selected) selectedLabel = choice.label;
    }
    if (data.choices.length == 1) {
      return Chip(
        avatar: const Icon(Icons.class_outlined, size: 18),
        label: Text(selectedLabel),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Sınıf/şube seç',
      onSelected: _handleAssignmentSelection,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _automaticSelectionValue,
          child: Row(
            children: [
              if (!_assignmentSelectionPinned)
                const Icon(Icons.check, size: 18)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Ders programına göre otomatik')),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final choice in data.choices)
          PopupMenuItem<String>(
            value: choice.assignmentId,
            child: Row(
              children: [
                if (_assignmentSelectionPinned &&
                    choice.assignmentId == selected)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(choice.label),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: Icon(
          _assignmentSelectionPinned
              ? Icons.class_outlined
              : Icons.auto_mode_rounded,
          size: 18,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selectedLabel),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _topTrailing(_ContinuityData data) => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    children: [
      _assignmentSelector(data),
      if (widget.topTrailing != null) widget.topTrailing!,
    ],
  );

  Widget _workspace(BuildContext context, _ContinuityData data) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dashboardTheme = theme.copyWith(
      colorScheme: scheme.copyWith(
        primaryContainer: scheme.surface,
        onPrimaryContainer: scheme.onSurface,
      ),
      cardTheme: theme.cardTheme.copyWith(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
    return Theme(
      data: dashboardTheme,
      child: ThisWeekPage(
        key: ValueKey('$_workspaceRevision:${data.selectedAssignmentId}'),
        repository: widget.repository,
        service: data.service,
        lessonPlanProgress: widget.lessonPlanProgress,
        instructionContext: data.instructionContext,
        assignmentLessonProgress: widget.assignmentLessonProgress,
        assignmentTimeline: widget.assignmentTimeline,
        courseId: widget.courseId,
        onConfigureSchedule: widget.onConfigureSchedule,
        onOutcomeViewed: (item) =>
            _rememberViewed(item, data.continuityScopeId),
        initialPlanFuture: Future.value(data.plan),
        topTrailing: _topTrailing(data),
        onOpenResources: widget.onOpenResources,
      ),
    );
  }

  bool _hasCurrentLessonCard(_ContinuityData data) =>
      data.scheduleReady &&
      data.selectedAssignmentId != null &&
      data.instructionContext != null &&
      widget.assignmentLessonProgress != null &&
      widget.assignmentTimeline != null;

  Widget _content(BuildContext context, _ContinuityData data) {
    final hasCurrentCard = _hasCurrentLessonCard(data);
    final hasResume = data.item != null && data.stored != null;
    final needsScheduleSetup =
        data.choices.isNotEmpty &&
        data.selectedAssignmentId != null &&
        !data.scheduleReady &&
        widget.onConfigureSchedule != null;
    if (!hasCurrentCard && !hasResume && !needsScheduleSetup) {
      return _workspace(context, data);
    }

    return NestedScrollView(
      physics: const ClampingScrollPhysics(),
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        if (needsScheduleSetup)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _ScheduleSetupBanner(
                  weeklyHours: data.plan.weeklyPlan.weeklyLessonHours,
                  onConfigure: widget.onConfigureSchedule!,
                ),
              ),
            ),
          ),
        if (hasCurrentCard)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: CurrentScheduledLessonCard(
                    repository: widget.repository,
                    annualPlan: data.plan,
                    courseId: widget.courseId,
                    instructionContext: data.instructionContext!,
                    timeline: widget.assignmentTimeline!,
                    progressRepository: widget.assignmentLessonProgress!,
                    onOpenResources: widget.onOpenResources,
                  ),
                ),
              ),
            ),
          ),
        if (hasResume)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _ResumeBanner(
                  state: data.stored!,
                  item: data.item!,
                  onResume: () => _resume(data),
                ),
              ),
            ),
          ),
      ],
      body: _workspace(context, data),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ContinuityData>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const LoadingView(label: 'Bu hafta hazırlanıyor…');
      }
      final data = snapshot.data!;
      _scheduleTimelineRefresh(data.timelineRefreshAt);
      return _content(context, data);
    },
  );
}

class _ContinuityData {
  const _ContinuityData({
    required this.plan,
    required this.service,
    required this.instructionContext,
    required this.continuityScopeId,
    required this.choices,
    required this.selectedAssignmentId,
    required this.scheduleReady,
    required this.timelineRefreshAt,
    this.stored,
    this.item,
  });

  final AnnualOutcomePlan plan;
  final OutcomePlanningService service;
  final InstructionContextRepository? instructionContext;
  final String continuityScopeId;
  final List<_AssignmentChoice> choices;
  final String? selectedAssignmentId;
  final bool scheduleReady;
  final DateTime? timelineRefreshAt;
  final LastFocusState? stored;
  final TrackedOutcome? item;
}

class _AssignmentChoice {
  const _AssignmentChoice({required this.assignmentId, required this.label});

  final String assignmentId;
  final String label;
}

class _ScheduleSetupBanner extends StatelessWidget {
  const _ScheduleSetupBanner({
    required this.weeklyHours,
    required this.onConfigure,
  });

  final int weeklyHours;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Card(
        color: scheme.secondaryContainer.withValues(alpha: 0.52),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.edit_calendar_outlined,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ders programını tamamla',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'ŞU AN dersini otomatik bulmak için seçili şubede haftalık $weeklyHours ders saatinin tamamı tanımlı olmalı.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onConfigure,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSecondaryContainer,
                ),
                child: const Text('Düzenle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({
    required this.state,
    required this.item,
    required this.onResume,
  });

  final LastFocusState state;
  final TrackedOutcome item;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = state.blockTitle ?? item.primaryBlock?.title;
    final theme = state.themeTitle ?? item.primaryTheme?.title;
    final contextLabel = [?theme, ?block].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Card(
        color: scheme.tertiaryContainer.withValues(alpha: 0.58),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kaldığın yer',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        '${state.weekNumber}. Hafta',
                        state.outcomeCode,
                        if (contextLabel.isNotEmpty) contextLabel,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Devam et'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
