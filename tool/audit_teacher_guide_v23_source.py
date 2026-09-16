#!/usr/bin/env python3
"""Fail-fast audit for the vendored TDE11 Teacher Guide V2.3 source patches."""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

THEMES = ("TEMA_01", "TEMA_02", "TEMA_03", "TEMA_04")


class AuditError(ValueError):
    pass


def load_patch(path: Path) -> dict[str, Any]:
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line.startswith("@@")) + 1
    except StopIteration as exc:
        raise AuditError(f"PATCH_HUNK_MISSING:{path}") from exc
    payload: list[str] = []
    for line in lines[start:]:
        if line.startswith("+"):
            payload.append(line[1:])
        elif line.startswith("\\ No newline"):
            continue
        elif line:
            raise AuditError(f"NEW_FILE_PATCH_HAS_NON_ADDITION:{path}:{line[:80]}")
    value = json.loads("\n".join(payload))
    if not isinstance(value, dict):
        raise AuditError(f"PATCH_JSON_OBJECT_REQUIRED:{path}")
    return value


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


def key_exists(value: Any, keys: list[str]) -> bool:
    if not keys:
        return True
    return isinstance(value, dict) and all(key in value for key in keys)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--database", type=Path, required=True)
    args = parser.parse_args()

    root = args.source_root.resolve()
    database = args.database.resolve()
    db = sqlite3.connect(database)
    try:
        sections = {str(row[0]) for row in db.execute("SELECT section_id FROM teacher_guide_sections")}
        canonical: dict[str, Any] = {}
        for item_id, expected_json in db.execute(
            "SELECT item_id, expected_response_json FROM teacher_guide_items "
            "WHERE item_id NOT LIKE '__pedv2_block__%' AND item_id NOT LIKE '__v23_item__%'"
        ):
            canonical[str(item_id)] = decode(expected_json, [])
    finally:
        db.close()

    failures: list[str] = []
    warnings: list[str] = []
    metrics: dict[str, Any] = {"themes": {}}
    all_mirror_ids: set[str] = set()
    all_component_keys: dict[str, set[str]] = defaultdict(set)
    all_component_refs_used: Counter[str] = Counter()
    total_entries = total_questions = total_locator_only = 0

    for theme in THEMES:
        theme_dir = root / theme
        mirror_paths = sorted(theme_dir.glob("book_mirror_v23*.json.patch"))
        component_paths = sorted(theme_dir.glob("book_components_v23*.json.patch"))
        if not mirror_paths:
            failures.append(f"{theme}:MIRROR_FILES_MISSING")
            continue

        components: dict[str, dict[str, Any]] = defaultdict(dict)
        for path in component_paths:
            try:
                doc = load_patch(path)
            except Exception as exc:
                failures.append(f"{theme}:{path.name}:PARSE:{exc}")
                continue
            if doc.get("document_type") != "TYMM_TEACHER_GUIDE_COMPONENT_REGISTRY":
                failures.append(f"{theme}:{path.name}:BAD_COMPONENT_DOC_TYPE")
            if doc.get("theme_id") != theme:
                failures.append(f"{theme}:{path.name}:COMPONENT_THEME_MISMATCH:{doc.get('theme_id')}")
            for item_id, values in (doc.get("components") or {}).items():
                if item_id not in canonical:
                    failures.append(f"{theme}:{path.name}:COMPONENT_UNKNOWN_CANONICAL:{item_id}")
                if not isinstance(values, dict):
                    failures.append(f"{theme}:{path.name}:COMPONENT_MAP_REQUIRED:{item_id}")
                    continue
                overlap = set(components[item_id]) & set(values)
                if overlap:
                    failures.append(f"{theme}:{item_id}:DUPLICATE_COMPONENT_KEYS:{sorted(overlap)}")
                components[item_id].update(values)
                all_component_keys[item_id].update(str(key) for key in values)

        # Build the answer map the projector will see before canonical overrides.
        answer_map = dict(canonical)
        for item_id, values in components.items():
            if item_id not in canonical:
                continue
            base = answer_map[item_id]
            if base in (None, []):
                base = {}
            if not isinstance(base, dict):
                failures.append(f"{theme}:{item_id}:COMPONENT_REQUIRES_OBJECT_ANSWER")
                continue
            merged = dict(base)
            for key, meta in values.items():
                if key in merged:
                    failures.append(f"{theme}:{item_id}:COMPONENT_OVERWRITE_FORBIDDEN:{key}")
                    continue
                if not isinstance(meta, dict) or not nonempty(meta.get("value")):
                    failures.append(f"{theme}:{item_id}:INVALID_COMPONENT_VALUE:{key}")
                    continue
                merged[str(key)] = meta["value"]
            answer_map[item_id] = merged

        entries = questions = locator_only = 0
        statuses: Counter[str] = Counter()
        used_component_keys: dict[str, set[str]] = defaultdict(set)
        for path in mirror_paths:
            try:
                doc = load_patch(path)
            except Exception as exc:
                failures.append(f"{theme}:{path.name}:PARSE:{exc}")
                continue
            if doc.get("document_type") != "TYMM_TEACHER_GUIDE_BOOK_MIRROR":
                failures.append(f"{theme}:{path.name}:BAD_MIRROR_DOC_TYPE")
            if doc.get("theme_id") != theme:
                failures.append(f"{theme}:{path.name}:MIRROR_THEME_MISMATCH:{doc.get('theme_id')}")
            status = str((doc.get("scope") or {}).get("status") or "UNKNOWN")
            statuses[status] += len(doc.get("entries") or [])
            for entry in doc.get("entries") or []:
                entries += 1
                mirror_id = str(entry.get("mirror_id") or "")
                if not mirror_id:
                    failures.append(f"{theme}:{path.name}:EMPTY_MIRROR_ID")
                    continue
                if mirror_id in all_mirror_ids:
                    failures.append(f"{theme}:{mirror_id}:DUPLICATE_MIRROR_ID")
                all_mirror_ids.add(mirror_id)

                section_id = str(entry.get("section_id") or "")
                if section_id not in sections:
                    failures.append(f"{theme}:{mirror_id}:UNKNOWN_SECTION:{section_id}")

                refs = [str(ref) for ref in entry.get("canonical_item_refs") or []]
                if not refs:
                    failures.append(f"{theme}:{mirror_id}:NO_CANONICAL_REFS")
                for ref in refs:
                    if ref not in canonical:
                        failures.append(f"{theme}:{mirror_id}:UNKNOWN_CANONICAL_REF:{ref}")

                presentation = entry.get("presentation_type")
                if presentation == "QUESTION":
                    questions += 1
                    if not str(entry.get("prompt_display") or "").strip():
                        failures.append(f"{theme}:{mirror_id}:QUESTION_PROMPT_MISSING")
                    mode = entry.get("prompt_mode")
                    if mode == "LOCATOR_ONLY":
                        locator_only += 1
                        failures.append(f"{theme}:{mirror_id}:LOCATOR_ONLY_QUESTION")
                    elif mode not in {"VERBATIM_SHORT", "VERIFIED_SUMMARY"}:
                        failures.append(f"{theme}:{mirror_id}:QUESTION_PROMPT_MODE_INVALID:{mode}")

                keys = [str(key) for key in entry.get("answer_keys") or []]
                if keys:
                    if len(refs) != 1:
                        failures.append(f"{theme}:{mirror_id}:ANSWER_KEYS_REQUIRE_SINGLE_REF:{refs}")
                    elif refs[0] in answer_map:
                        if not key_exists(answer_map[refs[0]], keys):
                            missing = keys if not isinstance(answer_map[refs[0]], dict) else [k for k in keys if k not in answer_map[refs[0]]]
                            failures.append(f"{theme}:{mirror_id}:ANSWER_KEYS_MISSING:{refs[0]}:{missing}")
                        for key in keys:
                            if key in all_component_keys.get(refs[0], set()):
                                used_component_keys[refs[0]].add(key)
                                all_component_refs_used[f"{refs[0]}::{key}"] += 1

        for item_id, keys in components.items():
            unused = set(keys) - used_component_keys.get(item_id, set())
            if unused:
                failures.append(f"{theme}:{item_id}:UNUSED_COMPONENT_KEYS:{sorted(unused)}")

        metrics["themes"][theme] = {
            "mirror_files": len(mirror_paths),
            "component_files": len(component_paths),
            "entries": entries,
            "questions": questions,
            "locator_only_questions": locator_only,
            "fragment_status_entries": dict(sorted(statuses.items())),
        }
        total_entries += entries
        total_questions += questions
        total_locator_only += locator_only

    reused_components = [key for key, count in all_component_refs_used.items() if count > 1]
    if reused_components:
        # Reuse can be intentional when one verified component supports several display cards,
        # so surface it rather than failing the build.
        warnings.append(f"COMPONENT_KEYS_REUSED:{len(reused_components)}")

    metrics.update({
        "entries": total_entries,
        "questions": total_questions,
        "locator_only_questions": total_locator_only,
        "canonical_baseline_items": len(canonical),
        "component_keys": sum(len(keys) for keys in all_component_keys.values()),
    })

    print(json.dumps({"metrics": metrics, "warnings": warnings, "failures": failures}, ensure_ascii=False, indent=2))
    if failures:
        print(f"TEACHER_GUIDE_V23_SOURCE_AUDIT: FAIL ({len(failures)} failures)")
        return 1
    print("TEACHER_GUIDE_V23_SOURCE_AUDIT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
