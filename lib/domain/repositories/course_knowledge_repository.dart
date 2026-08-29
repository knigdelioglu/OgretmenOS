import '../models/course_models.dart';
import '../models/form_models.dart';
import '../models/lesson_plan_models.dart';
import '../models/planning_models.dart';

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

/// Lazy, optional access to printable form definitions.
///
/// Older runtime packages and lightweight test repositories intentionally do
/// not need to implement this capability.
abstract interface class FormTemplateKnowledgeRepository {
  Future<FormDefinition?> getFormDefinition(String formId);
}

extension FormTemplateKnowledgeRepositoryAccess on CourseKnowledgeRepository {
  Future<FormDefinition?> getFormDefinitionIfAvailable(String formId) {
    final repository = this;
    if (repository is FormTemplateKnowledgeRepository) {
      return (repository as FormTemplateKnowledgeRepository).getFormDefinition(
        formId,
      );
    }
    return Future.value(null);
  }
}

/// Optional read-only capability used by planning and resource-context paths.
///
/// Keeping this separate from [CourseKnowledgeRepository] preserves existing
/// lightweight test and feature repositories while allowing the production
/// repository to expose a bulk planning projection and a one-row block/theme
/// lookup.
abstract interface class CoursePlanningKnowledgeRepository {
  Future<PlanningDataset> getPlanningDataset();

  Future<String?> getThemeIdForBlock(String blockId);
}

extension CoursePlanningKnowledgeAccess on CourseKnowledgeRepository {
  Future<PlanningDataset?> getPlanningDatasetIfAvailable() {
    final repository = this;
    if (repository is CoursePlanningKnowledgeRepository) {
      return (repository as CoursePlanningKnowledgeRepository)
          .getPlanningDataset()
          .then<PlanningDataset?>((dataset) => dataset);
    }
    return Future.value(null);
  }

  Future<String?> getThemeIdForBlockIfAvailable(String blockId) {
    final repository = this;
    if (repository is CoursePlanningKnowledgeRepository) {
      return (repository as CoursePlanningKnowledgeRepository)
          .getThemeIdForBlock(blockId);
    }
    return Future.value(null);
  }
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
      return (repository as LessonPlanKnowledgeRepository).getLessonPlan(
        packageId,
      );
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
      return (repository as LessonPlanKnowledgeRepository).getNextLessonPlan(
        packageId,
      );
    }
    return Future.value(null);
  }
}
