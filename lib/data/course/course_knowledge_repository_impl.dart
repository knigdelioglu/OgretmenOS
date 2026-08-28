import '../../domain/models/course_models.dart';
import '../../domain/models/lesson_plan_models.dart';
import '../../domain/models/planning_models.dart';
import '../../domain/performance_instrumentation.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import 'course_database_data_source.dart';
import 'lesson_plan_database_data_source.dart';

class CourseKnowledgeRepositoryImpl
    implements
        CourseKnowledgeRepository,
        CoursePlanningKnowledgeRepository,
        LessonPlanKnowledgeRepository {
  CourseKnowledgeRepositoryImpl({
    required this.dataSource,
    required this.manifest,
    this.lessonPlanDataSource,
  });

  final CourseDatabaseDataSource dataSource;
  final RuntimeManifest manifest;
  final LessonPlanDatabaseDataSource? lessonPlanDataSource;
  Future<PlanningDataset>? _planningDatasetFuture;
  String? _planningDatasetCacheKey;

  @override
  Future<Course> getCourse() => dataSource.getCourse();

  @override
  Future<RuntimeManifest> getManifest() async => manifest;

  @override
  Future<List<Theme>> getThemes() => dataSource.getThemes();

  @override
  Future<Theme> getTheme(String themeId) => dataSource.getTheme(themeId);

  @override
  Future<List<Block>> getBlocks(String themeId) =>
      dataSource.getBlocks(themeId);

  @override
  Future<BlockDetail> getBlock(String blockId) {
    RuntimePerformanceTrace.count('CourseKnowledgeRepository.getBlock');
    return dataSource.getBlockDetail(blockId);
  }

  @override
  Future<List<TimelineEntry>> getAnnualSequence() {
    RuntimePerformanceTrace.count(
      'CourseKnowledgeRepository.getAnnualSequence',
    );
    return dataSource.getAnnualSequence();
  }

  @override
  Future<PlanningDataset> getPlanningDataset() {
    RuntimePerformanceTrace.count(
      'CourseKnowledgeRepository.getPlanningDataset',
    );
    final cacheKey = [
      manifest.courseId,
      manifest.runtimePackageVersion,
      manifest.schemaVersion,
      manifest.canonicalContentFingerprint,
    ].join('|');
    if (_planningDatasetFuture == null ||
        _planningDatasetCacheKey != cacheKey) {
      _planningDatasetCacheKey = cacheKey;
      _planningDatasetFuture = dataSource.getPlanningDataset(
        courseId: manifest.courseId,
      );
    }
    return _planningDatasetFuture!;
  }

  @override
  Future<String?> getThemeIdForBlock(String blockId) =>
      dataSource.getThemeIdForBlock(blockId);

  @override
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) =>
      dataSource.getResourceDecisions(themeId);

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) =>
      _getTeacherPackage(themeId);

  Future<TeacherPackage> _getTeacherPackage(String themeId) {
    RuntimePerformanceTrace.count(
      'CourseKnowledgeRepository.getTeacherPackage',
    );
    return dataSource.getTeacherPackage(themeId);
  }

  @override
  Future<LessonPlanCapability> getLessonPlanCapability() =>
      lessonPlanDataSource?.getCapability(manifest) ??
      Future.value(
        const LessonPlanCapability.unavailable(
          reason: 'LESSON_PLAN_DATA_SOURCE_UNAVAILABLE',
        ),
      );

  @override
  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId) async {
    final lessonPlans = lessonPlanDataSource;
    if (lessonPlans == null || !await _lessonPlansUsable(lessonPlans)) {
      return const [];
    }
    return lessonPlans.getLessonPlansForBlock(blockId);
  }

  @override
  Future<LessonPlanPackage?> getLessonPlan(String packageId) async {
    final lessonPlans = lessonPlanDataSource;
    if (lessonPlans == null || !await _lessonPlansUsable(lessonPlans)) {
      return null;
    }
    return lessonPlans.getLessonPlan(packageId);
  }

  @override
  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) async {
    final lessonPlans = lessonPlanDataSource;
    if (lessonPlans == null || !await _lessonPlansUsable(lessonPlans)) {
      return null;
    }
    return lessonPlans.getPreviousLessonPlan(packageId);
  }

  @override
  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) async {
    final lessonPlans = lessonPlanDataSource;
    if (lessonPlans == null || !await _lessonPlansUsable(lessonPlans)) {
      return null;
    }
    return lessonPlans.getNextLessonPlan(packageId);
  }

  Future<bool> _lessonPlansUsable(
    LessonPlanDatabaseDataSource lessonPlans,
  ) async {
    final capability = await lessonPlans.getCapability(manifest);
    return capability.usable;
  }
}
