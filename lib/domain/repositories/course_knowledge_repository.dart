import '../models/course_models.dart';
import '../models/lesson_plan_models.dart';

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

abstract interface class LessonPlanKnowledgeRepository {
  Future<LessonPlanCapability> getLessonPlanCapability();

  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId);

  Future<LessonPlanPackage?> getLessonPlan(String packageId);

  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId);

  Future<LessonPlanPackage?> getNextLessonPlan(String packageId);
}

extension LessonPlanCourseKnowledgeAccess on CourseKnowledgeRepository {
  Future<LessonPlanCapability> getLessonPlanCapability() {
    final repository = this;
    if (repository is LessonPlanKnowledgeRepository) {
      return (repository as LessonPlanKnowledgeRepository)
          .getLessonPlanCapability();
    }
    return Future.value(
      const LessonPlanCapability.unavailable(
        reason: 'LESSON_PLAN_REPOSITORY_UNSUPPORTED',
      ),
    );
  }

  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId) {
    final repository = this;
    if (repository is LessonPlanKnowledgeRepository) {
      return (repository as LessonPlanKnowledgeRepository)
          .getLessonPlansForBlock(blockId);
    }
    return Future.value(const []);
  }

  Future<LessonPlanPackage?> getLessonPlan(String packageId) {
    final repository = this;
    if (repository is LessonPlanKnowledgeRepository) {
      return (repository as LessonPlanKnowledgeRepository)
          .getLessonPlan(packageId);
    }
    return Future.value(null);
  }

  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) {
    final repository = this;
    if (repository is LessonPlanKnowledgeRepository) {
      return (repository as LessonPlanKnowledgeRepository)
          .getPreviousLessonPlan(packageId);
    }
    return Future.value(null);
  }

  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) {
    final repository = this;
    if (repository is LessonPlanKnowledgeRepository) {
      return (repository as LessonPlanKnowledgeRepository)
          .getNextLessonPlan(packageId);
    }
    return Future.value(null);
  }
}
