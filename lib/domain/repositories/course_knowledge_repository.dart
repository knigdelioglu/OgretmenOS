import '../models/course_models.dart';
import '../models/form_models.dart';
import '../models/lesson_plan_models.dart';
import '../models/planning_models.dart';
import '../models/teacher_guide_models.dart';

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
  /// Resolves a form definition when the runtime exposes the optional
  /// `form_templates` capability; otherwise returns the legacy-safe fallback.
  ///
  /// Keeping this as an extension lets existing lightweight repository fakes
  /// compile unchanged while exposing the canonical API to feature code.
  Future<FormDefinition?> getFormDefinition(String formId) {
    final repository = this;
    if (repository is FormTemplateKnowledgeRepository) {
      return (repository as FormTemplateKnowledgeRepository).getFormDefinition(
        formId,
      );
    }
    return Future.value(null);
  }

  Future<FormDefinition?> getFormDefinitionIfAvailable(String formId) {
    return getFormDefinition(formId);
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

/// Optional, canonical read-only teacher-guide capability.
///
/// This interface intentionally stays outside [CourseKnowledgeRepository] so
/// legacy repository fakes and curriculum-only runtimes remain source
/// compatible. Implementations must only expose guide data that is advertised
/// and validated by the runtime manifest.
abstract interface class TeacherGuideKnowledgeRepository {
  Future<TeacherGuideCapability> getTeacherGuideCapability();

  Future<TeacherGuide?> getTeacherGuideForScope({
    required String scopeType,
    required String scopeId,
  });

  Future<List<TeacherGuideSection>> getTeacherGuideSections(String guideId);

  Future<TeacherGuideSection?> getTeacherGuideSection(String sectionId);

  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId);

  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId);

  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId);

  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId);

  Future<List<TeacherGuideItem>> getTeacherGuideItemsForEntity({
    required String targetType,
    required String targetId,
    String? relationType,
  });
}

extension TeacherGuideKnowledgeAccess on CourseKnowledgeRepository {
  Future<TeacherGuideCapability> getTeacherGuideCapability() {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideCapability();
    }
    return Future.value(
      const TeacherGuideCapability.unavailable(
        reason: 'TEACHER_GUIDE_REPOSITORY_UNSUPPORTED',
      ),
    );
  }

  Future<TeacherGuide?> getTeacherGuideForScope({
    required String scopeType,
    required String scopeId,
  }) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideForScope(scopeType: scopeType, scopeId: scopeId);
    }
    return Future.value(null);
  }

  /// Convenience API for the common canonical theme scope without coupling
  /// the capability to a particular subject or grade.
  Future<TeacherGuide?> getTeacherGuideForTheme(String themeId) =>
      getTeacherGuideForScope(scopeType: 'theme', scopeId: themeId);

  Future<List<TeacherGuideSection>> getTeacherGuideSections(String guideId) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideSections(guideId);
    }
    return Future.value(const []);
  }

  Future<TeacherGuideSection?> getTeacherGuideSection(String sectionId) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideSection(sectionId);
    }
    return Future.value(null);
  }

  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideUnits(sectionId);
    }
    return Future.value(const []);
  }

  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideUnit(unitId);
    }
    return Future.value(null);
  }

  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideItems(unitId);
    }
    return Future.value(const []);
  }

  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideItem(itemId);
    }
    return Future.value(null);
  }

  Future<List<TeacherGuideItem>> getTeacherGuideItemsForEntity({
    required String targetType,
    required String targetId,
    String? relationType,
  }) {
    final repository = this;
    if (repository is TeacherGuideKnowledgeRepository) {
      return (repository as TeacherGuideKnowledgeRepository)
          .getTeacherGuideItemsForEntity(
            targetType: targetType,
            targetId: targetId,
            relationType: relationType,
          );
    }
    return Future.value(const []);
  }
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
