/// A one-shot navigation request into the canonical theme resource catalogue.
///
/// This is navigation intent, not shared lesson state. It is consumed by the
/// app shell and does not alter continuity or the current-week resolver.
enum ResourceCategory { textbook, activities, forms, assessment, sources }

class ResourceNavigationContext {
  const ResourceNavigationContext({
    required this.themeId,
    this.blockId,
    this.resourceId,
    this.formId,
    this.category,
  });

  final String themeId;
  final String? blockId;
  final String? resourceId;
  final String? formId;
  final ResourceCategory? category;

  @override
  bool operator ==(Object other) =>
      other is ResourceNavigationContext &&
      other.themeId == themeId &&
      other.blockId == blockId &&
      other.resourceId == resourceId &&
      other.formId == formId &&
      other.category == category;

  @override
  int get hashCode =>
      Object.hash(themeId, blockId, resourceId, formId, category);
}

typedef ResourceNavigationCallback =
    void Function(ResourceNavigationContext context);
