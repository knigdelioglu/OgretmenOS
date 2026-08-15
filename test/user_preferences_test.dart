import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('manual position override ayrı yerel tercihte tutulur', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesUserPreferences(preferences);

    expect(await repository.getManualPositionOverride(), isNull);
    await repository.setManualPositionOverride('BLOCK_TEST');
    expect(await repository.getManualPositionOverride(), 'BLOCK_TEST');
    await repository.clearManualPositionOverride();
    expect(await repository.getManualPositionOverride(), isNull);
  });
}
