-- Teacher Guide runtime projection v1.
--
-- This is an additive, optional extension to the canonical course runtime.
-- The course runtime compiler owns population of these tables. Flutter only
-- opens the resulting database read-only.
PRAGMA foreign_keys = ON;

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
    canonical_payload_sha256 TEXT,
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
