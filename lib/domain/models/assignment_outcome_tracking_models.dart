import 'outcome_tracking_models.dart';

class AssignmentOutcomeTrackingRecord {
  const AssignmentOutcomeTrackingRecord({
    required this.assignmentId,
    required this.outcomeId,
    required this.plannedWeekNumber,
    required this.status,
    required this.updatedAt,
    this.actualHours,
    this.teacherNote,
    this.completedAt,
    this.carriedToWeekNumber,
  });

  final String assignmentId;
  final String outcomeId;
  final int plannedWeekNumber;
  final OutcomeTrackingStatus status;
  final int? actualHours;
  final String? teacherNote;
  final DateTime? completedAt;
  final int? carriedToWeekNumber;
  final DateTime updatedAt;

  String get trackingKey => assignmentOutcomeTrackingKey(
    assignmentId: assignmentId,
    outcomeId: outcomeId,
    plannedWeekNumber: plannedWeekNumber,
  );

  AssignmentOutcomeTrackingRecord copyWith({
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
  }) => AssignmentOutcomeTrackingRecord(
    assignmentId: assignmentId,
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

String assignmentOutcomeTrackingKey({
  required String assignmentId,
  required String outcomeId,
  required int plannedWeekNumber,
}) => '$assignmentId:$outcomeId:$plannedWeekNumber';
