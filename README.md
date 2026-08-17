# ÖğretmenOS

![Flutter CI](https://github.com/knigdelioglu/OgretmenOS/actions/workflows/flutter-ci.yml/badge.svg)

Offline-first Flutter öğretmen uygulaması. Ana ürün yüzü artık haftalık **kazanım takibi**dir: öğretmen derse girerken o haftanın doğrulanmış TDE 9 kazanımlarını görür, işlenme durumunu yerel olarak takip eder ve ders defteri için gerekli program/kitap/materyal bağlamına ulaşır.

## Veri sınırları

### Read-only course knowledge

```text
assets/courses/TDE_9/course_runtime.sqlite
assets/courses/TDE_9/runtime_manifest.json
```

Runtime canonical source değildir; `knigdelioglu/tymm` içindeki deterministik compiler çıktısının uygulama kopyasıdır. Uygulama bu DB'ye yazmaz.

### Versioned academic calendar

```text
assets/calendars/calendar_index.json
assets/calendars/academic_calendar_2026_2027.json
```

Takvim ve scheduling profile feature code içine gömülmez.

### Local teacher state

```text
ogretmen_os_teacher_state.sqlite
```

Bu uygulama-local DB yalnız kazanım takip durumunu, kısa öğretmen notunu, optional gerçekleşen saati ve haftaya taşıma bilgisini saklar. Runtime/calendar güncellemesi bu veriyi silmez.

## Ana kullanım

Uygulama şu navigasyonla açılır:

```text
Kazanımlar
Haftalık
Yıllık Plan
Paket
```

`Kazanımlar` varsayılan ekrandır.

Bir haftada öğretmen:

- kart tabanlı kazanımları görür;
- `Planlı`, `Devam ediyor`, `Kısmen işlendi`, `İşlendi`, `Sarktı` durumlarını kullanır;
- kazanımı sonraki bir öğretim haftasına taşıyabilir;
- kısa yerel not ekleyebilir;
- `Deftere Bakış` özetini panoya kopyalayabilir;
- kazanıma dokunup doğrulanmış blok, kitap, etkinlik, form, değerlendirme ve materyal bağlamına iner.

Planlanan yıllık program ile öğretmenin gerçekleşen takip durumu ayrı tutulur.

## Haftalık scheduling

Aktif 2026-2027 TDE 9 profile:

```text
Haftalık ders: 5 saat
Yıllık: 180 saat
4 tema × 45 saat
Tema başına 43 yapılandırılmış + 2 okul temelli
36 öğretim haftası = 180 saat
37. aktif hafta = Etkinlik Haftası
```

Canonical runtime blok başına resmî saat vermediği için 43 yapılandırılmış saat versioned profile'da planlama amacıyla `12 + 11 + 10 + 10` dağıtılır. UI bunu resmî blok süresi olarak sunmaz.

## Yeni akademik yıl

1. yeni `academic_calendar_YYYY_YYYY.json` eklenir;
2. gerekiyorsa scheduling profile güncellenir;
3. `calendar_index.json` aktif yıl girdisi değiştirilir;
4. toplu test/CI doğrulaması yapılır.

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

GitHub Actions kapıları:

```text
Analyze
Runtime Contract
Tests
Android Release Build
```

## Android signing

```sh
cp android/key.properties.example android/key.properties
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından yok sayılır. Release signing bilgisi repo içine commit edilmez.
