# AGENT.md — TYMM Teacher OS Agent Execution Protocol

> **Target Agents:** OpenAI Codex, Antigravity, Claude Code, Cursor, Windsurf  
> **Project:** TYMM Teacher OS  
> **Implementation:** Flutter + Dart + Material 3  
> **V1 Distribution Target:** Android  
> **Initial Course Package:** `TDE_9`  
> **Document Version:** 1.1.0  
> **Status:** Binding execution protocol

---

## 0. Document Authority

This file is an **agent execution protocol**. It does not replace the product scope or application blueprint.

Before changing code, read the project documents in this order:

1. `docs/PRODUCT_SCOPE.md` — **product scope authority**
2. `docs/FLUTTER_BLUEPRINT.md` — **application/data architecture authority**
3. `AGENT.md` — **execution and safety protocol**

Rules:

- `AGENT.md` must not silently redefine product scope or architecture.
- If these documents conflict, **STOP** and report `DOCUMENT_CONFLICT`.
- Do not choose the interpretation that is easiest to implement.
- Do not resolve a scope/architecture conflict by editing the authoritative document unless the user explicitly asked for that change.
- If `PRODUCT_SCOPE.md` still describes a non-Flutter implementation while `FLUTTER_BLUEPRINT.md` requires Flutter, treat that as `DOCUMENT_CONFLICT` before coding.
- For database structure, `runtime_schema.sql` and `runtime_manifest.json` are the runtime schema authorities. Do not rely on table lists copied into this file.

---

## 1. Mission

Implement a lightweight, deterministic, offline-first teacher workflow application over the verified TYMM course knowledge package.

The operational chain is:

```text
Canonical TYMM Knowledge
        ↓
Deterministic Runtime Compiler
        ↓
course_runtime.sqlite
        ↓
Flutter Runtime Asset / Local Read-Only Copy
        ↓
Flutter Application
```

The application must remain useful without daily teacher data entry.

The app **reads verified knowledge; it does not reinterpret the curriculum.**

---

## 2. Hard Invariants

Every coding task must preserve all rules below.

| ID | Rule | Binding Requirement |
|---|---|---|
| **R-01** | Canonical knowledge is immutable from the app repo | Never modify or overwrite canonical knowledge under the TYMM knowledge repository as part of Flutter feature work. |
| **R-02** | No hardcoded curriculum | Never hardcode outcomes, activities, textbook pages, theme hours, assessment mappings, gap mappings, or pedagogical relationships in Dart. Read them from `course_runtime.sqlite`. |
| **R-03** | Runtime DB is read-only | Never execute `INSERT`, `UPDATE`, `DELETE`, `ALTER`, `DROP`, or app-side runtime DB migrations. |
| **R-04** | No pedagogical invention | UI, state, repository, and data layers must not invent relationships, resource necessity, block durations, assessment semantics, or missing official values. |
| **R-05** | Planned progression is not mastery | Never present planned sequence as student learning, mastery, achievement, or success rate. |
| **R-06** | No fake date resolution | Do not derive a factual “today you should be on block X” position until verified calendar binding exists. |
| **R-07** | No AI/cloud dependency | V1 has no LLM, prompt runtime, RAG runtime, vector DB, Firebase, backend, account, internet dependency, telemetry, or cloud synchronization. |
| **R-08** | Strict product scope | No student roster, attendance, gradebook, teacher diary, notes system, e-Okul/MEBBİS integration, OCR, PDF/DOCX generation, curriculum editor, or unrelated teacher-management features. |
| **R-09** | Lean Flutter architecture | Do not create speculative abstractions, empty use-case layers, DTO forests, generic base repositories, plugin frameworks, or premature multi-package architecture. |
| **R-10** | Runtime freshness | Do not silently package a stale runtime DB. Build/sync tooling must require a compatible, validated runtime package. |
| **R-11** | User state is separate | Never store teacher/user state inside `course_runtime.sqlite`. |
| **R-12** | No opportunistic features | “Easy to add” is not a reason to add a feature. If it is outside A/B1/C/D/E or required infrastructure, stop and report it. |

---

## 3. Repository Boundary

Current development model:

```text
Knowledge repository
/Users/kadir/Desktop/tymm

    canonical knowledge
    runtime compiler
    runtime validation
    course_runtime.sqlite
             │
             │ deterministic sync
             ▼
Flutter repository
/Users/kadir/Desktop/tymm_teacher

    Flutter source
    runtime asset copy
    local preferences
    tests
```

The absolute paths above describe the current local workspace. Do not hardcode them into production Dart code.

### Runtime source

Expected knowledge-side runtime artifacts:

```text
courses/TDE_9/runtime/course_runtime.sqlite
courses/TDE_9/runtime/runtime_manifest.json
courses/TDE_9/runtime/runtime_schema.sql
courses/TDE_9/runtime/runtime_validation_report.md
```

### Runtime schema authority

Before writing or modifying SQL:

1. inspect `runtime_schema.sql`,
2. inspect `runtime_manifest.json`,
3. use the actual current schema,
4. do not infer tables/columns from this `AGENT.md`,
5. do not create Flutter-side schema migrations.

If the runtime schema does not support a requested query, report `RUNTIME_CONTRACT_GAP` instead of inventing columns or reconstructing canonical logic in Dart.

---

## 4. Runtime Database Lifecycle

The packaged database is a derived, rebuildable artifact.

Expected Flutter flow:

```text
1. Read bundled runtime_manifest.json
2. Verify supported course_id/schema_version/package metadata
3. Check local runtime copy
4. If missing or bundled runtime changed, copy bundled SQLite asset to app-local storage
5. Open SQLite read-only
6. Run lightweight integrity/compatibility checks
7. Expose data only through the repository/data-source boundary
```

The exact implementation belongs to `FLUTTER_BLUEPRINT.md`.

### Write protection

The course database API must expose read operations only.

Do not add:

```text
saveCourse(...)
updateOutcome(...)
markBlockCompleteInRuntimeDb(...)
insertTeacherNote(...)
```

Teacher-local state belongs in a separate preference/local-state store.

---

## 5. V1 Capability Gate

Every product feature must belong to one of these capabilities:

```text
A  Ders Yürütme Merkezi
B1 Current / Selected Block Brief
C  Yaşayan Yıllık Plan
D  Kitap-Önce / Materyal Gerekliliği
E  Otomatik Öğretmen Paketi
```

`B2` date-based “Bugünkü Ders” is **deferred** until verified calendar binding exists.

Infrastructure tasks are allowed only when directly required to deliver or validate one of the capabilities.

If a requested feature belongs to none of these:

```text
OUT_OF_SCOPE
```

Stop implementation and report it.

---

## 6. Capability Semantics

This section defines only the execution-critical boundaries. Detailed UX/product behavior belongs to `FLUTTER_BLUEPRINT.md`.

### A — Ders Yürütme Merkezi

May present verified block-level data such as:

```text
theme
block
outcomes
process components
textbook sections/pages
activities
forms
assessment mappings
resource decisions
source references
previous/next block
```

All curriculum/pedagogical data comes from runtime queries.

### B1 — Current / Selected Block Brief

Until calendar binding exists, there is no automatically factual date-based “current block”.

Resolution rule:

```text
manual_position_override exists
    → use that as the teacher-selected position

otherwise
    → no factual current block exists
```

Without a manual override, the UI may:

- show a user-selected block,
- show the annual sequence,
- default navigation to the first sequence entry,

but it must not label a fallback as:

```text
Bugünkü Ders
Şu anda burada olmalısınız
Bugün işlemeniz gereken
```

Use neutral labels such as:

```text
Seçili Plan Konumu
Plan Sırası
Blok Özeti
```

`B2` becomes valid only after verified calendar data is compiled into the supported runtime contract.

### C — Yaşayan Yıllık Plan

The annual plan represents **ordered planned sequence**, not learning achievement.

Allowed example:

```text
Plan sırası: 7 / 16
```

Do **not** convert ordinal block position into a percentage such as:

```text
7 / 16 = %43.7
```

because unresolved block durations mean that ordinal position is not equivalent to elapsed instructional time.

Do not use:

```text
Öğrenildi
Kazanıldı
Mastery
Başarı oranı
```

### D — Kitap-Önce

The application displays the deterministic runtime resource decision.

UI may translate machine codes into approved teacher-facing wording.

UI must not decide independently whether material is sufficient or missing.

If a required app-facing mapping is absent or ambiguous, report a runtime/data-contract gap instead of adding pedagogical inference.

### E — Otomatik Öğretmen Paketi

Input is a **single selected `theme_id`**.

The package may aggregate only the selected theme's verified:

```text
blocks
outcomes
activities
forms
assessment artifacts
resource decisions
source references
```

Do not aggregate unrelated themes into a single theme package.

---

## 7. Timeline and Unresolved Data Rules

Known timeline limitations must remain visible in the product logic.

Current planning model may know:

```text
theme order
block order
annual/theme-level time metadata
```

while still lacking:

```text
block hours
weekly lesson hours
academic calendar binding
date → block mapping
```

Rules:

- `null` / unresolved is a valid state.
- Never replace unresolved with `0`.
- Never derive official values from arithmetic convenience.
- Never infer block hours from theme totals.
- Never infer weekly lesson hours from annual total ÷ school weeks.
- Never create date-based position from sequence order alone.

Preferred UI wording:

```text
Programda doğrulanmış ayrı blok süresi bulunmuyor.
```

and:

```text
Tarih tabanlı plan konumu henüz doğrulanmış takvim verisiyle eşleştirilmedi.
```

---

## 8. Flutter Architecture Guardrails

Use the architecture defined in `FLUTTER_BLUEPRINT.md`.

Default shape:

```text
Flutter Widgets
      ↓
Lean Feature State / Controller
      ↓
Domain Model / Repository Contract
      ↓
CourseKnowledgeRepository
      ↓
SQLite Data Source
      ↓
course_runtime.sqlite
```

Local user preferences are separate.

### Architecture rules

- Widgets do not execute raw SQL.
- Raw SQL stays inside the data-source layer.
- Curriculum rules do not live in Widget code.
- State-management framework is not the domain model.
- Do not add a third-party state-management package unless current complexity justifies it.
- Do not add an ORM/code-generation database layer merely because it is available.
- Prefer the smallest implementation that preserves the boundaries.

---

## 9. Runtime Spike Is Temporary

A runtime integration spike may be created during Milestone 1.

Its purpose is only to verify:

```text
runtime asset exists
runtime copies successfully
SQLite opens read-only
manifest/schema are compatible
real TDE_9 rows can be queried
no curriculum values are hardcoded
```

Any `runtime_spike` screen/route is temporary development scaffolding.

Before V1 release it must either:

- be removed, or
- remain behind an explicit debug-only boundary.

It must not become a permanent user-facing product feature by accident.

---

## 10. Dependency Policy

Keep dependencies minimal.

Approved baseline dependency families:

```text
flutter
sqflite
path
path_provider
shared_preferences
```

Development baseline may include:

```text
flutter_test
flutter_lints
```

Rules:

- Dependency versions are governed by `pubspec.yaml`, `pubspec.lock`, and the project's current Flutter SDK compatibility.
- Do not treat versions written in documentation as package truth.
- Adding a new runtime dependency requires a concrete task-level justification.
- Do not add packages for hypothetical future use.
- Flutter's cross-platform capability does not expand V1 beyond the Android distribution target.

---

## 11. Git and Working-Tree Safety

This applies to Codex, Antigravity, and every coding agent.

Before editing:

```text
git status --short
```

Rules:

- Never run `git add` unless explicitly requested.
- Never create a commit unless explicitly requested.
- Never push unless explicitly requested.
- Preserve unrelated working-tree changes.
- Never discard, revert, reset, checkout-over, or overwrite pre-existing user changes unless explicitly asked.
- Do not reformat unrelated files.
- Do not mass-rename/move files outside the target task.
- If another process appears to be changing the same files, stop and report the conflict.
- Do not delete generated/user files merely because they are untracked.
- At task end, report the final `git status --short`.

---

## 12. Scope Change Protocol

If implementation reveals a useful idea outside the defined scope:

1. do not implement it,
2. label it `OUT_OF_SCOPE`,
3. state why it might be useful in one short note,
4. continue only with in-scope work,
5. wait for explicit user approval and authoritative scope-document revision before adding it.

Examples of forbidden opportunistic expansion:

```text
“We already use shared_preferences, so I added lesson history.”
“We already have SQLite, so I added teacher notes.”
“Flutter supports notifications, so I added reminders.”
“Flutter is cross-platform, so I added iOS/web support.”
```

---

## 13. Pre-Task Gate

Before writing code, report internally or visibly as appropriate:

```text
TARGET:
[A / B1 / C / D / E / INFRASTRUCTURE]

AUTHORITATIVE_DOCS_READ:
[PRODUCT_SCOPE / FLUTTER_BLUEPRINT / AGENT]

DOCUMENT_CONFLICT:
[NO / YES]

RUNTIME_SCHEMA_INSPECTED:
[YES / NOT_REQUIRED]

DATA_SOURCE:
[runtime query / manifest / preferences / none]

CANONICAL_WRITE_REQUIRED:
NO

DB_WRITE_REQUIRED:
NO

OUT_OF_SCOPE_RISK:
[NONE / description]
```

If `DOCUMENT_CONFLICT: YES`, stop.

If the task requires canonical knowledge edits, database writes, or product-scope expansion, stop unless the user's request explicitly changes that authority boundary.

---

## 14. Testing Expectations

Use the smallest test set that proves the changed behavior.

Relevant categories:

```text
unit
repository/data-source
runtime contract
widget
integration
```

Important:

- Use real runtime fixtures where the query contract itself is under test.
- Do not duplicate the entire TDE_9 dataset as hardcoded test constants.
- Small expected invariants such as known fixture counts may be asserted where appropriate.
- Tests must not mutate canonical knowledge.
- Tests must not write to the runtime DB.

For the integration milestone, expected verified facts include the runtime package's actual current manifest/validation values, not stale numbers copied from this file.

---

## 15. Error, Empty, and Unresolved States

Never fabricate data to avoid an empty UI.

Required conceptual states:

```text
Loading
Content
Empty
Error
Unresolved
```

Examples:

### Block duration unresolved

Use:

```text
Programda doğrulanmış ayrı blok süresi bulunmuyor.
```

Do not use:

```text
0 saat
Tahmini 5 saat
```

### Calendar position unresolved

Use:

```text
Tarih tabanlı plan konumu henüz doğrulanmış takvim verisiyle eşleştirilmedi.
```

Do not manufacture a current date-to-block answer.

### Database/package failure

Fail cleanly with a user-friendly message.

Developer diagnostics should preserve the actual failure reason, such as:

```text
missing asset
manifest incompatibility
unsupported schema version
hash/fingerprint mismatch
database open failure
query contract failure
```

---

## 16. Product Data vs User Data

### Course knowledge

Read-only:

```text
course_runtime.sqlite
```

### Allowed V1 mutable user state

Only if already authorized by scope/blueprint:

```text
manual_position_override
basic UI preferences
```

Preferred lightweight persistence:

```text
shared_preferences
```

Do not add a second relational user database in V1 without explicit scope revision.

---

## 17. Source and Copyright Boundary

The Flutter app may surface verified metadata needed for teacher navigation:

```text
source title
activity/form name
printed page
PDF page
source locator
short structured metadata
```

Do not bundle or reconstruct:

```text
full textbook PDFs
long copyrighted textbook passages
full literary works
embedding/model payloads
```

unless the product scope is explicitly revised with a rights decision.

---

## 18. Milestone Discipline

Follow the roadmap in `FLUTTER_BLUEPRINT.md`.

The intended order is:

```text
1. Flutter runtime integration spike
2. Capability A
3. Capability C
4. Capability D
5. Capability E
6. Capability B1
7. Hardening / Android release build
8. B2 only after verified calendar binding exists
```

Do not skip ahead simply because a later feature is easy.

A milestone may be split into smaller tasks, but its scope must not broaden.

---

## 19. Post-Task Compliance Report

Every code-modifying task must end with:

```text
=================== TYMM AGENT COMPLIANCE REPORT ===================

TARGET                      : [A / B1 / C / D / E / INFRASTRUCTURE]
SCOPE_COMPLIANCE            : [PASS / FAIL]
DOCUMENT_CONFLICT           : [NO / YES]
RUNTIME_DB_USED             : [YES / NO / NOT_REQUIRED]
RUNTIME_SCHEMA_INSPECTED    : [YES / NO / NOT_REQUIRED]
HARD_CODED_CURRICULUM_DATA  : [NO / VIOLATION_DETECTED]
NEW_USER_DATA_REQUIRED      : [NO / YES]
LLM_DEPENDENCY              : [NO / VIOLATION_DETECTED]
BACKEND_DEPENDENCY          : [NO / VIOLATION_DETECTED]
CANONICAL_KNOWLEDGE_MUTATED : [NO / VIOLATION_DETECTED]
DB_WRITE_QUERIES_DETECTED   : [NONE / VIOLATION_DETECTED]
OUT_OF_SCOPE_FEATURES_ADDED : [NONE / LIST]
TESTS_RUN                   : [summary]
TEST_RESULT                 : [PASS / FAIL / NOT_RUN]
GIT_ADD                     : [NO / YES]
GIT_COMMIT                  : [NO / YES]
GIT_PUSH                    : [NO / YES]

====================================================================
```

Then include:

```text
git status --short
```

Do not claim `PASS` if a required validation was not actually run.

---

## 20. Stop Conditions

Stop implementation and report the issue if any of the following occurs:

```text
DOCUMENT_CONFLICT
OUT_OF_SCOPE
RUNTIME_CONTRACT_GAP
RUNTIME_STALE
UNSUPPORTED_SCHEMA_VERSION
CANONICAL_MUTATION_REQUIRED
DB_WRITE_REQUIRED
PEDAGOGICAL_INFERENCE_REQUIRED
UNVERIFIED_CALENDAR_DATA_REQUIRED
WORKING_TREE_CONFLICT
```

Do not “solve” a stop condition by guessing.

---

## 21. Final Operating Principle

The V1 application should remain:

```text
small
offline
deterministic
read-only with respect to course knowledge
source-traceable
low-maintenance
usable without daily teacher logging
```

The key engineering rule is:

> **When the verified runtime data is sufficient, present it clearly. When it is insufficient, expose the limitation. Do not invent the missing pedagogy, time, or curriculum fact.**
