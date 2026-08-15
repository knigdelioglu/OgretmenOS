# TYMM Teacher OS

![Flutter CI](https://github.com/knigdelioglu/OgretmenOS/actions/workflows/flutter-ci.yml/badge.svg)

Offline-first Flutter uygulaması; doğrulanmış TDE_9 runtime paketini salt-okunur
olarak sunar. V1 dağıtım hedefi Android'dir.

## Runtime paketi

Flutter asset'leri canonical knowledge deposundan kopyalanmaz; yalnızca derlenmiş
runtime SQLite ve manifest senkronize edilir:

```sh
dart run tool/sync_course_runtime.dart
```

Senkronizasyon `PASS` + `RUNTIME_FRESH` manifest doğrulaması yapar ve
`assets/courses/TDE_9/` altında yerel build girdisi oluşturur. Bu dosyalar
generated olduğu için Git'e alınmaz.

## Doğrulama

```sh
flutter pub get
flutter analyze
flutter test
cd tool/runtime_verifier && dart pub get && dart run bin/verify_runtime.dart
flutter build apk --release
```

GitHub Actions, `main` push'larında ve pull request'lerde ayrı **Analyze** ve
**Tests** kontrolleri çalıştırır. Bu kontroller geçtikten sonra **Android Release
Build** kapısı gerçek release Gradle yolunu derler. CI signing anahtarı koşu
sırasında geçici üretilir ve dağıtım için kullanılmaz.

Canonical runtime asset'leri Git'e alınmadığı için CI asset bundle aşamasında
geçici placeholder dosyaları kullanır. Repository/data-source SQL sözleşmesi ise
in-memory SQLite runtime fixture ile test edilir. Gerçek canonical runtime paketi
mevcut olduğunda `runtime_verifier` manifest, row count ve ilişkileri salt-okunur
DB üzerinde doğrular.

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
