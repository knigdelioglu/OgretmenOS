import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ogretmen_os/features/shared/adaptive_surfaces.dart';

void main() {
  testWidgets('modal surface stays inside low-height safe area and IME', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);

    final actionKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppModalSheet(
            child: Column(
              children: [
                const SizedBox(height: 56),
                const Expanded(child: Placeholder()),
                SizedBox(key: actionKey, height: 48),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final actionRect = tester.getRect(find.byKey(actionKey));
    expect(actionRect.bottom, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
  });

  testWidgets('modal surface fits requested desktop and tablet heights', (
    tester,
  ) async {
    const scenarios = <Size>[
      Size(1440, 900),
      Size(1280, 720),
      Size(1280, 800),
      Size(1280, 720),
      Size(1024, 600),
      Size(800, 1280),
    ];

    for (final size in scenarios) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      tester.view.resetViewInsets();

      final contentKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppModalSheet(child: SizedBox(key: contentKey, height: 1600)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final contentRect = tester.getRect(find.byKey(contentKey));
      expect(contentRect.height, lessThanOrEqualTo(size.height - 72));
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
  });

  testWidgets('dialog frame leaves a bounded body for low-height landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);

    final contentKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDialogFrame(child: SizedBox(key: contentKey, height: 1200)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(contentKey)).height,
      lessThanOrEqualTo(496),
    );
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
  });

  testWidgets('long alert dialog keeps its action row reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAppDialog<void>(
                context: tester.element(find.byType(ElevatedButton)),
                builder: (dialogContext) => AppAlertDialog(
                  title: const Text('Uzun içerik'),
                  content: const SizedBox(height: 1200),
                  actions: [
                    TextButton(
                      key: const ValueKey('dialog-action'),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Tamam'),
                    ),
                  ],
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('dialog-action'));
    expect(action, findsOneWidget);
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
  });
}
