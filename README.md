# ÖğretmenOS

![Flutter CI](https://github.com/knigdelioglu/OgretmenOS/actions/workflows/flutter-ci.yml/badge.svg)

Offline-first Flutter öğretmen uygulaması. Ana akış **tracking yapmak değil, mevcut ders bağlamına hızlı ulaşmaktır**:

```text
Bu Hafta / ŞİMDİ
→ Ders ayrıntısını aç
→ doğrulanmış program/kitap/etkinlik/kaynak bilgisini kullan
```

Tracking (`Devam ediyor / Kısmen / İşlendi / Taşındı`) tamamen isteğe bağlıdır.

## Ana navigasyon

```text
Bu Hafta
Yıllık
Kaynaklar
```

`Bu Hafta` varsayılan ekrandır. Son görüntülenen ders `KALDIĞIN YER` olarak korunur; bu continuity bilgisi tracking statüsünden bağımsızdır.

## DEHB odaklı UX sözleşmesi

- tek baskın `ŞİMDİ` odağı;
- primary CTA `Ders ayrıntısını aç`;
- `İşlendi` zorunlu değil;
- teacher note autosave + başarısız kayıtta sessiz çıkış yok;
- tracking/carry işlemlerinde gerçek Undo;
- Kaynaklar: son görüntülenen ders → mevcut hafta → fallback tema;
- Yıllık manuel konum geçici, course-scoped ve yeni ders görüntülemesiyle otomatik güncellenir;
- blok konumu tamamlanma yüzdesi değildir;
- işaretlenmemiş kazanımlar eksik sayılmaz.

Ayrıntılı bağlayıcı sözleşme: `docs/PRODUCT_SCOPE.md` ve `docs/FLUTTER_BLUEPRINT.md`.

## Veri sınırları

### Read-only course knowledge

Versioned TYMM package runtime'ları `tymm-verileri/turk-dili-ve-edebiyati/<COURSE>/runtime/` altında tutulur ve uygulamada read-only kullanılır.

### Versioned academic calendar

```text
assets/calendars/calendar_index.json
assets/calendars/academic_calendar_2026_2027.json
```

### Local teacher state

`teacher_state.sqlite` yalnız optional outcome tracking, kısa teacher note, actual hours ve carry bilgisini saklar. Continuity/manual marker SharedPreferences convenience state'tir. Runtime/calendar refresh bu state'i silmez.

## Tracking semantiği

Storage/domain durumları:

```text
planned
in_progress
completed
partially_completed
carried_over
```

Missing row = `planned`, fakat UI bunu otomatik bir görev/borç gibi göstermez. Planned schedule ile explicit classroom tracking ayrı gerçeklerdir.

## Runtime sync

```sh
dart run tool/sync_course_runtime.dart
```

## Final validation

```sh
flutter pub get
flutter analyze
cd tool/runtime_verifier && dart pub get && dart run bin/verify_runtime.dart
cd ../..
flutter test
flutter build apk --release
```

GitHub Actions ayrıca TDE9–TDE12 runtime contract ve APK içi runtime assetlerini doğrular.

## Android signing

```sh
cp android/key.properties.example android/key.properties
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından yok sayılır.
