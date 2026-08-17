# PRODUCT_SCOPE.md — ÖğretmenOS V1.2

**Product:** ÖğretmenOS  
**Document version:** 1.2.0  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**V1 Distribution Target:** Android  
**Initial Course Package:** `TDE_9`  
**Operation Mode:** Offline-first, deterministic, local

---

## 1. Product definition

ÖğretmenOS, öğretmenin derse girerken haftalık kazanımlarını görüp ders defterini güvenilir program verisine bakarak doldurabildiği **kazanım takip ve ders yürütme uygulamasıdır**.

Ürün ön yüzde kazanım odaklıdır. Arka planda ise:

```text
verified TYMM course runtime
+
versioned academic calendar
+
versioned course scheduling profile
+
local teacher tracking state
```

birleştirilir.

Uygulama şu soruları en fazla birkaç dokunuşta cevaplamalıdır:

```text
Bu hafta hangi kazanımlar planlı?
Hangi tema/blok içindeyim?
Bu hafta kaç ders saati var?
Hangi kazanımları işledim, hangileri kısmen kaldı veya sarktı?
Ders defterine bakarken hangi resmî kazanım metnini kullanacağım?
Bu kazanımın bulunduğu blokta hangi kitap, etkinlik, materyal ve değerlendirme verileri var?
```

---

## 2. Authority and immutable knowledge

Authority order:

```text
1. PRODUCT_SCOPE.md
2. FLUTTER_BLUEPRINT.md
3. AGENT.md
```

Course knowledge remains authoritative only in the verified runtime package:

```text
Canonical TYMM Knowledge
→ deterministic runtime compiler
→ course_runtime.sqlite
→ read-only CourseKnowledgeRepository
```

The app must never edit runtime outcomes, themes, blocks, textbook relationships, activities, assessment mappings or resource decisions.

---

## 3. Calendar and scheduling authority

Academic-year dates and scheduling parameters remain versioned data assets. Dart UI code must not hardcode yearly dates or curriculum facts.

For `TDE_9` 2026-2027:

```text
weekly lesson hours = 5
annual course hours = 180
4 themes × 45 hours
43 structured + 2 school-based hours per theme
36 instructional weeks consume 180 hours
37th active week = EVENT_WEEK
```

The current deterministic block planning allocation remains:

```text
12 + 11 + 10 + 10 = 43 structured hours
```

This is a product scheduling policy, not an official block-duration claim.

---

## 4. Core capability A — Kazanım Takibi

**Kazanımlar is the default application surface.** The app must look and behave primarily like a weekly learning-outcome tracker rather than a runtime browser.

For the selected academic week the teacher can see card-based outcomes with:

```text
outcome code
official outcome text
week/date context
theme and block context
planned lesson context
tracking status
carry-over indicator
teacher note indicator
available book/material context summary
```

Supported local tracking states:

```text
PLANNED
IN_PROGRESS
COMPLETED
PARTIALLY_COMPLETED
CARRIED_OVER
```

Absence of a local tracking row means `PLANNED`.

Planned progression is not student mastery. Tracking state means only the teacher's classroom execution state for that week.

---

## 5. Core capability B — Kazanım Detail / Ders Yürütme

Tapping an outcome opens a detail surface centred on the selected outcome.

The screen may expose only data that can be reached truthfully through the current runtime/planning contracts, including:

```text
official outcome text
process components
planned week and date range
theme
block
block-level textbook sections/page ranges
block-level activities
forms
assessment artifacts
targeted assessment task bindings when the runtime explicitly targets the outcome
resource decisions
source/block navigation
```

If a relationship is only known at block level, the UI must label it as **block context** and must not imply an outcome-specific relationship.

No pedagogical text or missing relationship may be invented.

---

## 6. Core capability C — Ders Defteri Desteği

The selected week provides a compact **Deftere Bakış** view containing only verified/derived planning facts:

```text
academic week/date range
theme(s)
block(s)
outcome codes
official outcome texts when expanded/copied
```

The app may provide copy-to-clipboard convenience. It must not fabricate a new official lesson-log sentence unless such text exists in authoritative data.

The primary goal is to replace the common workflow of carrying Excel-table screenshots on a phone.

---

## 7. Core capability D — Takvim Tabanlı Haftalık Plan

The existing weekly plan remains available as the scheduling view and must expose:

```text
week type
planned TDE hours
active block segments
segment hours
school-based planning segments
weekly outcomes
```

Break weeks do not consume course hours. `EVENT_WEEK` consumes zero new curriculum hours.

---

## 8. Core capability E — Annual plan, book/material and teacher package

Existing capabilities remain supported:

```text
Akademik Takvime Bağlı Yıllık Plan
Kitap-Önce / Materyal Gerekliliği
Otomatik Öğretmen Paketi
Block Detail
```

They are secondary/detail surfaces behind the outcome-first workflow.

---

## 9. Mutable teacher state

Teacher-local tracking is explicitly in scope and must remain physically/logically separate from `course_runtime.sqlite`.

Allowed local mutable state:

```text
manual_position_override
UI preferences
learning_outcome_tracking
```

A tracking record may store:

```text
academic_year
outcome_id
planned_week_number
status
actual_hours (optional)
teacher_note (optional)
completed_at (optional)
carried_to_week_number (optional)
updated_at
```

Tracking rows may be written to a dedicated local teacher-state database. Runtime DB remains read-only.

Runtime/calendar asset updates must not erase teacher tracking state.

---

## 10. Carry-over semantics

The canonical plan never moves when classroom execution drifts.

The application shows two separate truths:

```text
PLANLANAN
vs
GERÇEKLEŞEN / TAKİP DURUMU
```

When an outcome is carried forward:

- its original planned week remains known;
- the source week shows `CARRIED_OVER`;
- the target instructional week may additionally show it as `Geçen haftadan`;
- event week is not a valid carry target;
- carry-over does not rewrite the annual planning service.

---

## 11. Navigation and UX identity

Top-level navigation is outcome-first:

```text
Kazanımlar
Haftalık
Yıllık Plan
Paket
```

`Kazanımlar` opens by default.

The teacher should be able to answer **“Bu hafta ne işleyeceğim?”** immediately after launch.

Outcome cards should use clear visual state chips, concise context, large touch targets and progressive disclosure. Technical runtime codes that do not help classroom use should not dominate the card.

Phone and tablet layouts, large text and dark mode must remain usable.

---

## 12. Offline and privacy boundary

All core capability remains offline after installation.

Still out of scope:

```text
student roster / attendance / grades
student mastery tracking
cloud account / backend / sync
MEBBİS or e-Okul integration
Google Calendar integration
school timetable synchronization
LLM / RAG / AI generation
OCR/PDF ingestion
curriculum editing
```

A teacher note attached to a weekly outcome tracking record is in scope; a general-purpose notes/task-manager product is not.

---

## 13. Required invariants

The product must preserve:

```text
runtime DB is read-only
tracking DB/state is separate
weekly_hours = 5 for the active TDE_9 profile
36 × 5 = 180
4 × 45 = 180
43 + 2 = 45 per theme
37th active week = EVENT_WEEK
EVENT_WEEK new curriculum assignment = 0
tracking never changes canonical outcome text or planned schedule
outcome detail never invents unavailable relationships
```

---

## 14. Definition of success

V1.2 is successful when a teacher can:

1. open the app directly into `Kazanımlar`;
2. see the current/selected week's outcome cards;
3. understand theme/block/date context without opening an Excel image;
4. mark an outcome in progress, completed, partial or carried over;
5. add a short local teacher note;
6. reopen the app and retain tracking state;
7. open an outcome and reach the verified block/book/activity/assessment/resource data currently available;
8. use `Deftere Bakış` while filling the class record;
9. distinguish planned schedule from actual classroom tracking;
10. use all of the above offline without modifying canonical course knowledge.

---

## 15. Change protocol

Future product changes follow:

```text
scope → blueprint → implementation → tests/CI
```

New academic years remain data updates through versioned calendar/profile assets.