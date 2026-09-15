# Generic Teacher Guide Runtime Contract

Teacher Guide is an optional canonical TYMM runtime projection. It is not a
teacher-local note store and it is not an asset/JSON source that widgets may
read directly.

## Boundary

```text
canonical TYMM guide source + canonical entity maps
  -> TYMM runtime compiler projection
  -> read-only course_runtime.sqlite + runtime_manifest.json
  -> TeacherGuideDatabaseDataSource
  -> TeacherGuideKnowledgeRepository
```

The application does not infer a relationship from a title, page, activity
name, or ID similarity. A capable runtime must publish an explicit relation
row for every item-to-entity link.

## Optional schema extension

The additive schema fragment is
`tool/teacher_guide/teacher_guide_runtime_schema.sql` and contains:

- `canonical_entities` — `(entity_type, entity_id)` registry used by generic
  composite foreign keys;
- `teacher_guides` — course/scope-level guide metadata;
- `teacher_guide_sections` — deterministic guide section order;
- `teacher_guide_units` — deterministic section unit order;
- `teacher_guide_items` — item content and canonical JSON payloads;
- `teacher_guide_item_relations` — explicit item-to-entity links.

`target_type`, `scope_type`, `relation_type`, and `item_type` are strings on
purpose. New canonical entity types do not require a Flutter enum or a new
subject-specific branch; the compiler only needs to register the target in
`canonical_entities`.

The JSON columns are required to contain JSON, including the literal `null`.
This preserves text, arrays, objects, numbers, booleans, and nested values
without converting them into question/answer-only strings.

## Manifest contract

A runtime may advertise the capability only when all of the following are
present and verified:

```json
{
  "capabilities": {"teacher_guide": true},
  "teacher_guide_capabilities": {
    "available": true,
    "schema_version": "1.0.0",
    "validation_status": "PASS",
    "source_bound": true
  },
  "teacher_guide_validation": {
    "status": "PASS",
    "scope": "COURSE",
    "content_fingerprint": "sha256:...",
    "canonical_content_fingerprint": "...64 hex characters...",
    "seal_path": "runtime/teacher_guide_validation_seal.json",
    "seal_sha256": "...64 hex characters...",
    "source_bound": true
  },
  "row_counts": {
    "canonical_entities": 0,
    "teacher_guides": 0,
    "teacher_guide_sections": 0,
    "teacher_guide_units": 0,
    "teacher_guide_items": 0,
    "teacher_guide_item_relations": 0
  }
}
```

The example counts are placeholders for the shape only; a capable package
must publish the exact SQLite counts. A missing or false capability is a
normal state for old runtimes. In that state the repository returns an
unavailable capability, empty collections, or `null` and never attempts a
best-effort relationship lookup.

The compiler and verifier use one capability truth. `capabilities.teacher_guide`
must agree with `teacher_guide_capabilities.available`, validation status,
canonical row counts, non-empty core tables, explicit relation foreign keys,
the canonical content fingerprint, and the validation seal. Any mismatch is a
fail-closed package error. A `false` capability does not require the additive
tables in an older runtime.

The seal also carries `teacher_guide_content_fingerprint`; it must equal the
unprefixed digest in `teacher_guide_validation.content_fingerprint`. The
runtime-level `canonical_content_fingerprint` is also stored as a raw
64-character SHA-256 hexadecimal value. The seal file digest in `seal_sha256`
is raw as well.

## Canonical projection contract

The TYMM compiler discovers teacher-guide manifests under any course root by
their validated document type (`TYMM_TEACHER_GUIDE_MANIFEST`). It does not
assume a course ID, subject, grade, theme name, section path, section type or
item type. A manifest may describe a course/scope guide and may reference
sections in any validated relative layout.

The compiler projects canonical guide, section, unit, item and relation rows.
JSON-valued fields are serialized with deterministic canonical JSON; `null`,
strings, arrays and objects remain distinguishable. Supported explicit targets
include scope/theme, block, outcome, activity, textbook section, form,
assessment and lesson-plan package. Unknown future canonical target types are
carried as strings after their entity is present in `canonical_entities`.

Relations are never created through title similarity. A missing target is a
projection error. Runtime validation checks SQLite foreign keys, deterministic
ordering, content hashes, row counts and the seal before sync accepts the
package.

## Current canonical source status

The accessible `knigdelioglu/tymm` checkout currently validates and projects
the TDE_11 Theme 1–4 manifests with `PASS_WITH_WARNINGS`. The resulting
runtime is synced into `tymm-verileri` only after database, manifest, row-count,
relation, fingerprint and seal verification. The warnings concern canonical
source material that is explicitly marked for teacher review; they are not
silently converted into official answers.

Teacher Guide remains optional. TDE_11's separate assessment/form parity
limitations do not advertise those capabilities, and do not invalidate a
teacher-guide capability whose own contract passes.

## Teacher-local notes boundary

The canonical guide database is read-only. Assignment-scoped notes live only
in `teacher_state.sqlite` under `assignment_teacher_guide_notes` and are keyed
by `assignment_id + guide_item_id`. Each note stores the canonical item payload
SHA-256. A changed hash produces a visible stale notice; missing canonical
items do not delete local notes.
