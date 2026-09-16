#!/usr/bin/env python3
"""Run the TDE11 V2.3 projector against the audited full-course source contract.

The adapter pins the full-course counts, consumes a frozen pre-V2.3 canonical snapshot so
projection remains reproducible after runtime materialization, normalizes provenance for
the Flutter domain model, and emits deterministic repo-relative source evidence.
"""
from __future__ import annotations

import copy
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
EXPECTED_CANONICAL_ITEMS = 283
EXPECTED_CANONICAL_RELATIONS = 3750
BASELINE_RUNTIME_COMMIT = "da93b3aa22a1edafe85e66c4b5a7c3ba9f7a1bf2"
SOURCE_IDS = ["official_textbook_pdf"]
REPO_ROOT = Path(__file__).resolve().parents[1]


def _arg_path(name: str) -> Path:
    try:
        index = sys.argv.index(name)
        value = sys.argv[index + 1]
    except (ValueError, IndexError) as exc:
        raise core.ProjectionError(f"MISSING_REQUIRED_ARGUMENT:{name}") from exc
    return Path(value).resolve()


def _pop_arg_path(name: str) -> Path:
    try:
        index = sys.argv.index(name)
        value = sys.argv[index + 1]
    except (ValueError, IndexError) as exc:
        raise core.ProjectionError(f"MISSING_REQUIRED_ARGUMENT:{name}") from exc
    del sys.argv[index : index + 2]
    return Path(value).resolve()


def _load_overrides() -> dict[str, Any]:
    path = _arg_path("--overrides")
    data = core.read_json(path)
    if data.get("source_commit") != core.SOURCE_COMMIT:
        raise core.ProjectionError("CANONICAL_OVERRIDE_SOURCE_COMMIT_MISMATCH")
    return data


def _load_canonical_snapshot(
    path: Path,
) -> tuple[dict[str, dict[str, Any]], dict[str, list[tuple[str, str, str]]]]:
    if not path.is_file():
        raise core.ProjectionError(f"CANONICAL_SNAPSHOT_MISSING:{path}")
    data = core.read_json(path)
    if data.get("document_type") != "TYMM_TEACHER_GUIDE_CANONICAL_SNAPSHOT":
        raise core.ProjectionError("CANONICAL_SNAPSHOT_DOC_TYPE_INVALID")
    if data.get("course_id") != "TDE_11":
        raise core.ProjectionError("CANONICAL_SNAPSHOT_COURSE_INVALID")
    if data.get("source_runtime_commit") != BASELINE_RUNTIME_COMMIT:
        raise core.ProjectionError("CANONICAL_SNAPSHOT_BASELINE_COMMIT_MISMATCH")

    raw_items = data.get("items")
    raw_relations = data.get("relations")
    if not isinstance(raw_items, dict) or len(raw_items) != EXPECTED_CANONICAL_ITEMS:
        raise core.ProjectionError("CANONICAL_SNAPSHOT_ITEM_COUNT_INVALID")
    if int(data.get("item_count") or 0) != EXPECTED_CANONICAL_ITEMS:
        raise core.ProjectionError("CANONICAL_SNAPSHOT_DECLARED_ITEM_COUNT_INVALID")
    if not isinstance(raw_relations, dict):
        raise core.ProjectionError("CANONICAL_SNAPSHOT_RELATIONS_OBJECT_REQUIRED")

    items: dict[str, dict[str, Any]] = {}
    for item_id, raw in raw_items.items():
        if not isinstance(raw, dict):
            raise core.ProjectionError(f"CANONICAL_SNAPSHOT_ITEM_OBJECT_REQUIRED:{item_id}")
        section_id = str(raw.get("section_id") or "").strip()
        if not section_id:
            raise core.ProjectionError(f"CANONICAL_SNAPSHOT_SECTION_MISSING:{item_id}")
        items[str(item_id)] = copy.deepcopy(raw)

    relations: dict[str, list[tuple[str, str, str]]] = {}
    relation_count = 0
    for item_id, raw_list in raw_relations.items():
        item_id = str(item_id)
        if item_id not in items:
            raise core.ProjectionError(f"CANONICAL_SNAPSHOT_RELATION_UNKNOWN_ITEM:{item_id}")
        if not isinstance(raw_list, list):
            raise core.ProjectionError(f"CANONICAL_SNAPSHOT_RELATION_LIST_REQUIRED:{item_id}")
        converted: list[tuple[str, str, str]] = []
        for raw in raw_list:
            if not isinstance(raw, dict):
                raise core.ProjectionError(f"CANONICAL_SNAPSHOT_RELATION_OBJECT_REQUIRED:{item_id}")
            relation = (
                str(raw.get("target_type") or "").strip(),
                str(raw.get("target_id") or "").strip(),
                str(raw.get("relation_type") or "").strip(),
            )
            if not all(relation):
                raise core.ProjectionError(f"CANONICAL_SNAPSHOT_RELATION_EMPTY:{item_id}")
            converted.append(relation)
            relation_count += 1
        if converted:
            relations[item_id] = converted

    if relation_count != EXPECTED_CANONICAL_RELATIONS:
        raise core.ProjectionError(
            f"CANONICAL_SNAPSHOT_RELATION_COUNT:{relation_count}!={EXPECTED_CANONICAL_RELATIONS}"
        )
    if int(data.get("relation_count") or 0) != EXPECTED_CANONICAL_RELATIONS:
        raise core.ProjectionError("CANONICAL_SNAPSHOT_DECLARED_RELATION_COUNT_INVALID")
    return items, relations


def _normalized_locators(value: Any, fallback: str) -> list[str]:
    raw = value if isinstance(value, list) else [value]
    result = [str(entry).strip() for entry in raw if str(entry or "").strip()]
    return result or [fallback]


def _repo_relative(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(REPO_ROOT).as_posix()
    except ValueError as exc:
        raise core.ProjectionError(f"SOURCE_PATH_OUTSIDE_REPOSITORY:{resolved}") from exc


def _install_source_contract(overrides: dict[str, Any], snapshot_path: Path) -> None:
    core.EXPECTED_THEME_COUNTS = dict(EXPECTED_THEME_COUNTS)
    core.EXPECTED_TOTALS = dict(EXPECTED_TOTALS)
    core.PROJECTION_VERSION = "1.2.0+book-first-v2.3-snapshot"

    canonical_items, canonical_relations = _load_canonical_snapshot(snapshot_path)

    def snapshot_canonical(
        _db: sqlite3.Connection,
    ) -> tuple[dict[str, dict[str, Any]], dict[str, list[tuple[str, str, str]]]]:
        return copy.deepcopy(canonical_items), copy.deepcopy(canonical_relations)

    core.snapshot_canonical = snapshot_canonical

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

    # The Flutter domain model requires source_ids/source_locators in provenance.
    # Inject them before hashing so canonical_payload_sha256 represents stored data.
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

    # Units have no payload hash, so normalize their provenance after the base build.
    # Add the frozen snapshot to source_paths so it participates in the validation seal.
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
        return metrics, [*paths, snapshot_path]

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

    # The original projector stores absolute Action-runner paths in source_files because
    # main() resolves every input path.  Rebuild metadata with stable repo-relative keys.
    def update_metadata(
        db: sqlite3.Connection,
        runtime_dir: Path,
        package_path: Path | None,
        source_paths: list[Path],
        override_path: Path,
        metrics: dict[str, Any],
    ) -> None:
        manifest_path = runtime_dir / "runtime_manifest.json"
        seal_path = runtime_dir / "teacher_guide_validation_seal.json"
        manifest = core.read_json(manifest_path)
        old_seal = core.read_json(seal_path)

        source_files: dict[str, str] = {}
        existing = old_seal.get("source_files")
        volatile_markers = (
            "teacher_guide_v2_profiles.json",
            "v23_source",
            "v23_canonical_overrides.json",
            "v23_canonical_snapshot.json",
        )
        if isinstance(existing, dict):
            for raw_key, value in existing.items():
                key = str(raw_key)
                if key.startswith("/") or any(marker in key for marker in volatile_markers):
                    continue
                source_files[key] = str(value)

        for path in sorted(set(source_paths), key=lambda value: _repo_relative(value)):
            source_files[_repo_relative(path)] = core.sha256_file(path)
        if override_path.is_file():
            source_files[_repo_relative(override_path)] = core.sha256_file(override_path)
        source_files = dict(sorted(source_files.items()))

        counts = core.teacher_counts(db)
        fingerprint_payload = {
            "projection_version": core.PROJECTION_VERSION,
            "source_tymm_commit": core.SOURCE_COMMIT,
            "source_hashes": source_files,
            "row_counts": counts,
            "items": core.ordered_item_hashes(db),
        }
        fingerprint = core.sha256_bytes(core.compact(fingerprint_payload).encode("utf-8"))
        book_first = {
            "available": True,
            "architecture_version": core.ARCHITECTURE_VERSION,
            "projection_version": core.PROJECTION_VERSION,
            "source_tymm_commit": core.SOURCE_COMMIT,
            "source_mode": "VENDORED_SOURCE_BOUND_BOOK_FIRST_PROJECTION",
            **metrics,
        }
        seal = {
            "seal_type": "TEACHER_GUIDE_COURSE_VALIDATION_SEAL",
            "projection_version": core.PROJECTION_VERSION,
            "status": "PASS",
            "scope": "COURSE",
            "course_id": manifest.get("course_id"),
            "canonical_content_fingerprint": manifest.get("canonical_content_fingerprint"),
            "teacher_guide_content_fingerprint": fingerprint,
            "source_validation_status": "PASS_WITH_WARNINGS",
            "source_files": source_files,
            "row_counts": counts,
            "book_first_v23": book_first,
        }
        seal_path.write_text(core.compact(seal) + "\n", encoding="utf-8")
        seal_sha = core.sha256_file(seal_path)

        row_counts = manifest.get("row_counts")
        capabilities = manifest.get("teacher_guide_capabilities")
        validation = manifest.get("teacher_guide_validation")
        if not isinstance(row_counts, dict) or not isinstance(capabilities, dict) or not isinstance(validation, dict):
            raise core.ProjectionError("RUNTIME_MANIFEST_TEACHER_GUIDE_METADATA_INVALID")
        row_counts.update(counts)
        capabilities["row_counts"] = counts
        capabilities.pop("pedagogy_overlay", None)
        capabilities["book_first_v23"] = book_first
        capabilities["architecture_version"] = core.ARCHITECTURE_VERSION
        validation["content_fingerprint"] = f"sha256:{fingerprint}"
        validation["seal_sha256"] = seal_sha
        validation["projection_version"] = core.PROJECTION_VERSION
        validation["architecture_version"] = core.ARCHITECTURE_VERSION
        manifest["teacher_guide_source_commit"] = core.SOURCE_COMMIT
        manifest["runtime_package_version"] = "1.4.0"
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        if package_path is not None:
            package = core.read_json(package_path)
            package["teacher_guide_source_commit"] = core.SOURCE_COMMIT
            package["runtime_package_version"] = "1.4.0"
            package["runtime_capabilities"] = manifest.get("capabilities", {})
            package["teacher_guide_capabilities"] = capabilities
            package["teacher_guide_validation"] = validation
            package["teacher_guide_row_counts"] = counts
            package_path.write_text(
                json.dumps(package, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    core.update_metadata = update_metadata


def main() -> int:
    snapshot_path = _pop_arg_path("--canonical-snapshot")
    overrides = _load_overrides()
    _install_source_contract(overrides, snapshot_path)
    return core.main()


if __name__ == "__main__":
    raise SystemExit(main())
