#!/usr/bin/env python3
"""Export the frozen pre-V2.3 TDE11 Teacher Guide canonical baseline as text JSON.

The V2.3 projector replaces presentation rows in SQLite.  Keeping this compact, reviewable
snapshot makes the projection reproducible and idempotent after the generated runtime has
already been materialized.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path
from typing import Any

BASELINE_RUNTIME_COMMIT = "da93b3aa22a1edafe85e66c4b5a7c3ba9f7a1bf2"
EXPECTED_ITEMS = 283
EXPECTED_RELATIONS = 3750
V2_ITEM_PREFIX = "__pedv2_block__"
V23_ITEM_PREFIX = "__v23_item__"


def decode(raw: str | None, default: Any) -> Any:
    if raw is None or not str(raw).strip():
        return default
    return json.loads(str(raw))


def export_snapshot(database: Path, source_runtime_commit: str) -> dict[str, Any]:
    db = sqlite3.connect(database)
    try:
        items: dict[str, dict[str, Any]] = {}
        rows = db.execute(
            """SELECT i.item_id,u.section_id,i.title,i.label,i.item_type,i.page_locator,
                      i.source_locator,i.content_status,i.expected_response_json,
                      i.acceptance_criteria_json,i.teacher_guidance_json,
                      i.common_misconceptions_json,i.assessment_evidence_json,
                      i.differentiation_json,i.provenance_json
               FROM teacher_guide_items i
               JOIN teacher_guide_units u ON u.unit_id=i.unit_id
               WHERE i.item_id NOT LIKE ? AND i.item_id NOT LIKE ?
               ORDER BY i.item_id""",
            (f"{V2_ITEM_PREFIX}%", f"{V23_ITEM_PREFIX}%"),
        )
        for row in rows:
            (
                item_id,
                section_id,
                title,
                label,
                item_type,
                page_locator,
                source_locator,
                content_status,
                expected_raw,
                acceptance_raw,
                guidance_raw,
                misconception_raw,
                assessment_raw,
                differentiation_raw,
                provenance_raw,
            ) = row
            items[str(item_id)] = {
                "section_id": str(section_id),
                "title": title,
                "label": label,
                "item_type": item_type,
                "page_locator": page_locator,
                "source_locator": source_locator,
                "content_status": content_status,
                "expected_response": decode(expected_raw, []),
                "acceptance_criteria": decode(acceptance_raw, []),
                "teacher_guidance": decode(guidance_raw, []),
                "common_misconceptions": decode(misconception_raw, []),
                "assessment_evidence": decode(assessment_raw, []),
                "differentiation": decode(
                    differentiation_raw,
                    {"support": [], "enrichment": []},
                ),
                "provenance": decode(provenance_raw, {}),
            }

        relations: dict[str, list[dict[str, str]]] = {}
        relation_count = 0
        for item_id, target_type, target_id, relation_type in db.execute(
            """SELECT item_id,target_type,target_id,relation_type
               FROM teacher_guide_item_relations
               WHERE item_id NOT LIKE ? AND item_id NOT LIKE ?
               ORDER BY item_id,relation_order,target_type,target_id,relation_type""",
            (f"{V2_ITEM_PREFIX}%", f"{V23_ITEM_PREFIX}%"),
        ):
            relations.setdefault(str(item_id), []).append(
                {
                    "target_type": str(target_type),
                    "target_id": str(target_id),
                    "relation_type": str(relation_type),
                }
            )
            relation_count += 1
    finally:
        db.close()

    if len(items) != EXPECTED_ITEMS:
        raise ValueError(f"CANONICAL_ITEM_BASELINE_DRIFT:{len(items)}!={EXPECTED_ITEMS}")
    if relation_count != EXPECTED_RELATIONS:
        raise ValueError(
            f"CANONICAL_RELATION_BASELINE_DRIFT:{relation_count}!={EXPECTED_RELATIONS}"
        )

    return {
        "schema_version": "1.0.0",
        "document_type": "TYMM_TEACHER_GUIDE_CANONICAL_SNAPSHOT",
        "course_id": "TDE_11",
        "source_runtime_commit": source_runtime_commit,
        "item_count": len(items),
        "relation_count": relation_count,
        "items": items,
        "relations": relations,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--source-runtime-commit",
        default=BASELINE_RUNTIME_COMMIT,
    )
    args = parser.parse_args()

    snapshot = export_snapshot(
        args.database.resolve(),
        str(args.source_runtime_commit).strip(),
    )
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(
        "TEACHER_GUIDE_V23_CANONICAL_SNAPSHOT: PASS "
        f"items={snapshot['item_count']} relations={snapshot['relation_count']} output={output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
