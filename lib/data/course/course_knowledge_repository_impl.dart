import '../../domain/models/course_models.dart';
import '../../domain/models/lesson_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import 'course_database_data_source.dart';
import 'lesson_plan_database_data_source.dart';

class CourseKnowledgeRepositoryImpl
    implements CourseKnowledgeRepository, LessonPlanKnowledgeRepository {
  const CourseKnowledgeRepositoryImpl({
    required this.dataSource,
    required this.manifest,
    this.lessonPlanDataSource,
  });

  final CourseDatabaseDataSource dataSource;
  final RuntimeManifest manifest;
  final LessonPlanDatabaseDataSource? lessonPlanDataSource;

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
  Future<BlockDetail> getBlock(String blockId) =>
      dataSource.getBlockDetail(blockId);

  @override
  Future<List<TimelineEntry>> getAnnualSequence() =>
      dataSource.getAnnualSequence();

  @override
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) =>
      dataSource.getResourceDecisions(themeId);

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) =>
      dataSource.getTeacherPackage(themeId);

  @override
  Future<LessonPlanCapability> getLessonPlanCapability() =>
      lessonPlanDataSource?.getCapability(manifest) ??
      Future.value(
        const LessonPlanCapability.unavailable(
          reason: 'LESSON_PLAN_DATA_SOURCE_UNAVAILABLE',
        ),
      );

  @override
  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId) =>
      lessonPlanDataSource?.getLessonPlansForBlock(blockId) ??
      Future.value(const []);

  @override
  Future<LessonPlanPackage?> getLessonPlan(String packageId) =>
      lessonPlanDataSource?.getLessonPlan(packageId) ?? Future.value(null);

  @override
  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) =>
      lessonPlanDataSource?.getPreviousLessonPlan(packageId) ??
      Future.value(null);

  @override
  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) =>
      lessonPlanDataSource?.getNextLessonPlan(packageId) ?? Future.value(null);
}
