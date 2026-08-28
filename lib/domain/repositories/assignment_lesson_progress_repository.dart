import '../models/assignment_lesson_progress_models.dart';

abstract interface class AssignmentLessonProgressRepository {
  Future<List<AssignmentLessonProgressRecord>> getForAssignment(
    String assignmentId,
  );

  Future<AssignmentLessonProgressRecord?> get({
    required String assignmentId,
    required String packageId,
    required int packageHour,
  });

  Future<void> save(AssignmentLessonProgressRecord record);

  Future<void> delete({
    required String assignmentId,
    required String packageId,
    required int packageHour,
  });
}

class MemoryAssignmentLessonProgressRepository
    implements AssignmentLessonProgressRepository {
  final Map<String, AssignmentLessonProgressRecord> _records = {};

  String _key(String assignmentId, String packageId, int packageHour) =>
      '$assignmentId\u0000$packageId\u0000$packageHour';

  @override
  Future<List<AssignmentLessonProgressRecord>> getForAssignment(
    String assignmentId,
  ) async => _records.values
      .where((record) => record.assignmentId == assignmentId)
      .toList(growable: false);

  @override
  Future<AssignmentLessonProgressRecord?> get({
    required String assignmentId,
    required String packageId,
    required int packageHour,
  }) async => _records[_key(assignmentId, packageId, packageHour)];

  @override
  Future<void> save(AssignmentLessonProgressRecord record) async {
    _records[_key(record.assignmentId, record.packageId, record.packageHour)] =
        record;
  }

  @override
  Future<void> delete({
    required String assignmentId,
    required String packageId,
    required int packageHour,
  }) async {
    _records.remove(_key(assignmentId, packageId, packageHour));
  }
}
