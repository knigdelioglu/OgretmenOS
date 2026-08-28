import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import 'feature_widgets.dart';

class ProcessComponentSummary extends StatelessWidget {
  const ProcessComponentSummary({super.key, required this.outcome, this.color});

  final model.Outcome outcome;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final raw = outcome.processComponents;
    if (raw == null || raw.trim().isEmpty) return const SizedBox.shrink();

    final components = model.jsonObjectList(raw);
    final labels = components
        .map((component) {
          final code = _componentValue(component, const [
            'component_code',
            'component_code_normalized',
          ]);
          final title = _componentValue(component, const [
            'component_title',
            'component_title_verbatim',
            'component_verbatim',
          ]);
          return [?code, ?title].join(' · ');
        })
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    final visibleLabels = labels.isEmpty ? [raw.trim()] : labels;
    final secondaryColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Süreç bileşenleri',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: secondaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final label in visibleLabels)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 16,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String? _componentValue(Map<String, dynamic> component, List<String> keys) {
  for (final key in keys) {
    final value = component[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
