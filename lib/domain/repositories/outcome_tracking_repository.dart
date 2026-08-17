import '../models/outcome_tracking_models.dart';

abstract interface class OutcomeTrackingRepository {
  Future<List<LearningOutcomeTrackingRecord>> getForAcademicYear(
    String academicYear,
  );

  Future<void> save(LearningOutcomeTrackingRecord record);

  Future<void> delete({
    required String academicYear,
    required String outcomeId,
    required int plannedWeekNumber,
  });
}

class MemoryOutcomeTrackingRepository implements OutcomeTrackingRepository {
  final Map<String, LearningOutcomeTrackingRecord> _records = {};

  String _key(String academicYear, String outcomeId, int weekNumber) =>
      '$academicYear:$outcomeId:$weekNumber';

  @override
  Future<List<LearningOutcomeTrackingRecord>> getForAcademicYear(
    String academicYear,
  ) async => _records.values
      .where((record) => record.academicYear == academicYear)
      .toList(growable: false);

  @override
  Future<void> save(LearningOutcomeTrackingRecord record) async {
    _records[_key(record.academicYear, record.outcomeId, record.plannedWeekNumber)] =
        record;
  }

  @override
  Future<void> delete({
    required String academicYear,
    required String outcomeId,
    required int plannedWeekNumber,
  }) async {
    _records.remove(_key(academicYear, outcomeId, plannedWeekNumber));
  }
}
