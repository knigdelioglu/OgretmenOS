#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from process_component_resolver import (
    ProcessComponentError,
    audit_curriculum,
    project_effective_components,
)

COMPILER_VERSION = "ogretmenos-curriculum-only-1.1.0"
RUNTIME_PACKAGE_VERSION = "1.2.0"
SCHEMA_VERSION = "1.2.0"

SCHEMA = r'''
PRAGMA foreign_keys = ON;
CREATE TABLE courses (course_id TEXT PRIMARY KEY, grade INTEGER, title TEXT NOT NULL, schema_version TEXT NOT NULL, source_manifest_fingerprint TEXT NOT NULL);
CREATE TABLE themes (theme_id TEXT PRIMARY KEY, course_id TEXT NOT NULL REFERENCES courses(course_id), theme_order INTEGER NOT NULL, title TEXT NOT NULL, page_range TEXT, planned_hours INTEGER, anlama_hours INTEGER, anlatma_hours INTEGER, source_locator TEXT);
CREATE TABLE blocks (block_id TEXT PRIMARY KEY, theme_id TEXT NOT NULL REFERENCES themes(theme_id), block_order INTEGER NOT NULL, title TEXT NOT NULL, skill_domain TEXT, learning_area TEXT, planned_hours INTEGER, time_status TEXT, source_locators_json TEXT NOT NULL);
CREATE TABLE outcomes (outcome_id TEXT PRIMARY KEY, theme_id TEXT NOT NULL REFERENCES themes(theme_id), outcome_code TEXT NOT NULL, official_text TEXT NOT NULL, process_components TEXT, process_component_origin TEXT, source_locator TEXT, verification_status TEXT);
CREATE TABLE block_outcomes (block_id TEXT NOT NULL REFERENCES blocks(block_id), outcome_id TEXT NOT NULL REFERENCES outcomes(outcome_id), PRIMARY KEY(block_id, outcome_id));
CREATE TABLE textbook_sections (section_id TEXT PRIMARY KEY, theme_id TEXT NOT NULL REFERENCES themes(theme_id), title TEXT NOT NULL, genre TEXT, printed_page_range TEXT, pdf_page_range TEXT, source_id TEXT);
CREATE TABLE activities (activity_id TEXT PRIMARY KEY, section_id TEXT REFERENCES textbook_sections(section_id), theme_id TEXT NOT NULL REFERENCES themes(theme_id), title TEXT NOT NULL, activity_type TEXT, student_action TEXT, expected_evidence TEXT, printed_page TEXT, pdf_page TEXT, verification_status TEXT);
CREATE TABLE block_activities (block_id TEXT NOT NULL REFERENCES blocks(block_id), activity_id TEXT NOT NULL REFERENCES activities(activity_id), PRIMARY KEY(block_id, activity_id));
CREATE TABLE activity_outcomes (activity_id TEXT NOT NULL REFERENCES activities(activity_id), outcome_id TEXT NOT NULL REFERENCES outcomes(outcome_id), PRIMARY KEY(activity_id, outcome_id));
CREATE TABLE forms (form_id TEXT PRIMARY KEY, title TEXT NOT NULL, structural_type TEXT, assessment_type TEXT, printed_page INTEGER, pdf_page INTEGER, evaluator TEXT, source_id TEXT, verification_status TEXT);
CREATE TABLE activity_forms (activity_id TEXT NOT NULL REFERENCES activities(activity_id), form_id TEXT NOT NULL REFERENCES forms(form_id), PRIMARY KEY(activity_id, form_id));
CREATE TABLE resource_decisions (resource_plan_id TEXT PRIMARY KEY, theme_id TEXT NOT NULL REFERENCES themes(theme_id), need_id TEXT, resource_type TEXT, decision_code TEXT NOT NULL, app_category TEXT, priority TEXT, purpose TEXT, expected_evidence TEXT, textbook_coverage TEXT, locator TEXT, teacher_review_required INTEGER);
CREATE TABLE assessment_artifacts (artifact_id TEXT PRIMARY KEY, title TEXT NOT NULL, skill_domain TEXT, scope TEXT, assessment_family TEXT, reuse_policy TEXT, generation_priority TEXT, generation_status TEXT, teacher_review_required INTEGER, covered_themes_json TEXT NOT NULL, covered_gap_instances_json TEXT NOT NULL, level_model_json TEXT NOT NULL DEFAULT '[]', criteria_json TEXT NOT NULL DEFAULT '[]', provenance_json TEXT NOT NULL DEFAULT '{}');
CREATE TABLE assessment_gap_mappings (gap_instance_id TEXT PRIMARY KEY, artifact_id TEXT NOT NULL REFERENCES assessment_artifacts(artifact_id), theme_id TEXT NOT NULL REFERENCES themes(theme_id), resource_plan_id TEXT, official_requirement TEXT, exact_remaining_gap TEXT, source_locators_json TEXT NOT NULL);
CREATE TABLE assessment_task_bindings (artifact_id TEXT NOT NULL REFERENCES assessment_artifacts(artifact_id), gap_instance_id TEXT NOT NULL, theme_id TEXT NOT NULL REFERENCES themes(theme_id), block_id TEXT REFERENCES blocks(block_id), activity_id TEXT REFERENCES activities(activity_id), targeted_outcomes_json TEXT NOT NULL, task_title TEXT, evidence TEXT, textbook_locator TEXT, curriculum_locator TEXT, task_specific_criteria_json TEXT NOT NULL DEFAULT '[]', source_equivalence_status TEXT, binding_key_semantics TEXT, PRIMARY KEY(artifact_id, gap_instance_id));
CREATE TABLE timeline_themes (theme_id TEXT PRIMARY KEY REFERENCES themes(theme_id), theme_order INTEGER NOT NULL, official_total_hours INTEGER, core_instruction_hours INTEGER, school_based_hours INTEGER, school_based_hours_status TEXT, source_locators_json TEXT NOT NULL);
CREATE TABLE timeline_blocks (block_id TEXT PRIMARY KEY REFERENCES blocks(block_id), theme_id TEXT NOT NULL REFERENCES themes(theme_id), block_order INTEGER NOT NULL, planned_hours INTEGER, time_status TEXT, source_locators_json TEXT NOT NULL);
CREATE TABLE source_references (source_id TEXT PRIMARY KEY, source_type TEXT, source_title TEXT NOT NULL, locator TEXT, provenance_category TEXT, authority_rank INTEGER, verification_status TEXT);
CREATE TABLE entity_source_references (entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, source_id TEXT NOT NULL REFERENCES source_references(source_id), locator TEXT, PRIMARY KEY(entity_type, entity_id, source_id, locator));
CREATE INDEX idx_blocks_theme_order ON blocks(theme_id, block_order);
CREATE INDEX idx_outcomes_theme_code ON outcomes(theme_id, outcome_code);
CREATE INDEX idx_outcomes_process_origin ON outcomes(process_component_origin);
CREATE INDEX idx_activities_theme_page ON activities(theme_id, printed_page);
CREATE INDEX idx_activity_forms_form ON activity_forms(form_id);
CREATE INDEX idx_resource_theme ON resource_decisions(theme_id, decision_code);
CREATE INDEX idx_gap_artifact ON assessment_gap_mappings(artifact_id);
CREATE INDEX idx_bindings_block ON assessment_task_bindings(block_id);
CREATE INDEX idx_source_entity ON entity_source_references(entity_type, entity_id);
'''

SKILLS = [
    ("Dinleme/İzleme", "DINLEME_IZLEME", "Dinleme/İzleme", "ANLAMA", 12),
    ("Okuma", "OKUMA", "Okuma", "ANLAMA", 11),
    ("Konuşma", "KONUSMA", "Konuşma", "ANLATMA", 10),
    ("Yazma", "YAZMA", "Yazma", "ANLATMA", 10),
]
TABLES = [
    "courses", "themes", "blocks", "block_activities", "outcomes", "block_outcomes",
    "textbook_sections", "activities", "activity_outcomes", "forms", "activity_forms",
    "resource_decisions", "assessment_artifacts", "assessment_gap_mappings",
    "assessment_task_bindings", "timeline_themes", "timeline_blocks", "source_references",
    "entity_source_references",
]


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stable_outcome_id(course_id: str, theme_id: str, code: str) -> str:
    return f"{course_id}_{theme_id}_{code.replace('.', '_')}"


def resolve_skill_category(outcome: dict[str, Any]) -> str:
    category = outcome.get("skill_category")
    if category in {item[0] for item in SKILLS}:
        return str(category)
    prefix = str(outcome.get("outcome_code") or "").split(".", 1)[0]
    inferred = {
        "TDE1": "Dinleme/İzleme",
        "TDE2": "Okuma",
        "TDE3": "Konuşma",
        "TDE4": "Yazma",
    }.get(prefix)
    if inferred is None:
        raise RuntimeError(
            f"skill_category çözümlenemedi: code={outcome.get('outcome_code')}, category={category}"
        )
    return inferred


def resolve_curriculum(
    package_root: Path,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Path]]:
    curriculum_dir = package_root / "curriculum"
    curriculum_path = curriculum_dir / "curriculum_map.json"
    validation_path = curriculum_dir / "curriculum_validation_report.json"
    source_manifest_path = curriculum_dir / "source_manifest.json"
    resolution_path = curriculum_dir / "curriculum_process_component_resolution.json"
    catalog_path = package_root.parent / "TDE_SHARED" / "curriculum_process_component_catalog.json"

    required = [
        curriculum_path,
        validation_path,
        source_manifest_path,
        resolution_path,
        catalog_path,
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise RuntimeError(f"curriculum-only canonical dependency missing: {missing}")

    raw = read_json(curriculum_path)
    validation = read_json(validation_path)
    resolution = read_json(resolution_path)
    catalog = read_json(catalog_path)

    if resolution.get("course_id") != raw.get("course_id"):
        raise RuntimeError("PROCESS_COMPONENT_COURSE_CONTRACT_MISMATCH")
    if resolution.get("catalog_id") != catalog.get("catalog_id"):
        raise RuntimeError("PROCESS_COMPONENT_CATALOG_CONTRACT_MISMATCH")

    audit = audit_curriculum(raw, catalog)
    if audit.get("final") != "PASS":
        raise RuntimeError(f"PROCESS_COMPONENT_INHERITANCE_INVALID: {audit.get('counts')}")
    expected = resolution.get("expected_counts", {})
    for key, value in expected.items():
        actual = audit.get("counts", {}).get(key)
        if actual != value:
            raise RuntimeError(
                f"PROCESS_COMPONENT_COUNT_MISMATCH: {key} actual={actual} expected={value}"
            )

    validation_counts = validation.get("canonical", {}).get("process_component_inheritance", {})
    if validation_counts:
        for key in (
            "total_outcomes",
            "outcomes_with_roof_components",
            "explicit_component_outcomes",
            "inherited_component_outcomes",
            "verified_no_component_outcomes",
            "unresolved_component_outcomes",
            "inheritance_missing_count",
            "structural_error_count",
        ):
            if key in validation_counts and validation_counts[key] != audit["counts"][key]:
                raise RuntimeError(
                    f"PROCESS_COMPONENT_VALIDATION_REPORT_DRIFT: {key} "
                    f"report={validation_counts[key]} audit={audit['counts'][key]}"
                )

    projected = project_effective_components(raw, catalog)
    sources = {
        "curriculum/curriculum_map.json": curriculum_path,
        "curriculum/curriculum_validation_report.json": validation_path,
        "curriculum/source_manifest.json": source_manifest_path,
        "curriculum/curriculum_process_component_resolution.json": resolution_path,
        "../TDE_SHARED/curriculum_process_component_catalog.json": catalog_path,
    }
    return projected, audit, sources


def source_fingerprint(sources: dict[str, Path]) -> tuple[dict[str, str], str]:
    hashes = {name: sha256(path) for name, path in sources.items()}
    canonical = "\n".join(f"{name}:{value}" for name, value in sorted(hashes.items()))
    return hashes, hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def build(package_root: Path, source_commit: str) -> None:
    package_root = package_root.resolve()
    runtime_dir = package_root / "runtime"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    curriculum, process_audit, sources = resolve_curriculum(package_root)
    validation = read_json(package_root / "curriculum/curriculum_validation_report.json")
    source_manifest_path = package_root / "curriculum/source_manifest.json"
    source_hashes, fingerprint = source_fingerprint(sources)

    course_id = str(curriculum["course_id"])
    grade = int(curriculum["grade"])
    db_path = runtime_dir / "course_runtime.sqlite"
    if db_path.exists():
        db_path.unlink()

    db = sqlite3.connect(db_path)
    try:
        db.executescript(SCHEMA)
        db.execute(
            "INSERT INTO courses VALUES (?, ?, ?, ?, ?)",
            (
                course_id,
                grade,
                curriculum.get("course_title", "Türk Dili ve Edebiyatı"),
                SCHEMA_VERSION,
                fingerprint,
            ),
        )

        for theme_index, theme in enumerate(curriculum["themes"], start=1):
            theme_id = theme["theme_id"]
            theme_order = int(theme.get("theme_no", theme_index))
            title = theme.get("exact_theme_name") or theme_id
            locator = theme.get("source_locator")
            db.execute(
                "INSERT INTO themes VALUES (?, ?, ?, ?, NULL, 45, NULL, NULL, ?)",
                (theme_id, course_id, theme_order, title, locator),
            )
            source_id = theme.get("source_id") or f"official_tymm_{course_id}_{theme_id}"
            db.execute(
                "INSERT INTO source_references VALUES (?, 'official_curriculum', ?, ?, 'curriculum', 1, ?)",
                (source_id, title, locator, curriculum.get("verification_status", "VERIFIED_OFFICIAL")),
            )
            db.execute(
                "INSERT INTO entity_source_references VALUES ('theme', ?, ?, ?)",
                (theme_id, source_id, locator or ""),
            )
            db.execute(
                "INSERT INTO timeline_themes VALUES (?, ?, 45, 43, 2, 'USER_CONFIRMED_PLANNING_RULE', ?)",
                (theme_id, theme_order, json.dumps([locator] if locator else [], ensure_ascii=False)),
            )

            outcomes = theme.get("learning_outcomes", [])
            by_skill = {skill[0]: [] for skill in SKILLS}
            for outcome in outcomes:
                by_skill[resolve_skill_category(outcome)].append(outcome)

            for block_order, (source_skill, suffix, title_skill, area, hours) in enumerate(SKILLS, start=1):
                block_id = f"BLOCK_T{theme_order}_{block_order:02d}_{suffix}"
                locators = [locator] if locator else []
                db.execute(
                    "INSERT INTO blocks VALUES (?, ?, ?, ?, ?, ?, ?, 'DERIVED_PLANNING_POLICY', ?)",
                    (
                        block_id,
                        theme_id,
                        block_order,
                        title_skill,
                        title_skill,
                        area,
                        hours,
                        json.dumps(locators, ensure_ascii=False),
                    ),
                )
                db.execute(
                    "INSERT INTO timeline_blocks VALUES (?, ?, ?, ?, 'DERIVED_PLANNING_POLICY', ?)",
                    (
                        block_id,
                        theme_id,
                        block_order,
                        hours,
                        json.dumps(locators, ensure_ascii=False),
                    ),
                )
                skill_outcomes = by_skill[source_skill]
                if not skill_outcomes:
                    raise RuntimeError(f"{course_id}/{theme_id}/{source_skill}: kazanım yok")
                for outcome in skill_outcomes:
                    outcome_id = stable_outcome_id(course_id, theme_id, outcome["outcome_code"])
                    components = outcome.get("process_components_effective", [])
                    origin = outcome.get("process_component_resolution", {}).get("origin") or "UNRESOLVED"
                    if origin != "SOURCE_VERIFIED_NONE" and not components:
                        raise RuntimeError(
                            f"PROCESS_COMPONENT_EFFECTIVE_EMPTY: {outcome_id} origin={origin}"
                        )
                    db.execute(
                        "INSERT INTO outcomes VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        (
                            outcome_id,
                            theme_id,
                            outcome["outcome_code"],
                            outcome["outcome_verbatim"],
                            json.dumps(components, ensure_ascii=False),
                            origin,
                            outcome.get("source_locator"),
                            outcome.get("verification_status"),
                        ),
                    )
                    db.execute("INSERT INTO block_outcomes VALUES (?, ?)", (block_id, outcome_id))

        db.commit()
        fk_errors = list(db.execute("PRAGMA foreign_key_check"))
        if fk_errors:
            raise RuntimeError(f"foreign key errors: {fk_errors}")
        counts = {
            table: db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            for table in TABLES
        }
        empty_process = db.execute(
            "SELECT COUNT(*) FROM outcomes WHERE process_components IS NULL OR process_components='' OR process_components='[]'"
        ).fetchone()[0]
        origin_counts = dict(
            db.execute(
                "SELECT process_component_origin, COUNT(*) FROM outcomes GROUP BY process_component_origin"
            ).fetchall()
        )
    finally:
        db.close()

    expected_outcomes = int(validation["canonical"]["outcomes"])
    if counts["themes"] != 4 or counts["blocks"] != 16 or counts["outcomes"] != expected_outcomes:
        raise RuntimeError(f"unexpected curriculum runtime counts: {counts}")
    if counts["textbook_sections"] != 0 or counts["activities"] != 0 or counts["forms"] != 0:
        raise RuntimeError("curriculum-only runtime textbook tables must stay empty")

    expected = process_audit["counts"]
    if empty_process != expected["verified_no_component_outcomes"]:
        raise RuntimeError(
            f"PROCESS_COMPONENT_RUNTIME_EMPTY_MISMATCH: runtime={empty_process} "
            f"verified_none={expected['verified_no_component_outcomes']}"
        )
    if origin_counts.get("THEME_EXPLICIT", 0) != expected["explicit_component_outcomes"]:
        raise RuntimeError(f"PROCESS_COMPONENT_EXPLICIT_ORIGIN_MISMATCH: {origin_counts}")
    if origin_counts.get("ROOF_INHERITED", 0) != expected["inherited_component_outcomes"]:
        raise RuntimeError(f"PROCESS_COMPONENT_INHERITED_ORIGIN_MISMATCH: {origin_counts}")

    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    manifest = {
        "runtime_package_version": RUNTIME_PACKAGE_VERSION,
        "schema_version": SCHEMA_VERSION,
        "course_id": course_id,
        "grade": grade,
        "build_timestamp": now,
        "compiler_version": COMPILER_VERSION,
        "data_mode": "CURRICULUM_ONLY",
        "textbook_status": "AWAITING_OFFICIAL_TEXTBOOK",
        "tymm_source_commit": source_commit,
        "canonical_source_files": sorted(sources),
        "canonical_source_hashes": {name: source_hashes[name] for name in sorted(source_hashes)},
        "canonical_content_fingerprint": fingerprint,
        "row_counts": counts,
        "timeline_resolution": "THEME_AND_SKILL_BLOCK_ORDER_RESOLVED",
        "timeline_unresolved_fields": {
            "weekly_lesson_hours": None,
            "calendar_binding": "OGRETMENOS_ACADEMIC_CALENDAR",
            "block_hours": "DERIVED_PLANNING_POLICY",
        },
        "source_manifest_fingerprint": sha256(source_manifest_path),
        "process_component_resolution_status": "PASS",
        "process_component_counts": expected,
        "process_component_origin_counts": origin_counts,
        "runtime_database_path": "runtime/course_runtime.sqlite",
        "validation_status": "PASS",
        "runtime_status": "RUNTIME_FRESH",
        "capabilities": {
            "curriculum": True,
            "themes": True,
            "outcomes": True,
            "effective_process_components": True,
            "process_component_provenance": True,
            "weekly_planning": True,
            "annual_planning": True,
            "source_references": True,
            "textbook_sections": False,
            "activities": False,
            "forms": False,
            "resource_decisions": False,
            "assessment_artifacts": False,
        },
        "assessment_payload_capabilities": {
            "rubric_level_model": False,
            "rubric_criteria": False,
            "task_specific_criteria": False,
            "source_equivalence_status": False,
            "binding_key_semantics": False,
        },
    }
    (runtime_dir / "runtime_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (runtime_dir / "runtime_schema.sql").write_text(SCHEMA.strip() + "\n", encoding="utf-8")
    report = f"""# Curriculum-Only Runtime Validation Report

**Final:** PASS

- course_id: `{course_id}`
- data_mode: `CURRICULUM_ONLY`
- textbook_status: `AWAITING_OFFICIAL_TEXTBOOK`
- source fingerprint status: **PASS · RUNTIME_FRESH**
- themes: {counts['themes']}
- blocks: {counts['blocks']}
- outcomes: {counts['outcomes']}
- process-component resolution: **PASS**
- roof-inherited outcomes: {expected['inherited_component_outcomes']}
- theme-explicit outcomes: {expected['explicit_component_outcomes']}
- unresolved process-component outcomes: {expected['unresolved_component_outcomes']}
- inheritance missing: {expected['inheritance_missing_count']}
- textbook_sections: 0
- activities: 0
- forms: 0
- foreign key integrity: PASS

Blok saatleri uygulama planlama katmanında 12+11+10+10 = 43 olarak türetilmiştir; resmî TYMM blok süresi değildir. Tema başına ek 2 saat okul temelli planlama katmanıdır.
"""
    (runtime_dir / "runtime_validation_report.md").write_text(report, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-root", required=True)
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()
    try:
        build(Path(args.package_root), args.source_commit)
    except (RuntimeError, ProcessComponentError, sqlite3.Error, KeyError, ValueError) as exc:
        raise SystemExit(f"CURRICULUM_RUNTIME_BUILD_FAIL: {exc}")


if __name__ == "__main__":
    main()
