# TYMM Teacher OS

![Flutter CI](https://github.com/knigdelioglu/OgretmenOS/actions/workflows/flutter-ci.yml/badge.svg)

Offline-first Flutter uygulaması; doğrulanmış TDE_9 runtime paketini ve sürümlenmiş akademik takvim verisini kullanarak öğretmene blok, haftalık plan, kazanım, ders kitabı ve materyal görünümü sunar. V1 dağıtım hedefi Android'dir.

## Veri kaynakları

Course knowledge:

```text
assets/courses/TDE_9/course_runtime.sqlite
assets/courses/TDE_9/runtime_manifest.json
```

Academic calendar:

```text
assets/calendars/calendar_index.json
assets/calendars/academic_calendar_2026_2027.json
```

Course runtime canonical source of truth değildir; `knigdelioglu/tymm` reposundaki deterministik compiler çıktısının uygulama kopyasıdır.

```text
knigdelioglu/tymm
courses/TDE_9/runtime/
```

Yerel canonical runtime yenilendiğinde:

```sh
dart run tool/sync_course_runtime.dart
```

komutu app asset kopyasını senkronize eder ve compatibility/freshness contract'ını doğrular.

## Haftalık plan

Aktif akademik yıl `calendar_index.json` üzerinden seçilir. Yıllık tarihler Flutter source code içine gömülmez.

2026-2027 TDE 9 scheduling profile:

```text
Haftalık ders: 5 saat
Yıllık toplam: 180 saat
4 tema × 45 saat
Tema başına: 43 yapılandırılmış + 2 okul temelli planlama
İlk 36 aktif okul haftası: curriculum planı
37. aktif okul haftası: Etkinlik Haftası
```

Canonical TYMM verisi blok başına resmî süre vermediğinden, 43 yapılandırılmış saat haftalık plan üretimi için versioned profile'da `12 + 11 + 10 + 10` olarak sıralı bloklara dağıtılır. Bu değerler öğretmen ekranında **planlama dağıtımı** olarak sunulur; resmî blok süresi olarak gösterilmez.

Öğretmen `Haftalık Plan` ekranında herhangi bir okul haftasını (ör. 3. hafta) seçip o haftaya düşen blokları, saatleri ve runtime'dan gelen doğrulanmış kazanımları görebilir.

## Yeni akademik yıl güncellemesi

Yeni yıl için feature code değiştirmek yerine:

1. yeni `academic_calendar_YYYY_YYYY.json` eklenir,
2. course scheduling profile doğrulanır/güncellenir,
3. `calendar_index.json` içindeki `active_academic_year` değiştirilir,
4. testler ve CI çalıştırılır.

## Doğrulama

```sh
flutter pub get
flutter analyze
flutter test
cd tool/runtime_verifier && dart pub get && dart run bin/verify_runtime.dart
flutter build apk --release
```

GitHub Actions kapıları:

```text
Analyze
Runtime Contract
Tests
Android Release Build
```

Runtime Contract gerçek versioned `course_runtime.sqlite` üzerinde manifest, freshness evidence, row count, sequence ve kritik ilişkileri doğrular. Tests job'ı gerçek bundled runtime ve akademik takvim planning testlerini çalıştırır.

## Android release signing

Gerçek dağıtım için:

```sh
cp android/key.properties.example android/key.properties
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından yok sayılır. Release build debug anahtarı kullanmaz; `key.properties` mevcutsa tanımlanan release anahtarıyla imzalanır.

Uygulama course runtime SQLite dosyasını uygulamaya özel dizinde salt-okunur açar. Öğretmen konumu gibi izinli yerel durum `shared_preferences` içinde ayrı tutulur.
