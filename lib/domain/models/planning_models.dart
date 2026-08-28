import 'course_models.dart';

/// The immutable course projection required to build the annual calendar.
///
/// It deliberately contains only the sequence-facing block fields and the
/// outcomes linked to each block. Teacher-package and block-detail data stays
/// behind the detail repository APIs.
class PlanningBlock {
  PlanningBlock({
    required this.theme,
    required this.block,
    required List<Outcome> outcomes,
  }) : outcomes = List.unmodifiable(outcomes);

  final Theme theme;
  final Block block;
  final List<Outcome> outcomes;
}

class PlanningDataset {
  PlanningDataset({
    required this.courseId,
    required List<TimelineEntry> sequence,
    required Map<String, PlanningBlock> blocksById,
  }) : sequence = List.unmodifiable(sequence),
       blocksById = Map.unmodifiable(blocksById);

  final String courseId;
  final List<TimelineEntry> sequence;
  final Map<String, PlanningBlock> blocksById;

  PlanningBlock? blockFor(String blockId) => blocksById[blockId];
}
