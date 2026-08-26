enum LessonPlanProgressStatus {
  notStarted,
  inProgress,
  completed;

  String get storageValue => switch (this) {
    LessonPlanProgressStatus.notStarted => 'not_started',
    LessonPlanProgressStatus.inProgress => 'in_progress',
    LessonPlanProgressStatus.completed => 'completed',
  };

  String get teacherLabel => switch (this) {
    LessonPlanProgressStatus.notStarted => 'Başlanmadı',
    LessonPlanProgressStatus.inProgress => 'Kısmen işlendi',
    LessonPlanProgressStatus.completed => 'İşlendi',
  };

  static LessonPlanProgressStatus fromStorage(String value) => switch (value) {
    'in_progress' => LessonPlanProgressStatus.inProgress,
    'completed' => LessonPlanProgressStatus.completed,
    _ => LessonPlanProgressStatus.notStarted,
  };
}

enum LessonPlanProgressBindingState { none, current, stale }

class LessonPlanProgressRecord {
  const LessonPlanProgressRecord({
    required this.courseId,
    required this.academicYear,
    required this.packageId,
    required this.status,
    required this.updatedAt,
    this.payloadSha256,
    this.startedAt,
    this.completedAt,
  });

  final String courseId;
  final String academicYear;
  final String packageId;
  final String? payloadSha256;
  final LessonPlanProgressStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  LessonPlanProgressRecord copyWith({
    String? payloadSha256,
    bool clearPayloadSha256 = false,
    LessonPlanProgressStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) => LessonPlanProgressRecord(
    courseId: courseId,
    academicYear: academicYear,
    packageId: packageId,
    payloadSha256: clearPayloadSha256
        ? null
        : payloadSha256 ?? this.payloadSha256,
    status: status ?? this.status,
    startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class LessonPlanProgressResolution {
  const LessonPlanProgressResolution({
    required this.record,
    required this.bindingState,
  });

  const LessonPlanProgressResolution.none()
    : record = null,
      bindingState = LessonPlanProgressBindingState.none;

  final LessonPlanProgressRecord? record;
  final LessonPlanProgressBindingState bindingState;

  bool get isStale => bindingState == LessonPlanProgressBindingState.stale;
  bool get isCurrent => bindingState == LessonPlanProgressBindingState.current;

  LessonPlanProgressStatus get effectiveStatus => isCurrent
      ? record?.status ?? LessonPlanProgressStatus.notStarted
      : LessonPlanProgressStatus.notStarted;
}

class LessonPlanProgressSnapshot {
  const LessonPlanProgressSnapshot({
    required this.records,
    required this.stalePackageIds,
    required this.currentPackageId,
    required this.nextPackageId,
  });

  final Map<String, LessonPlanProgressRecord> records;
  final Set<String> stalePackageIds;
  final String? currentPackageId;
  final String? nextPackageId;

  LessonPlanProgressStatus statusFor(String packageId) =>
      records[packageId]?.status ?? LessonPlanProgressStatus.notStarted;

  bool isStale(String packageId) => stalePackageIds.contains(packageId);
}
