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
    this.currentOccurrence,
    this.nextOccurrence,
  });

  final DateTime now;
  final Map<String, AssignmentTimelinePosition> positions;
  final ScheduledLessonOccurrence? currentOccurrence;
  final ScheduledLessonOccurrence? nextOccurrence;

  AssignmentTimelinePosition? positionFor(String assignmentId) =>
      positions[assignmentId];
}
