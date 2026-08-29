import 'course_models.dart';
import 'planning_models.dart';

enum AcademicWeekType { instruction, event }

enum WeeklyPlanSegmentType { block, schoolBasedPlanning }

class WeeklyPlanSegment {
  const WeeklyPlanSegment({
    required this.type,
    required this.theme,
    required this.hours,
    this.block,
    this.planningBlock,
  });

  final WeeklyPlanSegmentType type;
  final Theme theme;
  final int hours;
  final Block? block;
  final PlanningBlock? planningBlock;
}

class SchoolScheduleException {
  const SchoolScheduleException({
    required this.id,
    required this.date,
    required this.label,
    this.startMinute = 0,
    this.endMinute = 24 * 60,
  });

  final String id;
  final DateTime date;
  final String label;

  /// Local minute-of-day range. End is exclusive.
  final int startMinute;
  final int endMinute;

  bool get isFullDay => startMinute == 0 && endMinute == 24 * 60;

  bool cancels({
    required DateTime candidateDate,
    required int candidateStartMinute,
    required int candidateEndMinute,
  }) {
    if (candidateDate.year != date.year ||
        candidateDate.month != date.month ||
        candidateDate.day != date.day) {
      return false;
    }
    return candidateStartMinute < endMinute &&
        candidateEndMinute > startMinute;
  }
}

class AcademicWeekPlan {
  const AcademicWeekPlan({
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.type,
    required this.label,
    required this.plannedLessonHours,
    required this.segments,
    required this.outcomes,
  });

  final int weekNumber;
  final DateTime start;
  final DateTime end;
  final AcademicWeekType type;
  final String label;
  final int plannedLessonHours;
  final List<WeeklyPlanSegment> segments;
  final List<Outcome> outcomes;

  bool get isEventWeek => type == AcademicWeekType.event;
}

class AnnualWeeklyPlan {
  const AnnualWeeklyPlan({
    required this.academicYear,
    required this.courseId,
    required this.weeklyLessonHours,
    required this.annualHours,
    required this.weeks,
    required this.currentWeekNumber,
    this.scheduleExceptions = const [],
  });

  final String academicYear;
  final String courseId;
  final int weeklyLessonHours;
  final int annualHours;
  final List<AcademicWeekPlan> weeks;
  final int? currentWeekNumber;
  final List<SchoolScheduleException> scheduleExceptions;

  AcademicWeekPlan? week(int number) {
    for (final week in weeks) {
      if (week.weekNumber == number) return week;
    }
    return null;
  }

  AcademicWeekPlan? get currentWeek =>
      currentWeekNumber == null ? null : week(currentWeekNumber!);

  bool isScheduleCancelled({
    required DateTime date,
    required int startMinute,
    required int endMinute,
  }) => scheduleExceptions.any(
    (exception) => exception.cancels(
      candidateDate: date,
      candidateStartMinute: startMinute,
      candidateEndMinute: endMinute,
    ),
  );
}

abstract interface class WeeklyPlanningService {
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today});
}
