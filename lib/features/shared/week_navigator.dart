import 'package:flutter/material.dart';

import 'feature_widgets.dart';

class WeekNavigatorOption {
  const WeekNavigatorOption({required this.weekNumber, required this.label});

  final int weekNumber;
  final String label;
}

class AppWeekNavigator extends StatelessWidget {
  const AppWeekNavigator({
    super.key,
    required this.options,
    required this.selectedWeekNumber,
    required this.onChanged,
    this.currentWeekNumber,
    this.helperText,
  });

  final List<WeekNavigatorOption> options;
  final int selectedWeekNumber;
  final int? currentWeekNumber;
  final ValueChanged<int> onChanged;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere(
      (option) => option.weekNumber == selectedWeekNumber,
    );
    final current = currentWeekNumber;
    final canReturn = current != null &&
        current != selectedWeekNumber &&
        options.any((option) => option.weekNumber == current);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Önceki hafta',
                  onPressed: selectedIndex > 0
                      ? () => onChanged(options[selectedIndex - 1].weekNumber)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(selectedWeekNumber),
                    initialValue: selectedWeekNumber,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Okul haftası',
                      isDense: true,
                    ),
                    items: options
                        .map(
                          (option) => DropdownMenuItem<int>(
                            value: option.weekNumber,
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null && value != selectedWeekNumber) {
                        onChanged(value);
                      }
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Sonraki hafta',
                  onPressed: selectedIndex >= 0 &&
                          selectedIndex < options.length - 1
                      ? () => onChanged(options[selectedIndex + 1].weekNumber)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (helperText != null || canReturn) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  if (helperText != null)
                    Expanded(
                      child: Text(
                        helperText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (canReturn) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () => onChanged(current),
                      icon: const Icon(Icons.today_outlined, size: 18),
                      label: const Text('Bu haftaya dön'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
