#!/usr/bin/env python3
"""Add deterministic widget coverage for the optional V2.3 bulk repository path."""
from pathlib import Path

PATH = Path("test/teacher_guide_viewer_test.dart")
TEST_MARKER = "book-first bulk repository path avoids per-unit loading"
CLASS_MARKER = "class _BulkGuideRepository"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: EXPECTED_ONCE found={count}")
    return text.replace(old, new, 1)


def main() -> int:
    text = PATH.read_text(encoding="utf-8")
    changed = False

    if TEST_MARKER not in text:
        anchor = """      expect(tester.takeException(), isNull);\n    },\n  );\n}\n\nvoid _useSize"""
        addition = """      expect(tester.takeException(), isNull);\n    },\n  );\n\n  testWidgets(\n    'book-first bulk repository path avoids per-unit loading',\n    (tester) async {\n      _useSize(tester, const Size(412, 915));\n      final repository = _BulkGuideRepository();\n\n      await tester.pumpWidget(\n        MaterialApp(\n          home: TeacherGuideViewerPage(\n            repository: repository,\n            scopeType: 'theme',\n            scopeId: 'THEME_FORCE',\n            guideId: 'GUIDE_PHYSICS',\n          ),\n        ),\n      );\n      await tester.pumpAndSettle();\n\n      expect(repository.bulkUnitCalls, 1);\n      expect(repository.bulkItemCalls, 1);\n      expect(repository.perSectionUnitCalls, 0);\n      expect(repository.perUnitItemCalls, 0);\n      expect(find.byKey(const ValueKey('book-first-page-jump')), findsOneWidget);\n      expect(find.text('Kitap sayfasına git'), findsOneWidget);\n      expect(find.text('Belirtilmemiş'), findsNothing);\n      expect(tester.takeException(), isNull);\n    },\n  );\n}\n\nvoid _useSize"""
        text = replace_once(text, anchor, addition, "bulk-viewer-test")
        changed = True

    if CLASS_MARKER not in text:
        anchor = """class _MemoryNotes implements TeacherGuideNotesRepository {\n"""
        addition = """class _BulkGuideRepository extends _GuideRepository\n    implements TeacherGuideBulkKnowledgeRepository {\n  _BulkGuideRepository() : super(bookFirst: true);\n\n  int bulkUnitCalls = 0;\n  int bulkItemCalls = 0;\n  int perSectionUnitCalls = 0;\n  int perUnitItemCalls = 0;\n\n  @override\n  Future<List<TeacherGuideUnit>> getTeacherGuideUnitsForGuide(\n    String guideId,\n  ) async {\n    bulkUnitCalls++;\n    return guideId == _GuideRepository.guide.guideId\n        ? const [_GuideRepository.unit]\n        : const [];\n  }\n\n  @override\n  Future<List<TeacherGuideItem>> getTeacherGuideItemsForGuide(\n    String guideId,\n  ) async {\n    bulkItemCalls++;\n    return guideId == _GuideRepository.guide.guideId\n        ? const [\n            _GuideRepository.bookFirstItem,\n            _GuideRepository.bookFirstItemTwo,\n          ]\n        : const [];\n  }\n\n  @override\n  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async {\n    perSectionUnitCalls++;\n    return super.getTeacherGuideUnits(sectionId);\n  }\n\n  @override\n  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async {\n    perUnitItemCalls++;\n    return super.getTeacherGuideItems(unitId);\n  }\n}\n\nclass _MemoryNotes implements TeacherGuideNotesRepository {\n"""
        text = replace_once(text, anchor, addition, "bulk-viewer-repository")
        changed = True

    PATH.write_text(text, encoding="utf-8")
    print(
        "TEACHER_GUIDE_V23_BULK_VIEWER_CONTRACT: "
        + ("UPDATED" if changed else "ALREADY_CURRENT")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
