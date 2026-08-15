import '../models/course_models.dart';

Block? previousBlockInSequence(
  List<TimelineEntry> sequence,
  String currentBlockId,
) => _adjacentBlock(sequence, currentBlockId, -1);

Block? nextBlockInSequence(
  List<TimelineEntry> sequence,
  String currentBlockId,
) => _adjacentBlock(sequence, currentBlockId, 1);

Block? _adjacentBlock(
  List<TimelineEntry> sequence,
  String currentBlockId,
  int offset,
) {
  final currentIndex = sequence.indexWhere(
    (entry) => entry.block.id == currentBlockId,
  );
  if (currentIndex == -1) return null;

  final targetIndex = currentIndex + offset;
  if (targetIndex < 0 || targetIndex >= sequence.length) return null;
  return sequence[targetIndex].block;
}
