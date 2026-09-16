#!/usr/bin/env python3
"""Replace TDE11's V2.2/canonical guide presentation with the validated V2.3 book-first projection.

The authoritative runtime/curriculum tables are left intact.  The projector snapshots
canonical teacher-guide items/relations from the current SQLite package, applies the
vendored V2.3 component additions and narrow canonical answer overrides, then rebuilds
only teacher-guide units/items as textbook-page-first cards.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Iterable

ARCHITECTURE_VERSION = "2.3.0"
PROJECTION_VERSION = "1.0.0+book-first-v2.3"
SOURCE_COMMIT = "20860e3165d5e9de18913364286e6f89f28f6046"
EXPECTED_THEME_COUNTS = {
    "TEMA_01": (17, 6),
    "TEMA_02": (158, 107),
    "TEMA_03": (146, 114),
    "TEMA_04": (143, 105),
}
EXPECTED_TOTALS = {"entries": 464, "questions": 332, "locator_only_questions": 0}
V2_UNIT_PREFIX = "__pedv2_unit__"
V2_ITEM_PREFIX = "__pedv2_block__"
V23_UNIT_PREFIX = "__v23_unit__"
V23_ITEM_PREFIX = "__v23_item__"
TEACHER_TABLES = (
    "canonical_entities",
    "teacher_guides",
    "teacher_guide_sections",
    "teacher_guide_units",
    "teacher_guide_items",
    "teacher_guide_item_relations",
)


class ProjectionError(ValueError):
    pass


def compact(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ProjectionError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def decode_json(raw: str | None, default: Any) -> Any:
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


def load_new_file_patch(path: Path) -> dict[str, Any]:
    """Decode a PR new-file patch (all payload lines begin with '+')."""
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line.startswith("@@")) + 1
    except StopIteration as exc:
        raise ProjectionError(f"PATCH_HUNK_MISSING:{path}") from exc
    out: list[str] = []
    for line in lines[start:]:
        if line.startswith("+"):
            out.append(line[1:])
        elif line.startswith("\\ No newline"):
            continue
        elif line:
            raise ProjectionError(f"NEW_FILE_PATCH_HAS_NON_ADDITION:{path}:{line[:40]}")
    value = json.loads("\n".join(out))
    if not isinstance(value, dict):
        raise ProjectionError(f"PATCH_JSON_OBJECT_REQUIRED:{path}")
    return value


def parse_page_range(value: str) -> tuple[int, int]:
    match = re.fullmatch(r"\s*(\d+)\s*(?:[-–—]\s*(\d+)\s*)?", value)
    if not match:
        raise ProjectionError(f"INVALID_PAGE_RANGE:{value}")
    start, end = int(match.group(1)), int(match.group(2) or match.group(1))
    if end < start:
        raise ProjectionError(f"INVALID_PAGE_RANGE:{value}")
    return start, end


def source_patch_docs(source_root: Path, theme_id: str, kind: str) -> list[tuple[Path, dict[str, Any]]]:
    theme_root = source_root / theme_id
    if kind == "mirror":
        paths = list(theme_root.glob("book_mirror_v23*.json.patch"))
    elif kind == "components":
        paths = list(theme_root.glob("book_components_v23*.json.patch"))
    else:
        raise AssertionError(kind)
    docs = [(path, load_new_file_patch(path)) for path in paths]
    if kind == "mirror":
        docs.sort(key=lambda row: parse_page_range(str(row[1]["scope"]["printed_page_range"]))[0])
    else:
        docs.sort(key=lambda row: row[0].name)
    return docs


def merge_component_registries(docs: list[tuple[Path, dict[str, Any]]], theme_id: str) -> dict[str, dict[str, Any]]:
    merged: dict[str, dict[str, Any]] = {}
    for path, doc in docs:
        if doc.get("document_type") != "TYMM_TEACHER_GUIDE_COMPONENT_REGISTRY":
            raise ProjectionError(f"INVALID_COMPONENT_DOC:{path}")
        if doc.get("course_id") != "TDE_11" or doc.get("theme_id") != theme_id:
            raise ProjectionError(f"COMPONENT_IDENTITY_MISMATCH:{path}")
        components = doc.get("components")
        if not isinstance(components, dict):
            raise ProjectionError(f"COMPONENTS_OBJECT_REQUIRED:{path}")
        for item_id, values in components.items():
            if not isinstance(values, dict):
                raise ProjectionError(f"COMPONENT_MAP_REQUIRED:{path}:{item_id}")
            target = merged.setdefault(str(item_id), {})
            overlap = set(target) & set(values)
            if overlap:
                raise ProjectionError(f"DUPLICATE_COMPONENT_KEYS:{item_id}:{sorted(overlap)}")
            target.update(values)
    return merged


def load_mirror_entries(source_root: Path, theme_id: str) -> tuple[list[dict[str, Any]], dict[str, str], list[Path]]:
    docs = source_patch_docs(source_root, theme_id, "mirror")
    if not docs:
        raise ProjectionError(f"MIRROR_FILES_MISSING:{theme_id}")
    entries: list[dict[str, Any]] = []
    statuses: dict[str, str] = {}
    seen: set[str] = set()
    for path, doc in docs:
        if doc.get("document_type") != "TYMM_TEACHER_GUIDE_BOOK_MIRROR":
            raise ProjectionError(f"INVALID_MIRROR_DOC:{path}")
        if doc.get("course_id") != "TDE_11" or doc.get("theme_id") != theme_id:
            raise ProjectionError(f"MIRROR_IDENTITY_MISMATCH:{path}")
        status = str(doc.get("scope", {}).get("status") or "REVIEW_REQUIRED")
        for raw in doc.get("entries", []):
            if not isinstance(raw, dict):
                raise ProjectionError(f"MIRROR_ENTRY_OBJECT_REQUIRED:{path}")
            entry = dict(raw)
            mirror_id = str(entry.get("mirror_id") or "")
            if not mirror_id or mirror_id in seen:
                raise ProjectionError(f"DUPLICATE_OR_EMPTY_MIRROR_ID:{theme_id}:{mirror_id}")
            seen.add(mirror_id)
            entries.append(entry)
            statuses[mirror_id] = status
    return entries, statuses, [path for path, _ in docs]


def table_count(db: sqlite3.Connection, table: str) -> int:
    return int(db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def snapshot_canonical(db: sqlite3.Connection) -> tuple[dict[str, dict[str, Any]], dict[str, list[tuple[str, str, str]]]]:
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
            item_id, section_id, title, label, item_type, page_locator, source_locator,
            content_status, expected_raw, acceptance_raw, guidance_raw, misconception_raw,
            assessment_raw, differentiation_raw, provenance_raw,
        ) = row
        items[str(item_id)] = {
            "section_id": str(section_id),
            "title": title,
            "label": label,
            "item_type": item_type,
            "page_locator": page_locator,
            "source_locator": source_locator,
            "content_status": content_status,
            "expected_response": decode_json(expected_raw, []),
            "acceptance_criteria": decode_json(acceptance_raw, []),
            "teacher_guidance": decode_json(guidance_raw, []),
            "common_misconceptions": decode_json(misconception_raw, []),
            "assessment_evidence": decode_json(assessment_raw, []),
            "differentiation": decode_json(differentiation_raw, {"support": [], "enrichment": []}),
            "provenance": decode_json(provenance_raw, {}),
        }
    relations: dict[str, list[tuple[str, str, str]]] = {}
    for item_id, target_type, target_id, relation_type in db.execute(
        """SELECT item_id,target_type,target_id,relation_type
           FROM teacher_guide_item_relations
           WHERE item_id NOT LIKE ? AND item_id NOT LIKE ?
           ORDER BY item_id,relation_order,target_type,target_id,relation_type""",
        (f"{V2_ITEM_PREFIX}%", f"{V23_ITEM_PREFIX}%"),
    ):
        relations.setdefault(str(item_id), []).append((str(target_type), str(target_id), str(relation_type)))
    return items, relations


def apply_overrides(canonical: dict[str, dict[str, Any]], override_path: Path) -> None:
    if not override_path.is_file():
        return
    data = read_json(override_path)
    if data.get("source_commit") != SOURCE_COMMIT:
        raise ProjectionError("CANONICAL_OVERRIDE_SOURCE_COMMIT_MISMATCH")
    overrides = data.get("items", {})
    if not isinstance(overrides, dict):
        raise ProjectionError("CANONICAL_OVERRIDES_OBJECT_REQUIRED")
    for item_id, fields in overrides.items():
        if item_id not in canonical:
            raise ProjectionError(f"CANONICAL_OVERRIDE_UNKNOWN_ITEM:{item_id}")
        if not isinstance(fields, dict):
            raise ProjectionError(f"CANONICAL_OVERRIDE_FIELDS_OBJECT_REQUIRED:{item_id}")
        for field, value in fields.items():
            if field not in {"expected_response", "acceptance_criteria", "common_misconceptions", "differentiation"}:
                raise ProjectionError(f"CANONICAL_OVERRIDE_FIELD_NOT_ALLOWED:{item_id}:{field}")
            canonical[item_id][field] = value


def apply_components(canonical: dict[str, dict[str, Any]], components: dict[str, dict[str, Any]]) -> int:
    count = 0
    for item_id, component_map in components.items():
        item = canonical.get(item_id)
        if item is None:
            raise ProjectionError(f"COMPONENT_UNKNOWN_CANONICAL_ITEM:{item_id}")
        base = item.get("expected_response")
        if base is None or base == []:
            base = {}
        if not isinstance(base, dict):
            raise ProjectionError(f"COMPONENT_REQUIRES_OBJECT_ANSWER:{item_id}")
        merged = dict(base)
        for key, meta in component_map.items():
            if key in merged:
                raise ProjectionError(f"COMPONENT_OVERWRITE_FORBIDDEN:{item_id}:{key}")
            if not isinstance(meta, dict) or "value" not in meta or not nonempty(meta.get("value")):
                raise ProjectionError(f"INVALID_COMPONENT_VALUE:{item_id}:{key}")
            merged[str(key)] = meta["value"]
            count += 1
        item["expected_response"] = merged
    return count


def project_value(entry: dict[str, Any], value: Any) -> Any:
    keys = entry.get("answer_keys")
    if not keys:
        return value
    if not isinstance(value, dict):
        raise ProjectionError(f"ANSWER_KEYS_REQUIRE_OBJECT:{entry['mirror_id']}")
    missing = [key for key in keys if key not in value]
    if missing:
        raise ProjectionError(f"ANSWER_KEYS_MISSING:{entry['mirror_id']}:{missing}")
    if len(keys) == 1:
        return value[keys[0]]
    return {key: value[key] for key in keys}


def projected_field(entry: dict[str, Any], canonical: dict[str, dict[str, Any]], field: str) -> Any:
    values: list[tuple[str, str, Any]] = []
    for ref in entry.get("canonical_item_refs", []):
        item = canonical.get(str(ref))
        if item is None:
            raise ProjectionError(f"MIRROR_UNKNOWN_CANONICAL_REF:{entry['mirror_id']}:{ref}")
        value = item.get(field)
        if field == "expected_response" and nonempty(value):
            value = project_value(entry, value)
        if nonempty(value):
            values.append((str(ref), str(item.get("label") or item.get("title") or ref), value))
    if not values:
        return []
    if len(values) == 1:
        return values[0][2]
    return [{"canonical_ref": ref, "label": label, "value": value} for ref, label, value in values]


def projected_differentiation(entry: dict[str, Any], canonical: dict[str, dict[str, Any]]) -> dict[str, Any]:
    if not entry.get("show_differentiation"):
        return {"support": [], "enrichment": []}
    value = projected_field(entry, canonical, "differentiation")
    if isinstance(value, dict):
        return {
            "support": value.get("support", []),
            "enrichment": value.get("enrichment", []),
        }
    return {"support": [], "enrichment": []}


def union_relations(refs: Iterable[str], source: dict[str, list[tuple[str, str, str]]]) -> list[tuple[str, str, str]]:
    out: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for ref in refs:
        for relation in source.get(str(ref), []):
            if relation not in seen:
                seen.add(relation)
                out.append(relation)
    return out


def item_digest(payload: dict[str, Any]) -> str:
    return sha256_bytes(compact(payload).encode("utf-8"))


def delete_old_presentation(db: sqlite3.Connection) -> None:
    db.execute("DELETE FROM teacher_guide_item_relations")
    db.execute("DELETE FROM teacher_guide_items")
    db.execute("DELETE FROM teacher_guide_units")


def section_order_map(db: sqlite3.Connection) -> dict[str, tuple[str, int]]:
    return {
        str(section_id): (str(guide_id), int(section_order))
        for section_id, guide_id, section_order in db.execute(
            "SELECT section_id,guide_id,section_order FROM teacher_guide_sections"
        )
    }


def build_projection(
    db: sqlite3.Connection,
    source_root: Path,
    override_path: Path,
) -> tuple[dict[str, Any], list[Path]]:
    canonical, source_rel = snapshot_canonical(db)
    if len(canonical) != 283:
        raise ProjectionError(f"CANONICAL_ITEM_BASELINE_DRIFT:{len(canonical)}!=283")
    apply_overrides(canonical, override_path)
    sections = section_order_map(db)

    all_entries: list[tuple[str, dict[str, Any], str]] = []
    source_paths: list[Path] = []
    component_count = 0
    metrics: dict[str, Any] = {"themes": {}}
    for theme_id, (expected_entries, expected_questions) in EXPECTED_THEME_COUNTS.items():
        entries, statuses, mirror_paths = load_mirror_entries(source_root, theme_id)
        component_docs = source_patch_docs(source_root, theme_id, "components")
        components = merge_component_registries(component_docs, theme_id)
        component_count += apply_components(canonical, components)
        source_paths.extend(mirror_paths)
        source_paths.extend(path for path, _ in component_docs)
        questions = [e for e in entries if e.get("presentation_type") == "QUESTION"]
        locator_only = [e for e in questions if e.get("prompt_mode") == "LOCATOR_ONLY"]
        if (len(entries), len(questions)) != (expected_entries, expected_questions):
            raise ProjectionError(
                f"THEME_COUNT_DRIFT:{theme_id}:{len(entries)}/{len(questions)}"
                f"!={expected_entries}/{expected_questions}"
            )
        if locator_only:
            raise ProjectionError(f"LOCATOR_ONLY_QUESTION:{theme_id}:{[e['mirror_id'] for e in locator_only]}")
        metrics["themes"][theme_id] = {
            "entries": len(entries),
            "questions": len(questions),
            "locator_only_questions": 0,
            "mirror_files": len(mirror_paths),
            "component_registry_entries": sum(len(v) for v in components.values()),
        }
        all_entries.extend((theme_id, entry, statuses[str(entry["mirror_id"])]) for entry in entries)

    total_entries = len(all_entries)
    total_questions = sum(1 for _, entry, _ in all_entries if entry.get("presentation_type") == "QUESTION")
    totals = {"entries": total_entries, "questions": total_questions, "locator_only_questions": 0}
    if totals != EXPECTED_TOTALS:
        raise ProjectionError(f"TOTAL_COUNT_DRIFT:{totals}!={EXPECTED_TOTALS}")

    # Validate section ownership before destructive writes.
    for theme_id, entry, _ in all_entries:
        section_id = str(entry.get("section_id") or "")
        if section_id not in sections:
            raise ProjectionError(f"MIRROR_UNKNOWN_SECTION:{entry['mirror_id']}:{section_id}")
        guide_id, _ = sections[section_id]
        scope = db.execute("SELECT scope_id FROM teacher_guides WHERE guide_id=?", (guide_id,)).fetchone()
        if scope is None or str(scope[0]) != theme_id:
            raise ProjectionError(f"MIRROR_SECTION_THEME_MISMATCH:{entry['mirror_id']}:{section_id}:{theme_id}")

    delete_old_presentation(db)

    # Group contiguous entries by section/page/book heading; this mirrors a textbook page/activity card.
    unit_orders: dict[str, int] = {}
    current_key: tuple[str, str, str] | None = None
    current_unit_id: str | None = None
    current_item_order = 0
    used_unit_ids: set[str] = set()

    for theme_id, entry, fragment_status in all_entries:
        section_id = str(entry["section_id"])
        key = (section_id, str(entry["printed_page_range"]), str(entry["book_heading"]))
        if key != current_key:
            unit_orders[section_id] = unit_orders.get(section_id, 0) + 1
            raw_id = f"{V23_UNIT_PREFIX}{entry['mirror_id']}"
            current_unit_id = raw_id
            suffix = 2
            while current_unit_id in used_unit_ids:
                current_unit_id = f"{raw_id}_{suffix}"
                suffix += 1
            used_unit_ids.add(current_unit_id)
            current_item_order = 0
            unit_provenance = {
                "content_class": "BOOK_FIRST_V2_3_UNIT",
                "architecture_version": ARCHITECTURE_VERSION,
                "source_tymm_commit": SOURCE_COMMIT,
                "theme_id": theme_id,
                "section_id": section_id,
                "printed_page_range": entry["printed_page_range"],
                "book_heading": entry["book_heading"],
            }
            db.execute(
                """INSERT INTO teacher_guide_units(
                     unit_id,section_id,unit_order,title,page_locator,source_locator,
                     content_status,purpose_json,provenance_json
                   ) VALUES (?,?,?,?,?,?,?,?,?)""",
                (
                    current_unit_id,
                    section_id,
                    unit_orders[section_id],
                    str(entry["book_heading"]),
                    str(entry["printed_page_range"]),
                    str(entry.get("source_locator") or ""),
                    "REVIEW_REQUIRED" if fragment_status == "REVIEW_REQUIRED" else "VERIFIED",
                    compact({
                        "architecture_version": ARCHITECTURE_VERSION,
                        "presentation_policy": "book-first",
                        "printed_page_range": entry["printed_page_range"],
                        "book_heading": entry["book_heading"],
                    }),
                    compact(unit_provenance),
                ),
            )
            current_key = key
        assert current_unit_id is not None
        current_item_order += 1
        refs = [str(ref) for ref in entry.get("canonical_item_refs", [])]
        expected = projected_field(entry, canonical, "expected_response")
        acceptance = projected_field(entry, canonical, "acceptance_criteria") if entry.get("show_acceptance") else []
        misconceptions = projected_field(entry, canonical, "common_misconceptions") if entry.get("show_common_misconceptions") else []
        differentiation = projected_differentiation(entry, canonical)
        teacher_note = entry.get("teacher_note") if nonempty(entry.get("teacher_note")) else []
        relations = union_relations(refs, source_rel)
        item_id = f"{V23_ITEM_PREFIX}{entry['mirror_id']}"
        title = str(entry.get("prompt_display") or entry["book_heading"])
        label = str(entry["book_heading"])
        content_status = "REVIEW_REQUIRED" if fragment_status == "REVIEW_REQUIRED" else "VERIFIED"
        provenance = {
            "content_class": "BOOK_FIRST_V2_3_ITEM",
            "architecture_version": ARCHITECTURE_VERSION,
            "projection_version": PROJECTION_VERSION,
            "source_repository": "knigdelioglu/tymm",
            "source_tymm_commit": SOURCE_COMMIT,
            "theme_id": theme_id,
            "section_id": section_id,
            "mirror_id": entry["mirror_id"],
            "canonical_item_refs": refs,
            "prompt_mode": entry.get("prompt_mode"),
            "rights_mode": entry.get("rights_mode"),
            "fragment_status": fragment_status,
            "source_locators": [str(entry.get("source_locator") or "")],
        }
        payload = {
            "item_id": item_id,
            "unit_id": current_unit_id,
            "item_order": current_item_order,
            "title": title,
            "label": label,
            "item_type": str(entry["presentation_type"]),
            "page_locator": str(entry["printed_page_range"]),
            "source_locator": str(entry.get("source_locator") or ""),
            "content_status": content_status,
            "expected_response": expected,
            "acceptance_criteria": acceptance,
            "teacher_guidance": teacher_note,
            "common_misconceptions": misconceptions,
            "assessment_evidence": [],
            "differentiation": differentiation,
            "provenance": provenance,
            "relations": [
                {"target_type": t, "target_id": i, "relation_type": r, "order": n}
                for n, (t, i, r) in enumerate(relations, start=1)
            ],
        }
        digest = item_digest(payload)
        db.execute(
            """INSERT INTO teacher_guide_items(
                 item_id,unit_id,item_order,title,label,item_type,page_locator,source_locator,
                 content_status,expected_response_json,acceptance_criteria_json,
                 teacher_guidance_json,common_misconceptions_json,assessment_evidence_json,
                 differentiation_json,provenance_json,canonical_payload_sha256
               ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                item_id, current_unit_id, current_item_order, title, label,
                str(entry["presentation_type"]), str(entry["printed_page_range"]),
                str(entry.get("source_locator") or ""), content_status,
                compact(expected), compact(acceptance), compact(teacher_note),
                compact(misconceptions), compact([]), compact(differentiation),
                compact(provenance), digest,
            ),
        )
        for order, (target_type, target_id, relation_type) in enumerate(relations, start=1):
            db.execute(
                """INSERT INTO teacher_guide_item_relations(
                     item_id,target_type,target_id,relation_type,relation_order
                   ) VALUES (?,?,?,?,?)""",
                (item_id, target_type, target_id, relation_type, order),
            )

    metrics["entries"] = total_entries
    metrics["questions"] = total_questions
    metrics["locator_only_questions"] = 0
    metrics["component_registry_entries"] = component_count
    metrics["units"] = table_count(db, "teacher_guide_units")
    return metrics, sorted(set(source_paths))


def teacher_counts(db: sqlite3.Connection) -> dict[str, int]:
    return {table: table_count(db, table) for table in TEACHER_TABLES}


def ordered_item_hashes(db: sqlite3.Connection) -> list[dict[str, str]]:
    return [
        {"item_id": str(item_id), "canonical_payload_sha256": str(digest)}
        for item_id, digest in db.execute(
            """SELECT i.item_id,i.canonical_payload_sha256
               FROM teacher_guides g
               JOIN teacher_guide_sections s ON s.guide_id=g.guide_id
               JOIN teacher_guide_units u ON u.section_id=s.section_id
               JOIN teacher_guide_items i ON i.unit_id=u.unit_id
               ORDER BY g.guide_id,s.section_order,s.section_id,u.unit_order,u.unit_id,i.item_order,i.item_id"""
        )
    ]


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
    manifest = read_json(manifest_path)
    old_seal = read_json(seal_path)
    source_files: dict[str, str] = {}
    existing = old_seal.get("source_files")
    if isinstance(existing, dict):
        for key, value in existing.items():
            key = str(key)
            if "teacher_guide_v2_profiles.json" not in key and "v23_source" not in key:
                source_files[key] = str(value)
    for path in source_paths:
        source_files[path.as_posix()] = sha256_file(path)
    if override_path.is_file():
        source_files[override_path.as_posix()] = sha256_file(override_path)

    counts = teacher_counts(db)
    fingerprint_payload = {
        "projection_version": PROJECTION_VERSION,
        "source_tymm_commit": SOURCE_COMMIT,
        "source_hashes": source_files,
        "row_counts": counts,
        "items": ordered_item_hashes(db),
    }
    fingerprint = sha256_bytes(compact(fingerprint_payload).encode("utf-8"))
    book_first = {
        "available": True,
        "architecture_version": ARCHITECTURE_VERSION,
        "projection_version": PROJECTION_VERSION,
        "source_tymm_commit": SOURCE_COMMIT,
        "source_mode": "VENDORED_SOURCE_BOUND_BOOK_FIRST_PROJECTION",
        **metrics,
    }
    seal = {
        "seal_type": "TEACHER_GUIDE_COURSE_VALIDATION_SEAL",
        "projection_version": PROJECTION_VERSION,
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
    seal_path.write_text(compact(seal) + "\n", encoding="utf-8")
    seal_sha = sha256_file(seal_path)

    row_counts = manifest.get("row_counts")
    capabilities = manifest.get("teacher_guide_capabilities")
    validation = manifest.get("teacher_guide_validation")
    if not isinstance(row_counts, dict) or not isinstance(capabilities, dict) or not isinstance(validation, dict):
        raise ProjectionError("RUNTIME_MANIFEST_TEACHER_GUIDE_METADATA_INVALID")
    row_counts.update(counts)
    capabilities["row_counts"] = counts
    capabilities.pop("pedagogy_overlay", None)
    capabilities["book_first_v23"] = book_first
    capabilities["architecture_version"] = ARCHITECTURE_VERSION
    validation["content_fingerprint"] = f"sha256:{fingerprint}"
    validation["seal_sha256"] = seal_sha
    validation["projection_version"] = PROJECTION_VERSION
    validation["architecture_version"] = ARCHITECTURE_VERSION
    manifest["teacher_guide_source_commit"] = SOURCE_COMMIT
    manifest["runtime_package_version"] = "1.4.0"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if package_path is not None:
        package = read_json(package_path)
        package["teacher_guide_source_commit"] = SOURCE_COMMIT
        package["runtime_package_version"] = "1.4.0"
        package["runtime_capabilities"] = manifest.get("capabilities", {})
        package["teacher_guide_capabilities"] = capabilities
        package["teacher_guide_validation"] = validation
        package["teacher_guide_row_counts"] = counts
        package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def verify_projection(db: sqlite3.Connection, metrics: dict[str, Any]) -> None:
    if table_count(db, "teacher_guide_items") != 464:
        raise ProjectionError("V23_ITEM_COUNT_INVALID")
    if db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_id NOT LIKE ?", (f"{V23_ITEM_PREFIX}%",)).fetchone()[0]:
        raise ProjectionError("NON_V23_ITEMS_REMAIN")
    if db.execute("SELECT COUNT(*) FROM teacher_guide_units WHERE unit_id LIKE ?", (f"{V2_UNIT_PREFIX}%",)).fetchone()[0]:
        raise ProjectionError("V22_UNITS_REMAIN")
    if db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_id LIKE ?", (f"{V2_ITEM_PREFIX}%",)).fetchone()[0]:
        raise ProjectionError("V22_ITEMS_REMAIN")
    question_count = int(db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_type='QUESTION'").fetchone()[0])
    if question_count != 332:
        raise ProjectionError(f"V23_QUESTION_COUNT_INVALID:{question_count}")
    if metrics.get("locator_only_questions") != 0:
        raise ProjectionError("V23_LOCATOR_ONLY_PRESENT")
    foreign_keys = db.execute("PRAGMA foreign_key_check").fetchall()
    if foreign_keys:
        raise ProjectionError(f"FOREIGN_KEY_CHECK_FAILED:{foreign_keys[:5]}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--overrides", type=Path, required=True)
    parser.add_argument("--package-manifest", type=Path)
    args = parser.parse_args()

    runtime_dir = args.runtime_dir.resolve()
    source_root = args.source_root.resolve()
    override_path = args.overrides.resolve()
    package_path = args.package_manifest.resolve() if args.package_manifest else None
    database_path = runtime_dir / "course_runtime.sqlite"
    for path in (database_path, runtime_dir / "runtime_manifest.json", runtime_dir / "teacher_guide_validation_seal.json"):
        if not path.is_file():
            raise ProjectionError(f"MISSING_REQUIRED_FILE:{path}")

    db = sqlite3.connect(database_path)
    db.execute("PRAGMA foreign_keys=ON")
    try:
        metrics, source_paths = build_projection(db, source_root, override_path)
        verify_projection(db, metrics)
        db.commit()
        update_metadata(db, runtime_dir, package_path, source_paths, override_path, metrics)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    print("TEACHER_GUIDE_V23_BOOK_FIRST_PROJECTION: PASS")
    print(f"ARCHITECTURE_VERSION: {ARCHITECTURE_VERSION}")
    print(f"ENTRIES: {metrics['entries']}")
    print(f"QUESTIONS: {metrics['questions']}")
    print(f"LOCATOR_ONLY_QUESTIONS: {metrics['locator_only_questions']}")
    print(f"UNITS: {metrics['units']}")
    print(f"COMPONENT_REGISTRY_ENTRIES: {metrics['component_registry_entries']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
