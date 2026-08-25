import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';

void main() {
  test('tracking identity uses one canonical encoding', () {
    final record = LearningOutcomeTrackingRecord(
      academicYear: '2026-2027',
      outcomeId: 'OUTCOME_1',
      plannedWeekNumber: 7,
      status: OutcomeTrackingStatus.completed,
      updatedAt: DateTime(2026, 10, 1),
    );

    expect(
      record.trackingKey,
      outcomeTrackingKey(
        academicYear: '2026-2027',
        outcomeId: 'OUTCOME_1',
        plannedWeekNumber: 7,
      ),
    );
    expect(record.trackingKey, '2026-2027:OUTCOME_1:7');
  });
}
