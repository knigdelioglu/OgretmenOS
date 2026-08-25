import 'package:flutter/material.dart';

import 'feature_widgets.dart';

OverlayEntry? _teacherUndoOverlay;

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
}) {
  final previous = _teacherUndoOverlay;
  if (previous != null && previous.mounted) previous.remove();
  _teacherUndoOverlay = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;

  void dismiss() {
    if (entry.mounted) entry.remove();
    if (identical(_teacherUndoOverlay, entry)) {
      _teacherUndoOverlay = null;
    }
  }

  entry = OverlayEntry(
    builder: (overlayContext) => SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.undo_rounded),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(overlayContext).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        dismiss();
                        await onUndo();
                      },
                      child: const Text('Geri al'),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: dismiss,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  _teacherUndoOverlay = entry;
  overlay.insert(entry);
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
