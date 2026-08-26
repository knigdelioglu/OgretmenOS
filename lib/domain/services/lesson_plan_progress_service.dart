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

  Future<LessonPlanProgressResolution> resolve({
    required LessonPlanPackage package,
    required String academicYear,
  }) async => resolveRecord(
    package: package,
    record: await get(package: package, academicYear: academicYear),
  );

  LessonPlanProgressResolution resolveRecord({
    required LessonPlanPackage package,
    required LessonPlanProgressRecord? record,
  }) {
    if (record == null) return const LessonPlanProgressResolution.none();
    final packageHash = _cleanHash(package.payloadSha256);
    final recordHash = _cleanHash(record.payloadSha256);
    if (packageHash == null || recordHash == null || packageHash != recordHash) {
      return LessonPlanProgressResolution(
        record: record,
        bindingState: LessonPlanProgressBindingState.stale,
      );
    }
    return LessonPlanProgressResolution(
      record: record,
      bindingState: LessonPlanProgressBindingState.current,
    );
  }

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
    final rawRecords = await getForPackages(
      packages: orderedPackages,
      academicYear: academicYear,
    );
    final records = <String, LessonPlanProgressRecord>{};
    final stalePackageIds = <String>{};

    for (final package in orderedPackages) {
      final resolution = resolveRecord(
        package: package,
        record: rawRecords[package.packageId],
      );
      if (resolution.isCurrent && resolution.record != null) {
        records[package.packageId] = resolution.record!;
      } else if (resolution.isStale) {
        stalePackageIds.add(package.packageId);
      }
    }

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
      stalePackageIds: Set<String>.unmodifiable(stalePackageIds),
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

    final packageHash = _cleanHash(package.payloadSha256);
    if (packageHash == null) {
      throw StateError(
        'Ders planı ilerlemesi canonical payload hash olmadan kaydedilemez.',
      );
    }

    final timestamp = now ?? DateTime.now();
    final previous = await get(package: package, academicYear: academicYear);
    final previousResolution = resolveRecord(package: package, record: previous);
    final previousCurrent = previousResolution.isCurrent ? previous : null;
    final record = LessonPlanProgressRecord(
      courseId: package.courseId,
      academicYear: academicYear,
      packageId: package.packageId,
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

String? _cleanHash(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
