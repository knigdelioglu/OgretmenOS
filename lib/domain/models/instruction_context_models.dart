enum AssignmentProgressMode {
  followSchedule,
  manualOffset;

  String get storageValue => switch (this) {
    AssignmentProgressMode.followSchedule => 'follow_schedule',
    AssignmentProgressMode.manualOffset => 'manual_offset',
  };

  static AssignmentProgressMode fromStorage(String value) => switch (value) {
    'manual_offset' => AssignmentProgressMode.manualOffset,
    _ => AssignmentProgressMode.followSchedule,
  };
}

class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.academicYear,
    required this.grade,
    required this.section,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String academicYear;
  final int grade;
  final String section;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  SchoolClass copyWith({
    int? grade,
    String? section,
    String? displayName,
    DateTime? updatedAt,
  }) => SchoolClass(
    id: id,
    academicYear: academicYear,
    grade: grade ?? this.grade,
    section: section ?? this.section,
    displayName: displayName ?? this.displayName,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class TeachingAssignment {
  const TeachingAssignment({
    required this.id,
    required this.academicYear,
    required this.courseId,
    required this.classId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String academicYear;
  final String courseId;
  final String classId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeachingAssignment copyWith({
    bool? isActive,
    DateTime? updatedAt,
  }) => TeachingAssignment(
    id: id,
    academicYear: academicYear,
    courseId: courseId,
    classId: classId,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class BellPeriod {
  const BellPeriod({
    required this.periodNumber,
    required this.startMinute,
    required this.endMinute,
  });

  final int periodNumber;
  final int startMinute;
  final int endMinute;

  bool containsMinute(int minuteOfDay) =>
      minuteOfDay >= startMinute && minuteOfDay < endMinute;
}

class LessonScheduleSlot {
  const LessonScheduleSlot({
    required this.id,
    required this.assignmentId,
    required this.weekday,
    required this.periodNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String assignmentId;

  /// ISO weekday: Monday = 1, Sunday = 7.
  final int weekday;
  final int periodNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AssignmentProgressCursor {
  const AssignmentProgressCursor({
    required this.assignmentId,
    required this.mode,
    required this.plannedOrdinalAtAnchor,
    required this.actualOrdinalAtAnchor,
    required this.anchoredAt,
    required this.updatedAt,
  });

  final String assignmentId;
  final AssignmentProgressMode mode;
  final int plannedOrdinalAtAnchor;
  final int actualOrdinalAtAnchor;
  final DateTime anchoredAt;
  final DateTime updatedAt;

  int actualOrdinalForPlanned(int plannedOrdinal) => switch (mode) {
    AssignmentProgressMode.followSchedule => plannedOrdinal,
    AssignmentProgressMode.manualOffset =>
      actualOrdinalAtAnchor + (plannedOrdinal - plannedOrdinalAtAnchor),
  };

  AssignmentProgressCursor copyWith({
    AssignmentProgressMode? mode,
    int? plannedOrdinalAtAnchor,
    int? actualOrdinalAtAnchor,
    DateTime? anchoredAt,
    DateTime? updatedAt,
  }) => AssignmentProgressCursor(
    assignmentId: assignmentId,
    mode: mode ?? this.mode,
    plannedOrdinalAtAnchor:
        plannedOrdinalAtAnchor ?? this.plannedOrdinalAtAnchor,
    actualOrdinalAtAnchor: actualOrdinalAtAnchor ?? this.actualOrdinalAtAnchor,
    anchoredAt: anchoredAt ?? this.anchoredAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum ScheduleTimingState { past, current, future }

class AssignmentSchedulePosition {
  const AssignmentSchedulePosition({
    required this.assignmentId,
    required this.plannedOrdinal,
    required this.actualOrdinal,
    required this.timingState,
    required this.slot,
    required this.occursAt,
  });

  final String assignmentId;
  final int plannedOrdinal;
  final int actualOrdinal;
  final ScheduleTimingState timingState;
  final LessonScheduleSlot slot;
  final DateTime occursAt;

  int get delta => actualOrdinal - plannedOrdinal;
  bool get followsSchedule => delta == 0;
}
