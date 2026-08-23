import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LastFocusState {
  const LastFocusState({
    required this.courseId,
    required this.academicYear,
    required this.weekNumber,
    required this.trackingKey,
    required this.outcomeCode,
    required this.updatedAt,
    this.themeTitle,
    this.blockId,
    this.blockTitle,
  });

  final String courseId;
  final String academicYear;
  final int weekNumber;
  final String trackingKey;
  final String outcomeCode;
  final String? themeTitle;
  final String? blockId;
  final String? blockTitle;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'course_id': courseId,
    'academic_year': academicYear,
    'week_number': weekNumber,
    'tracking_key': trackingKey,
    'outcome_code': outcomeCode,
    'theme_title': themeTitle,
    'block_id': blockId,
    'block_title': blockTitle,
    'updated_at': updatedAt.toIso8601String(),
  };

  static LastFocusState? fromJson(Map<String, Object?> json) {
    final courseId = json['course_id'];
    final academicYear = json['academic_year'];
    final weekNumber = json['week_number'];
    final trackingKey = json['tracking_key'];
    final outcomeCode = json['outcome_code'];
    final updatedAt = json['updated_at'];
    if (courseId is! String ||
        academicYear is! String ||
        weekNumber is! int ||
        trackingKey is! String ||
        outcomeCode is! String ||
        updatedAt is! String) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;
    return LastFocusState(
      courseId: courseId,
      academicYear: academicYear,
      weekNumber: weekNumber,
      trackingKey: trackingKey,
      outcomeCode: outcomeCode,
      themeTitle: json['theme_title'] as String?,
      blockId: json['block_id'] as String?,
      blockTitle: json['block_title'] as String?,
      updatedAt: parsedUpdatedAt,
    );
  }
}

abstract interface class ContinuityRepository {
  Future<LastFocusState?> getLastFocus(String courseId);

  Future<void> setLastFocus(LastFocusState state);

  Future<void> clearLastFocus(String courseId);
}

class SharedPreferencesContinuityRepository implements ContinuityRepository {
  const SharedPreferencesContinuityRepository(this._preferences);

  static const _keyPrefix = 'last_focus_v1_';

  final SharedPreferences _preferences;

  String _key(String courseId) => '$_keyPrefix$courseId';

  @override
  Future<LastFocusState?> getLastFocus(String courseId) async {
    final key = _key(courseId);
    final raw = _preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _preferences.remove(key);
        return null;
      }
      final state = LastFocusState.fromJson(decoded);
      if (state == null || state.courseId != courseId) {
        await _preferences.remove(key);
        return null;
      }
      return state;
    } on FormatException {
      await _preferences.remove(key);
      return null;
    }
  }

  @override
  Future<void> setLastFocus(LastFocusState state) async {
    await _preferences.setString(_key(state.courseId), jsonEncode(state.toJson()));
  }

  @override
  Future<void> clearLastFocus(String courseId) async {
    await _preferences.remove(_key(courseId));
  }
}

class MemoryContinuityRepository implements ContinuityRepository {
  final Map<String, LastFocusState> _states = {};

  @override
  Future<LastFocusState?> getLastFocus(String courseId) async => _states[courseId];

  @override
  Future<void> setLastFocus(LastFocusState state) async {
    _states[state.courseId] = state;
  }

  @override
  Future<void> clearLastFocus(String courseId) async {
    _states.remove(courseId);
  }
}
