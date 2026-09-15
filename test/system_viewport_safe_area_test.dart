import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/features/shared/interaction_polish.dart';

void main() {
  testWidgets(
    'app reserves system viewport insets without replacing focus handling',
    (tester) async {
      final pending = Completer<AppDependencies>();

      await tester.pumpWidget(
        TeacherOsApp(courseLoader: (_) => pending.future),
      );
      await tester.pump();

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
      expect(find.byType(AppFocusDismissRegion), findsOneWidget);
    },
  );
}
