import 'course_models.dart';
import 'weekly_plan_models.dart';

enum OutcomeTrackingStatus {
  planned,
  inProgress,
  completed,
  partiallyCompleted,
  carriedOver;

  String get storageValue => switch (this) {
    OutcomeTrackingStatus.planned => 'planned',
    OutcomeTrackingStatus.inProgress => 'in_progress',
    OutcomeTrackingStatus.completed => 'completed',
    OutcomeTrackingStatus.partiallyCompleted => 'partially_completed',
    OutcomeTrackingStatus.carriedOver => 'carried_over',
  };

  static OutcomeTrackingStatus fromStorage(String value) => switch (value) {
    'in_progress' => OutcomeTrackingStatus.inProgress,
    'completed' => OutcomeTrackingStatus.completed,
    'partially_completed' => OutcomeTrackingStatus.partiallyCompleted,
    'carried_over' => OutcomeTrackingStatus.carriedOver,
    _ => OutcomeTrackingStatus.planned,
  };
}

class LearningOutcomeTrackingRecord {
  const LearningOutcomeTrackingRecord({
    required this.academicYear,
    required this.outcomeId,
    required this.plannedWeekNumber,
    required this.status,
    required this.updatedAt,
    this.actualHours,
    this.teacherNote,
    this.completedAt,
    this.carriedToWeekNumber,
  });

  final String academicYear;
  final String outcomeId;
  final int plannedWeekNumber;
  final OutcomeTrackingStatus status;
  final int? actualHours;
  final String? teacherNote;
  final DateTime? completedAt;
  final int? carriedToWeekNumber;
  final DateTime updatedAt;

  LearningOutcomeTrackingRecord copyWith({
    OutcomeTrackingStatus? status,
    int? actualHours,
    bool clearActualHours = false,
    String? teacherNote,
    bool clearTeacherNote = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? carriedToWeekNumber,
    bool clearCarriedToWeekNumber = false,
    DateTime? updatedAt,
  }) => LearningOutcomeTrackingRecord(
    academicYear: academicYear,
    outcomeId: outcomeId,
    plannedWeekNumber: plannedWeekNumber,
    status: status ?? this.status,
    actualHours: clearActualHours ? null : actualHours ?? this.actualHours,
    teacherNote: clearTeacherNote ? null : teacherNote ?? this.teacherNote,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    carriedToWeekNumber: clearCarriedToWeekNumber
        ? null
        : carriedToWeekNumber ?? this.carriedToWeekNumber,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class OutcomeBlockContext {
  const OutcomeBlockContext({required this.detail});

  final BlockDetail detail;

  Theme get theme => detail.theme;
  Block get block => detail.block;
}

class TrackedOutcome {
  const TrackedOutcome({
    required this.outcome,
    required this.academicYear,
    required this.plannedWeekNumber,
    required this.displayWeekNumber,
    required this.status,
    required this.contexts,
    this.actualHours,
    this.teacherNote,
    this.completedAt,
    this.carriedToWeekNumber,
    this.carriedFromWeekNumber,
    this.isCarriedIn = false,
  });

  final Outcome outcome;
  final String academicYear;
  final int plannedWeekNumber;
  final int displayWeekNumber;
  final OutcomeTrackingStatus status;
  final List<OutcomeBlockContext> contexts;
  final int? actualHours;
  final String? teacherNote;
  final DateTime? completedAt;
  final int? carriedToWeekNumber;
  final int? carriedFromWeekNumber;
  final bool isCarriedIn;

  String get trackingKey => '$academicYear:${outcome.id}:$plannedWeekNumber';

  Theme? get primaryTheme => contexts.isEmpty ? null : contexts.first.theme;
  Block? get primaryBlock => contexts.isEmpty ? null : contexts.first.block;
}

class WeeklyOutcomeSummary {
  const WeeklyOutcomeSummary({
    required this.week,
    required this.outcomes,
  });

  final AcademicWeekPlan week;
  final List<TrackedOutcome> outcomes;

  int get completedCount => outcomes
      .where((item) => item.status == OutcomeTrackingStatus.completed)
      .length;

  int get inProgressCount => outcomes
      .where(
        (item) =>
            item.status == OutcomeTrackingStatus.inProgress ||
            item.status == OutcomeTrackingStatus.partiallyCompleted,
      )
      .length;

  int get carriedCount => outcomes
      .where(
        (item) =>
            item.status == OutcomeTrackingStatus.carriedOver || item.isCarriedIn,
      )
      .length;

  int get plannedCount => outcomes
      .where((item) => item.status == OutcomeTrackingStatus.planned)
      .length;

  TrackedOutcome? findByKey(String key) {
    for (final item in outcomes) {
      if (item.trackingKey == key) return item;
    }
    return null;
  }
}

class AnnualOutcomePlan {
  const AnnualOutcomePlan({
    required this.weeklyPlan,
    required this.weeks,
  });

  final AnnualWeeklyPlan weeklyPlan;
  final List<WeeklyOutcomeSummary> weeks;

  String get academicYear => weeklyPlan.academicYear;
  int? get currentWeekNumber => weeklyPlan.currentWeekNumber;

  WeeklyOutcomeSummary? week(int number) {
    for (final item in weeks) {
      if (item.week.weekNumber == number) return item;
    }
    return null;
  }

  WeeklyOutcomeSummary? get currentWeek =>
      currentWeekNumber == null ? null : week(currentWeekNumber!);
}
