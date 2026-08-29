# ÖğretmenOS

![Flutter CI](https://github.com/knigdelioglu/OgretmenOS/actions/workflows/flutter-ci.yml/badge.svg)

Offline-first Flutter öğretmen uygulaması. Ana akış **tracking yapmak değil, ders programından doğru ders/sınıf bağlamına hızlı ulaşmaktır**:

```text
uygulamayı aç
→ akademik takvim + zil saatleri + haftalık program
→ mevcut / bugünkü sonraki ders ve şube bağlamını çöz
→ doğrulanmış ders planını veya ders ayrıntısını aç
→ yalnız gerekirse gerçek ilerlemeyi düzelt
```

Tracking (`Devam ediyor / Kısmen / İşlendi / Taşındı`) tamamen isteğe bağlıdır. Bir ders saatinin geçmiş olması veya bir ders planının açılması otomatik `İşlendi` kaydı oluşturmaz.

## Ana navigasyon

```text
Bu Hafta
Plan
Kaynaklar
```

`Bu Hafta` varsayılan ekrandır. Aynı dersin 9/A, 9/B, 9/C gibi farklı şubeleri ayrı `TeachingAssignment` olarak tutulur; ilerleme ve kazanım takibi şubeler arasında sızmaz.

Course selector normalde **Ders programına göre otomatik** çalışır. Geçerli ders başka desteklenen sınıf düzeyindeyse uygulama örneğin TDE_9 → TDE_10 bağlamına geçebilir. Kullanıcı açıkça bir sınıf düzeyi seçerse otomatik geçiş o oturum için pinlenir; otomatik moda yeniden dönülebilir.

## Ders programı ve gerçek ilerleme

Öğretmen okulun zil saatlerini, girdiği şubeleri ve haftalık ders slotlarını bir kez tanımlar. Aynı akademik yılda iki assignment aynı gün/ders saati hücresini kullanamaz.

Üç kavram birbirinden ayrıdır:

```text
Planlanan konum
→ akademik takvim + resmî tam/yarım gün istisnaları + haftalık program

Gerçek konum
→ normalde planlanan konumu takip eder
→ öğretmen sapma varsa tek seçimle düzeltir

Explicit takip
→ isteğe bağlı Kısmen işlendi / İşlendi kaydı
```

Örneğin haftalık program Pazartesi 2 + Çarşamba 2 + Cuma 1 ise, öğretmen önceki dört derse `İşlendi` demese bile Cuma dersi planlanan **5. ders** olarak çözülür. Resmî tatil veya yarım gün nedeniyle iptal edilen normal ders ordinal tüketmez.

## DEHB odaklı UX sözleşmesi

- program kurulmuşsa mevcut/sonraki ders bağlamı baskındır;
- `İşlendi` zorunlu değildir;
- gerçek ilerleme yalnız istisnada tek işlemle düzeltilir;
- manuel başka şubeye bakmak timetable gerçeğini değiştirmez;
- teacher note autosave + başarısız kayıtta sessiz çıkış yok;
- tracking/carry işlemlerinde gerçek Undo;
- Kaynaklar: son görüntülenen ders → mevcut hafta → fallback tema;
- Plan canonical öğretim sırasıdır; konum tamamlanma yüzdesi değildir;
- işaretlenmemiş kazanımlar eksik sayılmaz.

Ayrıntılı bağlayıcı sözleşme: `docs/PRODUCT_SCOPE.md`, `docs/FLUTTER_BLUEPRINT.md` ve `AGENT.md`.

## Veri sınırları

### Read-only course knowledge

Versioned TYMM package runtime'ları `tymm-verileri/turk-dili-ve-edebiyati/<COURSE>/runtime/` altında tutulur ve uygulamada read-only kullanılır.

### Versioned academic calendar

```text
assets/calendars/calendar_index.json
assets/calendars/academic_calendar_2026_2027.json
```

Calendar asset'i dönem/ara tatil/event-week bilgisinin yanında normal ders occurrence'ını iptal eden tam veya kısmi gün `schedule_exceptions` bilgisini de taşır.

### Local teacher state

`teacher_state.sqlite` güncel şema V5'tir. Teacher-local state şunları içerir:

```text
school_classes
teaching_assignments
bell_periods
lesson_schedule_slots
assignment_progress_cursor
assignment_lesson_progress
assignment_outcome_tracking
```

Eski `lesson_plan_progress` ve `outcome_tracking` tabloları güvenli explicit migration kaynağı olarak korunur. Hangi şubeye ait olduğu bilinmeyen eski kayıt otomatik olarak ilk şubeye atanmaz; öğretmen hedef şubeyi açıkça onaylar. Runtime/calendar refresh teacher-state verisini silmez.

Continuity ve migration decision guard gibi convenience state SharedPreferences'ta tutulur.

## Tracking semantiği

Outcome storage/domain durumları:

```text
planned
in_progress
completed
partially_completed
carried_over
```

Missing row = `planned`, fakat UI bunu otomatik bir görev/borç gibi göstermez. Planned schedule, actual cursor, explicit tracking ve continuity ayrı gerçeklerdir.

Ders planı explicit takibi assignment + package + package hour bazındadır. `payload_sha256` yalnız canonical içerik bağlama kanıtıdır; hash uyuşmazlığı stale kabul edilir.

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
flutter build macos --release
```

## macOS

macOS desktop desteği hazırdır ve uygulama minimum macOS **27.0** olacak şekilde ayarlanmıştır. Yerel geliştirme veya release build için macOS 27+, Xcode 27+ ve Flutter stable gerekir:

```sh
flutter devices
flutter run -d macos
flutter build macos --release
```

Release uygulaması `build/macos/Build/Products/Release/ogretmen_os.app` altında oluşur. Uygulama offline-first olduğu için çalışma sırasında ağ veya ek servis gerekmez.

GitHub Actions ayrıca TDE9–TDE12 runtime contract ve APK içi runtime assetlerini doğrular.

## Android signing

```sh
cp android/key.properties.example android/key.properties
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından yok sayılır.
