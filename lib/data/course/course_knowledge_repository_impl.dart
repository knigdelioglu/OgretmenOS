import '../../domain/models/course_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import 'course_database_data_source.dart';

class CourseKnowledgeRepositoryImpl implements CourseKnowledgeRepository {
  const CourseKnowledgeRepositoryImpl({
    required this.dataSource,
    required this.manifest,
  });

  final CourseDatabaseDataSource dataSource;
  final RuntimeManifest manifest;

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
}
