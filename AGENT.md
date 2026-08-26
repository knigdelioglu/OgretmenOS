# AGENT.md — ÖğretmenOS Agent Execution Protocol

> **Document version:** 1.3.2  
> **Status:** Binding execution protocol

## 0. Authority

Kod değişikliğinden önce sırayla oku:

1. `docs/PRODUCT_SCOPE.md`
2. `docs/FLUTTER_BLUEPRINT.md`
3. `AGENT.md`

Belge çatışması varsa yüksek otorite kazanır; çatışmayı çözmeden eski davranışı restore etme.

## 1. Mission

Öğretmenin **uygulamayı aç → şu anki dersi gör → gereken doğrulanmış bilgiyi al → çık** akışını en düşük karar yüküyle destekle.

**Tracking isteğe bağlıdır. `İşlendi` zorunlu değildir.** Tracking kullanan öğretmen için veri güvenilir ve geri alınabilir olmalıdır; kullanmayan öğretmen için ana ders akışı eksik/geride görünmemelidir.

Lesson-plan capability varsa doğrulanmış ders planını mevcut ders bağlamından erişilebilir kıl; capability yoksa ana akışı bozmadan sessizce fallback yap.

## 2. Hard invariants

- Canonical TYMM runtime read-only.
- Curriculum facts ve lesson-plan content Dart'ta hardcode edilmez.
- Runtime/calendar update teacher state'i silmez.
- Planned schedule != outcome tracking != lesson-plan progress != last-viewed continuity.
- Viewing an outcome veya lesson plan tracking/progress kaydı oluşturmaz.
- Tracking/progress status continuity oluşturmaz/silmez.
- Convenience preference failure authoritative content'i bloke etmez.
- Lesson-plan capability yokluğu normal fallback'tir; TDE_11/TDE_12 için hata üretme.
- Lesson-plan progress yalnız current package `payload_sha256` ile eşleşiyorsa current kabul edilir.
- Stale/missing hash progress completed veya in-progress gibi projekte edilmez ve otomatik silinmez.
- Teacher note silent-loss kabul etmez.
- Position != progress/completion percentage.
- Missing tracking/progress row kullanıcıya borç/eksik iş olarak gösterilmez.
- No backend/account/telemetry/AI dependency for V1 core.

## 3. Active product surfaces

Top-level:

```text
Bu Hafta
Yıllık
Kaynaklar
```

Default `Bu Hafta`.

Supporting routed details:

```text
OutcomeDetailPage
BlockDetailPage
LessonPlanPage
```

`LessonPlanPage` yeni top-level destination değildir. Eski `Kazanımlar / Haftalık / Paket` top-level yapısını veya unrouted legacy pages'i scope revizyonu olmadan yeniden bağlama.

## 4. Bu Hafta UX gate

- Tek dominant `ŞİMDİ` card.
- Primary CTA `Ders ayrıntısını aç`.
- Direct `Başla/İşlendi` primary button yok.
- Tracking overflow/disclosure altında optional.
- Default planned status badge/text yok.
- Completed/carry groups explicit teacher-marking dili kullanır.
- Lesson-plan entry yalnız runtime capability usable ise secondary action olarak görünür.
- Lesson-plan capability için top-level navigation ekleme.
- Stale lesson-plan progress varsa `Plan güncellendi / yeniden işaretle` açık metni göster; yalnız renge güvenme.

## 5. Continuity

`LastFocusState` last-viewed lesson'dır. View event detail navigation öncesi best-effort yazılır.

Read/write/cleanup failure navigation veya weekly content'i engelleyemez. Stale academic year/tracking key güvenle temizlenir veya yok sayılır.

Lesson-plan progress continuity state'i değildir ve continuity side effect'i üretemez.

## 6. Detail, notes and mutation safety

Outcome detail information-first kalır. Tracking `Daha fazla bilgi` altında optionaldır.

Not sistemi:

```text
700ms autosave
back/lifecycle flush
save failure => no silent exit
retry feedback
```

Outcome tracking/carry mutationları Undo sunar ve newer note/hours'u ezmez.

Lesson-plan status mutationları için P5 kuralı:

```text
mutation öncesi persisted LessonPlanProgressRecord? snapshot al
mutation persist edildikten sonra gerçek Geri al göster

previous == null
  → undo: created record delete
previous != null
  → undo: previous record exact save
```

Undo önceki `payloadSha256`, `status`, `startedAt`, `completedAt`, `updatedAt` değerlerini korur. Kullanıcı mutation sonrası başka pakete geçtiyse eski package'ın Undo işlemi yeni package'ın local status görünümünü overwrite etmemelidir. Undo failure kullanıcıya görünür feedback vermelidir.

Undo stale snapshot'ı geri getirirse stale state de geri gelmelidir; eski status current package'a yeniden uygulanmış gibi gösterilemez.

## 7. Lesson-plan runtime and progress boundary

Canonical plan source:

```text
course_runtime.sqlite
  lesson_plan_packages
        ↓ READ ONLY
LessonPlanKnowledgeRepository
```

Teacher-local progress:

```text
teacher_state.sqlite
  lesson_plan_progress
        ↓ READ/WRITE
LessonPlanProgressRepository
```

Progress identity:

```text
course_id + academic_year + package_id
```

Content validity:

```text
progress.payload_sha256 == package.payload_sha256
  → current

progress.payload_sha256 null / mismatch
  → stale
```

`payload_sha256` identity değildir; canonical package content binding kanıtıdır. Course-wide runtime fingerprint'i progress validity anahtarı yapma: unrelated package değişimi unaffected package progress'ini stale etmemelidir.

Semantics:

```text
missing row                  = Başlanmadı
matching in_progress         = Kısmen işlendi
matching completed           = İşlendi
missing/mismatched hash      = Plan güncellendi / yeniden gözden geçirilecek
```

Hash karşılaştırması için yalnız `LessonPlanProgressService.resolve/resolveRecord` kullan. UI veya başka service aynı karşılaştırmayı elle tekrar etmesin.

`LessonPlanProgressSnapshot.records` yalnız current-binding kayıtları taşır; stale identity'ler `stalePackageIds` üzerinden ayrı tutulur. Stale completed current/next veya all-completed hesabında completed sayılmaz.

`Başlanmadı` persisted row'u siler. `Kısmen işlendi/İşlendi` kaydı current canonical package hash'i olmadan oluşturulamaz. Stale record yeniden işaretlenirken eski `startedAt` yeni içeriğe taşınmaz; yeni timeline başlatılır.

Teacher-state schema v3'te `lesson_plan_progress.payload_sha256` nullable'dır yalnız migration uyumluluğu için. v2 hashesiz kayıtları backfill etme veya tahminen current sayma; koru ve stale kabul et.

TDE_9/TDE_10 lesson-plan runtime kullanılabilir; TDE_11/TDE_12 curriculum-only fallback'tir. Widget veya service package count/saat değerini hardcode ederek capability uyduramaz.

## 8. Resources

Context priority:

```text
last viewed lesson
→ current instructional week
→ fallback theme
```

Tema 1'e hardcoded reset yok. Context resolution failure resource access'i engellemez.

## 9. Annual

Temporary manual marker course-scoped ve timestamped'dır. Daha yeni viewed lesson eski marker'ı geçersiz kılar.

Annual sequence konumu yalnız `Sıra N / total` anlamındadır; progress bar veya completion yüzdesi üretme.

Optional tracking summary sadece explicit non-planned states sayar ve active course tracking keys ile scope edilir.

Lesson-plan progress annual outcome tracking summary'ye otomatik karıştırılmaz.

## 10. Data boundaries

```text
course_runtime.sqlite  READ ONLY canonical curriculum + lesson plans
calendar assets        READ ONLY
teacher_state.sqlite   READ/WRITE outcome tracking/note/carry + lesson_plan_progress
SharedPreferences      continuity/manual UI convenience
```

Widget raw SQL çalıştırmaz. Missing curriculum/lesson-plan relationship uydurulmaz.

Runtime replacement teacher-state DB'yi silmez. Content change destructive cleanup yerine binding-state resolution ile ele alınır.

## 11. Tracking identity

Outcome tracking identity için yalnız domain helper kullan:

```dart
outcomeTrackingKey(
  academicYear: ...,
  outcomeId: ...,
  plannedWeekNumber: ...,
)
```

Aynı string formatını UI/service içinde tekrar elle kurma.

Lesson-plan progress identity `courseId + academicYear + packageId` repository API'si üzerinden taşınır; UI key-string üretmez. `payloadSha256` identity'ye eklenmez.

## 12. Git safety

- Unrelated user work korunur.
- Feature/debt work current `main`den branch edilir.
- Kullanıcı uygulama istemişse PR + CI + merge akışı tamamlanabilir.
- Geçici patch workflow/script final diff'te bırakılmaz.
- Canonical runtime binary'sini text API ile yeniden üretmeye çalışma; runtime sync/publish workflow authority'sini kullan.

## 13. Validation

Final gate:

```text
flutter analyze
Runtime Contract TDE9/TDE10/TDE11/TDE12
flutter test
Android release APK
APK runtime asset verification
```

Tests yalnız happy path değil, convenience-state failure, stale/malformed state ve Undo persistence davranışlarını da kanıtlamalıdır.

Lesson-plan P5 content-binding değişikliğinde en az:

```text
same package id + same hash → progress current
same package id + changed hash → previous progress stale
v2 null hash → preserved + stale
stale completed → does not advance current package
stale reconfirm → new hash + new startedAt
mutation → Undo → exact previous hash/status/timestamps
```

kanıtlanmalıdır.

## 14. Pre-merge checklist

- binding docs active UX ile uyumlu;
- tracking optional;
- continuity independent;
- lesson-plan capability fallback safe;
- lesson plan top-level navigation değildir;
- no fake progress semantics;
- note/Undo safety preserved;
- lesson-plan status real Undo preserved;
- stale progress preserved but not treated current;
- payload hash binding package-level, runtime-wide değil;
- resources lesson-context aware;
- runtime read-only / teacher state separate;
- full CI green.
