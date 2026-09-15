import 'package:flutter/material.dart';

import '../../app/resource_navigation.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

/// Shows a contextual guide action only when the runtime contains an explicit
/// canonical relation for the requested entity.
class TeacherGuideRelationAction extends StatelessWidget {
  const TeacherGuideRelationAction({
    super.key,
    required this.repository,
    required this.themeId,
    required this.targetType,
    required this.targetId,
    required this.onOpenResources,
    this.assignmentId,
    this.label = 'Öğretmen rehberinde aç',
  });

  final CourseKnowledgeRepository repository;
  final String themeId;
  final String targetType;
  final String targetId;
  final ResourceNavigationCallback onOpenResources;
  final String? assignmentId;
  final String label;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: repository.getTeacherGuideItemsForEntity(
      targetType: targetType,
      targetId: targetId,
    ),
    builder: (context, snapshot) {
      final items = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done ||
          items == null ||
          items.isEmpty) {
        return const SizedBox.shrink();
      }
      final itemId = items.length == 1 ? items.single.itemId : null;
      return TextButton.icon(
        icon: const Icon(Icons.menu_book_outlined, size: 18),
        label: Text(items.length == 1 ? label : '$label (${items.length})'),
        onPressed: () => onOpenResources(
          ResourceNavigationContext(
            themeId: themeId,
            category: ResourceCategory.teacherGuide,
            itemId: itemId,
            guideItemIds: [for (final item in items) item.itemId],
            assignmentId: assignmentId,
          ),
        ),
      );
    },
  );
}

/// Adds only explicit lesson-plan context links. Each relation is resolved
/// against the runtime, so an absent relation produces no action.
class TeacherGuideLessonContextActions extends StatelessWidget {
  const TeacherGuideLessonContextActions({
    super.key,
    required this.repository,
    required this.themeId,
    required this.packageId,
    required this.blockId,
    required this.outcomeCodes,
    required this.onOpenResources,
    this.assignmentId,
  });

  final CourseKnowledgeRepository repository;
  final String themeId;
  final String packageId;
  final String blockId;
  final List<String> outcomeCodes;
  final ResourceNavigationCallback onOpenResources;
  final String? assignmentId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        TeacherGuideRelationAction(
          repository: repository,
          themeId: themeId,
          targetType: 'lesson_plan_package',
          targetId: packageId,
          label: 'Bu ders planının rehberini aç',
          assignmentId: assignmentId,
          onOpenResources: onOpenResources,
        ),
        for (final outcomeCode in outcomeCodes)
          TeacherGuideOutcomeRelationAction(
            repository: repository,
            themeId: themeId,
            blockId: blockId,
            outcomeCode: outcomeCode,
            assignmentId: assignmentId,
            onOpenResources: onOpenResources,
          ),
      ],
    ),
  );
}

/// Resolves an outcome code through the canonical block before querying guide
/// relations.  The code comparison is an exact canonical lookup; no title or
/// text similarity is used.
class TeacherGuideOutcomeRelationAction extends StatelessWidget {
  const TeacherGuideOutcomeRelationAction({
    super.key,
    required this.repository,
    required this.themeId,
    required this.blockId,
    required this.outcomeCode,
    required this.onOpenResources,
    this.assignmentId,
  });

  final CourseKnowledgeRepository repository;
  final String themeId;
  final String blockId;
  final String outcomeCode;
  final ResourceNavigationCallback onOpenResources;
  final String? assignmentId;

  @override
  Widget build(BuildContext context) => FutureBuilder<model.BlockDetail>(
    future: repository.getBlock(blockId),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          snapshot.hasError ||
          !snapshot.hasData) {
        return const SizedBox.shrink();
      }
      final matches = snapshot.data!.outcomes.where(
        (outcome) => outcome.code == outcomeCode,
      );
      if (matches.isEmpty) return const SizedBox.shrink();
      return TeacherGuideRelationAction(
        repository: repository,
        themeId: themeId,
        targetType: 'outcome',
        targetId: matches.first.id,
        label: 'Bu çıktının öğretmen rehberini aç',
        assignmentId: assignmentId,
        onOpenResources: onOpenResources,
      );
    },
  );
}
