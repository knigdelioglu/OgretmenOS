import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' hide Theme;
import '../shared/feature_widgets.dart';

class RubricScoreCard extends StatefulWidget {
  const RubricScoreCard({
    super.key,
    required this.binding,
    required this.artifact,
  });

  final AssessmentTaskBinding binding;
  final AssessmentArtifact? artifact;

  @override
  State<RubricScoreCard> createState() => _RubricScoreCardState();
}

class _RubricScoreCardState extends State<RubricScoreCard> {
  final Map<int, int> _scores = {};

  List<RubricLevel> get _levels {
    final levels = widget.artifact?.levels ?? const <RubricLevel>[];
    if (levels.isNotEmpty) return levels;
    return const [
      RubricLevel(score: 3, label: 'Oldukça iyi', descriptor: null),
      RubricLevel(score: 2, label: 'Kabul edilebilir', descriptor: null),
      RubricLevel(score: 1, label: 'Geliştirilmeli', descriptor: null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final criteria = widget.binding.taskSpecificCriteria;
    if (criteria.isEmpty) return const SizedBox.shrink();
    final maxLevel = _levels
        .map((level) => level.score)
        .reduce((a, b) => a > b ? a : b);
    final total = _scores.values.fold<int>(0, (sum, score) => sum + score);
    final maxScore = criteria.length * maxLevel;
    final complete = _scores.length == criteria.length;
    final percentage = maxScore == 0 ? 0 : (total / maxScore * 100).round();

    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dereceli puanlama formu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${criteria.length} ölçüt · maksimum $maxScore puan'),
            const SizedBox(height: AppSpacing.lg),
            for (var index = 0; index < criteria.length; index++) ...[
              Text(
                '${index + 1}. ${criteria[index]}',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final level in _levels)
                    ChoiceChip(
                      label: Text('${level.score} · ${level.label}'),
                      selected: _scores[index] == level.score,
                      onSelected: (_) =>
                          setState(() => _scores[index] = level.score),
                    ),
                ],
              ),
              if (index != criteria.length - 1)
                const Divider(height: AppSpacing.xl),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              complete
                  ? 'Toplam: $total / $maxScore · %$percentage'
                  : 'Puanlanan ölçüt: ${_scores.length}/${criteria.length}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (widget.binding.sourceEquivalenceStatus != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Bu form, kabul edilmiş güçlü kopya ve resmî program/kitap ölçütlerinden oluşturulmuş canonical değerlendirme formudur.',
                style: TextStyle(height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
