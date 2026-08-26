# ÖğretmenOS — Flutter Blueprint V1.3

**Belge sürümü:** 1.3.1  
**Durum:** Bağlayıcı teknik blueprint  
**Teknoloji:** Flutter + Dart + Material 3  
**Çalışma modu:** Offline-first / yerel / deterministik

`PRODUCT_SCOPE.md` üst otoritedir.

## 1. Architecture

```text
course_runtime.sqlite (read-only)
        ↓
CourseKnowledgeRepository
        ├─ curriculum / outcome / block knowledge
        └─ LessonPlanKnowledgeRepository capability

calendar/profile assets
        ↓
WeeklyPlanningService

teacher_state.sqlite (mutable optional teacher state)
        ├─ OutcomeTrackingRepository
        └─ LessonPlanProgressRepository

CourseKnowledgeRepository + WeeklyPlanningService + teacher-state repositories
        ↓
OutcomePlanningService / LessonPlanWorkflowService / LessonPlanProgressService
        ↓
Bu Hafta / Yıllık / Kaynaklar / routed details
```

Continuity ve annual manual marker SharedPreferences tabanlı convenience state'tir; curriculum veya tracking authority değildir.

## 2. Top-level shell

`TeacherOsApp` üç destination kullanır:

```text
0 Bu Hafta
1 Yıllık
2 Kaynaklar
```

`IndexedStack` ekran state'ini korur. Resource destination inactive→active geçişinde lesson context yeniden çözülür.

`LessonPlanPage` supporting routed detail'dir; destination sayısını artırmaz.

## 3. Bu Hafta composition

```text
ContinuityThisWeekPage
  ├─ optional KALDIĞIN YER card
  └─ ThisWeekPage
       └─ single ŞİMDİ focus card
            └─ optional lesson-plan entry when capability usable
```

`ContinuityThisWeekPage` önce authoritative `OutcomePlanningService.buildPlan()` sonucunu yükler. Continuity read/cleanup hataları yakalanır ve weekly workspace yine render edilir.

`ThisWeekPage` detail açılmadan önce optional `onOutcomeViewed` callback'ini best-effort çağırır. Callback hatası navigation'ı bloke etmez.

Lesson-plan entry yalnız `LessonPlanCapability.usable == true` olduğunda gösterilir. TDE_11/TDE_12 curriculum-only runtime veya fail-closed lesson-plan capability ana haftalık ekranı error state'e çeviremez.

## 4. Continuity contract

`LastFocusState`:

```text
courseId
academicYear
weekNumber
trackingKey
outcomeCode
theme/block context
updatedAt
```

Continuity yalnız viewing event ile güncellenir. Production `OutcomePlanningService` continuity callback'i almaz. Tracking mutationları continuity üzerinde side effect üretmez.

Malformed JSON, malformed optional field veya preference I/O problemi `null` continuity olarak ele alınır.

## 5. OutcomePlanningService and tracking identity

Tracking storage identity tek canonical encoder kullanır:

```text
outcomeTrackingKey(
  academicYear,
  outcomeId,
  plannedWeekNumber,
)
```

`LearningOutcomeTrackingRecord.trackingKey`, `TrackedOutcome.trackingKey`, plan projection ve annual optional tracking scope aynı encoder'a dayanır.

Missing tracking row projection'da `planned` olur; bu storage/domain fallback'ıdır, zorunlu kullanıcı görevi değildir.

## 6. Outcome detail

`OutcomeDetailPage` foreground hiyerarşisi:

```text
official outcome
Derste lazım
Daha fazla bilgi
  ├─ Takip seçenekleri (optional)
  ├─ Öğretmen notu
  ├─ süreç bileşenleri
  ├─ plan/blok context
  └─ doğrulanmış resource/assessment context
```

`Başla` / `İşlendi` primary CTA değildir.

Teacher note:

- 700ms debounce autosave;
- lifecycle/back flush;
- concurrent save serialization;
- save error görünür retry state;
- dirty note kaydedilemezse route kapanmaz.

## 7. Lesson-plan workflow and P5 progress

Runtime access:

```text
CourseKnowledgeRepository
  + LessonPlanKnowledgeRepository
        ↓
LessonPlanWorkflowService
        ↓
weekly/block lesson-plan entry
        ↓
LessonPlanPage
```

`LessonPlanPage` canonical payload'ı repository üzerinden okur; widget raw SQLite çalıştırmaz. Görünür içerik:

```text
package title / summary
package order + remaining block hours
outcome codes
continuation hint
structured lesson steps
previous / next package navigation
```

Progress access:

```text
teacher_state.sqlite
  lesson_plan_progress
        ↓
LessonPlanProgressRepository
        ↓
LessonPlanProgressService
        ↓
LessonPlanPage optional status card
```

Storage identity:

```text
course_id + academic_year + package_id
```

Semantics:

```text
missing row  → notStarted / Başlanmadı
in_progress  → Kısmen işlendi
completed    → İşlendi
```

`notStarted` mutation persisted row'u siler. `inProgress/completed` kayıtları `startedAt/completedAt/updatedAt` alanlarını taşır. Planı yalnız görüntülemek progress kaydı oluşturmaz.

### P5 real Undo contract

Her `LessonPlanPage` status mutasyonundan **önce** mevcut persisted `LessonPlanProgressRecord?` snapshot alınır. Mutation başarıyla persist edildikten sonra `showTeacherUndoFeedback` gösterilir.

Undo:

```text
previous == null
  → yeni kaydı delete et
previous != null
  → previous record'u aynen save et
```

Böylece `status`, `startedAt`, `completedAt` ve `updatedAt` önceki persisted değere döner. Undo yalnız mutation yapılan package'ın state'ini değiştirir; kullanıcı bu sırada başka pakete geçtiyse current package UI state'i yanlışlıkla overwrite edilmez.

Yeni bir mutasyon mevcut Undo teklifinin yerini alır. Undo persistence failure başarı gibi gösterilmez.

## 8. Mutation safety

Outcome status/carry/bulk tracking mutations persisted snapshot alır ve gerçek Undo sağlar. Status undo newer note/actual-hours state'ini ezmez.

Lesson-plan status mutationları da persisted snapshot'a gerçek Undo sağlar. Outcome tracking ile lesson-plan progress birbirinden bağımsız teacher-state kanallarıdır.

Tracking optional olsa da kullanıldığında persistence authoritative teacher state'tir; mutation hataları sessizce başarı gibi gösterilemez.

## 9. Resources context resolver

Resolution order:

```text
valid last-viewed outcome
→ current week outcome/theme
→ first theme fallback
```

Resolver errors resource package access'ini engellemez. Manual theme selection yalnız mevcut Resources oturumu için override'dır.

## 10. Annual plan

Annual authoritative sequence `CourseKnowledgeRepository.getAnnualSequence()`dan gelir.

Manual marker ve continuity read hataları annual sequence'i bloke etmez. Manual marker write/clear hataları kullanıcı feedback'i verir.

Active position:

```text
newer temporary manual marker
else last viewed block
```

Position presentation:

```text
Öğretim sırası: N. blok / total
```

Position-derived `LinearProgressIndicator` yasaktır.

Optional tracking panel yalnız active course planındaki canonical tracking keys ile eşleşen explicit non-planned statüleri sayar. Yüzde/denominator üretmez.

## 11. Runtime truth

- `course_runtime.sqlite` read-only.
- Widgets raw SQL çalıştırmaz.
- Block-level relation outcome-specific gibi sunulmaz.
- UI missing canonical relationship üretmez.
- Calendar/year rules versioned assets'ten gelir.
- Lesson-plan package payload/hash/navigation yalnız doğrulanmış runtime capability üzerinden açılır.
- TDE_9/TDE_10 lesson-plan runtime contract: package 1.3.0, schema 1.2.0, 88 package / 172 instructional hours.
- TDE_11/TDE_12 lesson-plan capability yokluğu normal fallback'tir.

## 12. Responsive/accessibility

- Material 3.
- Phone bottom navigation, tablet/desktop NavigationRail.
- Large text fixed-height cardlarla kırılmaz.
- Action groups overflow için `Wrap` kullanır.
- Dark mode scheme-based.
- Standard interactive target >= 48 logical px where audited.
- Lesson-plan status controls `Wrap` kullanır; yeni top-level navigation eklemez.

## 13. Legacy feature code

Faz 0–6 öncesi top-level alternatif ekranlar active shell tarafından route edilmez. Unrouted duplicate implementations ürün authority'si değildir ve bakım borcu olarak kaldırılabilir. Aynı capability gerekiyorsa mevcut `Bu Hafta / Yıllık / Kaynaklar / OutcomeDetail / BlockDetail / LessonPlanPage` akışları üzerinden geliştirilir.

## 14. Error hierarchy

Authoritative failures:

```text
runtime/course DB
weekly planning
teacher-state DB startup (production dependency)
```

uygun Loading/Error state üretir.

Convenience/capability fallback:

```text
last focus
manual annual marker
resource context preference
lesson-plan capability unavailable
```

ana içeriği bloke etmez.

Lesson-plan progress mutation/undo failure görünür feedback üretir; canonical plan içeriğini okunamaz hâle getirmez.

## 15. Validation gate

Her merge öncesi:

```text
flutter analyze
runtime contract TDE9–TDE12
flutter test
flutter build apk --release
APK runtime asset verification
```

Regresyon testleri ayrıca DEHB ve lesson-plan sözleşmesini korur: tracking-free primary flow, continuity independence, autosave/Undo, lesson-plan real Undo, context-aware resources, temporary annual marker, capability-safe TDE11/TDE12 fallback ve truthful progress semantics.
