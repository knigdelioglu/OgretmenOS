# PRODUCT_SCOPE.md — TYMM Teacher OS V1

**Product:** TYMM Teacher OS  
**Document version:** 1.0.0  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**V1 Distribution Target:** Android  
**Initial Course Package:** `TDE_9`  
**Operation Mode:** Offline-first, deterministic, local  
**LLM Dependency:** None  
**Backend Dependency:** None

---

## 1. Purpose

This document defines **what TYMM Teacher OS V1 is allowed to be**.

It is the highest product-scope authority for the Flutter application.

Detailed technical architecture belongs to:

```text
docs/FLUTTER_BLUEPRINT.md
```

Agent execution and safety behavior belongs to:

```text
AGENT.md
```

Authority order:

```text
1. PRODUCT_SCOPE.md
2. FLUTTER_BLUEPRINT.md
3. AGENT.md
```

If these documents conflict, implementation must stop and report:

```text
DOCUMENT_CONFLICT
```

No agent may silently broaden or reinterpret this scope.

---

## 2. Product Definition

TYMM Teacher OS V1 is a lightweight teacher workflow application that presents verified TYMM course knowledge in an operational form.

Its purpose is to answer:

```text
Program sırasının neresindeyim?
Bu blokta ne var?
Ders kitabında nereye bakacağım?
Hangi etkinlikler ilgili?
Hangi değerlendirme aracı kullanılmalı?
Ek materyale gerçekten ihtiyaç var mı?
Sonraki blok ne?
```

The app consumes the verified runtime course package:

```text
Canonical TYMM Knowledge
        ↓
Deterministic Runtime Compiler
        ↓
course_runtime.sqlite
        ↓
Flutter Application
```

The application is a **consumer of verified knowledge**.

It is not a second curriculum interpretation engine.

---

## 3. Product North Star

The teacher must receive useful course guidance **without being required to maintain the application manually every day**.

V1 must remain usable with:

```text
daily teacher logging = 0
student data = 0
internet = 0
account = 0
backend = 0
LLM = 0
```

Optional local teacher position override may exist, but the application must not depend on continuous manual progress entry.

---

## 4. V1 Core Capabilities

V1 contains exactly five product capabilities.

---

### Capability A — Ders Yürütme Merkezi

Purpose:

> Present the verified operational contents of a selected teaching block.

The user can navigate:

```text
Course
→ Theme
→ Block
```

A block view may present verified runtime data including:

```text
theme
block
block order
skill/learning domain
outcomes
process components
textbook sections
printed/PDF pages
activities
forms
assessment artifacts
resource decisions
source references
previous block
next block
```

The application must not invent missing relationships or values.

---

### Capability B1 — Current / Selected Block Brief

Purpose:

> Present a concise single-screen summary for a teacher-selected or manually marked position in the annual sequence.

It may include:

```text
selected block
theme
textbook pages
key activities
outcomes
relevant assessment/support tool
resource status
next block
```

#### Current-position rule

Until verified calendar binding exists:

```text
manual_position_override exists
    → may be used as teacher-selected current position

otherwise
    → no factual date-based current block exists
```

Without verified calendar data, the application must not claim:

```text
Bugünkü Ders
Bugün burada olmalısınız
Bugün işlemeniz gereken blok
```

Neutral labels must be used, such as:

```text
Seçili Plan Konumu
Plan Sırası
Blok Özeti
```

---

### Capability C — Yaşayan Yıllık Plan

Purpose:

> Show the verified ordered teaching sequence.

It may display:

```text
theme order
block order
sequence position
known theme-level time metadata
known/unresolved timeline metadata
manual teacher position marker
```

The annual plan represents **planned teaching sequence**, not student mastery.

Allowed:

```text
Plan sırası: 7 / 16
```

Not allowed:

```text
7 / 16 = %43.7 tamamlandı
```

unless future verified time data actually supports elapsed instructional-time calculation.

Do not use planned progression as:

```text
Öğrenildi
Kazanıldı
Mastery
Başarı oranı
Öğrenme tamamlandı
```

---

### Capability D — Kitap-Önce / Materyal Gerekliliği

Purpose:

> Show whether the verified course/resource model says the textbook or an existing assessment/support resource already satisfies the instructional need.

The UI may display deterministic runtime decisions such as:

```text
book sufficient
use textbook activity
use existing form
use annual assessment artifact
additional support required
```

The exact machine codes come from the runtime contract.

The app must not independently decide:

```text
this resource is sufficient
this material must be generated
this rubric is required
```

If the runtime contract is insufficient or ambiguous, report a data/runtime contract gap instead of adding pedagogical inference.

---

### Capability E — Otomatik Öğretmen Paketi

Purpose:

> Present a structured theme-level teacher preparation package assembled from verified data.

Input:

```text
one selected theme_id
```

The package may aggregate only that theme's verified:

```text
blocks
outcomes
textbook sections/pages
activities
forms
assessment artifacts
resource decisions
source references
```

V1 teacher package is:

```text
on-screen structured view
```

It does not generate new pedagogical prose.

It does not aggregate unrelated themes into one theme package.

---

## 5. Deferred Capability — B2 Date-Based “Bugünkü Ders”

Date-based automatic current-position resolution is explicitly **not part of active V1 implementation** until required planning data is verified.

Current known limitations may include:

```text
BLOCK_HOUR_RESOLUTION = ORDER_ONLY
WEEKLY_LESSON_HOURS = UNRESOLVED
ACADEMIC_CALENDAR_BINDING = UNRESOLVED
```

Therefore V1 must not infer:

```text
date
→ exact current block
```

from annual order alone.

B2 may be promoted into scope later only after a verified calendar/planning profile exists.

---

## 6. Zero-Input Product Behavior

Without entering any teacher data, the user must still be able to:

```text
view the annual sequence
browse themes
browse blocks
inspect block details
view outcomes
view textbook page/activity references
view forms
view assessment artifacts
view resource decisions
view teacher packages
```

Manual teacher input is optional convenience, not a prerequisite.

---

## 7. Allowed Mutable User State

V1 may store only minimal local application state that is already required by the defined capabilities.

Allowed examples:

```text
manual_position_override
basic UI preferences
```

This state must remain separate from:

```text
course_runtime.sqlite
```

No course knowledge may be modified through user state.

---

## 8. Explicitly Out of Scope

The following are NOT part of V1.

### AI / Content Generation

```text
LLM
AI API
local AI model
chat
prompt system
RAG runtime
AI lesson-plan generation
worksheet generation
rubric generation
question generation
AI recommendation engine
```

### Student Systems

```text
student roster
student profile
attendance
gradebook
exam scores
student portfolio
mastery tracking
individual student analytics
parent information
student PII
```

### Teacher Productivity Expansion

```text
teacher diary
lesson history
free-form notes system
task manager
reminders
notifications
calendar manager
```

### School Administration

```text
e-Okul
MEBBİS
school timetable synchronization
Google Calendar integration
administrative workflows
```

### Cloud / Accounts

```text
user accounts
authentication
backend
cloud database
cloud sync
multi-user collaboration
telemetry
analytics collection
Firebase
```

### Content / Source Processing

```text
PDF ingestion
OCR
curriculum parsing
textbook parsing
canonical knowledge editing
runtime DB editing
knowledge graph editor
in-app runtime rebuild
```

### Export / Publishing

```text
PDF export
DOCX export
content publishing
sharing subsystem
```

### Search Expansion

```text
general semantic textbook search
ask-the-book chat
vector search UI
```

These may be reconsidered only through an explicit future scope revision.

---

## 9. Platform Scope

Implementation technology:

```text
Flutter
Dart
Material 3
```

V1 distribution target:

```text
Android
```

Flutter's cross-platform capability does not automatically add:

```text
iOS
web
macOS
Windows
Linux
```

to V1.

Portable code is acceptable.

Additional platform release pipelines, QA, packaging, and platform-specific features are out of scope.

---

## 10. Data Authority

Course data originates from the verified TYMM knowledge system.

Application-facing runtime:

```text
course_runtime.sqlite
```

The application must treat it as:

```text
read-only
derived
rebuildable
source-traceable
```

The app must never treat it as user-writable state.

The Flutter app must not reconstruct canonical curriculum logic from scattered JSON files.

---

## 11. No Hardcoded Curriculum Rule

Dart source code must not hardcode:

```text
outcomes
theme contents
block contents
activities
textbook page mappings
forms
assessment mappings
resource decisions
gap mappings
curriculum hour allocations
```

Those values must be read from the runtime package.

Allowed hardcoded application constants include:

```text
UI labels
route names
supported runtime schema versions
generic status wording
```

as long as they do not encode curriculum facts.

---

## 12. No Pedagogical Invention Rule

When verified runtime data is absent or unresolved, the application must show the limitation.

It must not invent:

```text
block hours
weekly lesson hours
calendar position
resource need
assessment need
outcome/activity relationships
student mastery
```

Examples:

Correct:

```text
Programda doğrulanmış ayrı blok süresi bulunmuyor.
```

Incorrect:

```text
Blok süresi: 5 saat
```

when 5 hours is not verified.

---

## 13. Book-First Product Principle

The app must not create artificial demand for additional resources.

When the verified course model says the textbook already covers the instructional need, the application should communicate that clearly.

Conceptual example:

```text
Kitapta karşılığı var.
Ek materyal gerekli değil.
```

When verified support is required, the app points to the relevant existing/annual resource.

The app itself does not generate that resource in V1.

---

## 14. Copyright Boundary

The application may present verified navigation metadata such as:

```text
source title
activity/form name
printed page
PDF page
short metadata
source locator
```

V1 must not bundle or reproduce, merely for convenience:

```text
full textbook PDFs
long copyrighted textbook passages
full literary works
model/embedding payloads
```

Any future content bundling requires a separate rights decision.

---

## 15. Offline Requirement

All V1 core capabilities must work offline after installation.

Core functionality may not depend on:

```text
network access
API availability
authentication
cloud service availability
model download
```

---

## 16. UX Product Principles

V1 should minimize interaction cost.

The app should not require:

```text
daily forms
mandatory completion checklists
daily notes
manual outcome completion
long onboarding
```

The primary UI must prioritize:

```text
where am I in the plan?
what is in this block?
where is it in the textbook?
which activity/tool applies?
is extra material actually needed?
what is next?
```

Avoid product emphasis on:

```text
gamification
badges
decorative analytics
arbitrary progress charts
unnecessary animation
```

---

## 17. Unresolved Data Is a Valid Product State

The product must support:

```text
Loading
Content
Empty
Error
Unresolved
```

`Unresolved` is not automatically an error.

Example:

```text
Blok süresi:
Programda doğrulanmış ayrı süre bulunmuyor.
```

The app must not convert unknown data into zero or estimated values.

---

## 18. Scope Creep Rule

A feature is not allowed merely because:

```text
it is easy
Flutter supports it
a dependency already exists
the database could store it
the agent has time left
```

Every product feature must map directly to:

```text
A
B1
C
D
E
```

If not:

```text
OUT_OF_SCOPE
```

The product scope must be explicitly revised before implementation.

---

## 19. Definition of V1 Success

V1 is successful when a teacher can:

1. open the Android application,
2. inspect the TDE_9 annual sequence,
3. navigate themes and blocks,
4. inspect verified outcomes for a block,
5. inspect relevant textbook pages and activities,
6. inspect related forms and assessment artifacts,
7. see the verified book-first/resource decision,
8. view a structured teacher package for a selected theme,
9. optionally mark a local plan position if supported,
10. do all of the above without daily data entry, account, internet, backend, or AI.

---

## 20. Definition of Scope Failure

The product has drifted outside V1 if any of the following becomes true:

```text
teacher must log activity every day for the app to be useful
planned sequence is presented as mastery
calendar position is fabricated
curriculum facts are hardcoded in Dart
Flutter reimplements canonical pedagogy
runtime DB becomes writable
student data is introduced
teacher notes/history system is introduced
LLM becomes necessary
backend becomes necessary
cloud/account features appear
scope expands because Flutter is cross-platform
unapproved export/notification/search features appear
```

If this happens, implementation must stop and return to the defined V1 boundary.

---

## 21. Scope Change Protocol

A future product change must follow this order:

```text
1. Define the proposed feature.
2. Determine whether it fits A/B1/C/D/E.
3. Determine whether it adds new user data.
4. Determine whether it requires new canonical/runtime data.
5. Determine whether it requires backend/network/AI.
6. Revise PRODUCT_SCOPE.md explicitly if scope changes.
7. Align FLUTTER_BLUEPRINT.md.
8. Align AGENT.md only if execution rules change.
9. Then implement.
```

No implementation may silently precede this process.

---

## 22. Final Product Boundary

TYMM Teacher OS V1 is complete when it functions as:

> A small, offline, deterministic Flutter application that exposes verified TDE_9 teaching sequence, textbook alignment, assessment/support references, and resource-necessity decisions in a practical teacher workflow without requiring daily teacher maintenance.

Nothing beyond that is required for V1.
