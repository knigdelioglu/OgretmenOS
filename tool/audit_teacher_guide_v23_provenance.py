#!/usr/bin/env python3
"""Validate typed provenance required by the Flutter Teacher Guide models."""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path
from typing import Any

HEX64 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_PROJECTION_VERSION = "1.2.0+book-first-v2.3-snapshot"


def _decode(raw: Any, label: str) -> dict[str, Any]:
    try:
        value = json.loads(str(raw))
    except Exception as exc:
        raise ValueError(f"{label}:INVALID_JSON:{exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{label}:OBJECT_REQUIRED")
    return value


def _string_list(value: Any, label: str) -> list[str]:
    if not isinstance(value, list) or not value:
        raise ValueError(f"{label}:NONEMPTY_LIST_REQUIRED")
    result: list[str] = []
    for entry in value:
        text = str(entry).strip() if isinstance(entry, str) else ""
        if not text:
            raise ValueError(f"{label}:NONEMPTY_STRING_ENTRIES_REQUIRED")
        result.append(text)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", type=Path, required=True)
    args = parser.parse_args()

    db = sqlite3.connect(args.database.resolve())
    failures: list[str] = []
    units = items = 0
    try:
        for unit_id, provenance_raw in db.execute(
            "SELECT unit_id,provenance_json FROM teacher_guide_units WHERE unit_id LIKE '__v23_unit__%'"
        ):
            units += 1
            label = f"UNIT:{unit_id}"
            try:
                provenance = _decode(provenance_raw, label)
                _string_list(provenance.get("source_ids"), f"{label}:source_ids")
                _string_list(provenance.get("source_locators"), f"{label}:source_locators")
                if provenance.get("content_class") != "BOOK_FIRST_V2_3_UNIT":
                    raise ValueError(f"{label}:BAD_CONTENT_CLASS")
                if provenance.get("architecture_version") != "2.3.0":
                    raise ValueError(f"{label}:BAD_ARCHITECTURE_VERSION")
            except ValueError as exc:
                failures.append(str(exc))

        for item_id, digest, provenance_raw in db.execute(
            "SELECT item_id,canonical_payload_sha256,provenance_json "
            "FROM teacher_guide_items WHERE item_id LIKE '__v23_item__%'"
        ):
            items += 1
            label = f"ITEM:{item_id}"
            try:
                provenance = _decode(provenance_raw, label)
                _string_list(provenance.get("source_ids"), f"{label}:source_ids")
                _string_list(provenance.get("source_locators"), f"{label}:source_locators")
                if provenance.get("content_class") != "BOOK_FIRST_V2_3_ITEM":
                    raise ValueError(f"{label}:BAD_CONTENT_CLASS")
                if provenance.get("architecture_version") != "2.3.0":
                    raise ValueError(f"{label}:BAD_ARCHITECTURE_VERSION")
                if provenance.get("projection_version") != EXPECTED_PROJECTION_VERSION:
                    raise ValueError(f"{label}:BAD_PROJECTION_VERSION")
                if provenance.get("source_tymm_commit") != "20860e3165d5e9de18913364286e6f89f28f6046":
                    raise ValueError(f"{label}:BAD_SOURCE_COMMIT")
                if not isinstance(digest, str) or not HEX64.fullmatch(digest):
                    raise ValueError(f"{label}:BAD_CANONICAL_PAYLOAD_SHA256")
            except ValueError as exc:
                failures.append(str(exc))
    finally:
        db.close()

    if units != 431:
        failures.append(f"V23_UNIT_COUNT:{units}!=431")
    if items != 573:
        failures.append(f"V23_ITEM_COUNT:{items}!=573")

    print(json.dumps({"units": units, "items": items, "failures": failures}, ensure_ascii=False, indent=2))
    if failures:
        print(f"TEACHER_GUIDE_V23_PROVENANCE_AUDIT: FAIL ({len(failures)} failures)")
        return 1
    print("TEACHER_GUIDE_V23_PROVENANCE_AUDIT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
