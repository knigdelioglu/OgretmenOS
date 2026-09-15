/// A one-shot navigation request into the canonical theme resource catalogue.
///
/// This is navigation intent, not shared lesson state. It is consumed by the
/// app shell and does not alter continuity or the current-week resolver.
enum ResourceCategory {
  textbook,
  activities,
  forms,
  assessment,
  sources,
  teacherGuide,
}

class ResourceNavigationContext {
  const ResourceNavigationContext({
    required this.themeId,
    this.blockId,
    this.resourceId,
    this.formId,
    this.category,
    this.guideId,
    this.sectionId,
    this.unitId,
    this.itemId,
    this.guideItemIds = const [],
    this.assignmentId,
  });

  final String themeId;
  final String? blockId;
  final String? resourceId;
  final String? formId;
  final ResourceCategory? category;
  final String? guideId;
  final String? sectionId;
  final String? unitId;
  final String? itemId;
  final List<String> guideItemIds;
  final String? assignmentId;

  @override
  bool operator ==(Object other) =>
      other is ResourceNavigationContext &&
      other.themeId == themeId &&
      other.blockId == blockId &&
      other.resourceId == resourceId &&
      other.formId == formId &&
      other.category == category &&
      other.guideId == guideId &&
      other.sectionId == sectionId &&
      other.unitId == unitId &&
      other.itemId == itemId &&
      other.assignmentId == assignmentId &&
      _sameStrings(other.guideItemIds, guideItemIds);

  @override
  int get hashCode => Object.hash(
    themeId,
    blockId,
    resourceId,
    formId,
    category,
    guideId,
    sectionId,
    unitId,
    itemId,
    Object.hashAll(guideItemIds),
    assignmentId,
  );
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

typedef ResourceNavigationCallback =
    void Function(ResourceNavigationContext context);
