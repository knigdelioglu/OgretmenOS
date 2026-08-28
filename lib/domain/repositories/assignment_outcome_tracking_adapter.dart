import '../models/assignment_outcome_tracking_models.dart';
import '../models/outcome_tracking_models.dart';
import 'assignment_outcome_tracking_repository.dart';
import 'outcome_tracking_repository.dart';

/// Presents one teaching assignment as an ordinary outcome-tracking scope so
/// the existing planning service can remain unaware of persistence identity.
class AssignmentOutcomeTrackingAdapter implements OutcomeTrackingRepository {
  const AssignmentOutcomeTrackingAdapter({
    required this.repository,
    required this.assignmentId,
    required this.academicYear,
  });

  final AssignmentOutcomeTrackingRepository repository;
  final String assignmentId;
  final String academicYear;

  @override
  Future<List<LearningOutcomeTrackingRecord>> getForAcademicYear(
    String requestedAcademicYear,
  ) async {
    _requireAcademicYear(requestedAcademicYear);
    final records = await repository.getForAssignment(assignmentId);
    return records.map(_toLegacy).toList(growable: false);
  }

  @override
  Future<void> save(LearningOutcomeTrackingRecord record) async {
    _requireAcademicYear(record.academicYear);
    await repository.save(
      AssignmentOutcomeTrackingRecord(
        assignmentId: assignmentId,
        outcomeId: record.outcomeId,
        plannedWeekNumber: record.plannedWeekNumber,
        status: record.status,
        actualHours: record.actualHours,
        teacherNote: record.teacherNote,
        completedAt: record.completedAt,
        carriedToWeekNumber: record.carriedToWeekNumber,
        updatedAt: record.updatedAt,
      ),
    );
  }

  @override
  Future<void> delete({
    required String academicYear,
    required String outcomeId,
    required int plannedWeekNumber,
  }) async {
    _requireAcademicYear(academicYear);
    await repository.delete(
      assignmentId: assignmentId,
      outcomeId: outcomeId,
      plannedWeekNumber: plannedWeekNumber,
    );
  }

  LearningOutcomeTrackingRecord _toLegacy(
    AssignmentOutcomeTrackingRecord record,
  ) => LearningOutcomeTrackingRecord(
    academicYear: academicYear,
    outcomeId: record.outcomeId,
    plannedWeekNumber: record.plannedWeekNumber,
    status: record.status,
    actualHours: record.actualHours,
    teacherNote: record.teacherNote,
    completedAt: record.completedAt,
    carriedToWeekNumber: record.carriedToWeekNumber,
    updatedAt: record.updatedAt,
  );

  void _requireAcademicYear(String value) {
    if (value != academicYear) {
      throw StateError(
        'Outcome tracking scope akademik yıl uyuşmazlığı: '
        '$value != $academicYear',
      );
    }
  }
}
