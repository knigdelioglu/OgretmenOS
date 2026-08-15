# TYMM Teacher OS

![Flutter CI](https://github.com/knigdelioglu/OgretmenOS/actions/workflows/flutter-ci.yml/badge.svg)

Offline-first Flutter uygulaması; doğrulanmış TDE_9 runtime paketini salt-okunur
olarak sunar. V1 dağıtım hedefi Android'dir.

## Runtime paketi

Uygulamanın kullandığı versioned runtime girdileri:

```text
assets/courses/TDE_9/course_runtime.sqlite
assets/courses/TDE_9/runtime_manifest.json
assets/courses/TDE_9/runtime_validation_report.md
```

Bunlar canonical source of truth değildir; TYMM reposundaki deterministik runtime
compiler çıktısının uygulama kopyasıdır. Canonical kaynak repo:

```text
knigdelioglu/tymm
courses/TDE_9/runtime/
```

Yerel canonical runtime yenilendiğinde uygulama kopyası şu komutla senkronize
edilir:

```sh
dart run tool/sync_course_runtime.dart
```

Sync, startup compatibility contract'ını ve build-time freshness kanıtını
doğrular. Mevcut TDE_9 runtime paketi freshness sonucunu
`runtime_validation_report.md` içindeki `source fingerprint status = PASS /
RUNTIME_FRESH` kaydıyla taşır. Gelecekte compiler aynı bilgiyi manifest içindeki
`runtime_status` alanında verirse o kanıt da desteklenir.

## Doğrulama

Nihai doğrulama zinciri:

```sh
flutter pub get
flutter analyze
flutter test
cd tool/runtime_verifier && dart pub get && dart run bin/verify_runtime.dart
flutter build apk --release
```

GitHub Actions, `main` push'larında ve pull request'lerde şu ayrı kapıları
çalıştırır:

```text
Analyze
Runtime Contract
Tests
Android Release Build
```

`Runtime Contract` versioned gerçek `course_runtime.sqlite` üzerinde manifest,
freshness evidence, row count, sequence ve kritik ilişkileri doğrular. `Tests`
job'ı da gerçek bundled runtime'ı kullanan integration testlerini çalıştırır.
Placeholder runtime üretilmez. Bu kapılar geçtikten sonra Android release job'ı
aynı gerçek runtime ile release Gradle yolunu derler.

## Android release signing

Gerçek dağıtım için örneği kopyalayın ve kendi keystore bilgilerinizle doldurun:

```sh
cp android/key.properties.example android/key.properties
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından yok sayılır.
Release build debug anahtarı kullanmaz; `key.properties` mevcutsa tanımlanan
release anahtarıyla imzalanır.

Uygulama runtime veritabanını uygulamaya özel SQLite dizininde salt-okunur açar;
öğretmen konumu gibi izinli yerel durum `shared_preferences` içinde ayrı tutulur.
