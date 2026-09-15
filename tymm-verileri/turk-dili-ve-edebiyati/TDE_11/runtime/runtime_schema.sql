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
CREATE TABLE assessment_artifacts (artifact_id TEXT PRIMARY KEY, title TEXT NOT NULL, skill_domain TEXT, scope TEXT, assessment_family TEXT, reuse_policy TEXT, generation_priority TEXT, generation_status TEXT, teacher_review_required INTEGER, covered_themes_json TEXT NOT NULL, covered_gap_instances_json TEXT NOT NULL);
CREATE TABLE assessment_gap_mappings (gap_instance_id TEXT PRIMARY KEY, artifact_id TEXT NOT NULL REFERENCES assessment_artifacts(artifact_id), theme_id TEXT NOT NULL REFERENCES themes(theme_id), resource_plan_id TEXT, official_requirement TEXT, exact_remaining_gap TEXT, source_locators_json TEXT NOT NULL);
CREATE TABLE assessment_task_bindings (artifact_id TEXT NOT NULL REFERENCES assessment_artifacts(artifact_id), gap_instance_id TEXT NOT NULL, theme_id TEXT NOT NULL REFERENCES themes(theme_id), block_id TEXT REFERENCES blocks(block_id), activity_id TEXT REFERENCES activities(activity_id), targeted_outcomes_json TEXT NOT NULL, task_title TEXT, evidence TEXT, textbook_locator TEXT, curriculum_locator TEXT, PRIMARY KEY(artifact_id, gap_instance_id));
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

CREATE TABLE canonical_entities (
    entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0),
    entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
    PRIMARY KEY (entity_type, entity_id)
);
CREATE TABLE teacher_guides (
    guide_id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL REFERENCES courses(course_id),
    scope_type TEXT NOT NULL CHECK (length(trim(scope_type)) > 0),
    scope_id TEXT NOT NULL CHECK (length(trim(scope_id)) > 0),
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    content_status TEXT NOT NULL CHECK (length(trim(content_status)) > 0),
    schema_version TEXT NOT NULL CHECK (length(trim(schema_version)) > 0),
    provenance_json TEXT NOT NULL,
    FOREIGN KEY (scope_type, scope_id)
        REFERENCES canonical_entities(entity_type, entity_id),
    UNIQUE (course_id, scope_type, scope_id)
);
CREATE TABLE teacher_guide_sections (
    section_id TEXT PRIMARY KEY,
    guide_id TEXT NOT NULL REFERENCES teacher_guides(guide_id),
    section_order INTEGER NOT NULL CHECK (section_order > 0),
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    section_type TEXT NOT NULL CHECK (length(trim(section_type)) > 0),
    page_locator TEXT,
    source_locator TEXT,
    content_status TEXT NOT NULL CHECK (length(trim(content_status)) > 0),
    provenance_json TEXT NOT NULL,
    UNIQUE (guide_id, section_order)
);
CREATE TABLE teacher_guide_units (
    unit_id TEXT PRIMARY KEY,
    section_id TEXT NOT NULL REFERENCES teacher_guide_sections(section_id),
    unit_order INTEGER NOT NULL CHECK (unit_order > 0),
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    page_locator TEXT,
    source_locator TEXT,
    content_status TEXT NOT NULL CHECK (length(trim(content_status)) > 0),
    purpose_json TEXT NOT NULL,
    provenance_json TEXT NOT NULL,
    UNIQUE (section_id, unit_order)
);
CREATE TABLE teacher_guide_items (
    item_id TEXT PRIMARY KEY,
    unit_id TEXT NOT NULL REFERENCES teacher_guide_units(unit_id),
    item_order INTEGER NOT NULL CHECK (item_order > 0),
    title TEXT,
    label TEXT NOT NULL CHECK (length(trim(label)) > 0),
    item_type TEXT NOT NULL CHECK (length(trim(item_type)) > 0),
    page_locator TEXT,
    source_locator TEXT,
    content_status TEXT NOT NULL CHECK (length(trim(content_status)) > 0),
    expected_response_json TEXT NOT NULL,
    acceptance_criteria_json TEXT NOT NULL,
    teacher_guidance_json TEXT NOT NULL,
    common_misconceptions_json TEXT NOT NULL,
    assessment_evidence_json TEXT NOT NULL,
    differentiation_json TEXT NOT NULL,
    provenance_json TEXT NOT NULL,
    canonical_payload_sha256 TEXT NOT NULL
        CHECK (length(trim(canonical_payload_sha256)) = 64),
    UNIQUE (unit_id, item_order)
);
CREATE TABLE teacher_guide_item_relations (
    item_id TEXT NOT NULL REFERENCES teacher_guide_items(item_id),
    target_type TEXT NOT NULL CHECK (length(trim(target_type)) > 0),
    target_id TEXT NOT NULL CHECK (length(trim(target_id)) > 0),
    relation_type TEXT NOT NULL CHECK (length(trim(relation_type)) > 0),
    relation_order INTEGER NOT NULL DEFAULT 1 CHECK (relation_order > 0),
    PRIMARY KEY (item_id, target_type, target_id, relation_type),
    FOREIGN KEY (target_type, target_id)
        REFERENCES canonical_entities(entity_type, entity_id)
);
CREATE INDEX idx_teacher_guide_scope
    ON teacher_guides(scope_type, scope_id, guide_id);
CREATE INDEX idx_teacher_guide_section_order
    ON teacher_guide_sections(guide_id, section_order, section_id);
CREATE INDEX idx_teacher_guide_unit_order
    ON teacher_guide_units(section_id, unit_order, unit_id);
CREATE INDEX idx_teacher_guide_item_order
    ON teacher_guide_items(unit_id, item_order, item_id);
CREATE INDEX idx_teacher_guide_relation_target
    ON teacher_guide_item_relations(target_type, target_id, relation_order, item_id);

-- assessment-rubric-payload-extension-v1
ALTER TABLE assessment_artifacts ADD COLUMN level_model_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE assessment_artifacts ADD COLUMN criteria_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE assessment_artifacts ADD COLUMN provenance_json TEXT NOT NULL DEFAULT '{}';
ALTER TABLE assessment_task_bindings ADD COLUMN task_specific_criteria_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE assessment_task_bindings ADD COLUMN source_equivalence_status TEXT;
ALTER TABLE assessment_task_bindings ADD COLUMN binding_key_semantics TEXT;

-- lesson-plan-payload-extension-v1
CREATE TABLE IF NOT EXISTS lesson_plan_packages (
    package_id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL REFERENCES courses(course_id),
    theme_id TEXT NOT NULL REFERENCES themes(theme_id),
    block_id TEXT NOT NULL REFERENCES blocks(block_id),
    package_no INTEGER NOT NULL CHECK(package_no > 0),
    lesson_hours INTEGER NOT NULL CHECK(lesson_hours > 0),
    plan_title TEXT NOT NULL,
    plan_summary TEXT NOT NULL,
    remaining_block_hours INTEGER NOT NULL CHECK(remaining_block_hours >= 0),
    schema_version TEXT NOT NULL,
    validation_status TEXT NOT NULL,
    source_path TEXT NOT NULL,
    payload_sha256 TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    UNIQUE(block_id, package_no)
);
CREATE INDEX IF NOT EXISTS idx_lesson_plan_theme_block
    ON lesson_plan_packages(theme_id, block_id, package_no);
CREATE INDEX IF NOT EXISTS idx_lesson_plan_block_package
    ON lesson_plan_packages(block_id, package_no);
