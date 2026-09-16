#!/usr/bin/env python3
"""Run the existing V2.3 projector against the audited full-course source contract.

The base projector was written while Theme 1 only had the first pilot fragment, so its
embedded row-count contract is stale.  This adapter does not weaken validation: it pins
counts to the source-audit result, applies the single explicit section-id correction from
the source-bound override registry, restores the generic runtime provenance contract, and
replaces the stale final-count assertion.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

import project_teacher_guide_v23 as core

EXPECTED_THEME_COUNTS = {
    "TEMA_01": (126, 78),
    "TEMA_02": (158, 107),
    "TEMA_03": (146, 114),
    "TEMA_04": (143, 105),
}
EXPECTED_TOTALS = {"entries": 573, "questions": 404, "locator_only_questions": 0}
SOURCE_IDS = ["official_textbook_pdf"]


def _arg_path(name: str) -> Path:
    try:
        index = sys.argv.index(name)
        value = sys.argv[index + 1]
    except (ValueError, IndexError) as exc:
        raise core.ProjectionError(f"MISSING_REQUIRED_ARGUMENT:{name}") from exc
    return Path(value).resolve()


def _load_overrides() -> dict[str, Any]:
    path = _arg_path("--overrides")
    data = core.read_json(path)
    if data.get("source_commit") != core.SOURCE_COMMIT:
        raise core.ProjectionError("CANONICAL_OVERRIDE_SOURCE_COMMIT_MISMATCH")
    return data


def _normalized_locators(value: Any, fallback: str) -> list[str]:
    raw = value if isinstance(value, list) else [value]
    result = [str(entry).strip() for entry in raw if str(entry or "").strip()]
    return result or [fallback]


def _install_source_contract(overrides: dict[str, Any]) -> None:
    core.EXPECTED_THEME_COUNTS = dict(EXPECTED_THEME_COUNTS)
    core.EXPECTED_TOTALS = dict(EXPECTED_TOTALS)
    core.PROJECTION_VERSION = "1.1.0+book-first-v2.3-full-course"

    aliases_raw = overrides.get("section_aliases") or {}
    if not isinstance(aliases_raw, dict):
        raise core.ProjectionError("SECTION_ALIASES_OBJECT_REQUIRED")
    aliases = {str(key): str(value) for key, value in aliases_raw.items()}

    original_loader = core.load_mirror_entries

    def load_mirror_entries(source_root: Path, theme_id: str):
        entries, statuses, paths = original_loader(source_root, theme_id)
        alias_use = 0
        normalized: list[dict[str, Any]] = []
        for raw in entries:
            entry = dict(raw)
            source_section = str(entry.get("section_id") or "")
            target_section = aliases.get(source_section, source_section)
            if target_section != source_section:
                alias_use += 1
                entry["section_id"] = target_section
                entry["source_section_id"] = source_section
            normalized.append(entry)
        if theme_id == "TEMA_04" and aliases and alias_use != 1:
            raise core.ProjectionError(f"SECTION_ALIAS_USE_DRIFT:{theme_id}:{alias_use}!=1")
        return normalized, statuses, paths

    core.load_mirror_entries = load_mirror_entries

    # The Flutter domain model has always required source_ids/source_locators in
    # provenance.  The early V2.3 projector omitted source_ids.  Inject them before
    # hashing so canonical_payload_sha256 still represents the exact stored item.
    original_item_digest = core.item_digest

    def item_digest(payload: dict[str, Any]) -> str:
        provenance = payload.get("provenance")
        if not isinstance(provenance, dict):
            raise core.ProjectionError(f"ITEM_PROVENANCE_OBJECT_REQUIRED:{payload.get('item_id')}")
        provenance["source_ids"] = list(SOURCE_IDS)
        provenance["source_locators"] = _normalized_locators(
            provenance.get("source_locators"),
            f"basılı s.{payload.get('page_locator')}",
        )
        return original_item_digest(payload)

    core.item_digest = item_digest

    # Units have no payload hash, so normalize their provenance immediately after
    # the base build and before manifest/seal fingerprints are generated.
    original_build_projection = core.build_projection

    def build_projection(
        db: sqlite3.Connection,
        source_root: Path,
        override_path: Path,
    ):
        metrics, paths = original_build_projection(db, source_root, override_path)
        rows = db.execute(
            """SELECT unit_id,page_locator,source_locator,provenance_json
               FROM teacher_guide_units
               WHERE unit_id LIKE ?""",
            (f"{core.V23_UNIT_PREFIX}%",),
        ).fetchall()
        for unit_id, page_locator, source_locator, raw in rows:
            provenance = json.loads(str(raw))
            if not isinstance(provenance, dict):
                raise core.ProjectionError(f"UNIT_PROVENANCE_OBJECT_REQUIRED:{unit_id}")
            provenance["source_ids"] = list(SOURCE_IDS)
            provenance["source_locators"] = _normalized_locators(
                [source_locator],
                f"basılı s.{page_locator}",
            )
            db.execute(
                "UPDATE teacher_guide_units SET provenance_json=? WHERE unit_id=?",
                (core.compact(provenance), unit_id),
            )
        return metrics, paths

    core.build_projection = build_projection

    def verify_projection(db: sqlite3.Connection, metrics: dict[str, Any]) -> None:
        item_count = core.table_count(db, "teacher_guide_items")
        if item_count != EXPECTED_TOTALS["entries"]:
            raise core.ProjectionError(
                f"V23_ITEM_COUNT_INVALID:{item_count}!={EXPECTED_TOTALS['entries']}"
            )
        non_v23 = int(
            db.execute(
                "SELECT COUNT(*) FROM teacher_guide_items WHERE item_id NOT LIKE ?",
                (f"{core.V23_ITEM_PREFIX}%",),
            ).fetchone()[0]
        )
        if non_v23:
            raise core.ProjectionError(f"NON_V23_ITEMS_REMAIN:{non_v23}")
        if db.execute(
            "SELECT COUNT(*) FROM teacher_guide_units WHERE unit_id LIKE ?",
            (f"{core.V2_UNIT_PREFIX}%",),
        ).fetchone()[0]:
            raise core.ProjectionError("V22_UNITS_REMAIN")
        if db.execute(
            "SELECT COUNT(*) FROM teacher_guide_items WHERE item_id LIKE ?",
            (f"{core.V2_ITEM_PREFIX}%",),
        ).fetchone()[0]:
            raise core.ProjectionError("V22_ITEMS_REMAIN")
        question_count = int(
            db.execute(
                "SELECT COUNT(*) FROM teacher_guide_items WHERE item_type='QUESTION'"
            ).fetchone()[0]
        )
        if question_count != EXPECTED_TOTALS["questions"]:
            raise core.ProjectionError(
                f"V23_QUESTION_COUNT_INVALID:{question_count}!={EXPECTED_TOTALS['questions']}"
            )
        if metrics.get("locator_only_questions") != 0:
            raise core.ProjectionError("V23_LOCATOR_ONLY_PRESENT")
        foreign_keys = db.execute("PRAGMA foreign_key_check").fetchall()
        if foreign_keys:
            raise core.ProjectionError(f"FOREIGN_KEY_CHECK_FAILED:{foreign_keys[:5]}")

    core.verify_projection = verify_projection


def main() -> int:
    overrides = _load_overrides()
    _install_source_contract(overrides)
    return core.main()


if __name__ == "__main__":
    raise SystemExit(main())
