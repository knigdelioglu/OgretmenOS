import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/services/bell_schedule_builder.dart';

void main() {
  test('ders saatlerini öğle arasıyla birlikte oluşturur', () {
    final periods = buildBellPeriods(
      const BellScheduleConfiguration(
        firstLessonStartMinute: 8 * 60 + 30,
        lessonCount: 8,
        lessonsBeforeLunch: 4,
        lunchBreakMinutes: 45,
        lessonDurationMinutes: 40,
      ),
    );

    expect(periods, hasLength(8));
    expect(periods.first.startMinute, 510);
    expect(periods.first.endMinute, 550);
    expect(periods[3].startMinute, 660);
    expect(periods[3].endMinute, 700);
    expect(periods[4].startMinute, 745);
    expect(periods[4].endMinute, 785);
    expect(periods.last.startMinute, 895);
    expect(periods.last.endMinute, 935);
  });

  test('gün sonunu aşan ayarı reddeder', () {
    expect(
      () => buildBellPeriods(
        const BellScheduleConfiguration(
          firstLessonStartMinute: 23 * 60,
          lessonCount: 2,
          lessonsBeforeLunch: 1,
          lunchBreakMinutes: 45,
          lessonDurationMinutes: 40,
        ),
      ),
      throwsArgumentError,
    );
  });
}
