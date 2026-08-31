import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Presents a bottom sheet inside the usable viewport.
///
/// Flutter's [MediaQuery] is the native equivalent of a browser's dynamic
/// viewport: its padding accounts for system bars and its bottom inset grows
/// when the IME is visible. Keeping this policy here prevents individual
/// sheets from guessing a device-specific taskbar height.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: false,
  builder: (sheetContext) => AppModalSheet(child: builder(sheetContext)),
);

/// Gives a sheet a bounded height without forcing its content to be a fixed
/// size. Children should keep headers/actions non-flexible and make their
/// body the scrollable/flexible region.
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = math.max(media.padding.top, media.viewPadding.top);
    final bottom = math.max(
      media.padding.bottom,
      math.max(media.viewPadding.bottom, media.viewInsets.bottom),
    );
    final left = math.max(media.padding.left, media.viewPadding.left);
    final right = math.max(media.padding.right, media.viewPadding.right);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(left, top, right, bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

/// Applies native system-bar insets that can be removed by an ancestor
/// Scaffold. Unlike a fixed device padding, this follows Android taskbars,
/// navigation bars, cutouts, and desktop window changes through MediaQuery.
class AppViewport extends StatelessWidget {
  const AppViewport({
    super.key,
    required this.child,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.left = true,
  });

  final Widget child;
  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    double inset(double padding, double viewPadding) =>
        math.max(padding, viewPadding);
    return Padding(
      padding: EdgeInsets.only(
        top: top ? inset(media.padding.top, media.viewPadding.top) : 0,
        right: right ? inset(media.padding.right, media.viewPadding.right) : 0,
        bottom: bottom
            ? inset(media.padding.bottom, media.viewPadding.bottom)
            : 0,
        left: left ? inset(media.padding.left, media.viewPadding.left) : 0,
      ),
      child: child,
    );
  }
}

/// Bounds a dialog to the currently usable viewport. AlertDialog instances
/// wrapped with this widget should use `scrollable: true` when their content
/// can grow; actions remain in the dialog's non-scrolling action area.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = math.max(media.padding.top, media.viewPadding.top);
    final bottomInset = math.max(
      media.padding.bottom,
      media.viewPadding.bottom,
    );
    final maxHeight = math.max(
      0.0,
      media.size.height - topInset - bottomInset - 32,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: child,
    );
  }
}

/// Shared AlertDialog policy for variable-height content. The content area
/// can scroll while the action row remains available to the user.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({super.key, this.title, this.content, this.actions});

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: title,
    content: content,
    actions: actions,
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  builder: (dialogContext) => AppDialogFrame(child: builder(dialogContext)),
);
