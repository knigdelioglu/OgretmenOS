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
    final manual = await widget.preferences.getManualPositionOverride();
    return _PlanData(
      sequence: sequence,
      selectedBlockId: sequence.any((entry) => entry.block.id == manual)
          ? manual
          : null,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setPosition(String blockId) async {
    await widget.preferences.setManualPositionOverride(blockId);
    if (mounted) _reload();
  }

  Future<void> _clearPosition() async {
    await widget.preferences.clearManualPositionOverride();
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
        return const Center(child: Text('Gösterilebilir yıllık plan bulunmuyor.'));
      }

      final grouped = <String, List<model.TimelineEntry>>{};
      for (final entry in data.sequence) {
        grouped.putIfAbsent(entry.theme.id, () => []).add(entry);
      }
      final annualHours = grouped.values
          .map((entries) => entries.first.officialTotalHours ?? 0)
          .fold<int>(0, (a, b) => a + b);
      final selectedEntry = data.selectedBlockId == null
          ? null
          : data.sequence.firstWhere(
              (entry) => entry.block.id == data.selectedBlockId,
            );

      return AppPage(
        children: [
          _AnnualSummary(
            themeCount: grouped.length,
            blockCount: data.sequence.length,
            annualHours: annualHours,
            selectedEntry: selectedEntry,
            onClear: _clearPosition,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < grouped.values.length; i++) ...[
            _ThemePlanCard(
              entries: grouped.values.elementAt(i),
              totalBlocks: data.sequence.length,
              selectedBlockId: data.selectedBlockId,
              initiallyExpanded: data.selectedBlockId == null
                  ? i == 0
                  : grouped.values
                      .elementAt(i)
                      .any((entry) => entry.block.id == data.selectedBlockId),
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
  const _PlanData({required this.sequence, required this.selectedBlockId});

  final List<model.TimelineEntry> sequence;
  final String? selectedBlockId;
}

class _AnnualSummary extends StatelessWidget {
  const _AnnualSummary({
    required this.themeCount,
    required this.blockCount,
    required this.annualHours,
    required this.selectedEntry,
    required this.onClear,
  });

  final int themeCount;
  final int blockCount;
  final int annualHours;
  final model.TimelineEntry? selectedEntry;
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
              if (selectedEntry != null)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Konumu temizle'),
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
          if (selectedEntry != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_added),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Burada kaldım: ${selectedEntry!.theme.title} · ${selectedEntry!.block.title}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ThemePlanCard extends StatelessWidget {
  const _ThemePlanCard({
    required this.entries,
    required this.totalBlocks,
    required this.selectedBlockId,
    required this.initiallyExpanded,
    required this.onSelect,
    required this.onOpen,
  });

  final List<model.TimelineEntry> entries;
  final int totalBlocks;
  final String? selectedBlockId;
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
                    color: entries[i].block.id == selectedBlockId
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: Text(entries[i].block.title),
              subtitle: Text(
                '${entries[i].sequencePosition} / $totalBlocks',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: IconButton(
                tooltip: entries[i].block.id == selectedBlockId
                    ? 'Seçili konum'
                    : 'Burada kaldım',
                onPressed: () => onSelect(entries[i].block.id),
                icon: Icon(
                  entries[i].block.id == selectedBlockId
                      ? Icons.bookmark_added
                      : Icons.bookmark_add_outlined,
                ),
              ),
              onTap: () => onOpen(entries[i].block.id),
            ),
            if (i != entries.length - 1)
              const Divider(height: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}
