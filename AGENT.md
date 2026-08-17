# AGENT.md — ÖğretmenOS Agent Execution Protocol

> **Project:** ÖğretmenOS  
> **Implementation:** Flutter + Dart + Material 3  
> **Document version:** 1.2.0  
> **Status:** Binding execution protocol

## 0. Authority

Read before code changes:

1. `docs/PRODUCT_SCOPE.md`
2. `docs/FLUTTER_BLUEPRINT.md`
3. `AGENT.md`

Higher authority wins. Do not implement through an unresolved document conflict.

## 1. Mission

Build an offline-first teacher workflow whose primary surface is weekly **kazanım tracking**, backed by verified TYMM course knowledge, versioned academic calendar data and separate local teacher tracking state.

## 2. Hard invariants

- Canonical TYMM knowledge is immutable from this app repo.
- `course_runtime.sqlite` is read-only.
- Outcomes, themes, blocks, activities, textbook mappings, assessments and resource decisions are never hardcoded in Dart.
- The app does not invent pedagogical relationships or official text.
- Derived block-hour allocation is scheduling policy, never presented as official block duration.
- Planned progression is not student mastery.
- Calendar dates and yearly scheduling rules come from versioned assets.
- Teacher tracking state is stored separately from runtime knowledge.
- Runtime/calendar refresh must not erase teacher tracking state.
- V1 core remains offline; no backend/account/telemetry/AI dependency.
- Keep architecture lean; do not add speculative layers or frameworks.

## 3. Data boundaries

```text
course_runtime.sqlite
  READ ONLY
  authoritative runtime projection

assets/calendars/*.json
  READ ONLY
  academic calendar and scheduling profile

teacher_state.sqlite
  READ/WRITE
  local teacher outcome tracking only
```

Allowed teacher-state writes:

```text
learning-outcome weekly status
actual hours (optional)
short teacher note
completion timestamp
carry-to-week pointer
UI preferences/manual position override
```

A short note attached to an outcome tracking row is allowed. A general notes/task-manager feature is not.

## 4. Outcome-first capability gate

Allowed V1.2 product capabilities:

```text
A  Kazanım Takibi
B  Kazanım Detail / Ders Yürütme
C  Ders Defteri Desteği
D  Takvim Tabanlı Haftalık Plan
E  Yıllık Plan
F  Kitap-Önce / Materyal
G  Öğretmen Paketi
```

Still out of scope unless scope is explicitly revised:

```text
student roster/attendance/grades
student mastery analytics
cloud sync/accounts
MEBBİS/e-Okul
LLM/RAG/AI generation
OCR/PDF ingestion
personal calendar manager
curriculum editor
general notes/task manager
```

## 5. Runtime truth rules

Before modifying runtime SQL/query behavior, inspect current runtime schema/manifest. If a requested exact relationship is unavailable, surface it as block-level context or report a runtime-contract gap. Never reconstruct missing canonical logic in widgets.

Outcome detail may aggregate containing-block data, but labels must say that it is block context unless an explicit runtime relation targets the outcome.

## 6. Tracking semantics

Canonical plan and classroom execution are distinct:

```text
planned schedule != teacher execution state
```

Tracking status values:

```text
planned
in_progress
completed
partially_completed
carried_over
```

A missing local row means `planned`.

Carry-over:

- keeps original planned week identity;
- does not modify `AnnualWeeklyPlan`;
- may project into a later instructional week;
- cannot target event week;
- updates the original tracking row rather than creating curriculum data.

## 7. Flutter architecture

Default flow:

```text
Widgets
  ↓
OutcomePlanningService / existing lean feature state
  ↓
CourseKnowledgeRepository + WeeklyPlanningService + OutcomeTrackingRepository
  ↓
read-only runtime / calendar assets / writable teacher-state DB
```

Rules:

- widgets do not execute raw SQL;
- runtime writes are forbidden;
- teacher-state SQL stays in tracking data layer;
- no new state-management package unless demonstrated necessary;
- no ORM/codegen merely for convenience;
- use existing Material 3 shared components and responsive conventions.

## 8. Calendar invariants

For active TDE_9 2026-2027 profile:

```text
weekly_hours = 5
annual_hours = 180
theme_count = 4
theme_hours = 45
structured_theme_hours = 43
school_based_theme_hours = 2
instructional_weeks = 36
active_week_37 = EVENT_WEEK
EVENT_WEEK new curriculum hours = 0
```

Do not duplicate these as widget facts; consume planning service output.

## 9. UX requirements

Primary navigation:

```text
Kazanımlar
Haftalık
Yıllık Plan
Paket
```

`Kazanımlar` is default.

Outcome cards must prioritize classroom-useful information: code, official text, status, week, theme/block context, carry-over and relevant source hints. Long content uses progressive disclosure.

`Deftere Bakış` uses verified strings and may copy them to clipboard; it must not generate an invented official lesson-log sentence.

Support phone/tablet, large text and dark mode.

## 10. Git safety

- Preserve unrelated user work.
- Do not reset/revert unrelated changes.
- Branch feature work from current `main` unless user requests direct main edits.
- Push/PR/merge only when requested or when the user explicitly asked the feature to be applied in the repository; default PR remains draft until validation succeeds.

## 11. Testing

Do not run tests between grouped implementation sprints when the user explicitly asks for a single final validation batch.

Final validation target:

```text
flutter analyze
runtime contract
flutter test
flutter build apk --release
```

Tests must prove tracking persistence, carry semantics, event-week restriction, outcome projection and existing runtime/weekly regressions.

## 12. Error states

Do not fabricate content to avoid emptiness. Support Loading, Content, Empty, Error, Unresolved and Event Week states. Stale tracking rows whose outcome no longer exists must not create fake outcomes.

## 13. Final pre-merge gate

Before merging to main verify:

- authoritative docs aligned;
- runtime DB remains read-only;
- teacher-state DB is separate;
- all tracking mutations preserve planned schedule;
- no invented outcome relationships;
- full CI batch green.
