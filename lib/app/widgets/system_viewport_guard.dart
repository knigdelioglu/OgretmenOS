import 'package:flutter/material.dart';

/// Applies the system-UI contract once for the whole application.
///
/// The top inset remains the responsibility of Scaffold/AppBar. Bottom and
/// horizontal insets are reserved here so both top-level and pushed routes
/// follow the same Android gesture/three-button/landscape behavior.
class SystemViewportGuard extends StatelessWidget {
  const SystemViewportGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          key: const ValueKey('app-system-viewport-safe-area'),
          top: false,
          left: true,
          right: true,
          bottom: true,
          maintainBottomViewPadding: true,
          child: child,
        ),
      );
}
