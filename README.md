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

Senkronizasyon `PASS` manifest doğrulaması yapar ve `assets/courses/TDE_9/`
altında yerel build girdisi oluşturur. Bu dosyalar generated olduğu için Git'e
alınmaz.

## Doğrulama

```sh
flutter pub get
flutter analyze
flutter test
cd tool/runtime_verifier && flutter pub get && dart run bin/verify_runtime.dart
flutter build apk --release
```

GitHub Actions, `main` push'larında ve pull request'lerde `flutter analyze` ile
`flutter test` çalıştırır. Canonical runtime asset'leri Git'e alınmadığı için CI,
widget/unit test asset bundle'ı için yalnız geçici ve bilinçli olarak geçersiz
placeholder dosyaları üretir; gerçek runtime doğrulaması bu placeholder'ları
kullanmaz.

Host-only runtime verifier gerçek SQLite dosyasını salt-okunur açarak manifest,
ilişkiler ve data-source akışını kontrol eder. Uygulama runtime veritabanını
uygulamaya özel SQLite dizininde salt-okunur açar;
öğretmen konumu gibi izinli yerel durum `shared_preferences` içinde ayrı tutulur.
