import 'package:flutter/material.dart';

import '../../data/preferences/user_preferences_repository.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';

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
    if (mounted) _refresh();
  }

  Future<void> _clearPosition() async {
    await widget.preferences.clearManualPositionOverride();
    if (mounted) _refresh();
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
      model.TimelineEntry? selectedEntry;
      if (data.manualIsValid) {
        for (final entry in data.sequence) {
          if (entry.block.id == data.manualPosition) {
            selectedEntry = entry;
            break;
          }
        }
      }

      return AppPage(
        children: [
          const PageHeader(
            eyebrow: 'ÖĞRETİM ROTASI',
            title: 'Yıllık Plan',
            description:
                'Dersin doğrulanmış öğretim sırasını izleyin ve sınıfta kaldığınız konumu işaretleyin.',
          ),
          _PlanOverview(
            data: data,
            selectedEntry: selectedEntry,
            onClear: _clearPosition,
          ),
          if (data.sequence.isEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const StatusPanel(
              icon: Icons.view_timeline_outlined,
              title: 'Plan sırası bulunmuyor',
              message: 'Bu ders için gösterilebilir öğretim sırası bulunmuyor.',
            ),
          ] else ...[
            SectionHeading(
              'Planlanan öğretim sırası',
              subtitle: '${data.sequence.length} blok · tema sırasına göre',
              icon: Icons.route_outlined,
            ),
            _PlanTimeline(
              sequence: data.sequence,
              selectedBlockId: data.manualIsValid ? data.manualPosition : null,
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
}

class _PlanOverview extends StatelessWidget {
  const _PlanOverview({
    required this.data,
    required this.selectedEntry,
    required this.onClear,
  });

  final _PlanData data;
  final model.TimelineEntry? selectedEntry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final themeCount = data.sequence.map((entry) => entry.theme.id).toSet().length;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
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
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${timelineResolutionLabel(data.manifest.timelineResolution)}. Takvim eşlemesi doğrulanmadığı için tarih üzerinden otomatik ders konumu gösterilmez.',
                        style: const TextStyle(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (selectedEntry == null)
          const StatusPanel(
            icon: Icons.bookmark_add_outlined,
            title: 'Henüz bir plan konumu seçilmedi',
            message:
                'Aşağıdaki bloklardan birinde “Burada kaldım” seçeneğini kullanarak sınıfınızın plan konumunu işaretleyin.',
          )
        else
          _SelectedPlanCard(
            entry: selectedEntry!,
            total: data.sequence.length,
            onClear: onClear,
          ),
      ],
    );
  }
}

class _SelectedPlanCard extends StatelessWidget {
  const _SelectedPlanCard({
    required this.entry,
    required this.total,
    required this.onClear,
  });

  final model.TimelineEntry entry;
  final int total;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bookmark_added,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Burada kaldım',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.block.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${entry.theme.title} · Plan sırası: ${entry.sequencePosition} / $total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Plan sırasına dön'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlanTimeline extends StatelessWidget {
  const _PlanTimeline({
    required this.sequence,
    required this.selectedBlockId,
    required this.onSelect,
    required this.onOpen,
  });

  final List<model.TimelineEntry> sequence;
  final String? selectedBlockId;
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
              entry: entries[index],
              total: sequence.length,
              isSelected: entries[index].block.id == selectedBlockId,
              isLastInTheme: index == entries.length - 1,
              onSelect: () => onSelect(entries[index].block.id),
              onOpen: () => onOpen(entries[index].block.id),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
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
    required this.entry,
    required this.total,
    required this.isSelected,
    required this.isLastInTheme,
    required this.onSelect,
    required this.onOpen,
  });

  final model.TimelineEntry entry;
  final int total;
  final bool isSelected;
  final bool isLastInTheme;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
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
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${entry.sequencePosition}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isLastInTheme)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Card(
              color: isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.block.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Plan sırası: ${entry.sequencePosition} / $total',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (entry.block.timeStatus != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                blockTimeStatusLabel(entry.block.timeStatus!),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        tooltip: isSelected ? 'Seçili plan konumu' : 'Burada kaldım',
                        onPressed: onSelect,
                        icon: Icon(
                          isSelected
                              ? Icons.bookmark_added
                              : Icons.bookmark_add_outlined,
                        ),
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
