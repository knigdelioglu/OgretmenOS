#!/usr/bin/env python3
"""Quality/integrity audit for a projected TDE11 Teacher Guide V2.3 runtime copy."""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from collections import Counter
from pathlib import Path
from typing import Any

EXPECTED_THEME_COUNTS = {
    "TEMA_01": (126, 78),
    "TEMA_02": (158, 107),
    "TEMA_03": (146, 114),
    "TEMA_04": (143, 105),
}
EXPECTED_TOTALS = (573, 404)
ALLOWED_PROMPT_MODES = {"VERBATIM_SHORT", "VERIFIED_SUMMARY"}


def decode(raw: str | None, default: Any) -> Any:
    if raw is None or not str(raw).strip():
        return default
    return json.loads(str(raw))


def nonempty(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, dict, tuple, set)):
        return bool(value)
    return True


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--package-manifest", type=Path)
    args = parser.parse_args()

    runtime_dir = args.runtime_dir.resolve()
    db_path = runtime_dir / "course_runtime.sqlite"
    manifest_path = runtime_dir / "runtime_manifest.json"
    seal_path = runtime_dir / "teacher_guide_validation_seal.json"
    failures: list[str] = []
    warnings: list[str] = []

    manifest = read_json(manifest_path)
    seal = read_json(seal_path)
    package = read_json(args.package_manifest.resolve()) if args.package_manifest else None

    db = sqlite3.connect(db_path)
    db.row_factory = sqlite3.Row
    try:
        fk = db.execute("PRAGMA foreign_key_check").fetchall()
        if fk:
            failures.append(f"FOREIGN_KEY_CHECK:{[tuple(row) for row in fk[:5]]}")

        total = int(db.execute("SELECT COUNT(*) FROM teacher_guide_items").fetchone()[0])
        questions = int(
            db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_type='QUESTION'").fetchone()[0]
        )
        if (total, questions) != EXPECTED_TOTALS:
            failures.append(f"TOTAL_COUNT_DRIFT:{total}/{questions}!={EXPECTED_TOTALS[0]}/{EXPECTED_TOTALS[1]}")

        non_v23 = int(
            db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_id NOT LIKE '__v23_item__%'").fetchone()[0]
        )
        if non_v23:
            failures.append(f"NON_V23_ITEMS:{non_v23}")

        v22_units = int(
            db.execute("SELECT COUNT(*) FROM teacher_guide_units WHERE unit_id LIKE '__pedv2_unit__%'").fetchone()[0]
        )
        if v22_units:
            failures.append(f"V22_UNITS_REMAIN:{v22_units}")

        theme_rows = db.execute(
            """
            SELECT g.scope_id AS theme_id,
                   COUNT(i.item_id) AS entries,
                   SUM(CASE WHEN i.item_type='QUESTION' THEN 1 ELSE 0 END) AS questions
            FROM teacher_guides g
            JOIN teacher_guide_sections s ON s.guide_id=g.guide_id
            JOIN teacher_guide_units u ON u.section_id=s.section_id
            JOIN teacher_guide_items i ON i.unit_id=u.unit_id
            GROUP BY g.scope_id
            ORDER BY g.scope_id
            """
        ).fetchall()
        actual_theme_counts = {
            str(row["theme_id"]): (int(row["entries"]), int(row["questions"] or 0))
            for row in theme_rows
        }
        if actual_theme_counts != EXPECTED_THEME_COUNTS:
            failures.append(f"THEME_COUNT_DRIFT:{actual_theme_counts}")

        old_alias_rows = int(
            db.execute(
                "SELECT COUNT(*) FROM teacher_guide_units WHERE section_id='T4_SEC_04_DINLEME_BELSEL'"
            ).fetchone()[0]
        )
        if old_alias_rows:
            failures.append(f"UNNORMALIZED_SECTION_ALIAS:{old_alias_rows}")

        rows = db.execute(
            """
            SELECT i.item_id,i.title,i.label,i.item_type,i.page_locator,
                   i.expected_response_json,i.teacher_guidance_json,i.provenance_json,
                   u.section_id,u.unit_order,i.item_order
            FROM teacher_guide_items i
            JOIN teacher_guide_units u ON u.unit_id=i.unit_id
            ORDER BY u.section_id,u.unit_order,i.item_order,i.item_id
            """
        ).fetchall()
        guidance_counter: Counter[str] = Counter()
        recognizable_questions = 0
        review_required = 0
        question_without_answer = 0
        for row in rows:
            provenance = decode(row["provenance_json"], {})
            if provenance.get("content_class") != "BOOK_FIRST_V2_3_ITEM":
                failures.append(f"BAD_CONTENT_CLASS:{row['item_id']}")
            if provenance.get("architecture_version") != "2.3.0":
                failures.append(f"BAD_ARCHITECTURE_VERSION:{row['item_id']}")
            if provenance.get("fragment_status") == "REVIEW_REQUIRED":
                review_required += 1

            guidance = decode(row["teacher_guidance_json"], [])
            if nonempty(guidance):
                guidance_counter[json.dumps(guidance, ensure_ascii=False, sort_keys=True)] += 1

            if row["item_type"] == "QUESTION":
                title = str(row["title"] or "").strip()
                mode = provenance.get("prompt_mode")
                if mode not in ALLOWED_PROMPT_MODES:
                    failures.append(f"QUESTION_PROMPT_MODE:{row['item_id']}:{mode}")
                if not title:
                    failures.append(f"QUESTION_TITLE_EMPTY:{row['item_id']}")
                elif re.fullmatch(r"(?i)\s*(?:ders kitabı\s*)?s?\.?\s*\d+(?:[-–]\d+)?\s*(?:[—:-]\s*)?(?:\d+\.?\s*)?(?:soru)?\s*", title):
                    failures.append(f"QUESTION_NOT_RECOGNIZABLE:{row['item_id']}:{title}")
                else:
                    recognizable_questions += 1
                expected = decode(row["expected_response_json"], [])
                if not nonempty(expected):
                    question_without_answer += 1
                    failures.append(f"QUESTION_EXPECTED_RESPONSE_EMPTY:{row['item_id']}")

        duplicates = [value for value, count in guidance_counter.items() if count > 1]
        if duplicates:
            failures.append(f"DUPLICATE_TEACHER_GUIDANCE:{len(duplicates)}")

        duplicate_unit_order = db.execute(
            """
            SELECT section_id,unit_order,COUNT(*) AS c
            FROM teacher_guide_units
            GROUP BY section_id,unit_order
            HAVING c>1
            LIMIT 10
            """
        ).fetchall()
        if duplicate_unit_order:
            failures.append(
                "DUPLICATE_UNIT_ORDER:" + repr([tuple(row) for row in duplicate_unit_order])
            )

        duplicate_item_order = db.execute(
            """
            SELECT unit_id,item_order,COUNT(*) AS c
            FROM teacher_guide_items
            GROUP BY unit_id,item_order
            HAVING c>1
            LIMIT 10
            """
        ).fetchall()
        if duplicate_item_order:
            failures.append(
                "DUPLICATE_ITEM_ORDER:" + repr([tuple(row) for row in duplicate_item_order])
            )

        units = int(db.execute("SELECT COUNT(*) FROM teacher_guide_units").fetchone()[0])
        relations = int(db.execute("SELECT COUNT(*) FROM teacher_guide_item_relations").fetchone()[0])
    finally:
        db.close()

    capability = (manifest.get("teacher_guide_capabilities") or {}).get("book_first_v23") or {}
    if capability.get("available") is not True:
        failures.append("MANIFEST_BOOK_FIRST_V23_NOT_AVAILABLE")
    if capability.get("entries") != EXPECTED_TOTALS[0] or capability.get("questions") != EXPECTED_TOTALS[1]:
        failures.append(f"MANIFEST_BOOK_FIRST_COUNTS:{capability.get('entries')}/{capability.get('questions')}")
    if capability.get("locator_only_questions") != 0:
        failures.append("MANIFEST_LOCATOR_ONLY_NONZERO")
    if manifest.get("teacher_guide_source_commit") != "20860e3165d5e9de18913364286e6f89f28f6046":
        failures.append(f"MANIFEST_SOURCE_COMMIT:{manifest.get('teacher_guide_source_commit')}")

    if seal.get("status") != "PASS" or seal.get("projection_version") != "1.1.0+book-first-v2.3-full-course":
        failures.append(f"SEAL_STATUS_OR_VERSION:{seal.get('status')}:{seal.get('projection_version')}")

    if package is not None:
        pkg_cap = (package.get("teacher_guide_capabilities") or {}).get("book_first_v23") or {}
        if pkg_cap.get("entries") != EXPECTED_TOTALS[0] or pkg_cap.get("questions") != EXPECTED_TOTALS[1]:
            failures.append("PACKAGE_MANIFEST_BOOK_FIRST_COUNTS")

    metrics = {
        "entries": total,
        "questions": questions,
        "recognizable_questions": recognizable_questions,
        "question_without_answer": question_without_answer,
        "units": units,
        "relations": relations,
        "review_required_entries": review_required,
        "duplicate_teacher_guidance": len(duplicates),
        "themes": {key: {"entries": value[0], "questions": value[1]} for key, value in actual_theme_counts.items()},
    }
    print(json.dumps({"metrics": metrics, "warnings": warnings, "failures": failures}, ensure_ascii=False, indent=2))
    if failures:
        print(f"TEACHER_GUIDE_V23_PROJECTION_AUDIT: FAIL ({len(failures)} failures)")
        return 1
    print("TEACHER_GUIDE_V23_PROJECTION_AUDIT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
