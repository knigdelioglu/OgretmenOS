import 'instruction_context_models.dart';

class ScheduledLessonOccurrence {
  const ScheduledLessonOccurrence({
    required this.assignmentId,
    required this.slot,
    required this.period,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.plannedOrdinal,
  });

  final String assignmentId;
  final LessonScheduleSlot slot;
  final BellPeriod period;
  final DateTime date;
  final DateTime startsAt;
  final DateTime endsAt;
  final int plannedOrdinal;

  bool contains(DateTime value) =>
      !value.isBefore(startsAt) && value.isBefore(endsAt);
}

class AssignmentTimelinePosition {
  const AssignmentTimelinePosition({
    required this.assignmentId,
    required this.plannedOrdinal,
    required this.actualOrdinal,
    required this.mode,
    this.currentOccurrence,
    this.previousOccurrence,
    this.nextOccurrence,
  });

  final String assignmentId;
  final int plannedOrdinal;
  final int actualOrdinal;
  final AssignmentProgressMode mode;
  final ScheduledLessonOccurrence? currentOccurrence;
  final ScheduledLessonOccurrence? previousOccurrence;
  final ScheduledLessonOccurrence? nextOccurrence;

  int get delta => actualOrdinal - plannedOrdinal;
  bool get followsSchedule => delta == 0;
}

class InstructionTimelineSnapshot {
  const InstructionTimelineSnapshot({
    required this.now,
    required this.positions,
    this.occurrences = const [],
    this.currentOccurrence,
    this.nextOccurrence,
  });

  final DateTime now;
  final Map<String, AssignmentTimelinePosition> positions;

  /// Canonical timetable occurrences after academic-calendar exceptions are
  /// applied. They are ordered chronologically and carry assignment-local
  /// planned ordinals. Empty means schedule truth is unavailable; callers must
  /// not infer temporal position from optional tracking state in that case.
  final List<ScheduledLessonOccurrence> occurrences;

  final ScheduledLessonOccurrence? currentOccurrence;
  final ScheduledLessonOccurrence? nextOccurrence;

  AssignmentTimelinePosition? positionFor(String assignmentId) =>
      positions[assignmentId];

  List<ScheduledLessonOccurrence> occurrencesForAssignment(
    String assignmentId,
  ) => List.unmodifiable(
    occurrences.where((item) => item.assignmentId == assignmentId),
  );

  List<ScheduledLessonOccurrence> occurrencesForAssignmentBetween({
    required String assignmentId,
    required DateTime start,
    required DateTime end,
  }) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return List.unmodifiable(
      occurrences.where((item) {
        if (item.assignmentId != assignmentId) return false;
        final date = DateTime(item.date.year, item.date.month, item.date.day);
        return !date.isBefore(startDate) && !date.isAfter(endDate);
      }),
    );
  }
}
