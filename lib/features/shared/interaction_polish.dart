import 'dart:async';

import 'package:flutter/material.dart';

import 'feature_widgets.dart';

class AppFocusDismissRegion extends StatelessWidget {
  const AppFocusDismissRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      );
}

void showTeacherFeedback(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showTeacherUndoFeedback(
  BuildContext context,
  String message, {
  required Future<void> Function() onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.clearMaterialBanners();
  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      content: Text(message),
      leading: const Icon(Icons.undo_rounded),
      actions: [
        TextButton(
          onPressed: () async {
            controller.close();
            await onUndo();
          },
          child: const Text('Geri al'),
        ),
      ],
    ),
  );
  unawaited(
    Future<void>.delayed(duration, () {
      controller.close();
    }),
  );
}

class FeatureEmptyView extends StatelessWidget {
  const FeatureEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: StatusPanel(
              icon: icon,
              title: title,
              message: message,
            ),
          ),
        ),
      );
}
