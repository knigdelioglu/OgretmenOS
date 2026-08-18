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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
            final narrow = constraints.maxWidth < 420;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (largeText && narrow) ...[
                  DropdownButtonFormField<int>(
                    key: ValueKey(selectedWeekNumber),
                    initialValue: selectedWeekNumber,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Okul haftası'),
                    items: _items(),
                    onChanged: (value) => _change(value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectedIndex > 0
                              ? () => onChanged(
                                    options[selectedIndex - 1].weekNumber,
                                  )
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Önceki'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectedIndex >= 0 &&
                                  selectedIndex < options.length - 1
                              ? () => onChanged(
                                    options[selectedIndex + 1].weekNumber,
                                  )
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Sonraki'),
                        ),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Önceki hafta',
                        onPressed: selectedIndex > 0
                            ? () => onChanged(
                                  options[selectedIndex - 1].weekNumber,
                                )
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
                          items: _items(),
                          onChanged: (value) => _change(value),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sonraki hafta',
                        onPressed: selectedIndex >= 0 &&
                                selectedIndex < options.length - 1
                            ? () => onChanged(
                                  options[selectedIndex + 1].weekNumber,
                                )
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                if (helperText != null || canReturn) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (helperText != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth >= 560
                                ? constraints.maxWidth * 0.62
                                : constraints.maxWidth,
                          ),
                          child: Text(
                            helperText!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (canReturn)
                        TextButton.icon(
                          onPressed: () => onChanged(current),
                          icon: const Icon(Icons.today_outlined, size: 18),
                          label: const Text('Bu haftaya dön'),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _items() => options
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
      .toList(growable: false);

  void _change(int? value) {
    if (value != null && value != selectedWeekNumber) onChanged(value);
  }
}
