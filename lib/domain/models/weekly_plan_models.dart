import 'course_models.dart';

enum AcademicWeekType { instruction, event }

enum WeeklyPlanSegmentType { block, schoolBasedPlanning }

class WeeklyPlanSegment {
  const WeeklyPlanSegment({
    required this.type,
    required this.theme,
    required this.hours,
    this.block,
  });

  final WeeklyPlanSegmentType type;
  final Theme theme;
  final int hours;
  final Block? block;
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
  });

  final String academicYear;
  final String courseId;
  final int weeklyLessonHours;
  final int annualHours;
  final List<AcademicWeekPlan> weeks;
  final int? currentWeekNumber;

  AcademicWeekPlan? week(int number) {
    for (final week in weeks) {
      if (week.weekNumber == number) return week;
    }
    return null;
  }

  AcademicWeekPlan? get currentWeek =>
      currentWeekNumber == null ? null : week(currentWeekNumber!);
}

abstract interface class WeeklyPlanningService {
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today});
}
