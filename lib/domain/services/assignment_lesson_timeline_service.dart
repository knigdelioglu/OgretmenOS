import '../models/instruction_context_models.dart';
import '../models/instruction_timeline_models.dart';
import '../models/weekly_plan_models.dart';
import '../repositories/instruction_context_repository.dart';

class AssignmentLessonTimelineService {
  const AssignmentLessonTimelineService({
    required this.instructionContext,
    required this.weeklyPlanning,
  });

  final InstructionContextRepository instructionContext;
  final WeeklyPlanningService weeklyPlanning;

  Future<InstructionTimelineSnapshot> resolve({
    required String academicYear,
    required String courseId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final assignments = await instructionContext.getAssignments(
      academicYear: academicYear,
      courseId: courseId,
    );
    if (assignments.isEmpty) {
      return InstructionTimelineSnapshot(
        now: effectiveNow,
        positions: const {},
      );
    }

    final plan = await weeklyPlanning.buildPlan(today: effectiveNow);
    if (plan.academicYear != academicYear || plan.courseId != courseId) {
      throw StateError(
        'Ders programı bağlamı akademik planla uyuşmuyor: '
        '$academicYear/$courseId != ${plan.academicYear}/${plan.courseId}',
      );
    }

    final assignmentIds = assignments.map((item) => item.id).toList();
    final slots = await instructionContext.getScheduleSlotsForAssignments(
      assignmentIds,
    );
    final periods = await instructionContext.getBellPeriods();
    if (slots.isEmpty || periods.isEmpty) {
      return InstructionTimelineSnapshot(
        now: effectiveNow,
        positions: const {},
      );
    }

    final slotCounts = <String, int>{};
    for (final slot in slots) {
      slotCounts.update(
        slot.assignmentId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final completeAssignmentIds = {
      for (final assignment in assignments)
        if (slotCounts[assignment.id] == plan.weeklyLessonHours) assignment.id,
    };
    if (completeAssignmentIds.isEmpty) {
      return InstructionTimelineSnapshot(
        now: effectiveNow,
        positions: const {},
      );
    }
    final effectiveSlots = slots
        .where((slot) => completeAssignmentIds.contains(slot.assignmentId))
        .toList(growable: false);

    final periodByNumber = {
      for (final period in periods) period.periodNumber: period,
    };
    final occurrences = _buildOccurrences(
      plan: plan,
      slots: effectiveSlots,
      periodByNumber: periodByNumber,
    );

    ScheduledLessonOccurrence? current;
    ScheduledLessonOccurrence? next;
    for (final occurrence in occurrences) {
      if (occurrence.contains(effectiveNow)) {
        current = occurrence;
        break;
      }
      if (occurrence.startsAt.isAfter(effectiveNow)) {
        next = occurrence;
        break;
      }
    }
    if (current != null) {
      for (final occurrence in occurrences) {
        if (occurrence.startsAt.isAfter(effectiveNow)) {
          next = occurrence;
          break;
        }
      }
    }

    final positions = <String, AssignmentTimelinePosition>{};
    for (final assignment in assignments) {
      if (!completeAssignmentIds.contains(assignment.id)) continue;
      final scoped = occurrences
          .where((item) => item.assignmentId == assignment.id)
          .toList(growable: false);
      ScheduledLessonOccurrence? currentForAssignment;
      ScheduledLessonOccurrence? previousForAssignment;
      ScheduledLessonOccurrence? nextForAssignment;
      var plannedOrdinal = 0;

      for (final occurrence in scoped) {
        if (!occurrence.startsAt.isAfter(effectiveNow)) {
          plannedOrdinal = occurrence.plannedOrdinal;
          previousForAssignment = occurrence;
        }
        if (occurrence.contains(effectiveNow)) {
          currentForAssignment = occurrence;
        }
        if (nextForAssignment == null &&
            occurrence.startsAt.isAfter(effectiveNow)) {
          nextForAssignment = occurrence;
        }
      }

      final cursor = await instructionContext.getProgressCursor(assignment.id);
      final mode = cursor?.mode ?? AssignmentProgressMode.followSchedule;
      final resolvedActual = cursor?.actualOrdinalForPlanned(plannedOrdinal) ??
          plannedOrdinal;
      final actualOrdinal = resolvedActual < 0 ? 0 : resolvedActual;
      positions[assignment.id] = AssignmentTimelinePosition(
        assignmentId: assignment.id,
        plannedOrdinal: plannedOrdinal,
        actualOrdinal: actualOrdinal,
        mode: mode,
        currentOccurrence: currentForAssignment,
        previousOccurrence: previousForAssignment,
        nextOccurrence: nextForAssignment,
      );
    }

    return InstructionTimelineSnapshot(
      now: effectiveNow,
      positions: Map.unmodifiable(positions),
      currentOccurrence: current,
      nextOccurrence: next,
    );
  }

  List<ScheduledLessonOccurrence> _buildOccurrences({
    required AnnualWeeklyPlan plan,
    required List<LessonScheduleSlot> slots,
    required Map<int, BellPeriod> periodByNumber,
  }) {
    final counters = <String, int>{};
    final raw = <_RawOccurrence>[];

    for (final week in plan.weeks) {
      if (week.type != AcademicWeekType.instruction) continue;
      for (final slot in slots) {
        final period = periodByNumber[slot.periodNumber];
        if (period == null) {
          throw StateError(
            '${slot.periodNumber}. ders saati için zil saati tanımlı değil.',
          );
        }
        final date = _dateOnly(
          week.start.add(Duration(days: slot.weekday - DateTime.monday)),
        );
        if (date.isBefore(_dateOnly(week.start)) ||
            date.isAfter(_dateOnly(week.end))) {
          continue;
        }
        raw.add(
          _RawOccurrence(
            assignmentId: slot.assignmentId,
            slot: slot,
            period: period,
            date: date,
            startsAt: _atMinute(date, period.startMinute),
            endsAt: _atMinute(date, period.endMinute),
          ),
        );
      }
    }

    raw.sort((a, b) {
      final timeCompare = a.startsAt.compareTo(b.startsAt);
      if (timeCompare != 0) return timeCompare;
      return a.assignmentId.compareTo(b.assignmentId);
    });

    final occurrences = <ScheduledLessonOccurrence>[];
    for (final item in raw) {
      final ordinal = (counters[item.assignmentId] ?? 0) + 1;
      counters[item.assignmentId] = ordinal;
      occurrences.add(
        ScheduledLessonOccurrence(
          assignmentId: item.assignmentId,
          slot: item.slot,
          period: item.period,
          date: item.date,
          startsAt: item.startsAt,
          endsAt: item.endsAt,
          plannedOrdinal: ordinal,
        ),
      );
    }
    return List.unmodifiable(occurrences);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _atMinute(DateTime date, int minuteOfDay) => DateTime(
    date.year,
    date.month,
    date.day,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
}

class _RawOccurrence {
  const _RawOccurrence({
    required this.assignmentId,
    required this.slot,
    required this.period,
    required this.date,
    required this.startsAt,
    required this.endsAt,
  });

  final String assignmentId;
  final LessonScheduleSlot slot;
  final BellPeriod period;
  final DateTime date;
  final DateTime startsAt;
  final DateTime endsAt;
}
