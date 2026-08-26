import '../models/lesson_plan_progress_models.dart';

abstract interface class LessonPlanProgressRepository {
  Future<List<LessonPlanProgressRecord>> getForCourseAcademicYear({
    required String courseId,
    required String academicYear,
  });

  Future<LessonPlanProgressRecord?> get({
    required String courseId,
    required String academicYear,
    required String packageId,
  });

  Future<void> save(LessonPlanProgressRecord record);

  Future<void> delete({
    required String courseId,
    required String academicYear,
    required String packageId,
  });
}

class MemoryLessonPlanProgressRepository
    implements LessonPlanProgressRepository {
  final Map<String, LessonPlanProgressRecord> _records = {};

  String _key(String courseId, String academicYear, String packageId) =>
      '$courseId:$academicYear:$packageId';

  @override
  Future<List<LessonPlanProgressRecord>> getForCourseAcademicYear({
    required String courseId,
    required String academicYear,
  }) async => _records.values
      .where(
        (record) =>
            record.courseId == courseId && record.academicYear == academicYear,
      )
      .toList(growable: false);

  @override
  Future<LessonPlanProgressRecord?> get({
    required String courseId,
    required String academicYear,
    required String packageId,
  }) async => _records[_key(courseId, academicYear, packageId)];

  @override
  Future<void> save(LessonPlanProgressRecord record) async {
    _records[_key(record.courseId, record.academicYear, record.packageId)] = record;
  }

  @override
  Future<void> delete({
    required String courseId,
    required String academicYear,
    required String packageId,
  }) async {
    _records.remove(_key(courseId, academicYear, packageId));
  }
}
