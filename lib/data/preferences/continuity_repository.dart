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
    this.themeId,
    this.blockId,
    this.blockTitle,
  });

  final String courseId;
  final String academicYear;
  final int weekNumber;
  final String trackingKey;
  final String outcomeCode;
  final String? themeTitle;
  final String? themeId;
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
    'theme_id': themeId,
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
    final themeTitle = json['theme_title'];
    final themeId = json['theme_id'];
    final blockId = json['block_id'];
    final blockTitle = json['block_title'];
    if (courseId is! String ||
        academicYear is! String ||
        weekNumber is! int ||
        trackingKey is! String ||
        outcomeCode is! String ||
        updatedAt is! String ||
        (themeTitle != null && themeTitle is! String) ||
        (themeId != null && themeId is! String) ||
        (blockId != null && blockId is! String) ||
        (blockTitle != null && blockTitle is! String)) {
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
      themeTitle: themeTitle as String?,
      themeId: themeId as String?,
      blockId: blockId as String?,
      blockTitle: blockTitle as String?,
      updatedAt: parsedUpdatedAt,
    );
  }
}

typedef ContinuityChangeListener = void Function(String courseId);

abstract interface class ContinuityRepository {
  Future<LastFocusState?> getLastFocus(String courseId);

  Future<void> setLastFocus(LastFocusState state);

  Future<void> clearLastFocus(String courseId);

  void addChangeListener(ContinuityChangeListener listener);

  void removeChangeListener(ContinuityChangeListener listener);
}

class SharedPreferencesContinuityRepository implements ContinuityRepository {
  SharedPreferencesContinuityRepository(this._preferences);

  static const _keyPrefix = 'last_focus_v1_';

  final SharedPreferences _preferences;
  final List<ContinuityChangeListener> _listeners = [];

  String _key(String courseId) => '$_keyPrefix$courseId';

  @override
  void addChangeListener(ContinuityChangeListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeChangeListener(ContinuityChangeListener listener) {
    _listeners.remove(listener);
  }

  void _notify(String courseId) {
    for (final listener in List<ContinuityChangeListener>.of(_listeners)) {
      try {
        listener(courseId);
      } on Object {
        // Observer failures must never turn a completed preference write into
        // a failed continuity mutation.
      }
    }
  }

  @override
  Future<LastFocusState?> getLastFocus(String courseId) async {
    final key = _key(courseId);
    try {
      final raw = _preferences.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _removeBestEffort(key);
        return null;
      }
      final state = LastFocusState.fromJson(decoded);
      if (state == null || state.courseId != courseId) {
        await _removeBestEffort(key);
        return null;
      }
      return state;
    } on Object {
      // Continuity is convenience state. Corruption or preference read errors
      // must never block authoritative lesson content.
      await _removeBestEffort(key);
      return null;
    }
  }

  Future<void> _removeBestEffort(String key) async {
    try {
      await _preferences.remove(key);
    } on Object {
      // A failed cleanup may leave stale convenience state, but it must not
      // turn a non-authoritative preference into an app failure.
    }
  }

  @override
  Future<void> setLastFocus(LastFocusState state) async {
    await _preferences.setString(
      _key(state.courseId),
      jsonEncode(state.toJson()),
    );
    _notify(state.courseId);
  }

  @override
  Future<void> clearLastFocus(String courseId) async {
    await _preferences.remove(_key(courseId));
    _notify(courseId);
  }
}

class MemoryContinuityRepository implements ContinuityRepository {
  final Map<String, LastFocusState> _states = {};
  final List<ContinuityChangeListener> _listeners = [];

  @override
  void addChangeListener(ContinuityChangeListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeChangeListener(ContinuityChangeListener listener) {
    _listeners.remove(listener);
  }

  void _notify(String courseId) {
    for (final listener in List<ContinuityChangeListener>.of(_listeners)) {
      try {
        listener(courseId);
      } on Object {
        // Observer failures must never turn a completed in-memory write into
        // a failed continuity mutation.
      }
    }
  }

  @override
  Future<LastFocusState?> getLastFocus(String courseId) async =>
      _states[courseId];

  @override
  Future<void> setLastFocus(LastFocusState state) async {
    _states[state.courseId] = state;
    _notify(state.courseId);
  }

  @override
  Future<void> clearLastFocus(String courseId) async {
    _states.remove(courseId);
    _notify(courseId);
  }
}
