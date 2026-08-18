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
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _dismissFocusedEditableWhenOutside,
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

  void _dismissFocusedEditableWhenOutside(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focus == null || focusContext == null || !focus.hasFocus) return;

    final renderObject = focusContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bounds = topLeft & renderObject.size;
    if (!bounds.contains(event.position)) {
      focus.unfocus();
    }
  }
}
