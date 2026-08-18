import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/widgets/system_viewport_guard.dart';

void main() {
  testWidgets('viewport guard protects bottom and landscape side insets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SystemViewportGuard(
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final finder = find.byKey(
      const ValueKey('app-system-viewport-safe-area'),
    );
    expect(finder, findsOneWidget);

    final safeArea = tester.widget<SafeArea>(finder);
    expect(safeArea.top, isFalse);
    expect(safeArea.left, isTrue);
    expect(safeArea.right, isTrue);
    expect(safeArea.bottom, isTrue);
    expect(safeArea.maintainBottomViewPadding, isTrue);
  });

  testWidgets('tapping outside the focused field dismisses keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SystemViewportGuard(
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const ValueKey('field'),
                  focusNode: focusNode,
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      key: const ValueKey('outside'),
                      width: 160,
                      height: 80,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });
}
