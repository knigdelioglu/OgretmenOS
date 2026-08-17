import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';

void main() {
  testWidgets('app reserves the Android bottom system area globally', (
    tester,
  ) async {
    final pending = Completer<AppDependencies>();

    await tester.pumpWidget(
      TeacherOsApp(loader: () => pending.future),
    );
    await tester.pump();

    final finder = find.byKey(
      const ValueKey('app-system-bottom-safe-area'),
    );
    expect(finder, findsOneWidget);

    final safeArea = tester.widget<SafeArea>(finder);
    expect(safeArea.top, isFalse);
    expect(safeArea.left, isFalse);
    expect(safeArea.right, isFalse);
    expect(safeArea.bottom, isTrue);
  });
}
