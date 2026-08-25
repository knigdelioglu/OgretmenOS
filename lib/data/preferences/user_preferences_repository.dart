import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ManualPositionOverrideState {
  const ManualPositionOverrideState({
    required this.courseId,
    required this.blockId,
    required this.updatedAt,
  });

  final String courseId;
  final String blockId;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'course_id': courseId,
    'block_id': blockId,
    'updated_at': updatedAt.toIso8601String(),
  };

  static ManualPositionOverrideState? fromJson(Map<String, Object?> json) {
    final courseId = json['course_id'];
    final blockId = json['block_id'];
    final updatedAt = json['updated_at'];
    if (courseId is! String || blockId is! String || updatedAt is! String) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;
    return ManualPositionOverrideState(
      courseId: courseId,
      blockId: blockId,
      updatedAt: parsedUpdatedAt,
    );
  }
}

abstract interface class UserPreferencesRepository {
  Future<String?> getManualPositionOverride();

  Future<void> setManualPositionOverride(String blockId);

  Future<void> clearManualPositionOverride();
}

/// Optional richer contract used by the production annual-plan experience.
///
/// Keeping this separate preserves lightweight test/fake implementations of
/// [UserPreferencesRepository] while letting production scope a manual marker
/// per course and compare it with continuity timestamps.
abstract interface class ScopedManualPositionPreferences {
  Future<ManualPositionOverrideState?> getManualPositionOverrideForCourse(
    String courseId,
  );

  Future<void> setManualPositionOverrideForCourse(
    String courseId,
    String blockId,
  );

  Future<void> clearManualPositionOverrideForCourse(String courseId);
}

class SharedPreferencesUserPreferences
    implements UserPreferencesRepository, ScopedManualPositionPreferences {
  const SharedPreferencesUserPreferences(this._preferences);

  static const manualPositionKey = 'manual_position_override';
  static const _scopedManualPositionPrefix = 'manual_position_override_v2_';

  final SharedPreferences _preferences;

  String _scopedKey(String courseId) => '$_scopedManualPositionPrefix$courseId';

  @override
  Future<String?> getManualPositionOverride() async =>
      _preferences.getString(manualPositionKey);

  @override
  Future<void> setManualPositionOverride(String blockId) async {
    await _preferences.setString(manualPositionKey, blockId);
  }

  @override
  Future<void> clearManualPositionOverride() async {
    await _preferences.remove(manualPositionKey);
  }

  @override
  Future<ManualPositionOverrideState?> getManualPositionOverrideForCourse(
    String courseId,
  ) async {
    final key = _scopedKey(courseId);
    final raw = _preferences.getString(key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final state = ManualPositionOverrideState.fromJson(decoded);
          if (state != null && state.courseId == courseId) return state;
        }
      } on FormatException {
        // Malformed preference is non-authoritative convenience state.
      }
      await _preferences.remove(key);
    }

    // Backward-compatible fallback for the pre-Faz-5 global string. It gets
    // the oldest possible timestamp so any real viewed-lesson continuity wins.
    final legacy = _preferences.getString(manualPositionKey);
    if (legacy == null) return null;
    return ManualPositionOverrideState(
      courseId: courseId,
      blockId: legacy,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  Future<void> setManualPositionOverrideForCourse(
    String courseId,
    String blockId,
  ) async {
    final state = ManualPositionOverrideState(
      courseId: courseId,
      blockId: blockId,
      updatedAt: DateTime.now(),
    );
    await _preferences.setString(
      _scopedKey(courseId),
      jsonEncode(state.toJson()),
    );
    await _preferences.remove(manualPositionKey);
  }

  @override
  Future<void> clearManualPositionOverrideForCourse(String courseId) async {
    await _preferences.remove(_scopedKey(courseId));
    await _preferences.remove(manualPositionKey);
  }
}
