# PRODUCT_SCOPE.md — TYMM Teacher OS V1

**Product:** TYMM Teacher OS  
**Document version:** 1.1.0  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**V1 Distribution Target:** Android  
**Initial Course Package:** `TDE_9`  
**Operation Mode:** Offline-first, deterministic, local  
**LLM Dependency:** None  
**Backend Dependency:** None

---

## 1. Purpose and authority

This document defines what TYMM Teacher OS V1 is allowed and required to be.

Authority order:

```text
1. PRODUCT_SCOPE.md
2. FLUTTER_BLUEPRINT.md
3. AGENT.md
```

If a lower authority conflicts with this document, this document wins and the lower document must be aligned before implementation proceeds.

---

## 2. Product definition

TYMM Teacher OS V1 is an offline teacher workflow application that combines:

```text
verified TYMM course runtime
+
versioned academic calendar
+
versioned course scheduling profile
```

and presents the result as an operational weekly teaching plan.

The application must answer, without daily manual maintenance:

```text
Bu eğitim öğretim yılının kaçıncı okul haftasındayım?
Bu hafta TDE 9 için hangi tema/bloklar planlanıyor?
Bu hafta kaç ders saati var?
Bu haftaki program çıktıları/kazanımları neler?
Ders kitabında nereye bakacağım?
Hangi etkinlik ve değerlendirme araçları ilgili?
Ek materyale ihtiyaç var mı?
Sonraki hafta ne geliyor?
```

The application remains a consumer of verified course knowledge. It must not become a second curriculum interpretation engine.

---

## 3. Authoritative data inputs

### 3.1 Course knowledge authority

Course facts continue to come from the verified TYMM runtime package:

```text
Canonical TYMM Knowledge
        ↓
Deterministic Runtime Compiler
        ↓
course_runtime.sqlite + runtime_manifest.json
        ↓
Flutter Application
```

The runtime database is read-only, derived, rebuildable and source-traceable.

### 3.2 Academic calendar authority

Academic-year dates must come from a versioned calendar package consumed by the calendar service.

Dart source code must not hardcode annual dates such as:

```text
term start/end
mid-term breaks
semester break
school closing date
event week
orientation dates
```

A new academic year is introduced by adding/updating calendar data and switching the active academic-year entry in the calendar index. UI and planning code must consume the service output without yearly source-code edits.

### 3.3 Course scheduling profile

Weekly lesson hours and annual scheduling rules are versioned planning data, not widget constants.

For `TDE_9` in the 2026-2027 planning profile:

```text
weekly lesson hours = 5
annual course hours = 180
number of themes = 4
hours per theme = 45
structured programme hours per theme = 43
school-based planning hours per theme = 2
instructional course weeks = 36
final active school week = EVENT_WEEK
```

Therefore:

```text
4 × 45 = 180 hours
36 × 5 = 180 hours
```

The final active school week is an event week and must not receive newly invented curriculum outcomes.

---

## 4. Core capabilities

### Capability A — Ders Yürütme Merkezi

A selected block can present verified runtime data including:

```text
theme
block
block order
outcomes
process components
textbook sections/pages
activities
forms
assessment artifacts
resource decisions
source references
previous/next block
```

The UI must not invent missing curriculum relationships.

### Capability B — Takvim Tabanlı Haftalık Plan

The application must provide a week-oriented teacher view.

The teacher must be able to select an academic school week such as:

```text
3. Hafta
28 Eylül - 2 Ekim 2026
```

and see:

```text
week type
planned TDE lesson hours
active theme(s)
active block(s)
hours assigned to each segment
school-based planning segment, when applicable
outcomes/kazanımlar belonging to the active block segments
```

The service must also be able to resolve the current academic week from a date.

Break weeks must not consume course hours.

The final active school week marked `EVENT_WEEK` must not consume the 180-hour TDE course budget and must not fabricate new block/outcome assignments.

### Capability C — Akademik Takvime Bağlı Yıllık Plan

The annual plan is no longer only an abstract 1..N block sequence. It must be able to expose the sequence through academic weeks.

Required relation:

```text
academic calendar
→ active school weeks
→ weekly course-hour budget
→ theme-hour budget
→ block planning allocation
→ weekly block segments
→ outcomes from verified runtime
```

The annual plan represents a planned teaching schedule, not student mastery.

### Capability D — Kitap-Önce / Materyal Gerekliliği

Resource sufficiency and material-need decisions continue to come only from the verified runtime contract.

The application may translate machine codes into teacher-facing language but may not independently decide that a resource is sufficient or required.

### Capability E — Otomatik Öğretmen Paketi

The app may aggregate a selected theme's verified blocks, outcomes, textbook sections, activities, forms, assessment artifacts, resource decisions and source references into an on-screen teacher package.

---

## 5. Block-hour planning policy

The source TYMM package currently verifies theme-level hours but does not define official sub-hours for each pedagogical block.

Therefore the application must distinguish:

```text
OFFICIAL COURSE FACT
vs
DERIVED PLANNING ALLOCATION
```

For TDE 9:

```text
43 structured hours per theme = official programme fact
2 school-based planning hours per theme = official annual/theme planning budget used by this product profile
individual block-hour allocation = derived planning policy
```

A derived block allocation is permitted because weekly scheduling requires a deterministic mapping, but it must satisfy all of the following:

1. it is stored in versioned planning/calendar data, not hardcoded in widgets;
2. it preserves block order from the runtime;
3. its total structured hours per theme equals 43;
4. school-based planning remains a separate 2-hour segment;
5. it is presented as a planning allocation, not as an official block duration;
6. changing the policy requires a data/version update, not silent UI inference.

The initial deterministic profile uses the ordered four-block allocation:

```text
12 + 11 + 10 + 10 = 43 structured hours
+ 2 school-based planning hours
= 45 hours per theme
```

This distribution is a product planning policy, not an assertion that the official curriculum specifies those individual block durations.

---

## 6. 2026-2027 academic calendar contract

The bundled 2026-2027 calendar must represent at minimum:

```text
Orientation / guidance week: 7-11 September 2026
First term: 14 September 2026 - 22 January 2027
First mid-term break: 16-20 November 2026
Semester break: 25 January - 5 February 2027
Second term: 8 February - 25 June 2027
Second mid-term break: 8-12 March 2027
Final active school week: 21-25 June 2027 = EVENT_WEEK
```

For TDE 9 the first 36 active teaching weeks consume the full 180-hour course plan. The 37th active school week is reserved as event week.

Orientation/guidance activity before the first-term start is stored as calendar metadata and is not counted as one of the 36 TDE instructional weeks.

---

## 7. Current-week semantics

When calendar data and a matching course scheduling profile exist, the app may truthfully use labels such as:

```text
Bu Haftanın Planı
3. Hafta
Bu haftaki kazanımlar
```

provided those labels are resolved by the calendar service.

The app must not claim that planned schedule equals actual classroom progress.

An optional manual teacher position override may remain available for real-world schedule drift, but it is an override of the planned position, not the primary source of the annual plan.

---

## 8. Zero-input behavior

Without daily teacher data entry, the user must be able to:

```text
view the active academic year
view/select school weeks
view the weekly TDE plan
view weekly outcomes/kazanımlar
view the annual sequence
browse themes and blocks
inspect block details
inspect textbook/activity references
inspect forms and assessment artifacts
inspect resource decisions
view teacher packages
```

---

## 9. Allowed mutable user state

Allowed local state includes:

```text
manual_position_override
basic UI preferences
```

Course knowledge, academic calendar facts and scheduling profiles are versioned application data and must not be edited as user state.

---

## 10. Explicitly out of scope

Still out of V1 scope:

```text
student roster / attendance / grades
student mastery tracking
teacher diary / notes / task manager
LLM / RAG / AI generation
cloud account / backend / sync
MEBBİS or e-Okul integration
Google Calendar integration
school timetable synchronization
PDF/OCR ingestion
runtime DB editing
PDF/DOCX export
```

A local academic calendar service is in scope; a general-purpose personal calendar manager is not.

---

## 11. No hardcoded curriculum or yearly-calendar rule

Dart source must not hardcode:

```text
outcomes
theme contents
activities
textbook mappings
assessment mappings
resource decisions
curriculum hour totals
yearly term dates
yearly break dates
yearly event-week dates
```

Course knowledge comes from the runtime package. Annual dates and scheduling parameters come from versioned calendar/planning data.

---

## 12. No pedagogical invention

Unknown course facts remain unknown.

The application may execute an explicitly versioned scheduling policy, but it must not convert that policy into an official curriculum claim.

Correct:

```text
Planlama dağıtımı: bu blok için 12 saat
```

Incorrect:

```text
Programda bu blok 12 saattir
```

when the source programme does not specify that fact.

---

## 13. Offline requirement

All V1 core capabilities, including weekly planning, must work offline after installation.

Calendar packages and scheduling profiles required for the active academic year are bundled/versioned application assets.

No network availability, login or API call may be required to display the weekly plan.

---

## 14. Calendar update protocol

For each new academic year:

```text
1. add the new versioned academic calendar data;
2. add or update the course scheduling profile if weekly hours/rules changed;
3. mark the active academic year in calendar_index.json;
4. validate term and break ranges;
5. validate active-school-week count;
6. validate course-hour conservation;
7. run weekly-planning tests;
8. release the application update.
```

Application feature code must not require yearly date edits.

---

## 15. Required invariants for TDE_9 2026-2027

The application must reject or surface an error if any of these fail:

```text
weekly_hours = 5
theme_count = 4
theme_hours = 45
structured_theme_hours = 43
school_based_theme_hours = 2
annual_hours = 180
instructional_week_count = 36
instructional_week_count × weekly_hours = annual_hours
sum(theme_hours) = annual_hours
sum(block planning allocations per theme) = structured_theme_hours
37th active school week = EVENT_WEEK
EVENT_WEEK new curriculum hours = 0
```

---

## 16. UX principles

Primary teacher-facing navigation must make week access cheap.

A teacher should be able to reach a requested week such as “3. hafta” without calculating dates or block positions manually.

Weekly plan UI should prioritize:

```text
week number and date range
week type
planned lesson hours
active block(s)
block-hour segments
weekly outcomes/kazanımlar
school-based planning indicator
```

Avoid presenting planning position as student success or completion percentage.

---

## 17. Unresolved and invalid states

The product supports:

```text
Loading
Content
Empty
Error
Unresolved
```

If the active academic year has no valid calendar profile, weekly planning must fail visibly rather than fall back to fabricated dates.

If course scheduling hours do not conserve to the annual total, the service must reject the profile.

---

## 18. Definition of V1 success

V1 is successful when a teacher can:

1. open the Android application offline;
2. see the active academic year;
3. open a numbered school week, including week 3;
4. see that week's TDE 9 block allocation and lesson hours;
5. see outcomes/kazanımlar belonging to those planned blocks;
6. distinguish structured instruction from school-based planning;
7. see event week without fabricated curriculum content;
8. inspect block, textbook, activity, assessment and resource details;
9. use the app without daily logging, account, backend or AI.

---

## 19. Scope change protocol

Future product changes follow this order:

```text
1. revise PRODUCT_SCOPE.md;
2. align FLUTTER_BLUEPRINT.md;
3. update versioned runtime/calendar/planning contracts;
4. implement;
5. validate with tests and CI.
```

Implementation must not silently precede a required scope revision.

---

## 20. Final product boundary

TYMM Teacher OS V1 is a small, offline, deterministic teacher application that combines verified TDE 9 course knowledge with a versioned academic calendar and course scheduling profile to produce a truthful week-by-week teaching plan, including weekly outcomes, textbook/resource guidance and a distinct school-based planning budget, without requiring daily teacher maintenance.