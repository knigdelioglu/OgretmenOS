import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LegacyMigrationDecision {
  const LegacyMigrationDecision({
    required this.courseId,
    required this.academicYear,
    required this.assignmentId,
    required this.decidedAt,
  });

  final String courseId;
  final String academicYear;
  final String assignmentId;
  final DateTime decidedAt;

  Map<String, Object?> toJson() => {
    'course_id': courseId,
    'academic_year': academicYear,
    'assignment_id': assignmentId,
    'decided_at': decidedAt.toUtc().toIso8601String(),
  };

  static LegacyMigrationDecision? fromJson(Map<String, Object?> json) {
    final courseId = json['course_id'];
    final academicYear = json['academic_year'];
    final assignmentId = json['assignment_id'];
    final decidedAt = json['decided_at'];
    if (courseId is! String ||
        academicYear is! String ||
        assignmentId is! String ||
        decidedAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(decidedAt);
    if (parsed == null) return null;
    return LegacyMigrationDecision(
      courseId: courseId,
      academicYear: academicYear,
      assignmentId: assignmentId,
      decidedAt: parsed.toLocal(),
    );
  }
}

abstract interface class LegacyMigrationDecisionRepository {
  Future<LegacyMigrationDecision?> get({
    required String courseId,
    required String academicYear,
  });

  Future<void> save(LegacyMigrationDecision decision);

  Future<void> clear({
    required String courseId,
    required String academicYear,
  });
}

class SharedPreferencesLegacyMigrationDecisionRepository
    implements LegacyMigrationDecisionRepository {
  const SharedPreferencesLegacyMigrationDecisionRepository(this._preferences);

  static const _prefix = 'legacy_teacher_state_migration_v1_';

  final SharedPreferences _preferences;

  String _key(String courseId, String academicYear) =>
      '$_prefix${_safe(courseId)}_${_safe(academicYear)}';

  @override
  Future<LegacyMigrationDecision?> get({
    required String courseId,
    required String academicYear,
  }) async {
    final key = _key(courseId, academicYear);
    final raw = _preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _preferences.remove(key);
        return null;
      }
      final decision = LegacyMigrationDecision.fromJson(decoded);
      if (decision == null ||
          decision.courseId != courseId ||
          decision.academicYear != academicYear) {
        await _preferences.remove(key);
        return null;
      }
      return decision;
    } on Object {
      try {
        await _preferences.remove(key);
      } on Object {
        // This preference is only a duplicate-import guard.
      }
      return null;
    }
  }

  @override
  Future<void> save(LegacyMigrationDecision decision) async {
    await _preferences.setString(
      _key(decision.courseId, decision.academicYear),
      jsonEncode(decision.toJson()),
    );
  }

  @override
  Future<void> clear({
    required String courseId,
    required String academicYear,
  }) async {
    await _preferences.remove(_key(courseId, academicYear));
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
}

class MemoryLegacyMigrationDecisionRepository
    implements LegacyMigrationDecisionRepository {
  final Map<String, LegacyMigrationDecision> _values = {};

  String _key(String courseId, String academicYear) => '$courseId::$academicYear';

  @override
  Future<LegacyMigrationDecision?> get({
    required String courseId,
    required String academicYear,
  }) async => _values[_key(courseId, academicYear)];

  @override
  Future<void> save(LegacyMigrationDecision decision) async {
    _values[_key(decision.courseId, decision.academicYear)] = decision;
  }

  @override
  Future<void> clear({
    required String courseId,
    required String academicYear,
  }) async {
    _values.remove(_key(courseId, academicYear));
  }
}
