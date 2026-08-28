import '../models/instruction_context_models.dart';
import '../repositories/instruction_context_repository.dart';

class AssignmentProgressCursorService {
  const AssignmentProgressCursorService({required this.repository});

  final InstructionContextRepository repository;

  Future<AssignmentProgressCursor> setActualPosition({
    required String assignmentId,
    required int plannedOrdinal,
    required int actualOrdinal,
    DateTime? now,
  }) async {
    if (plannedOrdinal < 0) {
      throw ArgumentError.value(plannedOrdinal, 'plannedOrdinal');
    }
    if (actualOrdinal < 0) {
      throw ArgumentError.value(actualOrdinal, 'actualOrdinal');
    }
    final timestamp = now ?? DateTime.now();
    final mode = actualOrdinal == plannedOrdinal
        ? AssignmentProgressMode.followSchedule
        : AssignmentProgressMode.manualOffset;
    final cursor = AssignmentProgressCursor(
      assignmentId: assignmentId,
      mode: mode,
      plannedOrdinalAtAnchor: plannedOrdinal,
      actualOrdinalAtAnchor: actualOrdinal,
      anchoredAt: timestamp,
      updatedAt: timestamp,
    );
    await repository.saveProgressCursor(cursor);
    return cursor;
  }

  Future<void> followSchedule(String assignmentId) =>
      repository.deleteProgressCursor(assignmentId);

  Future<AssignmentProgressCursor?> reanchorForScheduleChange({
    required String assignmentId,
    required int oldPlannedOrdinal,
    required int newPlannedOrdinal,
    DateTime? now,
  }) async {
    final previous = await repository.getProgressCursor(assignmentId);
    if (previous == null ||
        previous.mode == AssignmentProgressMode.followSchedule) {
      return null;
    }
    final actualBeforeChange = previous.actualOrdinalForPlanned(
      oldPlannedOrdinal,
    );
    final timestamp = now ?? DateTime.now();
    final reanchored = AssignmentProgressCursor(
      assignmentId: assignmentId,
      mode: actualBeforeChange == newPlannedOrdinal
          ? AssignmentProgressMode.followSchedule
          : AssignmentProgressMode.manualOffset,
      plannedOrdinalAtAnchor: newPlannedOrdinal,
      actualOrdinalAtAnchor: actualBeforeChange < 0 ? 0 : actualBeforeChange,
      anchoredAt: timestamp,
      updatedAt: timestamp,
    );
    await repository.saveProgressCursor(reanchored);
    return reanchored;
  }
}
