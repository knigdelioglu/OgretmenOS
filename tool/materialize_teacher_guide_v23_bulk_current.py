#!/usr/bin/env python3
"""Materialize the current Teacher Guide V2.3 bulk-read contract idempotently.

The original migration was written before the real-runtime widget test was split into
an ordinary SQLite integration test.  The source migration is still useful for older
branches, but some of its exact-string sentinels no longer match the current files.
This thin coordinator keeps those transforms reusable while treating the already
materialized/current shapes as valid terminal states.
"""
from __future__ import annotations

from pathlib import Path

import migrate_teacher_guide_v23_bulk_loading as legacy


ROOTS = {
    "contract": Path("lib/domain/repositories/course_knowledge_repository.dart"),
    "data_source": Path("lib/data/course/teacher_guide_database_data_source.dart"),
    "repository_impl": Path("lib/data/course/course_knowledge_repository_impl.dart"),
    "viewer": Path("lib/features/resources/teacher_guide_viewer_page.dart"),
    "runtime_test": Path("test/teacher_guide_v23_runtime_viewer_test.dart"),
    "repository_test": Path("test/teacher_guide_repository_test.dart"),
}


def _contains(path: Path, *needles: str) -> bool:
    text = path.read_text(encoding="utf-8")
    return all(needle in text for needle in needles)


def main() -> int:
    changed: list[str] = []

    if not _contains(
        ROOTS["contract"],
        "abstract interface class TeacherGuideBulkKnowledgeRepository",
        "getTeacherGuideItemsForGuide(",
    ):
        if legacy.migrate_repository_contract(ROOTS["contract"]):
            changed.append("contract")

    if not _contains(
        ROOTS["data_source"],
        "getTeacherGuideUnitsForGuide(",
        "getTeacherGuideItemsForGuide(",
    ):
        if legacy.migrate_data_source(ROOTS["data_source"]):
            changed.append("data_source")

    if not _contains(
        ROOTS["repository_impl"],
        "TeacherGuideBulkKnowledgeRepository",
        "getTeacherGuideUnitsForGuide(",
        "getTeacherGuideItemsForGuide(",
    ):
        if legacy.migrate_repository_impl(ROOTS["repository_impl"]):
            changed.append("repository_impl")

    if not _contains(
        ROOTS["viewer"],
        "widget.repository is TeacherGuideBulkKnowledgeRepository",
        "getTeacherGuideItemsForGuide(",
    ):
        if legacy.migrate_viewer(ROOTS["viewer"]):
            changed.append("viewer")

    runtime_current = _contains(
        ROOTS["runtime_test"],
        "real TDE11 V2.3 runtime exposes deterministic printed-page targets via bulk read",
        "_pageTargetsFromItems(",
        "TeacherGuideBulkKnowledgeRepository",
    )
    runtime_legacy_bulk = _contains(
        ROOTS["runtime_test"],
        "repository is TeacherGuideBulkKnowledgeRepository",
    )
    if not runtime_current and not runtime_legacy_bulk:
        if legacy.migrate_runtime_test(ROOTS["runtime_test"]):
            changed.append("runtime_test")

    if not _contains(
        ROOTS["repository_test"],
        "bulk guide read keeps deterministic guide order",
    ):
        if legacy.migrate_repository_test(ROOTS["repository_test"]):
            changed.append("repository_test")

    print(
        "TEACHER_GUIDE_V23_BULK_CURRENT: "
        + ("UPDATED:" + ",".join(changed) if changed else "ALREADY_CURRENT")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
