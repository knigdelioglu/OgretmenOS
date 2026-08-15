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
        return const LoadingView();
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Yıllık plan verileri yüklenemedi.',
          onRetry: _refresh,
        );
      }
      final data = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planlanan öğretim sırası',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data.sequence.length} doğrulanmış blok · tema zamanı ${data.manifest.timelineResolution.toLowerCase()}',
                  ),
                  const SizedBox(height: 8),
                  const UnresolvedText(
                    label:
                        'Tarih tabanlı plan konumu henüz doğrulanmış takvim verisiyle eşleştirilmedi.',
                  ),
                  if (data.manualPosition != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          data.manualIsValid
                              ? Icons.bookmark_added_outlined
                              : Icons.warning_amber_outlined,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.manualIsValid
                                ? 'Seçili plan konumu kaydedildi.'
                                : 'Kaydedilmiş plan konumu bu runtime paketinde bulunamadı.',
                          ),
                        ),
                        TextButton(
                          onPressed: _clearPosition,
                          child: const Text('Temizle'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (data.sequence.isEmpty)
            const InfoCard(
              title: 'Yıllık sıra',
              child: UnresolvedText(
                label: 'Runtime paketinde doğrulanmış blok sırası bulunmuyor.',
              ),
            )
          else
            for (var index = 0; index < data.sequence.length; index++) ...[
              if (index == 0 ||
                  data.sequence[index - 1].theme.id !=
                      data.sequence[index].theme.id)
                SectionHeading(data.sequence[index].theme.title),
              _SequenceCard(
                entry: data.sequence[index],
                total: data.sequence.length,
                isSelected:
                    data.manualPosition == data.sequence[index].block.id,
                onSelect: () => _setPosition(data.sequence[index].block.id),
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlockDetailPage(
                      repository: widget.repository,
                      blockId: data.sequence[index].block.id,
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

class _SequenceCard extends StatelessWidget {
  const _SequenceCard({
    required this.entry,
    required this.total,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
  });

  final model.TimelineEntry entry;
  final int total;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: onOpen,
      leading: CircleAvatar(child: Text('${entry.sequencePosition}')),
      title: Text(entry.block.title),
      subtitle: Text(
        [
          'Plan sırası: ${entry.sequencePosition} / $total',
          if (entry.block.timeStatus != null)
            'Süre durumu: ${entry.block.timeStatus}',
        ].join(' · '),
      ),
      trailing: isSelected
          ? IconButton(
              tooltip: 'Seçili plan konumu',
              onPressed: onSelect,
              icon: const Icon(Icons.bookmark_added),
            )
          : IconButton(
              tooltip: 'Burada kaldım',
              onPressed: onSelect,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
    ),
  );
}
