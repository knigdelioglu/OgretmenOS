import 'package:flutter/material.dart';

import '../../domain/models/outcome_tracking_models.dart';

String outcomeStatusLabel(OutcomeTrackingStatus status) => switch (status) {
  OutcomeTrackingStatus.planned => 'Planlı',
  OutcomeTrackingStatus.inProgress => 'Devam ediyor',
  OutcomeTrackingStatus.completed => 'İşlendi',
  OutcomeTrackingStatus.partiallyCompleted => 'Kısmen işlendi',
  OutcomeTrackingStatus.carriedOver => 'Sarktı',
};

IconData outcomeStatusIcon(OutcomeTrackingStatus status) => switch (status) {
  OutcomeTrackingStatus.planned => Icons.schedule_outlined,
  OutcomeTrackingStatus.inProgress => Icons.play_circle_outline,
  OutcomeTrackingStatus.completed => Icons.check_circle_outline,
  OutcomeTrackingStatus.partiallyCompleted => Icons.timelapse_outlined,
  OutcomeTrackingStatus.carriedOver => Icons.redo_outlined,
};

class OutcomeStatusChip extends StatelessWidget {
  const OutcomeStatusChip({super.key, required this.status});

  final OutcomeTrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      OutcomeTrackingStatus.completed =>
        (scheme.primaryContainer, scheme.onPrimaryContainer),
      OutcomeTrackingStatus.inProgress ||
      OutcomeTrackingStatus.partiallyCompleted =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      OutcomeTrackingStatus.carriedOver =>
        (scheme.errorContainer, scheme.onErrorContainer),
      OutcomeTrackingStatus.planned =>
        (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Chip(
      avatar: Icon(outcomeStatusIcon(status), size: 17, color: foreground),
      label: Text(outcomeStatusLabel(status)),
      backgroundColor: background,
      side: BorderSide.none,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
    );
  }
}

String outcomeDateRange(DateTime start, DateTime end) =>
    '${start.day} ${_month(start.month)} - ${end.day} ${_month(end.month)} ${end.year}';

String _month(int month) => switch (month) {
  1 => 'Ocak',
  2 => 'Şubat',
  3 => 'Mart',
  4 => 'Nisan',
  5 => 'Mayıs',
  6 => 'Haziran',
  7 => 'Temmuz',
  8 => 'Ağustos',
  9 => 'Eylül',
  10 => 'Ekim',
  11 => 'Kasım',
  12 => 'Aralık',
  _ => '',
};
