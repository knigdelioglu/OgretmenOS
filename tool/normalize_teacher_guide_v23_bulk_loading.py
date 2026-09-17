#!/usr/bin/env python3
"""Normalize the optional bulk-interface cast used by the real-runtime widget test."""
from pathlib import Path

PATH = Path("test/teacher_guide_v23_runtime_viewer_test.dart")
OLD = """  if (repository is TeacherGuideBulkKnowledgeRepository) {\n    final items = await repository.getTeacherGuideItemsForGuide(guideId);\n"""
NEW = """  if (repository is TeacherGuideBulkKnowledgeRepository) {\n    final bulk = repository as TeacherGuideBulkKnowledgeRepository;\n    final items = await bulk.getTeacherGuideItemsForGuide(guideId);\n"""


def main() -> int:
    text = PATH.read_text(encoding="utf-8")
    if NEW in text:
        print("TEACHER_GUIDE_V23_BULK_TEST_CAST: ALREADY_CURRENT")
        return 0
    count = text.count(OLD)
    if count != 1:
        raise SystemExit(f"TEACHER_GUIDE_V23_BULK_TEST_CAST: EXPECTED_ONCE found={count}")
    PATH.write_text(text.replace(OLD, NEW, 1), encoding="utf-8")
    print("TEACHER_GUIDE_V23_BULK_TEST_CAST: UPDATED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
