import '../models/assignment_lesson_progress_models.dart';
import '../models/lesson_plan_models.dart';
import '../models/lesson_plan_progress_models.dart';
import '../repositories/assignment_lesson_progress_repository.dart';

class AssignmentLessonProgressService {
  const AssignmentLessonProgressService({required this.repository});

  final AssignmentLessonProgressRepository repository;

  Future<AssignmentLessonProgressRecord?> get({
    required String assignmentId,
    required LessonPlanPackage package,
    required int packageHour,
  }) => repository.get(
    assignmentId: assignmentId,
    packageId: package.packageId,
    packageHour: packageHour,
  );

  Future<AssignmentLessonProgressResolution> resolve({
    required String assignmentId,
    required LessonPlanPackage package,
    required int packageHour,
  }) async => resolveRecord(
    package: package,
    record: await get(
      assignmentId: assignmentId,
      package: package,
      packageHour: packageHour,
    ),
  );

  AssignmentLessonProgressResolution resolveRecord({
    required LessonPlanPackage package,
    required AssignmentLessonProgressRecord? record,
  }) {
    if (record == null) {
      return const AssignmentLessonProgressResolution.none();
    }
    final packageHash = _cleanHash(package.payloadSha256);
    final recordHash = _cleanHash(record.payloadSha256);
    if (packageHash == null || recordHash == null || packageHash != recordHash) {
      return AssignmentLessonProgressResolution(
        record: record,
        bindingState: LessonPlanProgressBindingState.stale,
      );
    }
    return AssignmentLessonProgressResolution(
      record: record,
      bindingState: LessonPlanProgressBindingState.current,
    );
  }

  Future<Map<AssignmentLessonProgressKey, AssignmentLessonProgressRecord>>
  getForAssignment(String assignmentId) async {
    final records = await repository.getForAssignment(assignmentId);
    return {
      for (final record in records)
        AssignmentLessonProgressKey(
          packageId: record.packageId,
          packageHour: record.packageHour,
        ): record,
    };
  }

  Future<AssignmentLessonProgressRecord?> setStatus({
    required String assignmentId,
    required LessonPlanPackage package,
    required int packageHour,
    required LessonPlanProgressStatus status,
    DateTime? now,
  }) async {
    if (packageHour < 1 || packageHour > package.lessonHours) {
      throw ArgumentError.value(packageHour, 'packageHour');
    }
    if (status == LessonPlanProgressStatus.notStarted) {
      await repository.delete(
        assignmentId: assignmentId,
        packageId: package.packageId,
        packageHour: packageHour,
      );
      return null;
    }

    final packageHash = _cleanHash(package.payloadSha256);
    if (packageHash == null) {
      throw StateError(
        'Ders planı ilerlemesi canonical payload hash olmadan kaydedilemez.',
      );
    }

    final timestamp = now ?? DateTime.now();
    final previous = await get(
      assignmentId: assignmentId,
      package: package,
      packageHour: packageHour,
    );
    final previousResolution = resolveRecord(package: package, record: previous);
    final previousCurrent = previousResolution.isCurrent ? previous : null;
    final record = AssignmentLessonProgressRecord(
      assignmentId: assignmentId,
      packageId: package.packageId,
      packageHour: packageHour,
      payloadSha256: packageHash,
      status: status,
      startedAt: previousCurrent?.startedAt ?? timestamp,
      completedAt: status == LessonPlanProgressStatus.completed
          ? timestamp
          : null,
      updatedAt: timestamp,
    );
    await repository.save(record);
    return record;
  }
}

String? _cleanHash(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
