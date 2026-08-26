import 'dart:convert';

typedef LessonPlanRow = Map<String, Object?>;

class LessonPlanCapability {
  const LessonPlanCapability({
    required this.available,
    required this.manifestAdvertised,
    required this.tableAvailable,
    required this.packageCount,
    required this.instructionHours,
    required this.schemaVersion,
    required this.validationStatus,
    this.reason,
  });

  const LessonPlanCapability.unavailable({this.reason})
    : available = false,
      manifestAdvertised = false,
      tableAvailable = false,
      packageCount = 0,
      instructionHours = 0,
      schemaVersion = null,
      validationStatus = null;

  final bool available;
  final bool manifestAdvertised;
  final bool tableAvailable;
  final int packageCount;
  final int instructionHours;
  final String? schemaVersion;
  final String? validationStatus;
  final String? reason;

  bool get usable => available && validationStatus == 'PASS';
}

class LessonPlanPackage {
  const LessonPlanPackage({
    required this.packageId,
    required this.courseId,
    required this.themeId,
    required this.blockId,
    required this.packageNo,
    required this.lessonHours,
    required this.title,
    required this.summary,
    required this.remainingBlockHours,
    required this.schemaVersion,
    required this.validationStatus,
    required this.sourcePath,
    required this.payloadSha256,
    required this.outcomeCodes,
    required this.usedActivityIds,
    required this.usedFormIds,
    required this.lessons,
    required this.teacherNotes,
    required this.continuation,
    required this.rawPayload,
  });

  factory LessonPlanPackage.fromRow(LessonPlanRow row) {
    final payload = _jsonMap(row['payload_json']);
    return LessonPlanPackage(
      packageId: row['package_id']?.toString() ?? '',
      courseId: row['course_id']?.toString() ?? '',
      themeId: row['theme_id']?.toString() ?? '',
      blockId: row['block_id']?.toString() ?? '',
      packageNo: _int(row['package_no']),
      lessonHours: _int(row['lesson_hours']),
      title: row['plan_title']?.toString() ?? '',
      summary: row['plan_summary']?.toString() ?? '',
      remainingBlockHours: _int(row['remaining_block_hours']),
      schemaVersion: row['schema_version']?.toString() ?? '',
      validationStatus: row['validation_status']?.toString() ?? '',
      sourcePath: row['source_path']?.toString() ?? '',
      payloadSha256: row['payload_sha256']?.toString() ?? '',
      outcomeCodes: _stringList(payload['outcome_codes']),
      usedActivityIds: _stringList(payload['used_activity_ids']),
      usedFormIds: _stringList(payload['used_form_ids']),
      lessons: _mapList(payload['lessons'])
          .map(LessonPlanLesson.fromJson)
          .toList(growable: false),
      teacherNotes: payload['teacher_notes'],
      continuation: LessonPlanContinuation.fromJson(
        _map(payload['continuation_summary']),
      ),
      rawPayload: payload,
    );
  }

  final String packageId;
  final String courseId;
  final String themeId;
  final String blockId;
  final int packageNo;
  final int lessonHours;
  final String title;
  final String summary;
  final int remainingBlockHours;
  final String schemaVersion;
  final String validationStatus;
  final String sourcePath;
  final String payloadSha256;
  final List<String> outcomeCodes;
  final List<String> usedActivityIds;
  final List<String> usedFormIds;
  final List<LessonPlanLesson> lessons;
  final Object? teacherNotes;
  final LessonPlanContinuation continuation;
  final Map<String, dynamic> rawPayload;
}

class LessonPlanLesson {
  const LessonPlanLesson({
    required this.lessonNo,
    required this.durationLessonHours,
    required this.title,
    required this.objective,
    required this.outcomeCodes,
    required this.opening,
    required this.teacherActions,
    required this.studentActions,
    required this.activityIds,
    required this.formIds,
    required this.assessment,
    required this.closure,
    required this.materials,
    required this.raw,
  });

  factory LessonPlanLesson.fromJson(Map<String, dynamic> json) =>
      LessonPlanLesson(
        lessonNo: _int(json['lesson_no']),
        durationLessonHours: _int(json['duration_lesson_hours']),
        title: json['title']?.toString() ?? '',
        objective: json['objective']?.toString() ?? '',
        outcomeCodes: _stringList(json['outcome_codes']),
        opening: json['opening'],
        teacherActions: _objectList(json['teacher_actions']),
        studentActions: _objectList(json['student_actions']),
        activityIds: _stringList(json['activity_ids']),
        formIds: _stringList(json['form_ids']),
        assessment: json['assessment'],
        closure: json['closure'],
        materials: _objectList(json['materials']),
        raw: Map<String, dynamic>.unmodifiable(json),
      );

  final int lessonNo;
  final int durationLessonHours;
  final String title;
  final String objective;
  final List<String> outcomeCodes;
  final Object? opening;
  final List<Object?> teacherActions;
  final List<Object?> studentActions;
  final List<String> activityIds;
  final List<String> formIds;
  final Object? assessment;
  final Object? closure;
  final List<Object?> materials;
  final Map<String, dynamic> raw;
}

class LessonPlanContinuation {
  const LessonPlanContinuation({
    required this.plannedNowHours,
    required this.remainingBlockHours,
    required this.coveredOutcomeCodes,
    required this.usedActivityIds,
    required this.nextStepHint,
    required this.raw,
  });

  factory LessonPlanContinuation.fromJson(Map<String, dynamic> json) =>
      LessonPlanContinuation(
        plannedNowHours: _int(json['planned_now_hours']),
        remainingBlockHours: _int(json['remaining_block_hours']),
        coveredOutcomeCodes: _stringList(json['covered_outcome_codes']),
        usedActivityIds: _stringList(json['used_activity_ids']),
        nextStepHint: json['next_step_hint']?.toString(),
        raw: Map<String, dynamic>.unmodifiable(json),
      );

  final int plannedNowHours;
  final int remainingBlockHours;
  final List<String> coveredOutcomeCodes;
  final List<String> usedActivityIds;
  final String? nextStepHint;
  final Map<String, dynamic> raw;
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is! String || value.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    return const {};
  }
  return const {};
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];

List<String> _stringList(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];

List<Object?> _objectList(Object? value) =>
    value is List ? List<Object?>.unmodifiable(value) : const [];

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
