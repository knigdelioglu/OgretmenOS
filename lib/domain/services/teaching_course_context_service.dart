import '../models/instruction_context_models.dart';
import '../models/weekly_plan_models.dart';
import '../repositories/instruction_context_repository.dart';
import '../repositories/school_schedule_exception_repository.dart';

class TeachingCourseContextService {
  const TeachingCourseContextService({
    required this.instructionContext,
    required this.weeklyPlanning,
    this.scheduleExceptions,
  });

  final InstructionContextRepository instructionContext;
  final WeeklyPlanningService weeklyPlanning;
  final SchoolScheduleExceptionRepository? scheduleExceptions;

  Future<TeachingCourseContextSnapshot> resolve({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final plan = await weeklyPlanning.buildPlan(today: effectiveNow);
    final fallbackTransition = _nextDayBoundary(effectiveNow);
    final week = plan.currentWeek;
    if (week == null || week.isEventWeek) {
      return TeachingCourseContextSnapshot(
        resolvedAt: effectiveNow,
        nextTransitionAt: fallbackTransition,
      );
    }

    final assignments = await instructionContext.getAssignments(
      academicYear: plan.academicYear,
    );
    if (assignments.isEmpty) {
      return TeachingCourseContextSnapshot(
        resolvedAt: effectiveNow,
        nextTransitionAt: fallbackTransition,
      );
    }
    final periods = await instructionContext.getBellPeriods();
    if (periods.isEmpty) {
      return TeachingCourseContextSnapshot(
        resolvedAt: effectiveNow,
        nextTransitionAt: fallbackTransition,
      );
    }

    final assignmentIds = assignments.map((item) => item.id).toList();
    final slots = await instructionContext.getScheduleSlotsForAssignments(
      assignmentIds,
    );
    if (slots.isEmpty) {
      return TeachingCourseContextSnapshot(
        resolvedAt: effectiveNow,
        nextTransitionAt: fallbackTransition,
      );
    }

    final slotCounts = <String, int>{};
    for (final slot in slots) {
      slotCounts.update(
        slot.assignmentId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final completeAssignmentIds = {
      for (final assignment in assignments)
        if (slotCounts[assignment.id] == plan.weeklyLessonHours) assignment.id,
    };
    if (completeAssignmentIds.isEmpty) {
      return TeachingCourseContextSnapshot(
        resolvedAt: effectiveNow,
        nextTransitionAt: fallbackTransition,
      );
    }

    final assignmentById = {
      for (final assignment in assignments) assignment.id: assignment,
    };
    final periodByNumber = {
      for (final period in periods) period.periodNumber: period,
    };
    var exceptions = plan.scheduleExceptions
        .where(
          (exception) => exception.appliesToAcademicYear(plan.academicYear),
        )
        .toList(growable: false);
    final exceptionRepository = scheduleExceptions;
    if (exceptionRepository != null) {
      final stored = await exceptionRepository.getForAcademicYear(
        plan.academicYear,
      );
      exceptions = List.unmodifiable([
        ...exceptions,
        ...stored.where(
          (exception) => exception.appliesToAcademicYear(plan.academicYear),
        ),
      ]);
    }

    final today = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final current = <_LessonMatch>[];
    _LessonMatch? nextLesson;
    DateTime? nextTransition;
    for (final slot in slots) {
      if (!completeAssignmentIds.contains(slot.assignmentId) ||
          slot.weekday != effectiveNow.weekday) {
        continue;
      }
      final period = periodByNumber[slot.periodNumber];
      if (period == null) continue;
      final cancelled = exceptions.any(
        (exception) => exception.cancels(
          candidateDate: today,
          candidateStartMinute: period.startMinute,
          candidateEndMinute: period.endMinute,
        ),
      );
      if (cancelled) continue;

      final assignment = assignmentById[slot.assignmentId];
      if (assignment == null) continue;
      final startsAt = _atMinute(today, period.startMinute);
      final endsAt = _atMinute(today, period.endMinute);
      final match = _LessonMatch(
        assignment: assignment,
        startsAt: startsAt,
        endsAt: endsAt,
      );
      if (!effectiveNow.isBefore(startsAt) && effectiveNow.isBefore(endsAt)) {
        current.add(match);
      }
      if (startsAt.isAfter(effectiveNow) &&
          (nextLesson == null || startsAt.isBefore(nextLesson.startsAt))) {
        nextLesson = match;
      }
      if (startsAt.isAfter(effectiveNow)) {
        nextTransition = _earlier(nextTransition, startsAt);
      }
      if (endsAt.isAfter(effectiveNow)) {
        nextTransition = _earlier(nextTransition, endsAt);
      }
    }

    if (current.length > 1) {
      throw StateError(
        'Aynı anda birden fazla öğretmen ders programı kaydı etkin.',
      );
    }
    final active = current.isEmpty ? null : current.single;
    return TeachingCourseContextSnapshot(
      resolvedAt: effectiveNow,
      currentCourseId: active?.assignment.courseId,
      currentAssignmentId: active?.assignment.id,
      currentStartsAt: active?.startsAt,
      currentEndsAt: active?.endsAt,
      nextCourseId: nextLesson?.assignment.courseId,
      nextAssignmentId: nextLesson?.assignment.id,
      nextStartsAt: nextLesson?.startsAt,
      nextEndsAt: nextLesson?.endsAt,
      nextTransitionAt: nextTransition ?? fallbackTransition,
    );
  }

  DateTime _nextDayBoundary(DateTime now) => DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1, seconds: 1));

  DateTime _atMinute(DateTime date, int minuteOfDay) => DateTime(
    date.year,
    date.month,
    date.day,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );

  DateTime _earlier(DateTime? current, DateTime candidate) =>
      current == null || candidate.isBefore(current) ? candidate : current;
}

class TeachingCourseContextSnapshot {
  const TeachingCourseContextSnapshot({
    required this.resolvedAt,
    required this.nextTransitionAt,
    this.currentCourseId,
    this.currentAssignmentId,
    this.currentStartsAt,
    this.currentEndsAt,
    this.nextCourseId,
    this.nextAssignmentId,
    this.nextStartsAt,
    this.nextEndsAt,
  });

  final DateTime resolvedAt;
  final String? currentCourseId;
  final String? currentAssignmentId;
  final DateTime? currentStartsAt;
  final DateTime? currentEndsAt;
  final String? nextCourseId;
  final String? nextAssignmentId;
  final DateTime? nextStartsAt;
  final DateTime? nextEndsAt;
  final DateTime nextTransitionAt;

  bool get hasCurrentLesson =>
      currentCourseId != null && currentAssignmentId != null;

  bool get hasNextLesson => nextCourseId != null && nextAssignmentId != null;

  String? get preferredCourseId => currentCourseId ?? nextCourseId;
}

class _LessonMatch {
  const _LessonMatch({
    required this.assignment,
    required this.startsAt,
    required this.endsAt,
  });

  final TeachingAssignment assignment;
  final DateTime startsAt;
  final DateTime endsAt;
}
