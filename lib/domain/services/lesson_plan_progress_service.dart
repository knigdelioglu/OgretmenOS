import '../models/lesson_plan_models.dart';
import '../models/lesson_plan_progress_models.dart';
import '../repositories/lesson_plan_progress_repository.dart';

class LessonPlanProgressService {
  const LessonPlanProgressService({required this.repository});

  final LessonPlanProgressRepository repository;

  Future<LessonPlanProgressRecord?> get({
    required LessonPlanPackage package,
    required String academicYear,
  }) => repository.get(
    courseId: package.courseId,
    academicYear: academicYear,
    packageId: package.packageId,
  );

  Future<Map<String, LessonPlanProgressRecord>> getForPackages({
    required List<LessonPlanPackage> packages,
    required String academicYear,
  }) async {
    if (packages.isEmpty) return const {};
    final courseId = packages.first.courseId;
    if (packages.any((package) => package.courseId != courseId)) {
      throw StateError('Ders planı ilerleme sorgusu tek derse ait olmalıdır.');
    }
    final ids = packages.map((package) => package.packageId).toSet();
    final records = await repository.getForCourseAcademicYear(
      courseId: courseId,
      academicYear: academicYear,
    );
    return {
      for (final record in records)
        if (ids.contains(record.packageId)) record.packageId: record,
    };
  }

  Future<LessonPlanProgressSnapshot> snapshot({
    required List<LessonPlanPackage> orderedPackages,
    required String academicYear,
  }) async {
    final records = await getForPackages(
      packages: orderedPackages,
      academicYear: academicYear,
    );

    String? currentPackageId;
    for (final package in orderedPackages) {
      if (records[package.packageId]?.status ==
          LessonPlanProgressStatus.inProgress) {
        currentPackageId = package.packageId;
        break;
      }
    }
    currentPackageId ??= _firstNotCompleted(orderedPackages, records);

    String? nextPackageId;
    if (currentPackageId != null) {
      final currentIndex = orderedPackages.indexWhere(
        (package) => package.packageId == currentPackageId,
      );
      for (var index = currentIndex + 1; index < orderedPackages.length; index++) {
        final candidate = orderedPackages[index];
        if (records[candidate.packageId]?.status !=
            LessonPlanProgressStatus.completed) {
          nextPackageId = candidate.packageId;
          break;
        }
      }
    }

    return LessonPlanProgressSnapshot(
      records: Map<String, LessonPlanProgressRecord>.unmodifiable(records),
      currentPackageId: currentPackageId,
      nextPackageId: nextPackageId,
    );
  }

  Future<LessonPlanProgressRecord?> setStatus({
    required LessonPlanPackage package,
    required String academicYear,
    required LessonPlanProgressStatus status,
    DateTime? now,
  }) async {
    if (status == LessonPlanProgressStatus.notStarted) {
      await repository.delete(
        courseId: package.courseId,
        academicYear: academicYear,
        packageId: package.packageId,
      );
      return null;
    }

    final timestamp = now ?? DateTime.now();
    final previous = await get(package: package, academicYear: academicYear);
    final record = LessonPlanProgressRecord(
      courseId: package.courseId,
      academicYear: academicYear,
      packageId: package.packageId,
      status: status,
      startedAt: previous?.startedAt ?? timestamp,
      completedAt: status == LessonPlanProgressStatus.completed
          ? timestamp
          : null,
      updatedAt: timestamp,
    );
    await repository.save(record);
    return record;
  }

  String? _firstNotCompleted(
    List<LessonPlanPackage> packages,
    Map<String, LessonPlanProgressRecord> records,
  ) {
    for (final package in packages) {
      if (records[package.packageId]?.status !=
          LessonPlanProgressStatus.completed) {
        return package.packageId;
      }
    }
    return null;
  }
}
