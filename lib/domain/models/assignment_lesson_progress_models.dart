import 'lesson_plan_progress_models.dart';

class AssignmentLessonProgressRecord {
  const AssignmentLessonProgressRecord({
    required this.assignmentId,
    required this.packageId,
    required this.packageHour,
    required this.status,
    required this.updatedAt,
    this.payloadSha256,
    this.startedAt,
    this.completedAt,
  });

  final String assignmentId;
  final String packageId;
  final int packageHour;
  final String? payloadSha256;
  final LessonPlanProgressStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  AssignmentLessonProgressRecord copyWith({
    String? payloadSha256,
    bool clearPayloadSha256 = false,
    LessonPlanProgressStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) => AssignmentLessonProgressRecord(
    assignmentId: assignmentId,
    packageId: packageId,
    packageHour: packageHour,
    payloadSha256: clearPayloadSha256
        ? null
        : payloadSha256 ?? this.payloadSha256,
    status: status ?? this.status,
    startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class AssignmentLessonProgressResolution {
  const AssignmentLessonProgressResolution({
    required this.record,
    required this.bindingState,
  });

  const AssignmentLessonProgressResolution.none()
    : record = null,
      bindingState = LessonPlanProgressBindingState.none;

  final AssignmentLessonProgressRecord? record;
  final LessonPlanProgressBindingState bindingState;

  bool get isStale => bindingState == LessonPlanProgressBindingState.stale;
  bool get isCurrent => bindingState == LessonPlanProgressBindingState.current;

  LessonPlanProgressStatus get effectiveStatus => isCurrent
      ? record?.status ?? LessonPlanProgressStatus.notStarted
      : LessonPlanProgressStatus.notStarted;
}

class AssignmentLessonProgressKey {
  const AssignmentLessonProgressKey({
    required this.packageId,
    required this.packageHour,
  });

  final String packageId;
  final int packageHour;

  @override
  bool operator ==(Object other) =>
      other is AssignmentLessonProgressKey &&
      other.packageId == packageId &&
      other.packageHour == packageHour;

  @override
  int get hashCode => Object.hash(packageId, packageHour);
}
