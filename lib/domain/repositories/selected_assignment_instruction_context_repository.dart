import '../models/instruction_context_models.dart';
import 'instruction_context_repository.dart';

/// Restricts assignment discovery and assignment-scoped mutations to one
/// teaching assignment while preserving shared bell-period/class reads on the
/// underlying repository.
class SelectedAssignmentInstructionContextRepository
    implements InstructionContextRepository {
  const SelectedAssignmentInstructionContextRepository({
    required this.delegate,
    required this.assignmentId,
  });

  final InstructionContextRepository delegate;
  final String assignmentId;

  @override
  Future<List<SchoolClass>> getClasses(String academicYear) =>
      delegate.getClasses(academicYear);

  @override
  Future<SchoolClass?> getClass(String classId) => delegate.getClass(classId);

  @override
  Future<void> saveClass(SchoolClass schoolClass) =>
      delegate.saveClass(schoolClass);

  @override
  Future<void> createClassWithAssignment({
    required SchoolClass schoolClass,
    required TeachingAssignment assignment,
  }) {
    _requireSelected(assignment.id);
    return delegate.createClassWithAssignment(
      schoolClass: schoolClass,
      assignment: assignment,
    );
  }

  @override
  Future<void> deleteClass(String classId) => delegate.deleteClass(classId);

  @override
  Future<List<TeachingAssignment>> getAssignments({
    required String academicYear,
    String? courseId,
    bool activeOnly = true,
  }) async {
    final assignments = await delegate.getAssignments(
      academicYear: academicYear,
      courseId: courseId,
      activeOnly: activeOnly,
    );
    return assignments
        .where((assignment) => assignment.id == assignmentId)
        .toList(growable: false);
  }

  @override
  Future<TeachingAssignment?> getAssignment(String requestedAssignmentId) {
    if (requestedAssignmentId != assignmentId) return Future.value(null);
    return delegate.getAssignment(requestedAssignmentId);
  }

  @override
  Future<void> saveAssignment(TeachingAssignment assignment) {
    _requireSelected(assignment.id);
    return delegate.saveAssignment(assignment);
  }

  @override
  Future<void> deleteAssignment(String requestedAssignmentId) {
    _requireSelected(requestedAssignmentId);
    return delegate.deleteAssignment(requestedAssignmentId);
  }

  @override
  Future<List<BellPeriod>> getBellPeriods() => delegate.getBellPeriods();

  @override
  Future<void> replaceBellPeriods(List<BellPeriod> periods) =>
      delegate.replaceBellPeriods(periods);

  @override
  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignment(
    String requestedAssignmentId,
  ) {
    if (requestedAssignmentId != assignmentId) return Future.value(const []);
    return delegate.getScheduleSlotsForAssignment(requestedAssignmentId);
  }

  @override
  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignments(
    Iterable<String> assignmentIds,
  ) {
    final containsSelected = assignmentIds.contains(assignmentId);
    if (!containsSelected) return Future.value(const []);
    return delegate.getScheduleSlotsForAssignments([assignmentId]);
  }

  @override
  Future<void> replaceScheduleSlotsForAssignment({
    required String assignmentId,
    required List<LessonScheduleSlot> slots,
  }) {
    _requireSelected(assignmentId);
    return delegate.replaceScheduleSlotsForAssignment(
      assignmentId: assignmentId,
      slots: slots,
    );
  }

  @override
  Future<AssignmentProgressCursor?> getProgressCursor(
    String requestedAssignmentId,
  ) {
    if (requestedAssignmentId != assignmentId) return Future.value(null);
    return delegate.getProgressCursor(requestedAssignmentId);
  }

  @override
  Future<void> saveProgressCursor(AssignmentProgressCursor cursor) {
    _requireSelected(cursor.assignmentId);
    return delegate.saveProgressCursor(cursor);
  }

  @override
  Future<void> deleteProgressCursor(String requestedAssignmentId) {
    _requireSelected(requestedAssignmentId);
    return delegate.deleteProgressCursor(requestedAssignmentId);
  }

  void _requireSelected(String requestedAssignmentId) {
    if (requestedAssignmentId != assignmentId) {
      throw StateError(
        'Selected assignment scope violation: $requestedAssignmentId',
      );
    }
  }
}
