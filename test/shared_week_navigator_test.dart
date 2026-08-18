import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/features/shared/week_navigator.dart';

void main() {
  testWidgets('week navigator supports previous next and current week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var selected = 2;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppWeekNavigator(
              options: const [
                WeekNavigatorOption(weekNumber: 1, label: '1. Hafta · 7-11 Eylül'),
                WeekNavigatorOption(weekNumber: 2, label: '2. Hafta · 14-18 Eylül'),
                WeekNavigatorOption(weekNumber: 3, label: '3. Hafta · 21-25 Eylül'),
              ],
              selectedWeekNumber: selected,
              currentWeekNumber: 1,
              helperText: 'Sağa veya sola kaydırabilirsiniz.',
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bu haftaya dön'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Önceki hafta'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.text('Bu haftaya dön'), findsNothing);

    await tester.tap(find.byTooltip('Sonraki hafta'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week navigator disables boundary arrows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppWeekNavigator(
            options: const [
              WeekNavigatorOption(weekNumber: 1, label: '1. Hafta'),
              WeekNavigatorOption(weekNumber: 2, label: '2. Hafta'),
            ],
            selectedWeekNumber: 1,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final previous = tester.widget<IconButton>(find.byTooltip('Önceki hafta'));
    final next = tester.widget<IconButton>(find.byTooltip('Sonraki hafta'));
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNotNull);
  });
}
