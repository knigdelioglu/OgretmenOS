import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy manual position override ayrı yerel tercihte tutulur', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesUserPreferences(preferences);

    expect(await repository.getManualPositionOverride(), isNull);
    await repository.setManualPositionOverride('BLOCK_TEST');
    expect(await repository.getManualPositionOverride(), 'BLOCK_TEST');
    await repository.clearManualPositionOverride();
    expect(await repository.getManualPositionOverride(), isNull);
  });

  test(
    'manuel yıllık konum ders bazında ayrılır ve zaman damgası taşır',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesUserPreferences(preferences);

      await repository.setManualPositionOverrideForCourse('TDE_9', 'B9');
      await repository.setManualPositionOverrideForCourse('TDE_10', 'B10');

      final grade9 = await repository.getManualPositionOverrideForCourse(
        'TDE_9',
      );
      final grade10 = await repository.getManualPositionOverrideForCourse(
        'TDE_10',
      );
      expect(grade9?.courseId, 'TDE_9');
      expect(grade9?.blockId, 'B9');
      expect(grade9?.updatedAt, isNotNull);
      expect(grade10?.courseId, 'TDE_10');
      expect(grade10?.blockId, 'B10');

      await repository.clearManualPositionOverrideForCourse('TDE_9');
      expect(
        await repository.getManualPositionOverrideForCourse('TDE_9'),
        isNull,
      );
      expect(
        (await repository.getManualPositionOverrideForCourse(
          'TDE_10',
        ))?.blockId,
        'B10',
      );
    },
  );

  test('eski global işaret en eski zaman damgasıyla okunur', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesUserPreferences.manualPositionKey: 'LEGACY_BLOCK',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesUserPreferences(preferences);

    final state = await repository.getManualPositionOverrideForCourse('TDE_9');
    expect(state?.blockId, 'LEGACY_BLOCK');
    expect(state?.updatedAt.millisecondsSinceEpoch, 0);
  });
}
