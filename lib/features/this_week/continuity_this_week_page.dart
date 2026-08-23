import 'package:flutter/material.dart';

import '../../data/preferences/continuity_repository.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
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
  });

  final CourseKnowledgeRepository repository;
  final OutcomePlanningService service;
  final ContinuityRepository continuity;
  final String courseId;

  @override
  State<ContinuityThisWeekPage> createState() => _ContinuityThisWeekPageState();
}

class _ContinuityThisWeekPageState extends State<ContinuityThisWeekPage> {
  late Future<_ContinuityData> _future;
  int _workspaceRevision = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ContinuityThisWeekPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _future = _load();
  }

  Future<_ContinuityData> _load() async {
    final results = await Future.wait<Object?>([
      widget.service.buildPlan(),
      widget.continuity.getLastFocus(widget.courseId),
    ]);
    final plan = results[0] as AnnualOutcomePlan;
    final stored = results[1] as LastFocusState?;
    if (stored == null) return _ContinuityData(plan: plan);
    if (stored.academicYear != plan.academicYear) {
      await widget.continuity.clearLastFocus(widget.courseId);
      return _ContinuityData(plan: plan);
    }

    final item = _resolveFocus(plan, stored);
    if (item == null || !_isRestorable(item)) {
      await widget.continuity.clearLastFocus(widget.courseId);
      return _ContinuityData(plan: plan);
    }
    return _ContinuityData(plan: plan, stored: stored, item: item);
  }

  TrackedOutcome? _resolveFocus(AnnualOutcomePlan plan, LastFocusState stored) {
    final preferredWeek = plan.week(stored.weekNumber);
    if (preferredWeek != null) {
      for (final item in preferredWeek.outcomes) {
        if (item.trackingKey == stored.trackingKey && _isRestorable(item)) {
          return item;
        }
      }
    }
    for (final summary in plan.weeks) {
      for (final item in summary.outcomes) {
        if (item.trackingKey == stored.trackingKey &&
            item.isCarriedIn &&
            _isRestorable(item)) {
          return item;
        }
      }
    }
    return null;
  }

  bool _isRestorable(TrackedOutcome item) {
    if (item.presentationStatus == OutcomeTrackingStatus.completed) return false;
    final carriedOut = !item.isCarriedIn && item.carriedToWeekNumber != null;
    return !carriedOut;
  }

  void _reload() {
    setState(() {
      _workspaceRevision += 1;
      _future = _load();
    });
  }

  Future<void> _resume(_ContinuityData data) async {
    final item = data.item;
    if (item == null) return;
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

  @override
  Widget build(BuildContext context) => FutureBuilder<_ContinuityData>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      return Column(
        children: [
          if (data?.item != null && data?.stored != null)
            _ResumeCard(
              state: data!.stored!,
              item: data.item!,
              onResume: () => _resume(data),
            ),
          Expanded(
            child: ThisWeekPage(
              key: ValueKey(_workspaceRevision),
              repository: widget.repository,
              service: widget.service,
            ),
          ),
        ],
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

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Card(
        color: scheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KALDIĞIN YER',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${state.weekNumber}. Hafta · ${state.outcomeCode}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (block != null || theme != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [if (theme != null) theme, if (block != null) block].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Devam et'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
