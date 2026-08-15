import 'package:shared_preferences/shared_preferences.dart';

abstract interface class UserPreferencesRepository {
  Future<String?> getManualPositionOverride();

  Future<void> setManualPositionOverride(String blockId);

  Future<void> clearManualPositionOverride();
}

class SharedPreferencesUserPreferences implements UserPreferencesRepository {
  const SharedPreferencesUserPreferences(this._preferences);

  static const manualPositionKey = 'manual_position_override';

  final SharedPreferences _preferences;

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
}
