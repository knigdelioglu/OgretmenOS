# AGENT.md — ÖğretmenOS Agent Execution Protocol

> **Document version:** 1.4.0  
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
→ programdan doğru sınıf/şube bağlamını gör
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
- Viewing outcome/lesson plan progress kaydı oluşturmaz.
- Previous/next navigation progress kaydı oluşturmaz.
- Manual başka şubeye bakmak timetable truth'u değiştirmez.
- Schedule change actual position'ı zıplatamaz; cursor re-anchor gerekir.
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

## 5. Bu Hafta UX gate

Program kuruluysa schedule-aware current/next class bağlamı ana karar yükünü azaltmalıdır.

- Direct `Başla/İşlendi` primary button yok.
- Program geçmiş saatleri `Programa göre geçildi` gibi planning diliyle gösterebilir.
- Bu görsel durum explicit `İşlendi` demek değildir.
- Gerçek ve planlanan konum farklıysa metinle ayrıştır.
- `Düzelt` tek işlemle actual cursor anchor etmelidir.
- `Programa yeniden eşitle` follow-schedule moduna dönmelidir.
- Program yoksa canonical weekly workspace çalışmaya devam eder.
- Lesson-plan capability yokluğu normal fallback'tir.

## 6. Cursor semantics

```text
follow_schedule:
  actual = planned

manual_offset:
  actual = actualAtAnchor + (planned - plannedAtAnchor)
```

Schedule edit öncesi actual position korunur; yeni planned ordinal ile re-anchor edilir.

Cursor explicit completion değildir ve `assignment_lesson_progress` yazmamalıdır.

## 7. Assignment lesson-plan progress

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

## 8. Assignment outcome tracking

Current identity:

```text
assignment_id + outcome_id + planned_week_number
```

`AssignmentOutcomeTrackingAdapter` üzerinden mevcut `OutcomePlanningService` projection mantığı yeniden kullanılabilir.

Outcome status/carry mutationları Undo sunmalı; note/actual-hours silent overwrite yapmamalıdır.

Course-wide legacy outcome records yeni şubelerin ortak state'i gibi sunulamaz.

## 9. Continuity

`LastFocusState` last-viewed context'tir; tracking değildir.

Assignment weekly workspace assignment-scoped key kullanabilir:

```text
courseId::assignmentId
```

Resources/Yıllık course-scoped bağlamını kaybetmemek için viewed curriculum context course-scoped key'e best-effort mirror edilebilir.

Bu mirror tracking status taşımaz.

Read/write/cleanup failure navigation veya canonical content'i engelleyemez.

## 10. Legacy migration

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

## 11. Data boundaries

```text
course_runtime.sqlite  READ ONLY canonical curriculum + lesson plans
calendar assets        READ ONLY planning authority
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

## 12. Resources / Annual

Resources context priority:

```text
last viewed lesson
→ current instructional week
→ fallback theme
```

Annual canonical sequence course-level'dır. Assignment completion percentage üretme.

Assignment scope açık değilse assignment tracking'i annual course-wide state gibi sunma.

## 13. Notes and mutation safety

Teacher note:

```text
700ms autosave
back/lifecycle flush
save failure visible
no silent exit with unsaved dirty note
```

Tracking/progress mutation failure başarı gibi gösterilemez.

## 14. Git safety

- Unrelated user work korunur.
- Feature work current `main`den branch edilir.
- User testleri kendisi yapacağını söylediyse test/CI çalıştırma; kodu test edilmemiş olarak açıkça bırak.
- User açıkça istemeden `main`e merge etme veya release üretme.
- Temporary patch/script final diff'te bırakma.
- Canonical runtime binary'sini text API ile yeniden üretme.

## 15. Validation contract

Final merge gate normalde:

```text
flutter analyze
Runtime Contract TDE9/TDE10/TDE11/TDE12
flutter test
release build
runtime asset verification
```

Assignment-aware minimum regression set:

```text
same course different sections isolated
5th scheduled lesson resolves without manual completion
schedule position never persists completion
manual offset persists
resync works
schedule edit reanchors actual
same-year slot conflict rejected
different-year same slot allowed
assignment outcome isolation
assignment lesson progress isolation
legacy target explicit
legacy source preserved
target record not overwritten
v4→v5 timetable migration preserves rows
continuity assignment scope + course mirror
```

## 16. Pre-merge checklist

- binding docs active architecture ile uyumlu;
- tracking optional;
- schedule position truthful;
- no automatic fake completion;
- section isolation preserved;
- continuity independent;
- runtime read-only;
- hash binding package-level;
- stale state preserved but not current;
- schedule conflicts scoped by academic year;
- legacy migration explicit and non-destructive;
- user-requested validation completed before merge.
