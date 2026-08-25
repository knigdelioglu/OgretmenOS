import 'package:flutter/material.dart';

import '../../data/preferences/continuity_repository.dart';
import '../../data/preferences/user_preferences_repository.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';

class AnnualPlanPage extends StatefulWidget {
  const AnnualPlanPage({
    super.key,
    required this.repository,
    required this.preferences,
    required this.continuity,
    required this.courseId,
    this.outcomePlanning,
  });

  final CourseKnowledgeRepository repository;
  final UserPreferencesRepository preferences;
  final ContinuityRepository continuity;
  final String courseId;
  final OutcomePlanningService? outcomePlanning;

  @override
  State<AnnualPlanPage> createState() => _AnnualPlanPageState();
}

class _AnnualPlanPageState extends State<AnnualPlanPage> {
  late Future<_PlanData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AnnualPlanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _future = _load();
  }

  Future<_PlanData> _load() async {
    final sequence = await widget.repository.getAnnualSequence();
    final manual = await _getManualPosition();
    final lastFocus = await widget.continuity.getLastFocus(widget.courseId);
    final trackingSummary = await _loadTrackingSummary();
    var manualBlockId =
        sequence.any((entry) => entry.block.id == manual?.blockId)
        ? manual?.blockId
        : null;
    final automaticBlockId =
        sequence.any((entry) => entry.block.id == lastFocus?.blockId)
        ? lastFocus?.blockId
        : null;

    final manualIsStale =
        manualBlockId != null &&
        automaticBlockId != null &&
        lastFocus != null &&
        lastFocus.updatedAt.isAfter(manual!.updatedAt);
    if ((manual != null && manualBlockId == null) || manualIsStale) {
      manualBlockId = null;
      await _clearPositionPreferenceBestEffort();
    }

    return _PlanData(
      sequence: sequence,
      manualBlockId: manualBlockId,
      automaticBlockId: automaticBlockId,
      trackingSummary: trackingSummary,
    );
  }

  Future<_OptionalTrackingSummary?> _loadTrackingSummary() async {
    final service = widget.outcomePlanning;
    if (service == null) return null;
    try {
      final plan = await service.buildPlan();
      final courseTrackingKeys = <String>{
        for (final week in plan.weeks)
          for (final item in week.outcomes) item.trackingKey,
      };
      final records = await service.trackingRepository.getForAcademicYear(
        plan.academicYear,
      );
      final scopedRecords = records
          .where(
            (record) => courseTrackingKeys.contains(
              '${record.academicYear}:${record.outcomeId}:${record.plannedWeekNumber}',
            ),
          )
          .toList();
      final summary = _OptionalTrackingSummary.fromRecords(scopedRecords);
      return summary.hasExplicitStatus ? summary : null;
    } on Object {
      // Optional tracking summary must never block the annual lesson sequence.
      return null;
    }
  }

  Future<ManualPositionOverrideState?> _getManualPosition() async {
    final preferences = widget.preferences;
    if (preferences is ScopedManualPositionPreferences) {
      return (preferences as ScopedManualPositionPreferences)
          .getManualPositionOverrideForCourse(widget.courseId);
    }
    final blockId = await preferences.getManualPositionOverride();
    if (blockId == null) return null;
    return ManualPositionOverrideState(
      courseId: widget.courseId,
      blockId: blockId,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Future<void> _setPositionPreference(String blockId) async {
    final preferences = widget.preferences;
    if (preferences is ScopedManualPositionPreferences) {
      await (preferences as ScopedManualPositionPreferences)
          .setManualPositionOverrideForCourse(widget.courseId, blockId);
      return;
    }
    await preferences.setManualPositionOverride(blockId);
  }

  Future<void> _clearPositionPreference() async {
    final preferences = widget.preferences;
    if (preferences is ScopedManualPositionPreferences) {
      await (preferences as ScopedManualPositionPreferences)
          .clearManualPositionOverrideForCourse(widget.courseId);
      return;
    }
    await preferences.clearManualPositionOverride();
  }

  Future<void> _clearPositionPreferenceBestEffort() async {
    try {
      await _clearPositionPreference();
    } on Object {
      // Position preference is convenience state and must not block the plan.
    }
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setPosition(String blockId) async {
    await _setPositionPreference(blockId);
    if (mounted) _reload();
  }

  Future<void> _clearPosition() async {
    await _clearPositionPreference();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_PlanData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView(label: 'Yıllık plan hazırlanıyor…');
      }
      if (!snapshot.hasData) {
        return FeatureErrorView(
          message: 'Yıllık plan verileri yüklenemedi.',
          onRetry: _reload,
        );
      }

      final data = snapshot.data!;
      if (data.sequence.isEmpty) {
        return const Center(
          child: Text('Gösterilebilir yıllık plan bulunmuyor.'),
        );
      }

      final grouped = <String, List<model.TimelineEntry>>{};
      for (final entry in data.sequence) {
        grouped.putIfAbsent(entry.theme.id, () => []).add(entry);
      }
      final annualHours = grouped.values
          .map((entries) => entries.first.officialTotalHours ?? 0)
          .fold<int>(0, (a, b) => a + b);
      final activeBlockId = data.manualBlockId ?? data.automaticBlockId;
      final activeEntry = activeBlockId == null
          ? null
          : data.sequence.firstWhere(
              (entry) => entry.block.id == activeBlockId,
            );
      final isManualPosition =
          activeEntry != null && data.manualBlockId == activeEntry.block.id;

      return AppPage(
        children: [
          _AnnualSummary(
            themeCount: grouped.length,
            blockCount: data.sequence.length,
            annualHours: annualHours,
            activeEntry: activeEntry,
            isManualPosition: isManualPosition,
            trackingSummary: data.trackingSummary,
            onClear: _clearPosition,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < grouped.values.length; i++) ...[
            _ThemePlanCard(
              entries: grouped.values.elementAt(i),
              totalBlocks: data.sequence.length,
              activeBlockId: activeBlockId,
              manualBlockId: data.manualBlockId,
              initiallyExpanded: activeBlockId == null
                  ? i == 0
                  : grouped.values
                        .elementAt(i)
                        .any((entry) => entry.block.id == activeBlockId),
              onSelect: _setPosition,
              onOpen: (blockId) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlockDetailPage(
                    repository: widget.repository,
                    blockId: blockId,
                  ),
                ),
              ),
            ),
            if (i != grouped.values.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    },
  );
}

class _PlanData {
  const _PlanData({
    required this.sequence,
    required this.manualBlockId,
    required this.automaticBlockId,
    required this.trackingSummary,
  });

  final List<model.TimelineEntry> sequence;
  final String? manualBlockId;
  final String? automaticBlockId;
  final _OptionalTrackingSummary? trackingSummary;
}

class _AnnualSummary extends StatelessWidget {
  const _AnnualSummary({
    required this.themeCount,
    required this.blockCount,
    required this.annualHours,
    required this.activeEntry,
    required this.isManualPosition,
    required this.trackingSummary,
    required this.onClear,
  });

  final int themeCount;
  final int blockCount;
  final int annualHours;
  final model.TimelineEntry? activeEntry;
  final bool isManualPosition;
  final _OptionalTrackingSummary? trackingSummary;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$themeCount tema · $annualHours saat · $blockCount blok',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isManualPosition)
                IconButton(
                  tooltip: 'Geçici konum işaretini temizle',
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bloklara ayrı resmî süre verilmediğinde bu görünüm öğretim sırasını gösterir; süre uyarısı her blokta tekrar edilmez.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (activeEntry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ŞU AN BURADASIN',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${activeEntry!.theme.title} · ${activeEntry!.block.title}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isManualPosition
                        ? 'Elle işaretlendi · yeni bir ders açtığında otomatik güncellenir'
                        : 'Son görüntülenen ders odağı',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Öğretim sırası: ${activeEntry!.sequencePosition}. blok / $blockCount',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Bu konum bir ilerleme veya tamamlanma yüzdesi değildir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (trackingSummary != null) ...[
            const SizedBox(height: AppSpacing.md),
            _OptionalTrackingPanel(summary: trackingSummary!),
          ],
        ],
      ),
    ),
  );
}

class _OptionalTrackingSummary {
  const _OptionalTrackingSummary({
    required this.completed,
    required this.inProgress,
    required this.partiallyCompleted,
    required this.carriedOver,
  });

  factory _OptionalTrackingSummary.fromRecords(
    List<LearningOutcomeTrackingRecord> records,
  ) {
    var completed = 0;
    var inProgress = 0;
    var partiallyCompleted = 0;
    var carriedOver = 0;
    for (final record in records) {
      switch (record.status) {
        case OutcomeTrackingStatus.completed:
          completed++;
        case OutcomeTrackingStatus.inProgress:
          inProgress++;
        case OutcomeTrackingStatus.partiallyCompleted:
          partiallyCompleted++;
        case OutcomeTrackingStatus.carriedOver:
          carriedOver++;
        case OutcomeTrackingStatus.planned:
          break;
      }
    }
    return _OptionalTrackingSummary(
      completed: completed,
      inProgress: inProgress,
      partiallyCompleted: partiallyCompleted,
      carriedOver: carriedOver,
    );
  }

  final int completed;
  final int inProgress;
  final int partiallyCompleted;
  final int carriedOver;

  bool get hasExplicitStatus =>
      completed + inProgress + partiallyCompleted + carriedOver > 0;
}

class _OptionalTrackingPanel extends StatelessWidget {
  const _OptionalTrackingPanel({required this.summary});

  final _OptionalTrackingSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İSTEĞE BAĞLI TAKİP',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (summary.completed > 0)
                Chip(label: Text('İşlendi ${summary.completed}')),
              if (summary.inProgress > 0)
                Chip(label: Text('Devam ediyor ${summary.inProgress}')),
              if (summary.partiallyCompleted > 0)
                Chip(label: Text('Kısmen ${summary.partiallyCompleted}')),
              if (summary.carriedOver > 0)
                Chip(label: Text('Taşındı ${summary.carriedOver}')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Yalnız senin açıkça işaretlediğin durumları özetler; işaretlenmemiş kazanımlar eksik sayılmaz.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ThemePlanCard extends StatelessWidget {
  const _ThemePlanCard({
    required this.entries,
    required this.totalBlocks,
    required this.activeBlockId,
    required this.manualBlockId,
    required this.initiallyExpanded,
    required this.onSelect,
    required this.onOpen,
  });

  final List<model.TimelineEntry> entries;
  final int totalBlocks;
  final String? activeBlockId;
  final String? manualBlockId;
  final bool initiallyExpanded;
  final Future<void> Function(String blockId) onSelect;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final first = entries.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: CircleAvatar(child: Text('${first.theme.order}')),
        title: Text(
          first.theme.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            if (first.officialTotalHours != null)
              '${first.officialTotalHours} saat',
            '${entries.length} blok',
          ].join(' · '),
        ),
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.only(left: 20, right: 8),
              leading: SizedBox(
                width: 32,
                child: Text(
                  '${entries[i].sequencePosition}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: entries[i].block.id == activeBlockId
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: Text(entries[i].block.title),
              subtitle: Text(
                'Sıra ${entries[i].sequencePosition} / $totalBlocks',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: IconButton(
                tooltip: entries[i].block.id == manualBlockId
                    ? 'Geçici konum işareti'
                    : 'Burayı geçici olarak işaretle',
                onPressed: () => onSelect(entries[i].block.id),
                icon: Icon(
                  entries[i].block.id == manualBlockId
                      ? Icons.bookmark_added
                      : Icons.bookmark_add_outlined,
                ),
              ),
              onTap: () => onOpen(entries[i].block.id),
            ),
            if (i != entries.length - 1) const Divider(height: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}
