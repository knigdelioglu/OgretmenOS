import 'package:flutter/material.dart';

import '../../data/preferences/continuity_repository.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../outcomes/outcome_detail_page.dart';
import '../shared/feature_widgets.dart';
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
  });

  final CourseKnowledgeRepository repository;
  final OutcomePlanningService service;
  final ContinuityRepository continuity;
  final LessonPlanProgressRepository? lessonPlanProgress;
  final String courseId;
  final Widget? topTrailing;

  @override
  State<ContinuityThisWeekPage> createState() => _ContinuityThisWeekPageState();
}

class _ContinuityThisWeekPageState extends State<ContinuityThisWeekPage> {
  late Future<_ContinuityData> _future;
  late Future<AnnualOutcomePlan> _planFuture;
  int _workspaceRevision = 0;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant ContinuityThisWeekPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.service != widget.service ||
        oldWidget.continuity != widget.continuity ||
        oldWidget.lessonPlanProgress != widget.lessonPlanProgress ||
        oldWidget.courseId != widget.courseId) {
      _workspaceRevision++;
      _startLoad();
    }
  }

  void _startLoad() {
    _planFuture = widget.service.buildPlan();
    _future = _load(_planFuture);
  }

  Future<_ContinuityData> _load(Future<AnnualOutcomePlan> planFuture) async {
    final plan = await planFuture;
    final stored = await _readLastFocusBestEffort();
    if (stored == null) return _ContinuityData(plan: plan);
    if (stored.academicYear != plan.academicYear) {
      await _clearLastFocusBestEffort();
      return _ContinuityData(plan: plan);
    }

    final item = _resolveFocus(plan, stored);
    if (item == null) {
      await _clearLastFocusBestEffort();
      return _ContinuityData(plan: plan);
    }
    return _ContinuityData(plan: plan, stored: stored, item: item);
  }

  Future<LastFocusState?> _readLastFocusBestEffort() async {
    try {
      return await widget.continuity.getLastFocus(widget.courseId);
    } on Object {
      return null;
    }
  }

  Future<void> _clearLastFocusBestEffort() async {
    try {
      await widget.continuity.clearLastFocus(widget.courseId);
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
      _startLoad();
    });
  }

  Future<void> _rememberViewed(TrackedOutcome item) =>
      widget.continuity.setLastFocus(
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
          updatedAt: DateTime.now(),
        ),
      );

  Future<void> _resume(_ContinuityData data) async {
    final item = data.item;
    if (item == null) return;
    try {
      await _rememberViewed(item);
    } on Object {
      // Resume must remain available even if preference persistence fails.
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OutcomeDetailPage(
          repository: widget.repository,
          service: widget.service,
          initialPlan: data.plan,
          initialItem: item,
        ),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Widget _workspace(BuildContext context) {
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
        key: ValueKey(_workspaceRevision),
        repository: widget.repository,
        service: widget.service,
        lessonPlanProgress: widget.lessonPlanProgress,
        onOutcomeViewed: _rememberViewed,
        initialPlanFuture: _planFuture,
        topTrailing: widget.topTrailing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ContinuityData>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data?.item == null || data?.stored == null) {
        return _workspace(context);
      }

      return NestedScrollView(
        physics: const ClampingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _ResumeBanner(
                  state: data!.stored!,
                  item: data.item!,
                  onResume: () => _resume(data),
                ),
              ),
            ),
          ),
        ],
        body: _workspace(context),
      );
    },
  );
}

class _ContinuityData {
  const _ContinuityData({required this.plan, this.stored, this.item});

  final AnnualOutcomePlan plan;
  final LastFocusState? stored;
  final TrackedOutcome? item;
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
