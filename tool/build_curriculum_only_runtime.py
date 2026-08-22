#!/usr/bin/env python3
import argparse
import hashlib
import json
import sqlite3
from pathlib import Path

SCHEMA = r'''
PRAGMA foreign_keys = ON;
CREATE TABLE courses (course_id TEXT PRIMARY KEY, grade INTEGER, title TEXT NOT NULL, schema_version TEXT NOT NULL, source_manifest_fingerprint TEXT NOT NULL);
CREATE TABLE themes (theme_id TEXT PRIMARY KEY, course_id TEXT NOT NULL REFERENCES courses(course_id), theme_order INTEGER NOT NULL, title TEXT NOT NULL, page_range TEXT, planned_hours INTEGER, anlama_hours INTEGER, anlatma_hours INTEGER, source_locator TEXT);
CREATE TABLE blocks (block_id TEXT PRIMARY KEY, theme_id TEXT NOT NULL REFERENCES themes(theme_id), block_order INTEGER NOT NULL, title TEXT NOT NULL, skill_domain TEXT, learning_area TEXT, planned_hours INTEGER, time_status TEXT, source_locators_json TEXT NOT NULL);
CREATE TABLE outcomes (outcome_id TEXT PRIMARY KEY, theme_id TEXT NOT NULL REFERENCES themes(theme_id), outcome_code TEXT NOT NULL, official_text TEXT NOT NULL, process_components TEXT, source_locator TEXT, verification_status TEXT);
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stable_outcome_id(course_id: str, theme_id: str, code: str) -> str:
    return f"{course_id}_{theme_id}_{code.replace('.', '_')}"


def build(package_root: Path, source_commit: str) -> None:
    curriculum_dir = package_root / "curriculum"
    runtime_dir = package_root / "runtime"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    curriculum_path = curriculum_dir / "curriculum_map.json"
    validation_path = curriculum_dir / "curriculum_validation_report.json"
    source_manifest_path = curriculum_dir / "source_manifest.json"
    curriculum = json.loads(curriculum_path.read_text(encoding="utf-8"))
    validation = json.loads(validation_path.read_text(encoding="utf-8"))
    course_id = curriculum["course_id"]
    grade = int(curriculum["grade"])
    fingerprint = sha256(curriculum_path)

    db_path = runtime_dir / "course_runtime.sqlite"
    if db_path.exists():
        db_path.unlink()
    db = sqlite3.connect(db_path)
    try:
        db.executescript(SCHEMA)
        db.execute(
            "INSERT INTO courses VALUES (?, ?, ?, ?, ?)",
            (course_id, grade, curriculum.get("course_title", "Türk Dili ve Edebiyatı"), "1.1.0", fingerprint),
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
                category = outcome.get("skill_category")
                if category not in by_skill:
                    raise RuntimeError(f"{course_id}/{theme_id}: bilinmeyen skill_category: {category}")
                by_skill[category].append(outcome)

            for block_order, (source_skill, suffix, title_skill, area, hours) in enumerate(SKILLS, start=1):
                theme_number = f"T{theme_order}"
                block_id = f"BLOCK_{theme_number}_{block_order:02d}_{suffix}"
                block_locators = [locator] if locator else []
                db.execute(
                    "INSERT INTO blocks VALUES (?, ?, ?, ?, ?, ?, ?, 'DERIVED_PLANNING_POLICY', ?)",
                    (block_id, theme_id, block_order, title_skill, title_skill, area, hours, json.dumps(block_locators, ensure_ascii=False)),
                )
                db.execute(
                    "INSERT INTO timeline_blocks VALUES (?, ?, ?, ?, 'DERIVED_PLANNING_POLICY', ?)",
                    (block_id, theme_id, block_order, hours, json.dumps(block_locators, ensure_ascii=False)),
                )
                skill_outcomes = by_skill[source_skill]
                if not skill_outcomes:
                    raise RuntimeError(f"{course_id}/{theme_id}/{source_skill}: kazanım yok")
                for outcome in skill_outcomes:
                    outcome_id = stable_outcome_id(course_id, theme_id, outcome["outcome_code"])
                    process_components = outcome.get("process_components")
                    if isinstance(process_components, (dict, list)):
                        process_components = json.dumps(process_components, ensure_ascii=False)
                    db.execute(
                        "INSERT INTO outcomes VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (
                            outcome_id,
                            theme_id,
                            outcome["outcome_code"],
                            outcome["outcome_verbatim"],
                            process_components,
                            outcome.get("source_locator"),
                            outcome.get("verification_status"),
                        ),
                    )
                    db.execute("INSERT INTO block_outcomes VALUES (?, ?)", (block_id, outcome_id))
        db.commit()
        fk_errors = list(db.execute("PRAGMA foreign_key_check"))
        if fk_errors:
            raise RuntimeError(f"foreign key errors: {fk_errors}")
        counts = {table: db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] for table in TABLES}
    finally:
        db.close()

    expected_outcomes = int(validation["canonical"]["outcomes"])
    if counts["themes"] != 4 or counts["blocks"] != 16 or counts["outcomes"] != expected_outcomes:
        raise RuntimeError(f"unexpected curriculum runtime counts: {counts}")
    if counts["textbook_sections"] != 0 or counts["activities"] != 0 or counts["forms"] != 0:
        raise RuntimeError("curriculum-only runtime textbook tables must stay empty")

    source_files = [
        "curriculum/curriculum_map.json",
        "curriculum/curriculum_validation_report.json",
        "curriculum/source_manifest.json",
    ]
    source_hashes = {name: sha256(package_root / name) for name in source_files}
    manifest = {
        "runtime_package_version": "1.1.0",
        "schema_version": "1.1.0",
        "course_id": course_id,
        "grade": grade,
        "build_timestamp": "2026-08-22T06:19:23Z",
        "compiler_version": "ogretmenos-curriculum-only-1.0.0",
        "data_mode": "CURRICULUM_ONLY",
        "textbook_status": "AWAITING_OFFICIAL_TEXTBOOK",
        "tymm_source_commit": source_commit,
        "canonical_source_files": source_files,
        "canonical_source_hashes": source_hashes,
        "canonical_content_fingerprint": fingerprint,
        "row_counts": counts,
        "timeline_resolution": "THEME_AND_SKILL_BLOCK_ORDER_RESOLVED",
        "timeline_unresolved_fields": {
            "weekly_lesson_hours": None,
            "calendar_binding": "OGRETMENOS_ACADEMIC_CALENDAR",
            "block_hours": "DERIVED_PLANNING_POLICY",
        },
        "source_manifest_fingerprint": sha256(source_manifest_path),
        "runtime_database_path": "runtime/course_runtime.sqlite",
        "validation_status": "PASS",
        "runtime_status": "RUNTIME_FRESH",
        "capabilities": {
            "curriculum": True,
            "themes": True,
            "outcomes": True,
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
    report = f"""# Curriculum-Only Runtime Validation Report\n\n**Final:** PASS\n\n- course_id: `{course_id}`\n- data_mode: `CURRICULUM_ONLY`\n- textbook_status: `AWAITING_OFFICIAL_TEXTBOOK`\n- source fingerprint status: **PASS · RUNTIME_FRESH**\n- themes: {counts['themes']}\n- blocks: {counts['blocks']}\n- outcomes: {counts['outcomes']}\n- textbook_sections: 0\n- activities: 0\n- forms: 0\n- foreign key integrity: PASS\n\nBlok saatleri uygulama planlama katmanında 12+11+10+10 = 43 olarak türetilmiştir; resmî TYMM blok süresi değildir. Tema başına ek 2 saat okul temelli planlama katmanıdır.\n"""
    (runtime_dir / "runtime_validation_report.md").write_text(report, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-root", required=True)
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()
    build(Path(args.package_root), args.source_commit)


if __name__ == "__main__":
    main()
