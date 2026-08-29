# ÖğretmenOS — Flutter Blueprint V1.4

**Belge sürümü:** 1.4.1  
**Durum:** Bağlayıcı teknik blueprint  
**Teknoloji:** Flutter + Dart + Material 3  
**Çalışma modu:** Offline-first / yerel / deterministik

`PRODUCT_SCOPE.md` üst otoritedir.

## 1. Architecture

```text
course_runtime.sqlite (READ ONLY)
        ↓
CourseKnowledgeRepository
        ├─ curriculum / outcome / block knowledge
        └─ LessonPlanKnowledgeRepository capability

calendar/profile assets
        ├─ terms / breaks / event weeks
        ├─ course profiles
        └─ schedule_exceptions (full/partial day)
                ↓
WeeklyPlanningService + SchoolScheduleExceptionRepository

teacher_state.sqlite (READ/WRITE)
        ├─ school_classes
        ├─ teaching_assignments
        ├─ bell_periods
        ├─ lesson_schedule_slots
        ├─ assignment_progress_cursor
        ├─ assignment_lesson_progress
        ├─ assignment_outcome_tracking
        ├─ legacy lesson_plan_progress
        └─ legacy outcome_tracking

InstructionContextRepository
        ├─ AssignmentLessonTimelineService
        │      ↓ assignment current/next/planned/actual
        └─ TeachingCourseContextService
               ↓ cross-course current/next course context

AssignmentOutcomeTrackingRepository
        ↓ adapter(selected assignment)
OutcomePlanningService

AssignmentLessonProgressRepository
        ↓
assignment-aware weekly plan / SingleLessonPlanPage

SharedPreferences
        ├─ continuity
        ├─ annual manual marker
        └─ legacy migration decision guard
```

Canonical runtime ve teacher-local state birbirine yazılamaz.

## 2. Top-level shell

`TeacherOsApp` üç destination kullanır:

```text
0 Bu Hafta
1 Plan
2 Kaynaklar
```

Ders programı/sınıf yönetimi top-level destination değildir; app bar'dan açılan supporting route'tur.

Course selector iki mod taşır:

```text
Ders programına göre otomatik   ← default
explicit TDE_9/TDE_10/...       ← session manual pin
```

Manual pin otomatik course switching'i durdurur. `Ders programına göre otomatik` tekrar seçilince pin kalkar.

## 3. Instruction context model

```dart
SchoolClass
  id
  academicYear
  grade
  section
  displayName

TeachingAssignment
  id
  academicYear
  courseId
  classId
  isActive

BellPeriod
  periodNumber
  startMinute
  endMinute

LessonScheduleSlot
  id
  assignmentId
  weekday
  periodNumber
```

Aynı `courseId` birden fazla `TeachingAssignment` ile kullanılabilir. Canonical ders içeriği kopyalanmaz.

Schedule collision domain kuralı:

```text
UNIQUE (academic_year, weekday, period_number)
```

Repository katmanı DB constraint'e güvenmekle yetinmez; domain-level `ScheduleSlotConflictException` üretir.

## 4. Calendar schedule exceptions

Versioned calendar asset optional `schedule_exceptions` taşır:

```json
{
  "id": "...",
  "date": "YYYY-MM-DD",
  "start_minute": 780,
  "end_minute": 1440,
  "label": "..."
}
```

`start_minute/end_minute` yoksa full-day `0..1440` kabul edilir.

Projection:

```text
calendar_index.json
→ academic year asset
→ AssetSchoolScheduleExceptionRepository
→ SchoolScheduleException
→ bell-period overlap check
```

`SchoolScheduleException.cancels()` yalnız aynı tarih + çakışan local minute interval için true döner. End exclusive'dir.

`AssignmentLessonTimelineService` canceled slot'u occurrence listesine hiç eklemez. Böylece tatil dersi ordinal tüketmez.

Exception parsing veya automatic context resolver problemi mevcut canonical course içeriğini startup-fatal yapmamalıdır; schedule-aware convenience fail-safe kalmalıdır. Ancak geçersiz versioned exception girdisi ilgili resolver tarafından sessizce doğru kabul edilmez.

## 5. teacher_state schema v5

`OutcomeTrackingDatabase.schemaVersion = 5`.

Current assignment-aware tables:

```text
school_classes
teaching_assignments
bell_periods
lesson_schedule_slots
assignment_progress_cursor
assignment_lesson_progress
assignment_outcome_tracking
```

Legacy migration source tables:

```text
lesson_plan_progress
outcome_tracking
```

v4 → v5 migration eski global `UNIQUE (weekday, period_number)` constraint'ini:

```text
UNIQUE (academic_year, weekday, period_number)
```

olarak düzeltir ve mevcut row'ları assignment academic year üzerinden korur.

## 6. Assignment timeline engine

`AssignmentLessonTimelineService` girdileri:

```text
InstructionContextRepository
WeeklyPlanningService
optional SchoolScheduleExceptionRepository
DateTime now
```

Ön koşullar:

- yalnız active assignment'lar;
- assignment program slot sayısı `plan.weeklyLessonHours` ile tam eşleşmeli;
- bell periods tanımlı olmalı;
- yalnız canonical instruction week'ler occurrence üretir;
- event week occurrence üretmez;
- schedule exception ile iptal edilen bell period occurrence üretmez.

Çıktı `InstructionTimelineSnapshot`:

```text
previousOccurrence
currentOccurrence
nextOccurrence
plannedOrdinal
actualOrdinal
```

Ders saati geçmiş olmak explicit completion değildir.

## 7. Cross-course context resolver

`TeachingCourseContextService` root navigation context için çalışır. Aynı academic year içindeki **tüm active teaching assignment'ları** inceler; course filter uygulamaz.

Girdiler:

```text
InstructionContextRepository
active course WeeklyPlanningService
SchoolScheduleExceptionRepository
DateTime now
```

Çözüm:

```text
current valid assignment
→ yoksa today next valid assignment
→ yoksa null preferred course
```

`TeachingCourseContextSnapshot`:

```text
currentCourseId / currentAssignmentId / currentStartsAt / currentEndsAt
nextCourseId / nextAssignmentId / nextStartsAt / nextEndsAt
preferredCourseId = currentCourseId ?? nextCourseId
nextTransitionAt
```

`TeacherOsApp` auto mode'da `preferredCourseId` farklı ve supported runtime ise course dependencies'i değiştirir. Resolver timer'ı sonraki geçerli start/end boundary'ye kurulur; app resume olduğunda tekrar çözülür. Schedule settings route'undan dönüş de recheck tetikler.

Resolver failure mevcut course'u kapatmaz; root mevcut yüklenmiş dependencies ile devam eder ve daha sonra retry eder.

### 7.1 Current TDE limitation

TDE_9–TDE_12 aktif profillerinde `weeklyLessonHours == 5` olduğu için resolver complete-schedule kontrolünde active course planındaki weekly-hour değerini tüm TDE assignment'larına uygulayabilir.

Farklı haftalık saatli yeni subject/course eklenirse cross-course resolver her assignment'ın own course profile'ını çözmelidir; mevcut ortak değer varsayımı başka ders alanlarına genellenemez.

## 8. Assignment progress cursor

`AssignmentProgressCursor`:

```text
follow_schedule:
  actual = planned

manual_offset:
  actual = actualAtAnchor + (planned - plannedAtAnchor)
```

`AssignmentProgressCursorService`:

- explicit actual position anchor;
- follow-schedule reset;
- timetable edit sonrası actual position korunacak re-anchor.

Cursor explicit completion değildir ve progress/tracking tablosuna side effect üretmez.

## 9. Bu Hafta composition

```text
ContinuityThisWeekPage
  ├─ assignment auto resolver
  ├─ optional assignment selector
  ├─ optional CurrentScheduledLessonCard
  ├─ optional Kaldığın yer
  └─ ThisWeekPage
       ├─ weekly curriculum focus
       └─ AssignmentAwareWeeklyLessonPlanSection
```

Assignment resolver order:

```text
pinned manual assignment
→ current scheduled occurrence
→ next scheduled occurrence
→ most recent previous occurrence
→ first assignment fallback
```

Manuel assignment selection yalnız görünüm bağlamını override eder. Timetable truth veya persisted cursor değişmez.

Schedule-aware current card yalnız seçili assignment programı tam ve timeline tarafından çözülebilir olduğunda gösterilir. Eksik programda canonical weekly workspace çalışır ve setup/complete-program aksiyonu görünür.

## 10. Assignment-scoped outcome tracking

```text
AssignmentOutcomeTrackingRepository
        ↓
AssignmentOutcomeTrackingAdapter
        ↓ implements OutcomeTrackingRepository projection
OutcomePlanningService
```

Storage identity:

```text
assignment_id + outcome_id + planned_week_number
```

Adapter yalnız kendi assignment'ına read/write/delete yapabilir. 9/A mutation'ı 9/B record'una erişemez.

## 11. Assignment-scoped lesson-plan progress

Storage identity:

```text
assignment_id + package_id + package_hour
```

Content binding:

```text
record.payload_sha256 == canonical package.payload_sha256
```

Hash mismatch/null stale'dir; current completion sayılmaz.

Programdan türeyen `Programa göre geçildi`, `ŞU AN`, `PLANLANAN` gibi görünüm durumları **assignment_lesson_progress** tablosuna yazılmaz.

`SingleLessonPlanPage`:

- assignment-aware repository varsa onu kullanır;
- legacy repository yalnız migration/fallback uyumluluğu içindir;
- görüntüleme veya previous/next navigation progress oluşturmaz;
- explicit mutation persisted snapshot tabanlı Undo sözleşmesini korur;
- tracking disclosure secondary/optional kalır.

## 12. Weekly lesson-plan projection

`LessonPlanWorkflowService.selectionForInstructionOrdinal()` curriculum hour ordinal'ını canonical lesson-plan selection'a map eder.

```text
valid schedule occurrence
→ planned ordinal
→ cursor ile actual ordinal
→ LessonPlanWorkflowService
→ canonical package + packageHour
```

Calendar exception occurrence'ı kaldırdığı için ordinal mapping otomatik olarak gerçek okul gününe kayar; widget ayrıca tatil telafisi hesaplamaz.

## 13. TeachingSchedulePage

Supporting route sorumlulukları:

- şube eklemek/kaldırmak;
- bell periods düzenlemek;
- assignment weekly slots seçmek;
- başka assignment'ın dolu hücrelerini bloke etmek;
- expected weekly hour sayısından eksik/fazla programı reddetmek;
- schedule edit sonrası cursor re-anchor;
- legacy teacher state için explicit migration.

Repository authoritative validation yapar. UI occupied-state yalnız ergonomidir.

Route kapanınca app shell schedule revision artırır; root automatic course resolver da programı yeniden değerlendirir.

## 14. Legacy teacher-state migration

`LegacyTeacherStateMigrationService` yalnız explicit target assignment ile çalışır.

```text
source legacy record
→ target assignment record yoksa copy
→ target mevcutsa skip
→ source delete edilmez
```

Legacy lesson identity yalnız güvenilir:

```text
<package_id>::lesson-hour:<N>
```

formatından taşınır. Malformed kayıt tahmin edilmez.

## 15. Continuity contract

`LastFocusState` tracking değildir.

Assignment workspace:

```text
courseId::assignmentId
```

course-scoped Resources/Yıllık için viewed curriculum context ayrıca course key'e best-effort mirror edilir. Mirror tracking status taşımaz.

Preference failure navigation'ı bloke edemez.

## 16. Resources / Annual

Resources canonical catalog olarak course-scoped kalır.

Annual canonical sequence course-level'dır. Assignment selector annual yüzeyine açıkça eklenmeden assignment-specific completion state course-wide legacy state gibi sunulamaz; bu nedenle assignment-aware geçiş sürecinde annual optional tracking projection fail-closed kalabilir.

## 17. Runtime truth

- `course_runtime.sqlite` READ ONLY.
- Widget raw SQL çalıştırmaz.
- Curriculum relationship uydurulmaz.
- Calendar/year/exception rules versioned assets'ten gelir.
- TDE_9/TDE_10 lesson-plan capability runtime authority'den çözülür.
- TDE_11/TDE_12 capability yokluğu normal fallback'tir.
- Schedule position teacher-local inference'dır; curriculum fact veya completion değildir.
- Daily schedule exceptions canonical annual curriculum-hour budgetini yeniden yazmaz; occurrence projection'ını düzeltir.

## 18. Error hierarchy

Authoritative startup failures:

```text
runtime/course DB
weekly planning
teacher-state DB open/migration
```

Visible mutation failures:

```text
schedule save conflict
assignment tracking save
lesson progress save/undo
teacher note save
```

Convenience/context failures:

```text
continuity mirror
automatic course resolver
legacy migration decision preference
manual UI state
```

Convenience failure mevcut canonical content'i bloke etmez.

## 19. Responsive/accessibility

- Material 3.
- Phone bottom navigation, tablet/desktop NavigationRail.
- Large text sabit yükseklik varsayımına bağlı olmamalı.
- Action groups `Wrap`/scroll-safe layout kullanmalı.
- Dark mode scheme-based.
- Standard interactive target >= 48 logical px.
- Stale/offset/conflict/automatic mode durumları yalnız renkle anlatılmaz; görünür metin/ikon gerekir.

## 20. Validation gate

Merge öncesi normal gate:

```text
flutter analyze
runtime contract TDE9–TDE12
flutter test
release build
runtime asset verification
```

Assignment/schedule regresyon seti en az şunları kanıtlamalıdır:

```text
9/A state != 9/B state
current/next assignment correct
5. ders programla otomatik bulunur
schedule position does not persist completed
manual offset persists
resync returns followSchedule
schedule edit reanchors actual position
same-year slot collision rejected
different-year same slot allowed
incomplete assignment schedule ignored
full-day exception removes occurrence + ordinal consumption
partial-day exception only removes overlapping bell periods
cross-course current context resolves supported target course
before lesson, next course can become preferred course
exception day suppresses false current/next course
assignment outcome isolation
assignment lesson-progress isolation
legacy import requires explicit target
legacy source preserved
existing target records not overwritten
continuity assignment scope + course mirror
v4 → v5 timetable migration preserves rows
```

Bu branch'te validation kullanıcı tarafından çalıştırılacaktır; test çalıştırılmamış kod merge edilmiş sayılmaz.
