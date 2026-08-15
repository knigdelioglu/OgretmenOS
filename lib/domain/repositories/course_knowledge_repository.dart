import '../models/course_models.dart';

abstract interface class CourseKnowledgeRepository {
  Future<Course> getCourse();

  Future<RuntimeManifest> getManifest();

  Future<List<Theme>> getThemes();

  Future<Theme> getTheme(String themeId);

  Future<List<Block>> getBlocks(String themeId);

  Future<BlockDetail> getBlock(String blockId);

  Future<List<TimelineEntry>> getAnnualSequence();

  Future<List<ResourceDecision>> getResourceDecisions(String themeId);

  Future<TeacherPackage> getTeacherPackage(String themeId);
}
