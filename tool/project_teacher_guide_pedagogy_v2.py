#!/usr/bin/env python3
"""Project TYMM Teacher Guide Pedagogy V2 overlays into the existing runtime schema.

The ÖğretmenOS app intentionally reads only the canonical SQLite runtime. This
compatibility projector keeps that boundary intact by materializing validated
`TYMM_TEACHER_GUIDE_PEDAGOGY_OVERLAY` documents as synthetic teacher-guide
units/items in the existing generic teacher-guide tables.

No Flutter-side JSON/source-file access is introduced.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any, Iterable

OVERLAY_TYPE = "TYMM_TEACHER_GUIDE_PEDAGOGY_OVERLAY"
SUPPORTED_OVERLAY_VERSIONS = {"2.0.0", "2.1.0", "2.2.0"}
PROJECTION_VERSION = "1.1.0+pedagogy-v2"
SYNTHETIC_UNIT_PREFIX = "__pedv2_unit__"
SYNTHETIC_BLOCK_PREFIX = "__pedv2_block__"
SYNTHETIC_TASK_PREFIX = "__pedv2_task__"
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


def compact_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ProjectionError(f"INVALID_JSON:{path}:{exc}") from exc
    if not isinstance(value, dict):
        raise ProjectionError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def require_text(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ProjectionError(f"TEXT_REQUIRED:{field}")
    return value.strip()


def string_list(value: Any, field: str, *, required: bool = False) -> list[str]:
    if value is None:
        if required:
            raise ProjectionError(f"LIST_REQUIRED:{field}")
        return []
    if not isinstance(value, list):
        raise ProjectionError(f"LIST_REQUIRED:{field}")
    result: list[str] = []
    for entry in value:
        if not isinstance(entry, str) or not entry.strip():
            raise ProjectionError(f"NONEMPTY_STRING_LIST_REQUIRED:{field}")
        result.append(entry.strip())
    if required and not result:
        raise ProjectionError(f"NONEMPTY_LIST_REQUIRED:{field}")
    return result


def differentiation(value: Any, field: str) -> dict[str, Any]:
    if value is None:
        return {"support": [], "enrichment": []}
    if not isinstance(value, dict):
        raise ProjectionError(f"DIFFERENTIATION_OBJECT_REQUIRED:{field}")
    support = value.get("support", [])
    enrichment = value.get("enrichment", [])
    if not isinstance(support, list) or not isinstance(enrichment, list):
        raise ProjectionError(f"DIFFERENTIATION_LISTS_REQUIRED:{field}")
    return {"support": support, "enrichment": enrichment}


def overlay_files(course_root: Path) -> list[Path]:
    result: list[Path] = []
    guide_root = course_root / "teacher_guide"
    if not guide_root.is_dir():
        return result
    for path in sorted(guide_root.glob("TEMA_*/pedagogy_v2.json")):
        value = read_json(path)
        if value.get("document_type") == OVERLAY_TYPE:
            result.append(path)
    return result


def table_exists(db: sqlite3.Connection, name: str) -> bool:
    return (
        db.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
            (name,),
        ).fetchone()
        is not None
    )


def count(db: sqlite3.Connection, table: str) -> int:
    return int(db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def delete_previous_projection(db: sqlite3.Connection) -> None:
    unit_rows = db.execute(
        "SELECT unit_id FROM teacher_guide_units WHERE unit_id LIKE ?",
        (f"{SYNTHETIC_UNIT_PREFIX}%",),
    ).fetchall()
    unit_ids = [str(row[0]) for row in unit_rows]
    if not unit_ids:
        return
    placeholders = ",".join("?" for _ in unit_ids)
    item_rows = db.execute(
        f"SELECT item_id FROM teacher_guide_items WHERE unit_id IN ({placeholders})",
        unit_ids,
    ).fetchall()
    item_ids = [str(row[0]) for row in item_rows]
    if item_ids:
        item_placeholders = ",".join("?" for _ in item_ids)
        db.execute(
            f"DELETE FROM teacher_guide_item_relations "
            f"WHERE item_id IN ({item_placeholders})",
            item_ids,
        )
        db.execute(
            f"DELETE FROM teacher_guide_items WHERE item_id IN ({item_placeholders})",
            item_ids,
        )
    db.execute(
        f"DELETE FROM teacher_guide_units WHERE unit_id IN ({placeholders})",
        unit_ids,
    )


def section_ids(db: sqlite3.Connection) -> set[str]:
    return {
        str(row[0])
        for row in db.execute("SELECT section_id FROM teacher_guide_sections")
    }


def canonical_item_ids(db: sqlite3.Connection) -> set[str]:
    return {
        str(row[0])
        for row in db.execute(
            "SELECT item_id FROM teacher_guide_items WHERE unit_id NOT LIKE ?",
            (f"{SYNTHETIC_UNIT_PREFIX}%",),
        )
    }


def source_relations(
    db: sqlite3.Connection, source_item_refs: Iterable[str]
) -> list[tuple[str, str, str]]:
    result: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for item_id in source_item_refs:
        rows = db.execute(
            """
            SELECT target_type, target_id, relation_type
            FROM teacher_guide_item_relations
            WHERE item_id = ?
            ORDER BY relation_order, target_type, target_id, relation_type
            """,
            (item_id,),
        )
        for target_type, target_id, relation_type in rows:
            key = (str(target_type), str(target_id), str(relation_type))
            if key not in seen:
                seen.add(key)
                result.append(key)
    return result


def item_payload_hash(
    *,
    item_id: str,
    unit_id: str,
    item_order: int,
    title: str | None,
    label: str,
    item_type: str,
    page_locator: str | None,
    source_locator: str | None,
    content_status: str,
    expected_response: Any,
    acceptance_criteria: Any,
    teacher_guidance: Any,
    common_misconceptions: Any,
    assessment_evidence: Any,
    differentiation_value: dict[str, Any],
    provenance: dict[str, Any],
    relations: list[tuple[str, str, str]],
) -> str:
    payload = {
        "item_id": item_id,
        "unit_id": unit_id,
        "item_order": item_order,
        "title": title,
        "label": label,
        "item_type": item_type,
        "page_locator": page_locator,
        "source_locator": source_locator,
        "content_status": content_status,
        "expected_response": expected_response,
        "acceptance_criteria": acceptance_criteria,
        "teacher_guidance": teacher_guidance,
        "common_misconceptions": common_misconceptions,
        "assessment_evidence": assessment_evidence,
        "differentiation": differentiation_value,
        "provenance": provenance,
        "relations": [
            {
                "target_type": target_type,
                "target_id": target_id,
                "relation_type": relation_type,
                "order": order,
            }
            for order, (target_type, target_id, relation_type) in enumerate(
                relations, start=1
            )
        ],
    }
    return sha256_bytes(compact_json(payload).encode("utf-8"))


def insert_item(
    db: sqlite3.Connection,
    *,
    item_id: str,
    unit_id: str,
    item_order: int,
    title: str | None,
    label: str,
    item_type: str,
    page_locator: str | None,
    source_locator: str | None,
    content_status: str,
    expected_response: Any,
    acceptance_criteria: Any,
    teacher_guidance: Any,
    common_misconceptions: Any,
    assessment_evidence: Any,
    differentiation_value: dict[str, Any],
    provenance: dict[str, Any],
    relations: list[tuple[str, str, str]],
) -> None:
    payload_hash = item_payload_hash(
        item_id=item_id,
        unit_id=unit_id,
        item_order=item_order,
        title=title,
        label=label,
        item_type=item_type,
        page_locator=page_locator,
        source_locator=source_locator,
        content_status=content_status,
        expected_response=expected_response,
        acceptance_criteria=acceptance_criteria,
        teacher_guidance=teacher_guidance,
        common_misconceptions=common_misconceptions,
        assessment_evidence=assessment_evidence,
        differentiation_value=differentiation_value,
        provenance=provenance,
        relations=relations,
    )
    db.execute(
        """
        INSERT INTO teacher_guide_items(
            item_id, unit_id, item_order, title, label, item_type,
            page_locator, source_locator, content_status,
            expected_response_json, acceptance_criteria_json,
            teacher_guidance_json, common_misconceptions_json,
            assessment_evidence_json, differentiation_json,
            provenance_json, canonical_payload_sha256
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            item_id,
            unit_id,
            item_order,
            title,
            label,
            item_type,
            page_locator,
            source_locator,
            content_status,
            compact_json(expected_response),
            compact_json(acceptance_criteria),
            compact_json(teacher_guidance),
            compact_json(common_misconceptions),
            compact_json(assessment_evidence),
            compact_json(differentiation_value),
            compact_json(provenance),
            payload_hash,
        ),
    )
    for order, (target_type, target_id, relation_type) in enumerate(
        relations, start=1
    ):
        db.execute(
            """
            INSERT INTO teacher_guide_item_relations(
                item_id, target_type, target_id, relation_type, relation_order
            ) VALUES (?,?,?,?,?)
            """,
            (item_id, target_type, target_id, relation_type, order),
        )


def stable_task_id(block_id: str, task_id: str) -> str:
    digest = sha256_bytes(f"{block_id}|{task_id}".encode("utf-8"))[:24]
    return f"{SYNTHETIC_TASK_PREFIX}{digest}"


def project_overlay(
    db: sqlite3.Connection,
    *,
    course_root: Path,
    overlay_path: Path,
    overlay: dict[str, Any],
    known_sections: set[str],
    known_items: set[str],
    next_unit_order: dict[str, int],
) -> dict[str, int]:
    require_text(overlay.get("course_id"), f"{overlay_path}:course_id")
    version = require_text(
        overlay.get("schema_version"), f"{overlay_path}:schema_version"
    )
    if version not in SUPPORTED_OVERLAY_VERSIONS:
        raise ProjectionError(f"UNSUPPORTED_OVERLAY_VERSION:{overlay_path}:{version}")
    status = require_text(overlay.get("status"), f"{overlay_path}:status")
    relative_source = overlay_path.relative_to(course_root).as_posix()
    string_list(
        overlay.get("principles"), f"{overlay_path}:principles", required=True
    )
    blocks = overlay.get("blocks")
    if not isinstance(blocks, list) or not blocks:
        raise ProjectionError(f"BLOCKS_REQUIRED:{overlay_path}")

    totals = {"blocks": 0, "task_cards": 0, "items": 0}
    for block in blocks:
        if not isinstance(block, dict):
            raise ProjectionError(f"BLOCK_OBJECT_REQUIRED:{overlay_path}")
        block_id = require_text(block.get("block_id"), f"{overlay_path}:block_id")
        section_id = require_text(
            block.get("section_id"), f"{overlay_path}:{block_id}:section_id"
        )
        if section_id not in known_sections:
            raise ProjectionError(
                f"UNKNOWN_TEACHER_GUIDE_SECTION:{overlay_path}:{block_id}:{section_id}"
            )
        source_item_refs = string_list(
            block.get("source_item_refs"),
            f"{overlay_path}:{block_id}:source_item_refs",
            required=True,
        )
        unknown = [item_id for item_id in source_item_refs if item_id not in known_items]
        if unknown:
            raise ProjectionError(
                f"UNKNOWN_SOURCE_ITEMS:{overlay_path}:{block_id}:{','.join(unknown)}"
            )

        next_order = next_unit_order.get(section_id)
        if next_order is None:
            current = db.execute(
                "SELECT COALESCE(MAX(unit_order),0) FROM teacher_guide_units "
                "WHERE section_id=?",
                (section_id,),
            ).fetchone()[0]
            next_order = int(current) + 1
        next_unit_order[section_id] = next_order + 1

        unit_id = f"{SYNTHETIC_UNIT_PREFIX}{block_id}"
        title = require_text(block.get("title"), f"{overlay_path}:{block_id}:title")
        page_locator = require_text(
            block.get("printed_page_range"),
            f"{overlay_path}:{block_id}:printed_page_range",
        )
        phase_name = block.get("phase_name")
        if phase_name is not None:
            phase_name = require_text(
                phase_name, f"{overlay_path}:{block_id}:phase_name"
            )

        unit_provenance = {
            "source_ids": [OVERLAY_TYPE],
            "source_locators": [relative_source],
            "content_class": "PEDAGOGY_V2_BLOCK",
            "overlay_schema_version": version,
            "overlay_status": status,
            "block_id": block_id,
            "source_item_refs": source_item_refs,
        }
        purpose = {
            "pedagogical_intent": block.get("pedagogical_intent"),
            "book_task_summaries": block.get("book_task_summaries", []),
            "phase_name": phase_name,
            "source_item_refs": source_item_refs,
            "source_limitations": block.get("source_limitations", []),
        }
        db.execute(
            """
            INSERT INTO teacher_guide_units(
                unit_id, section_id, unit_order, title, page_locator,
                source_locator, content_status, purpose_json, provenance_json
            ) VALUES (?,?,?,?,?,?,?,?,?)
            """,
            (
                unit_id,
                section_id,
                next_order,
                title,
                page_locator,
                relative_source,
                status,
                compact_json(purpose),
                compact_json(unit_provenance),
            ),
        )

        block_relations = source_relations(db, source_item_refs)
        block_guidance = {
            "pedagojik_amaç": block.get("pedagogical_intent"),
            "öğretmen_hamleleri": block.get("teacher_moves", []),
            "takip_soruları": block.get("follow_up_questions", []),
            "tahtaya_yaz": block.get("board_notes", []),
            "kaynak_sınırı": block.get("source_limitations", []),
        }
        block_provenance = {
            **unit_provenance,
            "content_class": "PEDAGOGY_V2_GUIDANCE",
        }
        block_item_id = f"{SYNTHETIC_BLOCK_PREFIX}{block_id}"
        insert_item(
            db,
            item_id=block_item_id,
            unit_id=unit_id,
            item_order=1,
            title=title,
            label="Öğretmen için pedagojik uygulama notları",
            item_type="ÖĞRETMEN_REHBERİ",
            page_locator=page_locator,
            source_locator=relative_source,
            content_status=status,
            expected_response={
                "kitaptaki_görevler": block.get("book_task_summaries", []),
                "faz": phase_name,
            },
            acceptance_criteria=[],
            teacher_guidance=block_guidance,
            common_misconceptions=block.get("misconception_interventions", []),
            assessment_evidence=block.get("assessment_look_fors", []),
            differentiation_value=differentiation(
                block.get("differentiation"),
                f"{overlay_path}:{block_id}:differentiation",
            ),
            provenance=block_provenance,
            relations=block_relations,
        )
        totals["items"] += 1

        task_cards = block.get("task_cards", [])
        if task_cards is None:
            task_cards = []
        if not isinstance(task_cards, list):
            raise ProjectionError(f"TASK_CARDS_LIST_REQUIRED:{overlay_path}:{block_id}")
        for task_index, task in enumerate(task_cards, start=2):
            if not isinstance(task, dict):
                raise ProjectionError(
                    f"TASK_CARD_OBJECT_REQUIRED:{overlay_path}:{block_id}:{task_index}"
                )
            source_item_ref = require_text(
                task.get("source_item_ref"),
                f"{overlay_path}:{block_id}:task.source_item_ref",
            )
            if source_item_ref not in source_item_refs:
                raise ProjectionError(
                    f"TASK_SOURCE_NOT_IN_BLOCK:{overlay_path}:{block_id}:{source_item_ref}"
                )
            task_id = require_text(
                task.get("task_id"), f"{overlay_path}:{block_id}:task_id"
            )
            task_label = require_text(
                task.get("label"), f"{overlay_path}:{block_id}:{task_id}:label"
            )
            task_page = task.get("printed_page_range")
            if task_page is not None:
                task_page = require_text(
                    task_page,
                    f"{overlay_path}:{block_id}:{task_id}:printed_page_range",
                )
            task_relations = source_relations(db, [source_item_ref])
            task_provenance = {
                "source_ids": [OVERLAY_TYPE],
                "source_locators": [relative_source]
                + string_list(
                    task.get("source_locators"),
                    f"{overlay_path}:{block_id}:{task_id}:source_locators",
                ),
                "content_class": "PEDAGOGY_V2_TASK",
                "overlay_schema_version": version,
                "overlay_status": status,
                "block_id": block_id,
                "task_id": task_id,
                "source_item_ref": source_item_ref,
            }
            expected_response = {
                "kitap_yönergesi": task.get("book_prompt"),
                "yönerge_modu": task.get("prompt_mode"),
                "soru_no": task.get("question_number"),
                "beklenen_cevap": task.get("expected_answer"),
                "beklenen_tepki": task.get("expected_response"),
                "grup_sorusundan_ayrıldı": task.get("split_from_group", False),
                "cevap_bileşeni": task.get("answer_component_key"),
            }
            insert_item(
                db,
                item_id=stable_task_id(block_id, task_id),
                unit_id=unit_id,
                item_order=task_index,
                title=task_label,
                label=task_label,
                item_type="DERS_KİTABI_GÖREVİ",
                page_locator=task_page or page_locator,
                source_locator=relative_source,
                content_status=status,
                expected_response=expected_response,
                acceptance_criteria=task.get("acceptance_criteria", []),
                teacher_guidance=task.get("canonical_teacher_guidance", []),
                common_misconceptions=task.get(
                    "canonical_common_misconceptions", []
                ),
                assessment_evidence=task.get("canonical_assessment_evidence", []),
                differentiation_value=differentiation(
                    task.get("canonical_differentiation"),
                    f"{overlay_path}:{block_id}:{task_id}:differentiation",
                ),
                provenance=task_provenance,
                relations=task_relations,
            )
            totals["task_cards"] += 1
            totals["items"] += 1

        totals["blocks"] += 1
    return totals


def teacher_counts(db: sqlite3.Connection) -> dict[str, int]:
    return {table: count(db, table) for table in TEACHER_TABLES}


def ordered_item_hashes(db: sqlite3.Connection) -> list[dict[str, str]]:
    rows = db.execute(
        """
        SELECT i.item_id, i.canonical_payload_sha256
        FROM teacher_guides g
        JOIN teacher_guide_sections s ON s.guide_id = g.guide_id
        JOIN teacher_guide_units u ON u.section_id = s.section_id
        JOIN teacher_guide_items i ON i.unit_id = u.unit_id
        ORDER BY g.guide_id, s.section_order, s.section_id,
                 u.unit_order, u.unit_id, i.item_order, i.item_id
        """
    )
    return [
        {
            "item_id": str(item_id),
            "canonical_payload_sha256": str(payload_sha),
        }
        for item_id, payload_sha in rows
    ]


def update_manifest_and_seal(
    *,
    db: sqlite3.Connection,
    runtime_dir: Path,
    course_root: Path,
    overlays: list[Path],
    overlay_versions: list[str],
    stats: dict[str, int],
) -> dict[str, Any]:
    manifest_path = runtime_dir / "runtime_manifest.json"
    seal_path = runtime_dir / "teacher_guide_validation_seal.json"
    manifest = read_json(manifest_path)
    if not seal_path.is_file():
        raise ProjectionError(f"TEACHER_GUIDE_SEAL_MISSING:{seal_path}")
    old_seal = read_json(seal_path)
    source_files_raw = old_seal.get("source_files", {})
    if not isinstance(source_files_raw, dict):
        raise ProjectionError("TEACHER_GUIDE_SEAL_SOURCE_FILES_INVALID")
    source_files = {
        str(key): str(value)
        for key, value in source_files_raw.items()
        if not str(key).replace("\\", "/").endswith("/pedagogy_v2.json")
    }
    for overlay_path in overlays:
        key = overlay_path.relative_to(course_root).as_posix()
        source_files[key] = sha256_file(overlay_path)

    counts = teacher_counts(db)
    teacher_payload = {
        "projection_version": PROJECTION_VERSION,
        "source_hashes": source_files,
        "row_counts": counts,
        "items": ordered_item_hashes(db),
    }
    teacher_fingerprint = sha256_bytes(
        compact_json(teacher_payload).encode("utf-8")
    )
    source_validation_status = old_seal.get(
        "source_validation_status", "PASS_WITH_WARNINGS"
    )
    seal = {
        "seal_type": "TEACHER_GUIDE_COURSE_VALIDATION_SEAL",
        "projection_version": PROJECTION_VERSION,
        "status": "PASS",
        "scope": "COURSE",
        "course_id": manifest.get("course_id"),
        "canonical_content_fingerprint": manifest.get(
            "canonical_content_fingerprint"
        ),
        "teacher_guide_content_fingerprint": teacher_fingerprint,
        "source_validation_status": source_validation_status,
        "source_files": source_files,
        "row_counts": counts,
        "pedagogy_overlay": {
            "available": True,
            "projection_version": PROJECTION_VERSION,
            "overlay_schema_versions": sorted(set(overlay_versions)),
            "overlay_count": len(overlays),
            **stats,
        },
    }
    seal_path.write_text(compact_json(seal) + "\n", encoding="utf-8")
    seal_sha = sha256_file(seal_path)

    row_counts = manifest.get("row_counts")
    if not isinstance(row_counts, dict):
        raise ProjectionError("RUNTIME_MANIFEST_ROW_COUNTS_REQUIRED")
    row_counts.update(counts)

    capabilities = manifest.get("capabilities")
    if not isinstance(capabilities, dict) or capabilities.get("teacher_guide") is not True:
        raise ProjectionError("TEACHER_GUIDE_CAPABILITY_REQUIRED")
    metadata = manifest.get("teacher_guide_capabilities")
    validation = manifest.get("teacher_guide_validation")
    if not isinstance(metadata, dict) or not isinstance(validation, dict):
        raise ProjectionError("TEACHER_GUIDE_METADATA_REQUIRED")
    metadata["row_counts"] = counts
    metadata["pedagogy_overlay"] = seal["pedagogy_overlay"]
    validation["content_fingerprint"] = f"sha256:{teacher_fingerprint}"
    validation["seal_sha256"] = seal_sha
    validation["projection_version"] = PROJECTION_VERSION
    validation["source_validation_status"] = source_validation_status
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def update_package_manifest(
    package_manifest_path: Path,
    runtime_manifest: dict[str, Any],
) -> None:
    if not package_manifest_path.is_file():
        raise ProjectionError(
            f"PACKAGE_MANIFEST_MISSING:{package_manifest_path}"
        )
    package = read_json(package_manifest_path)
    package["runtime_capabilities"] = runtime_manifest.get("capabilities", {})
    package["teacher_guide_capabilities"] = runtime_manifest.get(
        "teacher_guide_capabilities", {}
    )
    package["teacher_guide_validation"] = runtime_manifest.get(
        "teacher_guide_validation", {}
    )
    row_counts = runtime_manifest.get("row_counts", {})
    package["teacher_guide_row_counts"] = {
        table: row_counts.get(table) for table in TEACHER_TABLES
    }
    package_manifest_path.write_text(
        json.dumps(package, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--course-id", required=True)
    parser.add_argument("--course-root", type=Path, required=True)
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--package-manifest", type=Path)
    args = parser.parse_args()

    course_root = args.course_root.resolve()
    runtime_dir = args.runtime_dir.resolve()
    database_path = runtime_dir / "course_runtime.sqlite"
    manifest_path = runtime_dir / "runtime_manifest.json"
    if not database_path.is_file() or not manifest_path.is_file():
        raise ProjectionError("RUNTIME_PACKAGE_INCOMPLETE")

    overlays = overlay_files(course_root)
    if not overlays:
        print("PEDAGOGY_V2_PROJECTION: SKIP (no overlays)")
        return 0

    runtime_manifest = read_json(manifest_path)
    if runtime_manifest.get("course_id") != args.course_id:
        raise ProjectionError(
            f"COURSE_ID_MISMATCH:{args.course_id}:{runtime_manifest.get('course_id')}"
        )

    db = sqlite3.connect(database_path)
    db.execute("PRAGMA foreign_keys = ON")
    try:
        for table in TEACHER_TABLES:
            if not table_exists(db, table):
                raise ProjectionError(f"TEACHER_GUIDE_TABLE_MISSING:{table}")
        delete_previous_projection(db)
        known_sections = section_ids(db)
        known_items = canonical_item_ids(db)
        next_unit_order: dict[str, int] = {}
        totals = {"blocks": 0, "task_cards": 0, "items": 0}
        overlay_versions: list[str] = []
        for path in overlays:
            overlay = read_json(path)
            if overlay.get("document_type") != OVERLAY_TYPE:
                continue
            if overlay.get("course_id") != args.course_id:
                raise ProjectionError(
                    f"OVERLAY_COURSE_MISMATCH:{path}:{overlay.get('course_id')}"
                )
            overlay_versions.append(
                require_text(overlay.get("schema_version"), f"{path}:schema_version")
            )
            result = project_overlay(
                db,
                course_root=course_root,
                overlay_path=path,
                overlay=overlay,
                known_sections=known_sections,
                known_items=known_items,
                next_unit_order=next_unit_order,
            )
            for key, value in result.items():
                totals[key] += value
        fk_errors = db.execute("PRAGMA foreign_key_check").fetchall()
        if fk_errors:
            raise ProjectionError(f"FOREIGN_KEY_CHECK_FAILED:{fk_errors[:3]}")
        db.commit()
        runtime_manifest = update_manifest_and_seal(
            db=db,
            runtime_dir=runtime_dir,
            course_root=course_root,
            overlays=overlays,
            overlay_versions=overlay_versions,
            stats=totals,
        )
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    if args.package_manifest:
        update_package_manifest(args.package_manifest.resolve(), runtime_manifest)

    print("PEDAGOGY_V2_PROJECTION: PASS")
    print(f"COURSE_ID: {args.course_id}")
    print(f"OVERLAYS: {len(overlays)}")
    print(f"BLOCKS: {totals['blocks']}")
    print(f"TASK_CARDS: {totals['task_cards']}")
    print(f"SYNTHETIC_ITEMS: {totals['items']}")
    print(f"PROJECTION_VERSION: {PROJECTION_VERSION}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
