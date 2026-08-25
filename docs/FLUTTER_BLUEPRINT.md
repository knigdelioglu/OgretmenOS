# ÖğretmenOS — Flutter Blueprint V1.3

**Belge sürümü:** 1.3.0  
**Durum:** Bağlayıcı teknik blueprint  
**Teknoloji:** Flutter + Dart + Material 3  
**Çalışma modu:** Offline-first / yerel / deterministik

`PRODUCT_SCOPE.md` üst otoritedir.

## 1. Architecture

```text
course_runtime.sqlite (read-only)
        ↓
CourseKnowledgeRepository

calendar/profile assets
        ↓
WeeklyPlanningService

teacher_state.sqlite (mutable optional tracking)
        ↓
OutcomeTrackingRepository

CourseKnowledgeRepository + WeeklyPlanningService + OutcomeTrackingRepository
        ↓
OutcomePlanningService
        ↓
Bu Hafta / Yıllık / Kaynaklar
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

## 3. Bu Hafta composition

```text
ContinuityThisWeekPage
  ├─ optional KALDIĞIN YER card
  └─ ThisWeekPage
       └─ single ŞİMDİ focus card
```

`ContinuityThisWeekPage` önce authoritative `OutcomePlanningService.buildPlan()` sonucunu yükler. Continuity read/cleanup hataları yakalanır ve weekly workspace yine render edilir.

`ThisWeekPage` detail açılmadan önce optional `onOutcomeViewed` callback'ini best-effort çağırır. Callback hatası navigation'ı bloke etmez.

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

## 7. Mutation safety

Status/carry/bulk tracking mutations persisted snapshot alır ve gerçek Undo sağlar. Status undo newer note/actual-hours state'ini ezmez.

Tracking optional olsa da kullanıldığında persistence authoritative teacher state'tir; mutation hataları sessizce başarı gibi gösterilemez.

## 8. Resources context resolver

Resolution order:

```text
valid last-viewed outcome
→ current week outcome/theme
→ first theme fallback
```

Resolver errors resource package access'ini engellemez. Manual theme selection yalnız mevcut Resources oturumu için override'dır.

## 9. Annual plan

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

## 10. Runtime truth

- `course_runtime.sqlite` read-only.
- Widgets raw SQL çalıştırmaz.
- Block-level relation outcome-specific gibi sunulmaz.
- UI missing canonical relationship üretmez.
- Calendar/year rules versioned assets'ten gelir.

## 11. Responsive/accessibility

- Material 3.
- Phone bottom navigation, tablet/desktop NavigationRail.
- Large text fixed-height cardlarla kırılmaz.
- Action groups overflow için `Wrap` kullanır.
- Dark mode scheme-based.
- Standard interactive target >= 48 logical px where audited.

## 12. Legacy feature code

Faz 0–6 öncesi top-level alternatif ekranlar active shell tarafından route edilmez. Unrouted duplicate implementations ürün authority'si değildir ve bakım borcu olarak kaldırılabilir. Aynı capability gerekiyorsa mevcut `Bu Hafta / Yıllık / Kaynaklar / OutcomeDetail / BlockDetail` akışları üzerinden geliştirilir.

## 13. Error hierarchy

Authoritative failures:

```text
runtime/course DB
weekly planning
tracking DB startup (production dependency)
```

uygun Loading/Error state üretir.

Convenience failures:

```text
last focus
manual annual marker
resource context preference
```

ana içeriği bloke etmez.

## 14. Validation gate

Her merge öncesi:

```text
flutter analyze
runtime contract TDE9–TDE12
flutter test
flutter build apk --release
APK runtime asset verification
```

Regresyon testleri ayrıca DEHB sözleşmesini korur: tracking-free primary flow, continuity independence, autosave/Undo, context-aware resources, temporary annual marker ve truthful progress semantics.
