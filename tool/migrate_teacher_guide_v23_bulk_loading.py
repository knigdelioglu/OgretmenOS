#!/usr/bin/env python3
"""Add a bulk read path for the Teacher Guide V2.3 viewer.

The real TDE11 runtime contains hundreds of guide units/items. Loading every unit
one-by-one makes the viewer perform an N+1 query sequence and can exceed widget-test
timeouts. This migration adds an optional bulk repository capability used only when
available, while keeping legacy/lightweight repositories source compatible.
"""
from __future__ import annotations

from pathlib import Path


class MigrationError(RuntimeError):
    pass


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise MigrationError(f"{label}:EXPECTED_ONCE:found={count}")
    return text.replace(old, new, 1)


def migrate_repository_contract(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    marker = "abstract interface class TeacherGuideBulkKnowledgeRepository"
    if marker in text:
        return False
    old = """}\n\nextension TeacherGuideKnowledgeAccess on CourseKnowledgeRepository {\n"""
    new = """}\n\n/// Optional bulk read path for teacher-guide viewers that need a whole guide.\n///\n/// Keeping this separate from [TeacherGuideKnowledgeRepository] means legacy\n/// fakes and small subject runtimes do not have to implement it. Production\n/// SQLite repositories can use it to avoid N+1 section/unit/item reads.\nabstract interface class TeacherGuideBulkKnowledgeRepository {\n  Future<List<TeacherGuideUnit>> getTeacherGuideUnitsForGuide(String guideId);\n\n  Future<List<TeacherGuideItem>> getTeacherGuideItemsForGuide(String guideId);\n}\n\nextension TeacherGuideKnowledgeAccess on CourseKnowledgeRepository {\n"""
    path.write_text(replace_once(text, old, new, "bulk-contract"), encoding="utf-8")
    return True


def migrate_data_source(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "getTeacherGuideItemsForGuide(String guideId)" in text:
        return False

    unit_anchor = """  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId) async {\n"""
    unit_bulk = """  Future<List<TeacherGuideUnit>> getTeacherGuideUnitsForGuide(\n    String guideId,\n  ) async {\n    if (!await _hasTable('teacher_guide_units') ||\n        !await _hasTable('teacher_guide_sections')) {\n      return const [];\n    }\n    final rows = await _database.rawQuery(\n      '''\n      SELECT u.unit_id, u.section_id, u.unit_order, u.title, u.page_locator,\n             u.source_locator, u.content_status, u.purpose_json,\n             u.provenance_json\n      FROM teacher_guide_units u\n      INNER JOIN teacher_guide_sections s ON s.section_id = u.section_id\n      WHERE s.guide_id = ?\n      ORDER BY s.section_order, s.section_id, u.unit_order, u.unit_id\n      ''',\n      [guideId],\n    );\n    return rows.map(TeacherGuideUnit.fromRow).toList(growable: false);\n  }\n\n"""
    text = replace_once(
        text,
        unit_anchor,
        unit_bulk + unit_anchor,
        "bulk-units-data-source",
    )

    item_anchor = """  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId) async {\n"""
    item_bulk = """  Future<List<TeacherGuideItem>> getTeacherGuideItemsForGuide(\n    String guideId,\n  ) async {\n    if (!await _hasTable('teacher_guide_items') ||\n        !await _hasTable('teacher_guide_units') ||\n        !await _hasTable('teacher_guide_sections')) {\n      return const [];\n    }\n    final rows = await _database.rawQuery(\n      '''\n      SELECT i.item_id, i.unit_id, i.item_order, i.title, i.label, i.item_type,\n             i.page_locator, i.source_locator, i.content_status,\n             i.expected_response_json, i.acceptance_criteria_json,\n             i.teacher_guidance_json, i.common_misconceptions_json,\n             i.assessment_evidence_json, i.differentiation_json,\n             i.provenance_json, i.canonical_payload_sha256\n      FROM teacher_guide_items i\n      INNER JOIN teacher_guide_units u ON u.unit_id = i.unit_id\n      INNER JOIN teacher_guide_sections s ON s.section_id = u.section_id\n      WHERE s.guide_id = ?\n      ORDER BY s.section_order, s.section_id, u.unit_order, u.unit_id,\n               i.item_order, i.item_id\n      ''',\n      [guideId],\n    );\n    return _hydrateItems(rows);\n  }\n\n"""
    text = replace_once(
        text,
        item_anchor,
        item_bulk + item_anchor,
        "bulk-items-data-source",
    )
    path.write_text(text, encoding="utf-8")
    return True


def migrate_repository_impl(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "getTeacherGuideItemsForGuide(String guideId)" in text:
        return False

    text = replace_once(
        text,
        """        LessonPlanKnowledgeRepository,\n        TeacherGuideKnowledgeRepository {\n""",
        """        LessonPlanKnowledgeRepository,\n        TeacherGuideKnowledgeRepository,\n        TeacherGuideBulkKnowledgeRepository {\n""",
        "bulk-interface-impl",
    )

    tail = """  @override\n  Future<List<TeacherGuideItem>> getTeacherGuideItemsForEntity({\n    required String targetType,\n    required String targetId,\n    String? relationType,\n  }) async {\n    final teacherGuide = teacherGuideDataSource;\n    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {\n      return const [];\n    }\n    return teacherGuide.getTeacherGuideItemsForEntity(\n      targetType: targetType,\n      targetId: targetId,\n      relationType: relationType,\n    );\n  }\n}\n"""
    replacement = """  @override\n  Future<List<TeacherGuideItem>> getTeacherGuideItemsForEntity({\n    required String targetType,\n    required String targetId,\n    String? relationType,\n  }) async {\n    final teacherGuide = teacherGuideDataSource;\n    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {\n      return const [];\n    }\n    return teacherGuide.getTeacherGuideItemsForEntity(\n      targetType: targetType,\n      targetId: targetId,\n      relationType: relationType,\n    );\n  }\n\n  @override\n  Future<List<TeacherGuideUnit>> getTeacherGuideUnitsForGuide(\n    String guideId,\n  ) async {\n    final teacherGuide = teacherGuideDataSource;\n    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {\n      return const [];\n    }\n    return teacherGuide.getTeacherGuideUnitsForGuide(guideId);\n  }\n\n  @override\n  Future<List<TeacherGuideItem>> getTeacherGuideItemsForGuide(\n    String guideId,\n  ) async {\n    final teacherGuide = teacherGuideDataSource;\n    if (teacherGuide == null || !(await getTeacherGuideCapability()).usable) {\n      return const [];\n    }\n    return teacherGuide.getTeacherGuideItemsForGuide(guideId);\n  }\n}\n"""
    path.write_text(
        replace_once(text, tail, replacement, "bulk-repository-methods"),
        encoding="utf-8",
    )
    return True


def migrate_viewer(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    marker = "final bulkRepository = widget.repository is TeacherGuideBulkKnowledgeRepository"
    if marker in text:
        return False
    old = """    final sectionData = <_GuideSectionData>[];\n    for (final section in sections) {\n      final units = await widget.repository.getTeacherGuideUnits(\n        section.sectionId,\n      );\n      final unitData = <_GuideUnitData>[];\n      for (final unit in units) {\n        unitData.add(\n          _GuideUnitData(\n            unit: unit,\n            items: await widget.repository.getTeacherGuideItems(unit.unitId),\n          ),\n        );\n      }\n      sectionData.add(_GuideSectionData(section: section, units: unitData));\n    }\n"""
    new = """    final sectionData = <_GuideSectionData>[];\n    final bulkRepository =\n        widget.repository is TeacherGuideBulkKnowledgeRepository\n        ? widget.repository as TeacherGuideBulkKnowledgeRepository\n        : null;\n    if (bulkRepository != null) {\n      final units = await bulkRepository.getTeacherGuideUnitsForGuide(\n        guide.guideId,\n      );\n      final items = await bulkRepository.getTeacherGuideItemsForGuide(\n        guide.guideId,\n      );\n      final unitsBySection = <String, List<TeacherGuideUnit>>{};\n      for (final unit in units) {\n        unitsBySection.putIfAbsent(unit.sectionId, () => []).add(unit);\n      }\n      final itemsByUnit = <String, List<TeacherGuideItem>>{};\n      for (final item in items) {\n        itemsByUnit.putIfAbsent(item.unitId, () => []).add(item);\n      }\n      for (final section in sections) {\n        final sectionUnits = unitsBySection[section.sectionId] ?? const [];\n        sectionData.add(\n          _GuideSectionData(\n            section: section,\n            units: [\n              for (final unit in sectionUnits)\n                _GuideUnitData(\n                  unit: unit,\n                  items: itemsByUnit[unit.unitId] ?? const [],\n                ),\n            ],\n          ),\n        );\n      }\n    } else {\n      for (final section in sections) {\n        final units = await widget.repository.getTeacherGuideUnits(\n          section.sectionId,\n        );\n        final unitData = <_GuideUnitData>[];\n        for (final unit in units) {\n          unitData.add(\n            _GuideUnitData(\n              unit: unit,\n              items: await widget.repository.getTeacherGuideItems(unit.unitId),\n            ),\n          );\n        }\n        sectionData.add(_GuideSectionData(section: section, units: unitData));\n      }\n    }\n"""
    path.write_text(replace_once(text, old, new, "viewer-bulk-load"), encoding="utf-8")
    return True


def migrate_runtime_test(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    marker = "repository is TeacherGuideBulkKnowledgeRepository"
    if marker in text:
        return False
    old = """  final byLocator = <String, _PageTarget>{};\n  final sections = await repository.getTeacherGuideSections(guideId);\n  for (final section in sections) {\n    final units = await repository.getTeacherGuideUnits(section.sectionId);\n    for (final unit in units) {\n      final items = await repository.getTeacherGuideItems(unit.unitId);\n      for (final item in items) {\n        final locator = item.pageLocator?.trim();\n        if (locator == null || locator.isEmpty) continue;\n        byLocator.putIfAbsent(\n          locator,\n          () => _PageTarget(\n            locator: locator,\n            itemId: item.itemId,\n            title: item.title ?? item.label,\n          ),\n        );\n      }\n    }\n  }\n"""
    new = """  final byLocator = <String, _PageTarget>{};\n  if (repository is TeacherGuideBulkKnowledgeRepository) {\n    final items = await repository.getTeacherGuideItemsForGuide(guideId);\n    for (final item in items) {\n      final locator = item.pageLocator?.trim();\n      if (locator == null || locator.isEmpty) continue;\n      byLocator.putIfAbsent(\n        locator,\n        () => _PageTarget(\n          locator: locator,\n          itemId: item.itemId,\n          title: item.title ?? item.label,\n        ),\n      );\n    }\n  } else {\n    final sections = await repository.getTeacherGuideSections(guideId);\n    for (final section in sections) {\n      final units = await repository.getTeacherGuideUnits(section.sectionId);\n      for (final unit in units) {\n        final items = await repository.getTeacherGuideItems(unit.unitId);\n        for (final item in items) {\n          final locator = item.pageLocator?.trim();\n          if (locator == null || locator.isEmpty) continue;\n          byLocator.putIfAbsent(\n            locator,\n            () => _PageTarget(\n              locator: locator,\n              itemId: item.itemId,\n              title: item.title ?? item.label,\n            ),\n          );\n        }\n      }\n    }\n  }\n"""
    path.write_text(replace_once(text, old, new, "runtime-test-bulk-targets"), encoding="utf-8")
    return True


def migrate_repository_test(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    marker = "bulk guide read keeps deterministic guide order"
    if marker in text:
        return False
    anchor = """    test('explicit activity/block/outcome relationları item bulur', () async {\n"""
    addition = """    test('bulk guide read keeps deterministic guide order and relations', () async {\n      final guide = (await repository.getTeacherGuideForTheme(\n        'THEME_MECHANICS',\n      ))!;\n      final bulk = repository as TeacherGuideBulkKnowledgeRepository;\n\n      final units = await bulk.getTeacherGuideUnitsForGuide(guide.guideId);\n      expect(\n        units.map((unit) => unit.unitId),\n        orderedEquals([\n          'UNIT_OBSERVATION',\n          'UNIT_MODEL',\n          'UNIT_EXTENSION',\n        ]),\n      );\n\n      final items = await bulk.getTeacherGuideItemsForGuide(guide.guideId);\n      expect(\n        items.map((item) => item.itemId),\n        orderedEquals([\n          'ITEM_BLOCK',\n          'ITEM_ACTIVITY',\n          'ITEM_OUTCOME',\n          'ITEM_UNRELATED',\n          'ITEM_EXTENSION',\n        ]),\n      );\n      expect(items.first.relations.single.targetId, 'BLOCK_MECHANICS');\n      expect(items[1].relations.single.targetId, 'ACTIVITY_EXPERIMENT');\n    });\n\n"""
    path.write_text(
        replace_once(text, anchor, addition + anchor, "bulk-repository-test"),
        encoding="utf-8",
    )
    return True


def main() -> int:
    roots = {
        "contract": Path("lib/domain/repositories/course_knowledge_repository.dart"),
        "data_source": Path("lib/data/course/teacher_guide_database_data_source.dart"),
        "repository_impl": Path("lib/data/course/course_knowledge_repository_impl.dart"),
        "viewer": Path("lib/features/resources/teacher_guide_viewer_page.dart"),
        "runtime_test": Path("test/teacher_guide_v23_runtime_viewer_test.dart"),
        "repository_test": Path("test/teacher_guide_repository_test.dart"),
    }
    changed = []
    if migrate_repository_contract(roots["contract"]):
        changed.append("contract")
    if migrate_data_source(roots["data_source"]):
        changed.append("data_source")
    if migrate_repository_impl(roots["repository_impl"]):
        changed.append("repository_impl")
    if migrate_viewer(roots["viewer"]):
        changed.append("viewer")
    if migrate_runtime_test(roots["runtime_test"]):
        changed.append("runtime_test")
    if migrate_repository_test(roots["repository_test"]):
        changed.append("repository_test")
    print(
        "TEACHER_GUIDE_V23_BULK_LOADING_MIGRATION: "
        + ("UPDATED:" + ",".join(changed) if changed else "ALREADY_CURRENT")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
