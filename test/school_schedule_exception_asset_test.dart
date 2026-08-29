import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/calendar/asset_school_schedule_exception_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('2026-2027 schedule exceptions parse full and partial days', () async {
    final repository = AssetSchoolScheduleExceptionRepository();

    final exceptions = await repository.getForAcademicYear('2026-2027');

    expect(exceptions, hasLength(7));
    final eve = exceptions.firstWhere(
      (item) => item.id == 'REPUBLIC_DAY_EVE_2026',
    );
    expect(eve.date, DateTime(2026, 10, 28));
    expect(eve.startMinute, 13 * 60);
    expect(eve.endMinute, 24 * 60);
    expect(eve.isFullDay, isFalse);

    final republicDay = exceptions.firstWhere(
      (item) => item.id == 'REPUBLIC_DAY_2026',
    );
    expect(republicDay.date, DateTime(2026, 10, 29));
    expect(republicDay.isFullDay, isTrue);

    expect(
      exceptions.map((item) => item.date),
      containsAll([
        DateTime(2027, 1, 1),
        DateTime(2027, 4, 23),
        DateTime(2027, 5, 17),
        DateTime(2027, 5, 18),
        DateTime(2027, 5, 19),
      ]),
    );
  });

  test('unknown academic year fails closed with no invented exceptions', () async {
    final repository = AssetSchoolScheduleExceptionRepository();

    final exceptions = await repository.getForAcademicYear('2099-2100');

    expect(exceptions, isEmpty);
  });
}
