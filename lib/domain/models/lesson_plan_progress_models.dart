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

class LessonPlanProgressRecord {
  const LessonPlanProgressRecord({
    required this.courseId,
    required this.academicYear,
    required this.packageId,
    required this.status,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
  });

  final String courseId;
  final String academicYear;
  final String packageId;
  final LessonPlanProgressStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  LessonPlanProgressRecord copyWith({
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
    status: status ?? this.status,
    startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class LessonPlanProgressSnapshot {
  const LessonPlanProgressSnapshot({
    required this.records,
    required this.currentPackageId,
    required this.nextPackageId,
  });

  final Map<String, LessonPlanProgressRecord> records;
  final String? currentPackageId;
  final String? nextPackageId;

  LessonPlanProgressStatus statusFor(String packageId) =>
      records[packageId]?.status ?? LessonPlanProgressStatus.notStarted;
}
