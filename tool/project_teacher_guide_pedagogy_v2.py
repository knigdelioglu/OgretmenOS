#!/usr/bin/env python3
"""Project TYMM Teacher Guide V2.2 pedagogy onto the verified ÖğretmenOS runtime.

Canonical teacher-guide items stay authoritative. The projector adds one synthetic
V2.2 pedagogy unit/item for every canonical unit in TEMA_02..04, reusing the
canonical items and relations instead of duplicating task/answer data.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Iterable

PROJECTION_VERSION = "1.2.0+pedagogy-v2.2-profile"
ARCHITECTURE_VERSION = "2.2.0"
SYNTHETIC_UNIT_PREFIX = "__pedv2_unit__"
SYNTHETIC_ITEM_PREFIX = "__pedv2_block__"
PROFILE_SOURCE_ID = "TYMM_TEACHER_GUIDE_PEDAGOGY_PROFILE"
TEACHER_TABLES = (
    "canonical_entities", "teacher_guides", "teacher_guide_sections",
    "teacher_guide_units", "teacher_guide_items", "teacher_guide_item_relations",
)
PROFILE_FIELDS = (
    "teacher_moves", "follow_up_questions", "misconception_interventions",
    "board_notes", "assessment_look_fors", "support", "enrichment",
    "source_limitations",
)
FIELD_CAPS = {
    "teacher_moves": 4, "follow_up_questions": 4,
    "misconception_interventions": 3, "board_notes": 2,
    "assessment_look_fors": 4, "support": 2, "enrichment": 2,
    "source_limitations": 99,
}
STOPWORDS = {
    "ve", "veya", "ile", "icin", "bir", "bu", "su", "da", "de", "mi", "mu",
    "metin", "gorev", "ogrenci", "ogrencinin", "olarak", "uzerinden", "gibi",
    "daha", "yalniz", "sonra", "once", "kendi", "ayni", "ise",
}
TR_MAP = str.maketrans({"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u"})


class ProjectionError(ValueError):
    pass


def compact_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


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


def stable_source_key(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def table_exists(db: sqlite3.Connection, table: str) -> bool:
    return db.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", (table,)
    ).fetchone() is not None


def table_count(db: sqlite3.Connection, table: str) -> int:
    return int(db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def unique(values: Iterable[str]) -> list[str]:
    out: list[str] = []
    for value in values:
        value = value.strip()
        if value and value not in out:
            out.append(value)
    return out


def normalize_tokens(text: str) -> set[str]:
    normalized = text.casefold().translate(TR_MAP)
    tokens = set(re.findall(r"[a-z0-9]+", normalized))
    return {token for token in tokens if len(token) >= 3 and token not in STOPWORDS}


def classify_phase(section_type: str, unit_title: str) -> str:
    if section_type == "THEME_OPENING":
        return "opening"
    if section_type == "THEME_ASSESSMENT":
        return "assessment"
    title = unit_title.casefold()
    if any(key in title for key in ("yönet", "hazır", "planla")):
        return "manage"
    if any(key in title for key in ("değerl", "yansıt", "öz değerlend", "kontrol")):
        return "reflect"
    if section_type in {"SPEAKING", "WRITING"}:
        return "analyze_apply"
    if any(key in title for key in ("çözüm", "kural", "uygula", "gerçekleştir")):
        return "analyze_apply"
    return "meaning"


def phase_hint(text: str) -> str | None:
    value = text.casefold()
    if any(key in value for key in ("tahmin", "strateji", "hazır", "amaç", "ön bilgi", "planla")):
        return "manage"
    if any(key in value for key in ("öz değerlend", "geri bildirim", "revizyon", "yansıt", "değerlendir")):
        return "reflect"
    if any(key in value for key in ("çözüm", "yapı", "üslup", "işlev", "uygula", "ürün", "taslak", "performans")):
        return "analyze_apply"
    if any(key in value for key in ("konu", "tema", "ileti", "anlam", "yorum", "çıkarım", "soru")):
        return "meaning"
    return None


def lower_first(text: str) -> str:
    return text[:1].lower() + text[1:] if text else text


def contextual_fallback(field: str, phase: str, phase_profile: dict[str, Any], anchor: str) -> str:
    candidates = phase_profile.get(field)
    if not isinstance(candidates, list) or not candidates:
        raise ProjectionError(f"MISSING_PHASE_FALLBACK:{phase}:{field}")
    base = str(candidates[0]).strip()
    if field == "teacher_moves":
        return f"“{anchor}” görevinde {lower_first(base)}"
    if field == "follow_up_questions":
        return f"“{anchor}” için: {base}"
    if field == "misconception_interventions":
        return f"“{anchor}” sırasında {lower_first(base)}"
    if field == "assessment_look_fors":
        return f"“{anchor}” için ölçmede: {lower_first(base)}"
    if field == "support":
        return f"“{anchor}” için destek: {lower_first(base)}"
    if field == "enrichment":
        return f"“{anchor}” için zenginleştirme: {lower_first(base)}"
    return base


def delete_previous_projection(db: sqlite3.Connection) -> None:
    unit_ids = [
        str(row[0]) for row in db.execute(
            "SELECT unit_id FROM teacher_guide_units WHERE unit_id LIKE ?",
            (f"{SYNTHETIC_UNIT_PREFIX}%",),
        )
    ]
    if not unit_ids:
        return
    unit_marks = ",".join("?" for _ in unit_ids)
    item_ids = [
        str(row[0]) for row in db.execute(
            f"SELECT item_id FROM teacher_guide_items WHERE unit_id IN ({unit_marks})", unit_ids
        )
    ]
    if item_ids:
        item_marks = ",".join("?" for _ in item_ids)
        db.execute(f"DELETE FROM teacher_guide_item_relations WHERE item_id IN ({item_marks})", item_ids)
        db.execute(f"DELETE FROM teacher_guide_items WHERE item_id IN ({item_marks})", item_ids)
    db.execute(f"DELETE FROM teacher_guide_units WHERE unit_id IN ({unit_marks})", unit_ids)


def source_relations(db: sqlite3.Connection, item_ids: Iterable[str]) -> list[tuple[str, str, str]]:
    out: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for item_id in item_ids:
        rows = db.execute(
            """SELECT target_type,target_id,relation_type
               FROM teacher_guide_item_relations
               WHERE item_id=?
               ORDER BY relation_order,target_type,target_id,relation_type""",
            (item_id,),
        )
        for target_type, target_id, relation_type in rows:
            value = (str(target_type), str(target_id), str(relation_type))
            if value not in seen:
                seen.add(value)
                out.append(value)
    return out


def payload_hash(
    *, item_id: str, unit_id: str, title: str, page_locator: str | None,
    source_locator: str, content_status: str, expected_response: Any,
    teacher_guidance: Any, misconceptions: Any, assessment: Any,
    differentiation: Any, provenance: Any, relations: list[tuple[str, str, str]],
) -> str:
    payload = {
        "item_id": item_id,
        "unit_id": unit_id,
        "item_order": 1,
        "title": title,
        "label": "Öğretmen için V2.2 pedagojik uygulama notları",
        "item_type": "ÖĞRETMEN_REHBERİ_V2_2",
        "page_locator": page_locator,
        "source_locator": source_locator,
        "content_status": content_status,
        "expected_response": expected_response,
        "acceptance_criteria": [],
        "teacher_guidance": teacher_guidance,
        "common_misconceptions": misconceptions,
        "assessment_evidence": assessment,
        "differentiation": differentiation,
        "provenance": provenance,
        "relations": [
            {"target_type": target_type, "target_id": target_id,
             "relation_type": relation_type, "order": order}
            for order, (target_type, target_id, relation_type) in enumerate(relations, start=1)
        ],
    }
    return sha256_bytes(compact_json(payload).encode("utf-8"))


def insert_block_item(
    db: sqlite3.Connection, *, item_id: str, unit_id: str, title: str,
    page_locator: str | None, source_locator: str, expected_response: Any,
    teacher_guidance: Any, misconceptions: Any, assessment: Any,
    differentiation: Any, provenance: Any, relations: list[tuple[str, str, str]],
) -> None:
    content_status = "REVIEW_REQUIRED"
    digest = payload_hash(
        item_id=item_id, unit_id=unit_id, title=title, page_locator=page_locator,
        source_locator=source_locator, content_status=content_status,
        expected_response=expected_response, teacher_guidance=teacher_guidance,
        misconceptions=misconceptions, assessment=assessment,
        differentiation=differentiation, provenance=provenance, relations=relations,
    )
    db.execute(
        """INSERT INTO teacher_guide_items(
             item_id,unit_id,item_order,title,label,item_type,page_locator,
             source_locator,content_status,expected_response_json,
             acceptance_criteria_json,teacher_guidance_json,
             common_misconceptions_json,assessment_evidence_json,
             differentiation_json,provenance_json,canonical_payload_sha256
           ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (
            item_id, unit_id, 1, title,
            "Öğretmen için V2.2 pedagojik uygulama notları",
            "ÖĞRETMEN_REHBERİ_V2_2", page_locator, source_locator,
            content_status, compact_json(expected_response), compact_json([]),
            compact_json(teacher_guidance), compact_json(misconceptions),
            compact_json(assessment), compact_json(differentiation),
            compact_json(provenance), digest,
        ),
    )
    for order, (target_type, target_id, relation_type) in enumerate(relations, start=1):
        db.execute(
            """INSERT INTO teacher_guide_item_relations(
                 item_id,target_type,target_id,relation_type,relation_order
               ) VALUES (?,?,?,?,?)""",
            (item_id, target_type, target_id, relation_type, order),
        )


def load_units(db: sqlite3.Connection, section_id: str) -> list[dict[str, Any]]:
    units: list[dict[str, Any]] = []
    rows = db.execute(
        """SELECT unit_id,unit_order,title,page_locator,purpose_json
           FROM teacher_guide_units
           WHERE section_id=? AND unit_id NOT LIKE ?
           ORDER BY unit_order,unit_id""",
        (section_id, f"{SYNTHETIC_UNIT_PREFIX}%"),
    )
    for unit_id, unit_order, title, page_locator, purpose_json in rows:
        items = [
            {"item_id": str(iid), "label": str(label or item_title or iid),
             "item_type": str(item_type or "")}
            for iid, label, item_title, item_type in db.execute(
                """SELECT item_id,label,title,item_type FROM teacher_guide_items
                   WHERE unit_id=? ORDER BY item_order,item_id""",
                (unit_id,),
            )
        ]
        try:
            purpose = json.loads(purpose_json) if purpose_json else None
        except json.JSONDecodeError:
            purpose = None
        units.append({
            "unit_id": str(unit_id), "unit_order": int(unit_order),
            "title": str(title or unit_id), "page_locator": page_locator,
            "purpose": purpose, "items": items,
        })
    return units


def unit_descriptor(unit: dict[str, Any]) -> str:
    parts = [unit["title"], compact_json(unit.get("purpose"))]
    for item in unit["items"]:
        parts.extend((item["label"], item["item_type"]))
    return " ".join(parts)


def task_anchor(unit: dict[str, Any]) -> str:
    for item in unit["items"]:
        if item["label"].strip():
            return item["label"].strip()
    return unit["title"]


def assign_guidance(
    units: list[dict[str, Any]], section_type: str, profile: dict[str, Any]
) -> dict[str, dict[str, list[str]]]:
    assignments = {unit["unit_id"]: {field: [] for field in PROFILE_FIELDS} for unit in units}
    phases = {unit["unit_id"]: classify_phase(section_type, unit["title"]) for unit in units}
    descriptors = {unit["unit_id"]: normalize_tokens(unit_descriptor(unit)) for unit in units}
    for field in PROFILE_FIELDS:
        entries = profile.get(field, [])
        if not isinstance(entries, list):
            continue
        if field == "board_notes":
            entries = entries[: 2 * len(units)]
        for entry in entries:
            if not isinstance(entry, str) or not entry.strip():
                continue
            tokens = normalize_tokens(entry)
            hint = phase_hint(entry)
            candidates: list[tuple[int, int, str]] = []
            for index, unit in enumerate(units):
                unit_id = unit["unit_id"]
                if len(assignments[unit_id][field]) >= FIELD_CAPS[field]:
                    continue
                score = len(tokens & descriptors[unit_id]) * 10
                if hint and phases[unit_id] == hint:
                    score += 7
                if not hint:
                    preferred = "analyze_apply" if section_type in {"SPEAKING", "WRITING"} else "meaning"
                    if phases[unit_id] == preferred:
                        score += 2
                candidates.append((score, -index, unit_id))
            if not candidates:
                raise ProjectionError(f"NO_GUIDANCE_CAPACITY:{field}:{entry}")
            assignments[max(candidates)[2]][field].append(entry.strip())
    return assignments


def select_field(
    field: str, assigned: list[str], phase: str,
    phase_profile: dict[str, Any], anchor: str,
) -> list[str]:
    if field == "board_notes":
        return unique(assigned)[:2]
    if field == "source_limitations":
        return unique(assigned)
    if assigned:
        return unique(assigned)[: FIELD_CAPS[field]]
    return [contextual_fallback(field, phase, phase_profile, anchor)]


def section_index(db: sqlite3.Connection) -> dict[str, dict[str, str]]:
    return {
        str(section_id): {
            "theme_id": str(scope_id),
            "section_type": str(section_type or ""),
            "title": str(title or section_id),
        }
        for section_id, section_type, title, scope_id in db.execute(
            """SELECT s.section_id,s.section_type,s.title,g.scope_id
               FROM teacher_guide_sections s
               JOIN teacher_guides g ON g.guide_id=s.guide_id"""
        )
    }


def project_profiles(
    db: sqlite3.Connection, profiles: dict[str, Any], profile_source_key: str
) -> dict[str, Any]:
    if profiles.get("architecture_version") != ARCHITECTURE_VERSION:
        raise ProjectionError("PROFILE_ARCHITECTURE_VERSION_MISMATCH")
    phase_profiles = profiles.get("phase_profiles")
    themes = profiles.get("section_profiles")
    if not isinstance(phase_profiles, dict) or not isinstance(themes, dict):
        raise ProjectionError("PROFILE_STRUCTURE_INVALID")

    sections = section_index(db)
    stats: dict[str, Any] = {
        "themes": [], "sections": 0, "blocks": 0,
        "canonical_task_items_reused": 0,
    }
    for theme_id, section_profiles in themes.items():
        if not isinstance(section_profiles, dict):
            raise ProjectionError(f"THEME_PROFILE_INVALID:{theme_id}")
        stats["themes"].append(theme_id)
        for section_id, section_profile in section_profiles.items():
            section = sections.get(section_id)
            if section is None or section["theme_id"] != theme_id:
                raise ProjectionError(f"CANONICAL_SECTION_MISSING:{theme_id}:{section_id}")
            if not isinstance(section_profile, dict):
                raise ProjectionError(f"SECTION_PROFILE_INVALID:{section_id}")
            units = load_units(db, section_id)
            if not units:
                raise ProjectionError(f"CANONICAL_UNITS_MISSING:{section_id}")
            assigned = assign_guidance(units, section["section_type"], section_profile)
            max_order = max(unit["unit_order"] for unit in units)
            focus = str(section_profile.get("focus") or section["title"])
            for offset, unit in enumerate(units, start=1):
                phase = classify_phase(section["section_type"], unit["title"])
                phase_profile = phase_profiles.get(phase)
                if not isinstance(phase_profile, dict):
                    raise ProjectionError(f"PHASE_PROFILE_MISSING:{phase}")
                anchor = task_anchor(unit)
                fields = {
                    field: select_field(field, assigned[unit["unit_id"]][field], phase, phase_profile, anchor)
                    for field in PROFILE_FIELDS
                }
                source_item_refs = [item["item_id"] for item in unit["items"]]
                stats["canonical_task_items_reused"] += len(source_item_refs)
                synthetic_unit_id = f"{SYNTHETIC_UNIT_PREFIX}{unit['unit_id']}"
                synthetic_item_id = f"{SYNTHETIC_ITEM_PREFIX}{unit['unit_id']}"
                pedagogical_intent = f"{unit['title']} aşamasında: {focus}"
                provenance = {
                    "source_ids": [PROFILE_SOURCE_ID],
                    "source_locators": [profile_source_key],
                    "source_tymm_commit": profiles.get("source_tymm_commit"),
                    "content_class": "PEDAGOGY_V2_2_BLOCK",
                    "architecture_version": ARCHITECTURE_VERSION,
                    "profile_schema_version": profiles.get("schema_version"),
                    "theme_id": theme_id,
                    "section_id": section_id,
                    "canonical_unit_id": unit["unit_id"],
                    "source_item_refs": source_item_refs,
                }
                purpose = {
                    "architecture_version": ARCHITECTURE_VERSION,
                    "phase_name": phase,
                    "pedagogical_intent": pedagogical_intent,
                    "canonical_unit_id": unit["unit_id"],
                    "source_item_refs": source_item_refs,
                    "source_limitations": fields["source_limitations"],
                }
                db.execute(
                    """INSERT INTO teacher_guide_units(
                         unit_id,section_id,unit_order,title,page_locator,source_locator,
                         content_status,purpose_json,provenance_json
                       ) VALUES (?,?,?,?,?,?,?,?,?)""",
                    (
                        synthetic_unit_id, section_id, max_order + offset,
                        f"V2.2 · {unit['title']}", unit["page_locator"],
                        profile_source_key, "REVIEW_REQUIRED",
                        compact_json(purpose), compact_json(provenance),
                    ),
                )
                relations = source_relations(db, source_item_refs)
                insert_block_item(
                    db,
                    item_id=synthetic_item_id,
                    unit_id=synthetic_unit_id,
                    title=f"V2.2 · {unit['title']}",
                    page_locator=unit["page_locator"],
                    source_locator=profile_source_key,
                    expected_response={
                        "pedagojik_amaç": pedagogical_intent,
                        "faz": phase,
                        "kaynak_görevler": [item["label"] for item in unit["items"]],
                        "tahtaya_yaz": fields["board_notes"],
                        "kaynak_sınırı": fields["source_limitations"],
                    },
                    teacher_guidance={
                        "öğretmen_hamleleri": fields["teacher_moves"],
                        "takip_soruları": fields["follow_up_questions"],
                        "tahtaya_yaz": fields["board_notes"],
                    },
                    misconceptions=fields["misconception_interventions"],
                    assessment=fields["assessment_look_fors"],
                    differentiation={
                        "support": fields["support"],
                        "enrichment": fields["enrichment"],
                    },
                    provenance=provenance,
                    relations=relations,
                )
                stats["blocks"] += 1
            stats["sections"] += 1
    stats["themes"] = sorted(stats["themes"])
    return stats


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
               ORDER BY g.guide_id,s.section_order,s.section_id,
                        u.unit_order,u.unit_id,i.item_order,i.item_id"""
        )
    ]


def update_metadata(
    db: sqlite3.Connection, runtime_dir: Path, package_path: Path | None,
    profile_path: Path, profile_source_key: str,
    profiles: dict[str, Any], stats: dict[str, Any],
) -> None:
    manifest_path = runtime_dir / "runtime_manifest.json"
    seal_path = runtime_dir / "teacher_guide_validation_seal.json"
    manifest = read_json(manifest_path)
    old_seal = read_json(seal_path)
    existing_sources = old_seal.get("source_files")
    if not isinstance(existing_sources, dict):
        raise ProjectionError("SEAL_SOURCE_FILES_INVALID")
    source_files = {
        str(key): str(value) for key, value in existing_sources.items()
        if "teacher_guide_v2_profiles.json" not in str(key)
    }
    source_files[profile_source_key] = sha256_file(profile_path)
    counts = teacher_counts(db)
    fingerprint_payload = {
        "projection_version": PROJECTION_VERSION,
        "source_hashes": source_files,
        "row_counts": counts,
        "items": ordered_item_hashes(db),
    }
    fingerprint = sha256_bytes(compact_json(fingerprint_payload).encode("utf-8"))
    pedagogy = {
        "available": True,
        "architecture_version": ARCHITECTURE_VERSION,
        "projection_version": PROJECTION_VERSION,
        "profile_schema_version": profiles.get("schema_version"),
        "source_tymm_commit": profiles.get("source_tymm_commit"),
        "source_mode": "CANONICAL_RUNTIME_PLUS_V2_PROFILE",
        **stats,
    }
    seal = {
        "seal_type": "TEACHER_GUIDE_COURSE_VALIDATION_SEAL",
        "projection_version": PROJECTION_VERSION,
        "status": "PASS",
        "scope": "COURSE",
        "course_id": manifest.get("course_id"),
        "canonical_content_fingerprint": manifest.get("canonical_content_fingerprint"),
        "teacher_guide_content_fingerprint": fingerprint,
        "source_validation_status": old_seal.get("source_validation_status", "PASS_WITH_WARNINGS"),
        "source_files": source_files,
        "row_counts": counts,
        "pedagogy_overlay": pedagogy,
    }
    seal_path.write_text(compact_json(seal) + "\n", encoding="utf-8")
    seal_sha = sha256_file(seal_path)

    row_counts = manifest.get("row_counts")
    capabilities = manifest.get("teacher_guide_capabilities")
    validation = manifest.get("teacher_guide_validation")
    if not isinstance(row_counts, dict) or not isinstance(capabilities, dict) or not isinstance(validation, dict):
        raise ProjectionError("RUNTIME_MANIFEST_TEACHER_GUIDE_METADATA_INVALID")
    row_counts.update(counts)
    capabilities["row_counts"] = counts
    capabilities["pedagogy_overlay"] = pedagogy
    validation["content_fingerprint"] = f"sha256:{fingerprint}"
    validation["seal_sha256"] = seal_sha
    validation["projection_version"] = PROJECTION_VERSION
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if package_path is not None:
        package = read_json(package_path)
        package["teacher_guide_source_commit"] = profiles.get("source_tymm_commit")
        package["runtime_capabilities"] = manifest.get("capabilities", {})
        package["teacher_guide_capabilities"] = capabilities
        package["teacher_guide_validation"] = validation
        package["teacher_guide_row_counts"] = counts
        package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--course-id", default="TDE_11")
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--profiles", type=Path, required=True)
    parser.add_argument("--package-manifest", type=Path)
    parser.add_argument("--expected-canonical-fingerprint")
    parser.add_argument("--expected-teacher-guide-fingerprint")
    args = parser.parse_args()

    runtime_dir = args.runtime_dir.resolve()
    profile_path = args.profiles.resolve()
    package_path = args.package_manifest.resolve() if args.package_manifest else None
    database_path = runtime_dir / "course_runtime.sqlite"
    manifest_path = runtime_dir / "runtime_manifest.json"
    seal_path = runtime_dir / "teacher_guide_validation_seal.json"
    for path in (database_path, manifest_path, seal_path, profile_path):
        if not path.is_file():
            raise ProjectionError(f"MISSING_REQUIRED_FILE:{path}")

    manifest = read_json(manifest_path)
    seal = read_json(seal_path)
    if manifest.get("course_id") != args.course_id:
        raise ProjectionError("COURSE_ID_MISMATCH")
    if args.expected_canonical_fingerprint and manifest.get("canonical_content_fingerprint") != args.expected_canonical_fingerprint:
        raise ProjectionError("CANONICAL_FINGERPRINT_MISMATCH")
    if args.expected_teacher_guide_fingerprint and seal.get("teacher_guide_content_fingerprint") != args.expected_teacher_guide_fingerprint:
        if seal.get("projection_version") != PROJECTION_VERSION:
            raise ProjectionError("TEACHER_GUIDE_FINGERPRINT_MISMATCH")

    profiles = read_json(profile_path)
    profile_source_key = stable_source_key(profile_path)
    db = sqlite3.connect(database_path)
    db.execute("PRAGMA foreign_keys=ON")
    try:
        for table in TEACHER_TABLES:
            if not table_exists(db, table):
                raise ProjectionError(f"TEACHER_GUIDE_TABLE_MISSING:{table}")
        delete_previous_projection(db)
        stats = project_profiles(db, profiles, profile_source_key)
        foreign_key_errors = db.execute("PRAGMA foreign_key_check").fetchall()
        if foreign_key_errors:
            raise ProjectionError(f"FOREIGN_KEY_CHECK_FAILED:{foreign_key_errors[:3]}")
        db.commit()
        update_metadata(
            db, runtime_dir, package_path, profile_path, profile_source_key,
            profiles, stats,
        )
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    print("PEDAGOGY_V2_2_PROFILE_PROJECTION: PASS")
    print(f"ARCHITECTURE_VERSION: {ARCHITECTURE_VERSION}")
    print(f"THEMES: {','.join(stats['themes'])}")
    print(f"SECTIONS: {stats['sections']}")
    print(f"BLOCKS: {stats['blocks']}")
    print(f"CANONICAL_TASK_ITEMS_REUSED: {stats['canonical_task_items_reused']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
