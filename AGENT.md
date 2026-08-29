# AGENT.md — ÖğretmenOS Agent Execution Protocol

> **Document version:** 1.4.1  
> **Status:** Binding execution protocol

## 0. Authority

Kod değişikliğinden önce sırayla oku:

1. `docs/PRODUCT_SCOPE.md`
2. `docs/FLUTTER_BLUEPRINT.md`
3. `AGENT.md`

Belge çatışması varsa yüksek otorite kazanır. Aktif davranışla çelişen eski V1.3 varsayımını restore etme.

## 1. Mission

Öğretmenin:

```text
uygulamayı aç
→ takvim + ders programından doğru course/şube bağlamını gör
→ doğrulanmış ders bilgisini veya planını aç
→ yalnız istisna varsa gerçek ilerlemeyi düzelt
→ çık
```

akışını en düşük karar yüküyle destekle.

**Tracking isteğe bağlıdır. `İşlendi` zorunlu değildir.** Normal kullanım her ders için manual completion bekleyemez.

## 2. Hard invariants

- Canonical TYMM runtime READ ONLY.
- Curriculum facts / lesson-plan content Dart'ta uydurulmaz veya hardcode edilmez.
- Runtime/calendar update teacher-state'i silmez.
- `TeachingAssignment` aynı dersin farklı şubelerini ayıran teacher-local scope'tur.
- 9/A state'i 9/B/9/C'ye sızamaz.
- Planned schedule != actual position != outcome tracking != lesson-plan progress != continuity.
- Ders saatinin geçmiş olması completion kanıtı değildir.
- Schedule engine otomatik `completed` / `in_progress` kaydı yazamaz.
- Takvimde iptal edilen normal ders occurrence/ordinal tüketemez.
- Full-day exception bütün normal bell-period occurrence'larını, partial-day exception yalnız çakışan period'ları kaldırır.
- Viewing outcome/lesson plan progress kaydı oluşturmaz.
- Previous/next navigation progress kaydı oluşturmaz.
- Manual başka şubeye bakmak timetable truth'u değiştirmez.
- Schedule change actual position'ı zıplatamaz; cursor re-anchor gerekir.
- Eksik weekly schedule `ŞU AN` üretmek için geçerli sayılmaz.
- Default course mode `Ders programına göre otomatik`tir.
- Explicit course seçimi manual pin'dir; auto mode'a dönüş görünür olmalıdır.
- Automatic course resolver hatası mevcut canonical course'u bloke edemez.
- Missing tracking/progress row kullanıcı borcu değildir.
- `payload_sha256` yalnız content binding kanıtıdır; identity değildir.
- Missing/mismatched hash current progress sayılmaz ve sessizce silinmez.
- Legacy teacher-state target şube tahmin edilmez; explicit seçim gerekir.
- Legacy migration source kayıtlarını silme veya target mevcut record'u overwrite etme.
- Continuity/preferences authoritative content'i bloke edemez.
- Teacher note silent-loss kabul etmez.
- Position != completion percentage.
- V1 core backend/account/telemetry/AI dependency gerektirmez.

## 3. Active surfaces

Top-level:

```text
Bu Hafta
Plan
Kaynaklar
```

Supporting routes:

```text
OutcomeDetailPage
BlockDetailPage
LessonPlanPage / SingleLessonPlanPage
TeachingSchedulePage
```

Ders programı veya ders planı için yeni top-level navigation ekleme.

## 4. Instruction context

Teacher-local model:

```text
SchoolClass
TeachingAssignment
BellPeriod
LessonScheduleSlot
AssignmentProgressCursor
```

Schedule collision aynı akademik yıl içinde:

```text
academic_year + weekday + period_number
```

ile unique olmalıdır. Farklı akademik yıllar aynı hücreyi kullanabilir.

UI occupied chip'i tek authority değildir; repository/DB aynı conflict'i reddetmelidir.

Her assignment'ın weekly slot count'u course profile `weeklyLessonHours` ile tam olmalıdır. Eksik programı normal schedule truth gibi projekte etme.

## 5. Calendar exceptions

Calendar asset optional:

```text
schedule_exceptions[]
  id
  date
  start_minute (default 0)
  end_minute   (default 1440)
  label
```

kurallarını taşır.

- `AssetSchoolScheduleExceptionRepository` versioned calendar asset'ten okur.
- End minute exclusive'dir.
- Bir `BellPeriod`, aynı tarihte exception interval ile overlap ederse o slot occurrence oluşturmaz.
- Tatil/yarım gün nedeniyle atlanan slot explicit tracking state yazmaz.
- Exception nedeniyle atlanan slot planned ordinal'ı artırmaz.
- Calendar exception annual curriculum budgetini yeniden hesaplayan ikinci bir curriculum planner değildir.

## 6. Automatic course context

`TeachingCourseContextService` active academic year'daki tüm active assignment'ları course filtresi olmadan değerlendirir.

Resolution:

```text
current valid assignment
→ today next valid assignment
→ preferredCourseId = current ?? next
```

Valid assignment için program tam olmalı ve ilgili slot schedule exception ile iptal edilmemiş olmalıdır.

`TeacherOsApp` auto mode'da farklı supported `preferredCourseId` bulursa runtime course context'ini değiştirebilir. Bu işlem tracking/progress mutation değildir.

Explicit course seçimi session manual pin'dir. Auto mode yeniden seçilene kadar schedule resolver course'u değiştirmemelidir.

App resume, bell start/end transition ve TeachingSchedulePage dönüşünde context yeniden çözülebilir.

Resolver failure:

```text
current loaded course remains usable
→ retry later
```

şeklinde fail-safe olmalıdır.

**V1.4 TDE varsayımı:** TDE_9–TDE_12 weekly hours aynıdır. Farklı weekly-hour profilli yeni subject eklenirse cross-course resolver'ı active course weekly-hour değeriyle genelleme; assignment course profile çözümü ekle.

## 7. Bu Hafta UX gate

Program kuruluysa schedule-aware current/next class bağlamı ana karar yükünü azaltmalıdır.

- Direct `Başla/İşlendi` primary button yok.
- Program geçmiş saatleri `Programa göre geçildi` gibi planning diliyle gösterebilir.
- Bu görsel durum explicit `İşlendi` demek değildir.
- Gerçek ve planlanan konum farklıysa metinle ayrıştır.
- `Düzelt` tek işlemle actual cursor anchor etmelidir.
- `Programa yeniden eşitle` follow-schedule moduna dönmelidir.
- Program yok/eksikse canonical weekly workspace çalışmaya devam eder.
- Lesson-plan capability yokluğu normal fallback'tir.

## 8. Cursor semantics

```text
follow_schedule:
  actual = planned

manual_offset:
  actual = actualAtAnchor + (planned - plannedAtAnchor)
```

Schedule edit öncesi actual position korunur; yeni planned ordinal ile re-anchor edilir.

Cursor explicit completion değildir ve `assignment_lesson_progress` yazmamalıdır.

## 9. Assignment lesson-plan progress

Current identity:

```text
assignment_id + package_id + package_hour
```

Legacy identity yalnız migration/fallback içindir:

```text
course_id + academic_year + package_id
```

Canonical binding:

```text
progress.payload_sha256 == package.payload_sha256
  → current

null / mismatch
  → stale
```

Explicit status mutation:

```text
notStarted → persisted row yok
inProgress → Kısmen işlendi
completed  → İşlendi
```

Explicit mutation real Undo sunmalıdır. Undo önceki persisted hash/status/timestamp değerlerini korumalıdır.

Stale record yeniden işaretlenirse eski timeline yeni canonical içeriğe taşınmaz.

## 10. Assignment outcome tracking

Current identity:

```text
assignment_id + outcome_id + planned_week_number
```

`AssignmentOutcomeTrackingAdapter` üzerinden mevcut `OutcomePlanningService` projection mantığı yeniden kullanılabilir.

Adapter kendi assignment scope'u dışına mutation yapmamalıdır.

Outcome status/carry mutationları Undo sunmalı; note/actual-hours silent overwrite yapmamalıdır.

Course-wide legacy outcome records yeni şubelerin ortak state'i gibi sunulamaz.

## 11. Continuity

`LastFocusState` last-viewed context'tir; tracking değildir.

Assignment weekly workspace assignment-scoped key kullanabilir:

```text
courseId::assignmentId
```

Resources/Yıllık course-scoped bağlamını kaybetmemek için viewed curriculum context course-scoped key'e best-effort mirror edilebilir.

Bu mirror tracking status taşımaz.

Read/write/cleanup failure navigation veya canonical content'i engelleyemez.

## 12. Legacy migration

Eski record hangi şubeye ait bilinmiyorsa:

```text
preview
→ teacher explicit target assignment seçer
→ copy-if-target-missing
→ source preserved
```

Otomatik ilk şubeye bağlama yasaktır.

Parse edilemeyen legacy lesson-hour identity tahmin edilmez.

Migration decision preference yalnız tekrar sorusunu azaltan convenience guard'dır.

## 13. Data boundaries

```text
course_runtime.sqlite  READ ONLY canonical curriculum + lesson plans
calendar assets        READ ONLY planning + schedule-exception authority
teacher_state.sqlite   READ/WRITE teacher-local state
SharedPreferences      continuity / manual UI / migration guard
```

`teacher_state.sqlite` current schema V5'tir.

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

Legacy tables korunur:

```text
lesson_plan_progress
outcome_tracking
```

Widget raw SQL çalıştırmaz.

## 14. Resources / Annual

Resources context priority:

```text
last viewed lesson
→ current instructional week
→ fallback theme
```

Annual canonical sequence course-level'dır. Assignment completion percentage üretme.

Assignment scope açık değilse assignment tracking'i annual course-wide state gibi sunma.

## 15. Notes and mutation safety

Teacher note:

```text
700ms autosave
back/lifecycle flush
save failure visible
no silent exit with unsaved dirty note
```

Tracking/progress mutation failure başarı gibi gösterilemez.

## 16. Git safety

- Unrelated user work korunur.
- Feature work current `main`den branch edilir.
- User testleri kendisi yapacağını söylediyse test/CI/analyze/build çalıştırma; kodu test edilmemiş olarak açıkça bırak.
- Test dosyası eklemek serbesttir; çalıştırma kullanıcıya bırakılır.
- User açıkça istemeden `main`e merge etme veya release üretme.
- Temporary patch/script final diff'te bırakma.
- Canonical runtime binary'sini text API ile yeniden üretme.

## 17. Validation contract

Final merge gate normalde:

```text
flutter analyze
Runtime Contract TDE9/TDE10/TDE11/TDE12
flutter test
release build
runtime asset verification
```

Assignment/schedule minimum regression set:

```text
same course different sections isolated
5th scheduled lesson resolves without manual completion
schedule position never persists completion
manual offset persists
resync works
schedule edit reanchors actual
same-year slot conflict rejected
different-year same slot allowed
incomplete schedule ignored
full-day schedule exception removes occurrence/ordinal
partial-day exception only removes overlapping bell periods
cross-course current course resolution works
before lesson next course can be preferred
automatic resolver respects schedule exception
manual course pin prevents auto switching
assignment outcome isolation
assignment lesson progress isolation
legacy target explicit
legacy source preserved
target record not overwritten
v4→v5 timetable migration preserves rows
continuity assignment scope + course mirror
```

## 18. Pre-merge checklist

- binding docs active architecture ile uyumlu;
- tracking optional;
- schedule position truthful;
- calendar exceptions applied before ordinal projection;
- no automatic fake completion;
- section isolation preserved;
- automatic course mode/manual pin semantics explicit;
- automatic resolver failure non-blocking;
- continuity independent;
- runtime read-only;
- hash binding package-level;
- stale state preserved but not current;
- schedule conflicts scoped by academic year;
- legacy migration explicit and non-destructive;
- user-requested validation completed before merge.
