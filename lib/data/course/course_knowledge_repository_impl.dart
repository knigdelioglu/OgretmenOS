import '../../domain/models/course_models.dart';
import '../../domain/models/form_models.dart';
import '../../domain/models/lesson_plan_models.dart';
import '../../domain/models/planning_models.dart';
import '../../domain/models/teacher_guide_models.dart';
import '../../domain/performance_instrumentation.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import 'course_database_data_source.dart';
import 'lesson_plan_database_data_source.dart';
import 'teacher_guide_database_data_source.dart';

class CourseKnowledgeRepositoryImpl
    implements
        CourseKnowledgeRepository,
        FormTemplateKnowledgeRepository,
        CoursePlanningKnowledgeRepository,
        LessonPlanKnowledgeRepository,
        TeacherGuideKnowledgeRepository {
  CourseKnowledgeRepositoryImpl({
    required this.dataSource,
    required this.manifest,
    this.lessonPlanDataSource,
    this.teacherGuideDataSource,
  });

  final CourseDatabaseDataSource dataSource;
  final RuntimeManifest manifest;
  final LessonPlanDatabaseDataSource? lessonPlanDataSource;
  final TeacherGuideDatabaseDataSource? teacherGuideDataSource;
  Future<PlanningDataset>? _planningDatasetFuture;
  String? _planningDatasetCacheKey;
  Future<TeacherGuideCapability>? _teacherGuideCapabilityFuture;

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
  Future<PlanningDataset> getPlanningDataset() async {
    RuntimePerformanceTrace.count(
      'CourseKnowledgeRepository.getPlanningDataset',
    );
    final cacheKey = [
      manifest.courseId,
      manifest.runtimePackageVersion,
      manifest.schemaVersion,
      manifest.canonicalContentFingerprint,
    ].join('|');
    var future = _planningDatasetFuture;
    if (future == null || _planningDatasetCacheKey != cacheKey) {
      _planningDatasetCacheKey = cacheKey;
      future = _planningDatasetFuture = dataSource.getPlanningDataset(
        courseId: manifest.courseId,
      );
    }
    try {
      return await future;
    } catch (_) {
      if (identical(_planningDatasetFuture, future)) {
        _planningDatasetFuture = null;
        _planningDatasetCacheKey = null;
      }
      rethrow;
    }
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
  Future<FormDefinition?> getFormDefinition(String formId) {
    RuntimePerformanceTrace.count(
      'CourseKnowledgeRepository.getFormDefinition',
    );
    return dataSource.getFormDefinition(formId);
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

  @override
  Future<TeacherGuideCapability> getTeacherGuideCapability() {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null) {
      return Future.value(
        const TeacherGuideCapability.unavailable(
          reason: 'TEACHER_GUIDE_DATA_SOURCE_UNAVAILABLE',
        ),
      );
    }
    final future = _teacherGuideCapabilityFuture ??= teacherGuide.getCapability(
      manifest,
    );
    return future.catchError((Object error) {
      if (identical(_teacherGuideCapabilityFuture, future)) {
        _teacherGuideCapabilityFuture = null;
      }
      throw error;
    });
  }

  @override
  Future<TeacherGuide?> getTeacherGuideForScope({
    required String scopeType,
    required String scopeId,
  }) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return null;
    }
    return teacherGuide.getTeacherGuideForScope(
      scopeType: scopeType,
      scopeId: scopeId,
    );
  }

  @override
  Future<List<TeacherGuideSection>> getTeacherGuideSections(
    String guideId,
  ) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return const [];
    }
    return teacherGuide.getTeacherGuideSections(guideId);
  }

  @override
  Future<TeacherGuideSection?> getTeacherGuideSection(String sectionId) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return null;
    }
    return teacherGuide.getTeacherGuideSection(sectionId);
  }

  @override
  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return const [];
    }
    return teacherGuide.getTeacherGuideUnits(sectionId);
  }

  @override
  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return null;
    }
    return teacherGuide.getTeacherGuideUnit(unitId);
  }

  @override
  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return const [];
    }
    return teacherGuide.getTeacherGuideItems(unitId);
  }

  @override
  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return null;
    }
    return teacherGuide.getTeacherGuideItem(itemId);
  }

  @override
  Future<List<TeacherGuideItem>> getTeacherGuideItemsForEntity({
    required String targetType,
    required String targetId,
    String? relationType,
  }) async {
    final teacherGuide = teacherGuideDataSource;
    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {
      return const [];
    }
    return teacherGuide.getTeacherGuideItemsForEntity(
      targetType: targetType,
      targetId: targetId,
      relationType: relationType,
    );
  }
}
