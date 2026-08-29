# ÖğretmenOS — Flutter Blueprint V1.4

**Belge sürümü:** 1.4.0  
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
        ↓
WeeklyPlanningService

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
        ↓
AssignmentLessonTimelineService
        ↓
planned/current/next assignment position

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

`LessonPlanPage` / `SingleLessonPlanPage` supporting detail route'larıdır.

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

Bu kural teacher timetable içindir; farklı akademik yıllar aynı haftalık hücreyi kullanabilir.

Repository katmanı DB constraint'e güvenmekle yetinmez; domain-level `ScheduleSlotConflictException` üretir.

## 4. teacher_state schema v5

`OutcomeTrackingDatabase.schemaVersion = 5`.

### 4.1 Current assignment-aware tables

```text
school_classes
teaching_assignments
bell_periods
lesson_schedule_slots
assignment_progress_cursor
assignment_lesson_progress
assignment_outcome_tracking
```

### 4.2 Legacy tables

```text
lesson_plan_progress
outcome_tracking
```

Legacy tablolar migration source olarak korunur. Yeni assignment-aware akış bunları ortak şube state'i olarak kullanmaz.

### 4.3 v4 → v5 migration

v4 `lesson_schedule_slots` tablosundaki global:

```text
UNIQUE (weekday, period_number)
```

kuralı yanlıştı. v5 migration assignment üzerinden `academic_year` backfill eder ve tabloyu:

```text
UNIQUE (academic_year, weekday, period_number)
```

ile yeniden kurar.

Migration teacher state'i silmez.

## 5. Timeline engine

`AssignmentLessonTimelineService` girdileri:

```text
InstructionContextRepository
WeeklyPlanningService
DateTime now
```

Çıktı `InstructionTimelineSnapshot` içinde assignment bazlı occurrence/position bilgisidir.

Sadece canonical `AnnualWeeklyPlan` içindeki instruction week'ler kullanılır. Event week yeni ders occurrence üretmez.

Pozisyonlar:

```text
previousOccurrence
currentOccurrence
nextOccurrence
plannedOrdinal
actualOrdinal
```

Ders saati geçmiş olmak explicit completion değildir.

## 6. Assignment progress cursor

`AssignmentProgressCursor` iki mod taşır:

```text
follow_schedule
manual_offset
```

`follow_schedule`:

```text
actual = planned
```

`manual_offset`:

```text
actual = actualAtAnchor + (planned - plannedAtAnchor)
```

`AssignmentProgressCursorService` sorumlulukları:

- gerçek konumu explicit öğretmen seçimiyle anchor etmek;
- programa yeniden eşitlemek;
- program düzenlenince gerçek pozisyonu koruyacak biçimde re-anchor etmek.

Program değişikliği explicit lesson/outcome tracking state'ini otomatik değiştirmez.

## 7. Bu Hafta composition

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

Assignment auto resolution order:

```text
pinned manual assignment (yalnız kullanıcı seçtiyse)
→ current scheduled occurrence
→ next scheduled occurrence
→ most recent previous occurrence
→ first assignment fallback
```

Manuel selection yalnız görünüm bağlamını override eder. Timetable gerçeğini veya persisted cursor'u değiştirmez.

Current scheduled card yalnız selected assignment için bell period + schedule slot olduğunda aktif kabul edilir.

## 8. Assignment-scoped outcome tracking

Weekly outcome tracking selected assignment üzerinden adapter ile mevcut `OutcomePlanningService`'e bağlanır:

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

Bu adapter canonical outcome projection mantığını kopyalamadan mevcut planning service'i yeniden kullanır.

9/A mutation'ı 9/B record'una erişemez.

## 9. Assignment-scoped lesson-plan progress

Storage identity:

```text
assignment_id + package_id + package_hour
```

`AssignmentLessonProgressRepository` teacher-local explicit status içindir.

Content binding:

```text
record.payload_sha256 == canonical package.payload_sha256
```

Hash mismatch/null stale'dir; current completion sayılmaz.

Programdan türeyen `Programa göre geçildi`, `ŞU AN`, `PLANLANAN` gibi görünüm durumları **bu tabloya yazılmaz**.

`SingleLessonPlanPage`:

- assignment-aware repository varsa onu kullanır;
- legacy repository yalnız geçiş/fallback uyumluluğu içindir;
- görüntüleme veya previous/next navigation progress oluşturmaz;
- explicit mutation Undo sözleşmesini korur.

## 10. Weekly lesson plan projection

`LessonPlanWorkflowService.selectionForInstructionOrdinal()` curriculum hour ordinal'ını canonical lesson-plan selection'a map eder.

Assignment timeline'dan gelen actual/planned ordinal bu resolver'a girer. Widget package/hour sayılarını kendi başına tahmin etmez.

Assignment-aware haftalık panel:

```text
schedule occurrence
→ planned ordinal
→ cursor ile actual ordinal
→ LessonPlanWorkflowService
→ canonical package + packageHour
```

Planlanan/geçmiş satır görsel durumu explicit completion'dan ayrı tutulur.

## 11. TeachingSchedulePage

Supporting route sorumlulukları:

- şube eklemek/kaldırmak;
- bell periods düzenlemek;
- assignment'ın weekly slots'unu seçmek;
- başka assignment'ın dolu hücrelerini bloke etmek;
- schedule değişiminden sonra cursor re-anchor etmek;
- legacy teacher state bulunduğunda explicit migration akışını göstermek.

Repository authoritative validation yapar. UI'deki occupied-state yalnız ergonomidir ve DB/domain constraint'in yerine geçmez.

## 12. Legacy teacher-state migration

`LegacyTeacherStateMigrationService` yalnız explicit target assignment ile çalışır.

Preview:

```text
legacy course lesson progress
+ active course outcome IDs ile eşleşen legacy outcome records
```

Migration:

```text
source legacy record
→ target assignment record yoksa copy
→ target mevcutsa skip
→ source hiçbir zaman delete edilmez
```

Legacy lesson identity yalnız güvenilir şekilde parse edilebilen:

```text
<package_id>::lesson-hour:<N>
```

formatından taşınır. Malformed kayıt tahmin edilmez.

`LegacyMigrationDecisionRepository` yalnız aynı kullanıcıya tekrar tekrar aynı import sorusunu sormamak için SharedPreferences guard'dır.

## 13. Continuity contract

`LastFocusState` tracking değildir.

Assignment-aware weekly workspace assignment-scoped continuity key kullanır:

```text
<courseId>::<assignmentId>
```

Kaynaklar ve Yıllık course-scoped resolver kullandığından viewing event ayrıca course-scoped last-focus'a best-effort mirror edilir.

Mirror yalnız curriculum/view context taşır; assignment tracking state'i course-wide state'e dönüştürülmez.

Preference failure navigation'ı bloke edemez.

## 14. Outcome detail and notes

`OutcomeDetailPage` information-first kalır.

Tracking optionaldır ve selected assignment'a bağlı active `OutcomePlanningService` kullanılır.

Teacher note safety sözleşmesi korunur:

```text
700ms autosave
back/lifecycle flush
save failure visible
no silent loss
```

## 15. Resources / Annual

Resources canonical catalog olarak course-scoped kalır; son görüntülenen assignment outcome context'i course mirror sayesinde theme/block çözümüne katkı verebilir.

Annual canonical sequence course-level'dır. Assignment-specific completion yüzdesi üretmez.

Assignment seçimi açıkça annual tracking scope'una taşınmadıkça course-wide legacy status yeni şube status'u gibi sunulmamalıdır.

## 16. Runtime truth

- `course_runtime.sqlite` READ ONLY.
- Widget raw SQL çalıştırmaz.
- Curriculum relationship uydurulmaz.
- Calendar/year rules versioned assets'ten gelir.
- TDE_9/TDE_10 lesson-plan capability runtime authority'den çözülür.
- TDE_11/TDE_12 capability yokluğu normal fallback'tir.
- Schedule position teacher-local inference'dır; curriculum fact veya completion değildir.

## 17. Error hierarchy

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

Convenience failures:

```text
continuity mirror
legacy migration decision preference
manual UI state
```

ana canonical içeriği bloke etmez.

## 18. Responsive/accessibility

- Material 3.
- Phone bottom navigation, tablet/desktop NavigationRail.
- Large text sabit yükseklik varsayımına bağlı olmamalı.
- Action groups `Wrap`/scroll-safe layout kullanmalı.
- Dark mode scheme-based.
- Standard interactive target >= 48 logical px.
- Stale/offset/conflict durumları yalnız renkle anlatılmaz; görünür metin gerekir.

## 19. Validation gate

Merge öncesi doğrulama hedefleri:

```text
flutter analyze
runtime contract TDE9–TDE12
flutter test
release build
runtime asset verification
```

Assignment-aware regresyon seti en az şunları kanıtlamalıdır:

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
assignment outcome isolation
assignment lesson-progress isolation
legacy import requires explicit target
legacy source preserved
existing target records not overwritten
continuity assignment scope + course mirror
v4 → v5 timetable migration preserves rows
```

Bu branch'te validation kullanıcı tarafından ayrıca çalıştırılabilir; test çalıştırılmamış kod merge edilmiş sayılmaz.
