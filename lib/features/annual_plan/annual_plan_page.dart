import 'package:flutter/material.dart';

import '../../data/preferences/user_preferences_repository.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';
import '../shared/teacher_presentation.dart';

class AnnualPlanPage extends StatefulWidget {
  const AnnualPlanPage({
    super.key,
    required this.repository,
    required this.preferences,
  });

  final CourseKnowledgeRepository repository;
  final UserPreferencesRepository preferences;

  @override
  State<AnnualPlanPage> createState() => _AnnualPlanPageState();
}

class _AnnualPlanPageState extends State<AnnualPlanPage> {
  late Future<_PlanData> _future;
  final GlobalKey _selectedTimelineKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlanData> _load() async {
    final sequence = await widget.repository.getAnnualSequence();
    final manifest = await widget.repository.getManifest();
    final manual = await widget.preferences.getManualPositionOverride();
    final manualIsValid =
        manual != null && sequence.any((entry) => entry.block.id == manual);
    return _PlanData(
      sequence: sequence,
      manifest: manifest,
      manualPosition: manual,
      manualIsValid: manualIsValid,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _setPosition(String blockId) async {
    await widget.preferences.setManualPositionOverride(blockId);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _clearPosition() async {
    await widget.preferences.clearManualPositionOverride();
    if (!mounted) return;
    _refresh();
  }

  void _jumpToSelected() {
    final context = _selectedTimelineKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_PlanData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView(label: 'Yıllık plan hazırlanıyor…');
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Yıllık plan verileri yüklenemedi.',
          onRetry: _refresh,
        );
      }

      final data = snapshot.data!;
      final selectedEntry = data.selectedEntry;

      return AppPage(
        children: [
          const PageHeader(
            eyebrow: 'ÖĞRETİM ROTASI',
            title: 'Yıllık Plan',
            description:
                'Sınıfta kaldığınız konumu işaretleyin; önceki ve sıradaki blokları rota üzerinde görün.',
          ),
          _PlanOverview(
            data: data,
            selectedEntry: selectedEntry,
            onClear: _clearPosition,
            onJump: selectedEntry == null ? null : _jumpToSelected,
          ),
          if (data.sequence.isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const StatusPanel(
              icon: Icons.view_timeline_outlined,
              title: 'Plan sırası bulunmuyor',
              message: 'Bu ders için gösterilebilir öğretim sırası bulunmuyor.',
            ),
          ] else ...[
            SectionHeading(
              'Planlanan öğretim sırası',
              subtitle: '${data.sequence.length} blok · tema bazında gruplanmış rota',
              icon: Icons.route_outlined,
            ),
            _PlanTimeline(
              sequence: data.sequence,
              selectedBlockId: data.manualIsValid ? data.manualPosition : null,
              selectedPosition: selectedEntry?.sequencePosition,
              selectedKey: _selectedTimelineKey,
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
          ],
        ],
      );
    },
  );
}

class _PlanData {
  const _PlanData({
    required this.sequence,
    required this.manifest,
    required this.manualPosition,
    required this.manualIsValid,
  });

  final List<model.TimelineEntry> sequence;
  final model.RuntimeManifest manifest;
  final String? manualPosition;
  final bool manualIsValid;

  model.TimelineEntry? get selectedEntry {
    if (!manualIsValid || manualPosition == null) return null;
    for (final entry in sequence) {
      if (entry.block.id == manualPosition) return entry;
    }
    return null;
  }
}

class _PlanOverview extends StatelessWidget {
  const _PlanOverview({
    required this.data,
    required this.selectedEntry,
    required this.onClear,
    required this.onJump,
  });

  final _PlanData data;
  final model.TimelineEntry? selectedEntry;
  final VoidCallback onClear;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    final themeCount = data.sequence.map((entry) => entry.theme.id).toSet().length;
    final selected = selectedEntry;
    final next = selected == null
        ? null
        : data.sequence.where(
            (entry) => entry.sequencePosition == selected.sequencePosition + 1,
          ).firstOrNull;

    return Column(
      children: [
        if (selected == null)
          StatusPanel(
            icon: Icons.bookmark_add_outlined,
            title: 'Nerede kaldığınızı işaretleyin',
            message:
                'Aşağıdaki rota üzerinde bulunduğunuz blokta “Burada kaldım” simgesine dokunun.',
            action: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MetricChip(
                  icon: Icons.layers_outlined,
                  label: 'tema',
                  value: '$themeCount',
                ),
                MetricChip(
                  icon: Icons.view_timeline_outlined,
                  label: 'blok',
                  value: '${data.sequence.length}',
                ),
              ],
            ),
          )
        else
          _SelectedPlanCard(
            entry: selected,
            total: data.sequence.length,
            nextEntry: next,
            onClear: onClear,
            onJump: onJump!,
          ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Planlama bilgisi'),
            subtitle: const Text('Program sırası ve zaman çözünürlüğü'),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${teacherTimelineResolutionLabel(data.manifest.timelineResolution)}. Bu ekran sınıftaki gerçek konumu otomatik tarih eşlemesiyle varsaymaz; “Burada kaldım” işareti öğretmenin yerel tercihidir.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedPlanCard extends StatelessWidget {
  const _SelectedPlanCard({
    required this.entry,
    required this.total,
    required this.nextEntry,
    required this.onClear,
    required this.onJump,
  });

  final model.TimelineEntry entry;
  final int total;
  final model.TimelineEntry? nextEntry;
  final VoidCallback onClear;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bookmark_added, color: scheme.onSecondaryContainer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Burada kaldım',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        entry.block.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${entry.theme.title} · Plan sırası: ${entry.sequencePosition} / $total',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (nextEntry != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Sırada: ${nextEntry!.block.title}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onJump,
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('Rotada göster'),
                ),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('İşareti kaldır'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _RouteState { past, current, next, future }

class _PlanTimeline extends StatelessWidget {
  const _PlanTimeline({
    required this.sequence,
    required this.selectedBlockId,
    required this.selectedPosition,
    required this.selectedKey,
    required this.onSelect,
    required this.onOpen,
  });

  final List<model.TimelineEntry> sequence;
  final String? selectedBlockId;
  final int? selectedPosition;
  final GlobalKey selectedKey;
  final Future<void> Function(String blockId) onSelect;
  final void Function(String blockId) onOpen;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<model.TimelineEntry>>{};
    for (final entry in sequence) {
      grouped.putIfAbsent(entry.theme.id, () => []).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entries in grouped.values) ...[
          _ThemeTimelineHeader(entry: entries.first),
          for (var index = 0; index < entries.length; index++)
            _TimelineEntryCard(
              key: entries[index].block.id == selectedBlockId ? selectedKey : null,
              entry: entries[index],
              total: sequence.length,
              state: _stateFor(entries[index]),
              isLastInTheme: index == entries.length - 1,
              onSelect: () => onSelect(entries[index].block.id),
              onOpen: () => onOpen(entries[index].block.id),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }

  _RouteState _stateFor(model.TimelineEntry entry) {
    final selected = selectedPosition;
    if (selected == null) return _RouteState.future;
    if (entry.sequencePosition < selected) return _RouteState.past;
    if (entry.sequencePosition == selected) return _RouteState.current;
    if (entry.sequencePosition == selected + 1) return _RouteState.next;
    return _RouteState.future;
  }
}

class _ThemeTimelineHeader extends StatelessWidget {
  const _ThemeTimelineHeader({required this.entry});

  final model.TimelineEntry entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${entry.theme.order}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                entry.theme.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (entry.officialTotalHours != null)
                Text(
                  '${entry.officialTotalHours} saatlik tema planı',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TimelineEntryCard extends StatelessWidget {
  const _TimelineEntryCard({
    super.key,
    required this.entry,
    required this.total,
    required this.state,
    required this.isLastInTheme,
    required this.onSelect,
    required this.onOpen,
  });

  final model.TimelineEntry entry;
  final int total;
  final _RouteState state;
  final bool isLastInTheme;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = state == _RouteState.current;
    final isPast = state == _RouteState.past;
    final isNext = state == _RouteState.next;
    final cardColor = isCurrent
        ? scheme.secondaryContainer
        : isNext
        ? scheme.primaryContainer.withValues(alpha: 0.6)
        : isPast
        ? scheme.surfaceContainerLow
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? scheme.primary
                        : isPast
                        ? scheme.surfaceContainerHighest
                        : scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPast ? Icons.check : isCurrent ? Icons.my_location : null,
                    size: 16,
                    color: isCurrent ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
                if (!isLastInTheme)
                  Expanded(
                    child: Container(width: 2, color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                color: cardColor,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.block.title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Plan sırası: ${entry.sequencePosition} / $total',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (isCurrent || isNext) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      isCurrent ? 'Mevcut işaretli konum' : 'Sıradaki blok',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: onSelect,
                              icon: Icon(
                                isCurrent
                                    ? Icons.bookmark_added
                                    : Icons.bookmark_add_outlined,
                              ),
                              label: Text(isCurrent ? 'Burada kaldım' : 'Burada kaldım'),
                            ),
                            Text(
                              teacherBlockTimeLabel(entry.block.timeStatus),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
