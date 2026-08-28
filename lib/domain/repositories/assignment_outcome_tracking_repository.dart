import '../models/assignment_outcome_tracking_models.dart';

abstract interface class AssignmentOutcomeTrackingRepository {
  Future<List<AssignmentOutcomeTrackingRecord>> getForAssignment(
    String assignmentId,
  );

  Future<AssignmentOutcomeTrackingRecord?> get({
    required String assignmentId,
    required String outcomeId,
    required int plannedWeekNumber,
  });

  Future<void> save(AssignmentOutcomeTrackingRecord record);

  Future<void> delete({
    required String assignmentId,
    required String outcomeId,
    required int plannedWeekNumber,
  });
}

class MemoryAssignmentOutcomeTrackingRepository
    implements AssignmentOutcomeTrackingRepository {
  final Map<String, AssignmentOutcomeTrackingRecord> _records = {};

  String _key(String assignmentId, String outcomeId, int plannedWeekNumber) =>
      '$assignmentId\u0000$outcomeId\u0000$plannedWeekNumber';

  @override
  Future<List<AssignmentOutcomeTrackingRecord>> getForAssignment(
    String assignmentId,
  ) async => _records.values
      .where((record) => record.assignmentId == assignmentId)
      .toList(growable: false);

  @override
  Future<AssignmentOutcomeTrackingRecord?> get({
    required String assignmentId,
    required String outcomeId,
    required int plannedWeekNumber,
  }) async => _records[_key(assignmentId, outcomeId, plannedWeekNumber)];

  @override
  Future<void> save(AssignmentOutcomeTrackingRecord record) async {
    _records[_key(
      record.assignmentId,
      record.outcomeId,
      record.plannedWeekNumber,
    )] = record;
  }

  @override
  Future<void> delete({
    required String assignmentId,
    required String outcomeId,
    required int plannedWeekNumber,
  }) async {
    _records.remove(_key(assignmentId, outcomeId, plannedWeekNumber));
  }
}
