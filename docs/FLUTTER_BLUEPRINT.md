# ÖğretmenOS — Flutter Blueprint V1.2

**Belge sürümü:** 1.2.0  
**Durum:** Bağlayıcı teknik blueprint  
**Teknoloji:** Flutter + Dart + Material 3  
**Çalışma modu:** Offline-first / yerel / deterministik

`PRODUCT_SCOPE.md` bu belgenin üst otoritesidir.

---

## 1. Architecture summary

ÖğretmenOS dört ayrı kaynağı birleştirir:

```text
course_runtime.sqlite (read-only course knowledge)
        ↓
CourseKnowledgeRepository

calendar/profile assets
        ↓
WeeklyPlanningService

teacher_state.sqlite (mutable local tracking)
        ↓
OutcomeTrackingRepository

CourseKnowledgeRepository + WeeklyPlanningService + OutcomeTrackingRepository
        ↓
OutcomePlanningService
        ↓
Outcome-first Flutter UI
```

Runtime course knowledge ile teacher tracking aynı veritabanına yazılmaz.

---

## 2. Runtime boundary

`course_runtime.sqlite` read-only kalır. Outcomes, themes, blocks, textbook sections, activities, forms, assessment artifacts, resource decisions ve source references bu kaynaktan gelir.

Widget katmanı curriculum ilişkisi üretmez. Bir ilişki yalnız block seviyesinde biliniyorsa outcome detail bunu block context olarak sunar.

---

## 3. Calendar / weekly planning

Mevcut versioned calendar flow korunur:

```text
calendar_index.json
→ active academic calendar JSON
→ AssetWeeklyPlanningService
→ AnnualWeeklyPlan
```

2026-2027 TDE_9 profile:

```text
5 hours/week
180 annual hours
4 × 45 theme hours
43 structured + 2 school-based per theme
36 instruction weeks
37th active week EVENT_WEEK
```

Derived block allocation `12,11,10,10` calendar/profile data authority altında kalır.

---

## 4. Teacher tracking database

Yeni mutable store:

```text
teacher_state.sqlite
```

İlk schema:

```text
outcome_tracking
  academic_year TEXT
  outcome_id TEXT
  planned_week_number INTEGER
  status TEXT
  actual_hours INTEGER NULL
  teacher_note TEXT NULL
  completed_at TEXT NULL
  carried_to_week_number INTEGER NULL
  updated_at TEXT
  PRIMARY KEY (academic_year, outcome_id, planned_week_number)
```

Bu DB uygulama-local veridir ve runtime asset refresh işleminden bağımsızdır.

Valid status values:

```text
planned
in_progress
completed
partially_completed
carried_over
```

Eksik row = `planned`.

---

## 5. OutcomePlanningService

Service input:

```text
WeeklyPlanningService
CourseKnowledgeRepository
OutcomeTrackingRepository
```

Service responsibilities:

1. annual weekly planı yükle;
2. week segmentlerindeki unique block detail'leri repository'den al;
3. weekly outcomes ile block context'i eşleştir;
4. local tracking records ile merge et;
5. carry-over kayıtlarını hedef instruction week'e ek görünüm olarak taşı;
6. weekly summary/count üret;
7. status, note ve carry mutationlarını tracking repository üzerinden kaydet.

The service never mutates `AnnualWeeklyPlan` authority or runtime objects.

---

## 6. Outcome domain types

```text
OutcomeTrackingStatus
LearningOutcomeTrackingRecord
OutcomeBlockContext
TrackedOutcome
WeeklyOutcomeSummary
AnnualOutcomePlan
```

`TrackedOutcome` bir projection'dır:

```text
verified Outcome
+
planned week
+
verified block context(s)
+
local teacher tracking state
```

`isCarriedIn` yalnız UI context bilgisidir; canonical planı değiştirmez.

---

## 7. Top-level navigation

```text
Kazanımlar
Haftalık
Yıllık Plan
Paket
```

Default index = `Kazanımlar`.

Existing Home dashboard top-level navigation'dan çıkarılır; reusable underlying feature pages remain available where needed.

---

## 8. Outcome Tracker screen

`OutcomeTrackerPage` loads `AnnualOutcomePlan` and defaults to calendar-resolved current week, otherwise first active week.

Required screen elements:

```text
academic year
week selector + previous/next controls
date range
planned lesson hours
summary metrics
filter chips
Deftere Bakış
outcome cards
```

Outcome card:

```text
code
official text
status chip
theme/block context
carry-over marker
book/page context if available
note indicator
quick Complete action
more-actions menu
```

Filters:

```text
all
open
completed
carried
```

Event week shows event status and no fabricated new outcomes.

---

## 9. Outcome Detail screen

`OutcomeDetailPage` receives a `TrackedOutcome` and current annual outcome plan.

Sections:

```text
Outcome / official text
Tracking controls
Teacher note
Deftere Bakış
Plan context
Block context navigation
Textbook sections/pages
Activities
Forms
Assessment artifacts
Explicitly targeted assessment task bindings
Resource decisions
```

Aggregations must deduplicate by stable runtime IDs.

Outcome-specific targeting is shown only if runtime data explicitly targets the outcome. Otherwise labels state that the data belongs to the containing block.

---

## 10. Carry-over behavior

Carry action stores:

```text
status = carried_over
carried_to_week_number = target
```

Target choices include only instructional weeks after the planned/source week. Event week cannot be selected.

Source week keeps the canonical planned card with carried status. Target week gets an additional `Geçen haftadan` card projection.

If the teacher later marks the carried item completed, the same original tracking row is updated; no duplicate canonical record is created.

---

## 11. Deftere Bakış

The tracker screen exposes a compact copy-friendly summary built only from:

```text
week/date
runtime theme/block names
runtime outcome codes and official texts
```

Clipboard output must not invent a rewritten curriculum sentence.

---

## 12. Dependency wiring

Production:

```text
CourseDatabase.open()
OutcomeTrackingDatabase.open()
CourseKnowledgeRepositoryImpl
SqfliteOutcomeTrackingRepository
AssetWeeklyPlanningService
OutcomePlanningService
AppDependencies
```

Dispose closes teacher-state DB and runtime DB.

Tests may inject an in-memory tracking repository.

---

## 13. UX guardrails

- Material 3.
- Cards must remain readable at large text scale.
- Avoid fixed-height outcome cards.
- Use `Wrap` for state/actions likely to overflow.
- Tablet uses existing NavigationRail breakpoint.
- Dark theme inherits app color scheme; no hardcoded light-only colors.
- Long official texts use progressive disclosure on cards and full text in detail.
- Touch targets remain at least standard Material interactive size.

---

## 14. Error / empty states

Supported states:

```text
Loading
Content
Empty
Error
Unresolved
Event week
```

Tracking DB failure is a startup error because persistence is a core capability in V1.2.

Stale tracking rows whose outcome no longer exists in the active runtime are ignored in projections; they must not manufacture course content.

---

## 15. Test strategy

After implementation completes, run as one validation batch:

```text
flutter analyze
runtime contract checks
flutter test
flutter build apk --release
```

Required new tests include:

1. tracking DB CRUD and persistence;
2. default missing row = planned;
3. status update does not mutate runtime;
4. carry-over appears in target week while source remains planned-origin aware;
5. event week is not a valid carry target;
6. completed/partial/in-progress summary counts;
7. OutcomeTracker phone/tablet/large-text smoke;
8. outcome detail block-context aggregation;
9. existing weekly/annual/runtime regressions.

---

## 16. Data truth rule

The UI may reorganize verified information for teacher usability but never upgrade the certainty of a relationship.

Correct:

```text
Bu kazanımın yer aldığı blokta erişilebilen kitap bölümleri
```

Incorrect when no direct mapping exists:

```text
Bu kitap sayfası doğrudan bu kazanıma aittir
```

Planning and tracking remain separate truths throughout the UI.