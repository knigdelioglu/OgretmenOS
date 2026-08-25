# AGENT.md — ÖğretmenOS Agent Execution Protocol

> **Document version:** 1.3.0  
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

## 2. Hard invariants

- Canonical TYMM runtime read-only.
- Curriculum facts Dart'ta hardcode edilmez.
- Runtime/calendar update teacher state'i silmez.
- Planned schedule != classroom tracking != last-viewed continuity.
- Viewing an outcome tracking kaydı oluşturmaz.
- Tracking status continuity oluşturmaz/silmez.
- Convenience preference failure authoritative content'i bloke etmez.
- Teacher note silent-loss kabul etmez.
- Position != progress/completion percentage.
- Missing tracking row kullanıcıya borç/eksik iş olarak gösterilmez.
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
```

Eski `Kazanımlar / Haftalık / Paket` top-level yapısını veya unrouted legacy pages'i scope revizyonu olmadan yeniden bağlama.

## 4. Bu Hafta UX gate

- Tek dominant `ŞİMDİ` card.
- Primary CTA `Ders ayrıntısını aç`.
- Direct `Başla/İşlendi` primary button yok.
- Tracking overflow/disclosure altında optional.
- Default planned status badge/text yok.
- Completed/carry groups explicit teacher-marking dili kullanır.

## 5. Continuity

`LastFocusState` last-viewed lesson'dır. View event detail navigation öncesi best-effort yazılır.

Read/write/cleanup failure navigation veya weekly content'i engelleyemez. Stale academic year/tracking key güvenle temizlenir veya yok sayılır.

## 6. Detail and notes

Outcome detail information-first kalır. Tracking `Daha fazla bilgi` altında optionaldır.

Not sistemi:

```text
700ms autosave
back/lifecycle flush
save failure => no silent exit
retry feedback
```

Tracking/carry mutationları Undo sunar ve newer note/hours'u ezmez.

## 7. Resources

Context priority:

```text
last viewed lesson
→ current instructional week
→ fallback theme
```

Tema 1'e hardcoded reset yok. Context resolution failure resource access'i engellemez.

## 8. Annual

Temporary manual marker course-scoped ve timestamped'dır. Daha yeni viewed lesson eski marker'ı geçersiz kılar.

Annual sequence konumu yalnız `Sıra N / total` anlamındadır; progress bar veya completion yüzdesi üretme.

Optional tracking summary sadece explicit non-planned states sayar ve active course tracking keys ile scope edilir.

## 9. Data boundaries

```text
course_runtime.sqlite  READ ONLY
calendar assets        READ ONLY
teacher_state.sqlite   READ/WRITE optional tracking/note/carry
SharedPreferences      continuity/manual UI convenience
```

Widget raw SQL çalıştırmaz. Missing curriculum relationship uydurulmaz.

## 10. Tracking identity

Tracking identity için yalnız domain helper kullan:

```dart
outcomeTrackingKey(
  academicYear: ...,
  outcomeId: ...,
  plannedWeekNumber: ...,
)
```

Aynı string formatını UI/service içinde tekrar elle kurma.

## 11. Git safety

- Unrelated user work korunur.
- Feature/debt work current `main`den branch edilir.
- Kullanıcı uygulama istemişse PR + CI + merge akışı tamamlanabilir.
- Geçici patch workflow/script final diff'te bırakılmaz.

## 12. Validation

Final gate:

```text
flutter analyze
Runtime Contract TDE9/TDE10/TDE11/TDE12
flutter test
Android release APK
APK runtime asset verification
```

Tests yalnız happy path değil, convenience-state failure ve stale/malformed state davranışlarını da kanıtlamalıdır.

## 13. Pre-merge checklist

- binding docs active UX ile uyumlu;
- tracking optional;
- continuity independent;
- no fake progress semantics;
- note/Undo safety preserved;
- resources lesson-context aware;
- runtime read-only / teacher state separate;
- full CI green.
