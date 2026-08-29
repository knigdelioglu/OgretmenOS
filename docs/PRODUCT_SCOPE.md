# PRODUCT_SCOPE.md — ÖğretmenOS V1.4

**Product:** ÖğretmenOS  
**Document version:** 1.4.0  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**Operation mode:** Offline-first, deterministic, local

## 1. Product definition

ÖğretmenOS öğretmenin uygulamayı açtığında mümkün olan en az karar yüküyle **hangi sınıfta olması gerektiğini, o sınıfın planlanan ders konumunu ve gerekli doğrulanmış ders bilgisini** görmesini sağlar.

Birincil akış:

```text
uygulamayı aç
→ ders programından sınıf/şube bağlamını çöz
→ ŞİMDİ / SONRAKİ DERS
→ doğrulanmış ders planını veya ders ayrıntısını aç
→ gerekirse gerçek ilerlemeyi tek işlemle düzelt
→ çık
```

**Tracking isteğe bağlıdır.** Öğretmenin her ders sonunda `İşlendi` düğmesine basması normal kullanımın ön koşulu değildir.

## 2. Authority and truth boundary

Authority order:

```text
1. PRODUCT_SCOPE.md
2. FLUTTER_BLUEPRINT.md
3. AGENT.md
```

Canonical TYMM bilgisi yalnız doğrulanmış runtime paketinden gelir:

```text
Canonical TYMM Knowledge
→ deterministic runtime compiler
→ course_runtime.sqlite
→ read-only CourseKnowledgeRepository
```

Sınıf/şube, zil saatleri, öğretmenin haftalık ders programı, gerçek ilerleme sapması ve explicit takip durumları **teacher-local state**'tir. Bunlar canonical curriculum gerçeği değildir.

## 3. Temel öğretim bağlamı

Aynı ders birden fazla şubede verilebilir. Runtime ders içeriği kopyalanmaz; öğretmen state'i şube bazında ayrılır.

```text
Course
  ├─ TeachingAssignment → 9/A
  ├─ TeachingAssignment → 9/B
  └─ TeachingAssignment → 9/C
```

`TeachingAssignment` kimliği:

```text
academic_year + course_id + class_id
```

Aşağıdaki bilgiler assignment bazlı tutulur:

- haftalık ders programı bağlantısı;
- gerçek ilerleme cursor'u;
- saat bazlı ders-planı işaretleri;
- outcome/kazanım takibi.

9/A'daki bir durum değişikliği 9/B veya 9/C'yi değiştiremez.

## 4. Ders programı ve planlanan konum

Öğretmen bir kez okulun zil saatlerini ve haftalık programını tanımlar:

```text
BellPeriod
  period_number
  start_minute
  end_minute

LessonScheduleSlot
  assignment_id
  academic_year
  weekday
  period_number
```

Aynı akademik yılda öğretmenin iki farklı assignment'ı aynı `weekday + period_number` hücresini kullanamaz. Farklı akademik yıllar birbirini bloke etmez.

Takvim + program + saat yalnız **planlanan konumu** üretir. Ders saatinin geçmiş olması, dersin gerçekten işlendiğinin kanıtı değildir ve otomatik `completed` kaydı oluşturamaz.

## 5. Planlanan konum, gerçek konum ve explicit takip ayrımı

Üç ayrı kavram korunur:

```text
Planlanan konum
  → takvim ve ders programından deterministik hesaplanır

Gerçek konum
  → varsayılan olarak planlanan konumu takip eder
  → öğretmen sapma varsa tek seferlik düzeltir

Explicit takip
  → öğretmenin isteğe bağlı Kısmen işlendi / İşlendi işaretidir
```

Bunlar birbirinin yerine kullanılamaz.

### 5.1 Cursor

Normal mod:

```text
followSchedule
actualOrdinal = plannedOrdinal
```

Sapma modu:

```text
manualOffset
actualOrdinal = actualOrdinalAtAnchor
              + (plannedOrdinal - plannedOrdinalAtAnchor)
```

Örneğin planlanan 5. ders, gerçek 3. ders olarak düzeltilirse sonraki planlanan ders geldiğinde gerçek konum da bir saat ilerler; öğretmenden tekrar tekrar veri girişi istenmez.

`Programa yeniden eşitle` tekrar `followSchedule` moduna döndürür.

Ders programı değiştirildiğinde cursor yeniden anchor edilir; öğretmenin gerçek konumu program düzenlemesi yüzünden zıplayamaz.

## 6. Bu Hafta UX sözleşmesi

Program kurulmuşsa `Bu Hafta` yüzeyi program bağlamını öne çıkarır:

```text
ŞİMDİKİ / SONRAKİ DERS
9/A
3. ders saati
Ders planını aç
```

Sınıf seçimi varsayılan olarak programdan otomatik çözülür. Kullanıcı isterse geçici olarak başka bir şubeye bakabilir; başka şubeyi görüntülemek o şubeyi "şu anki ders" yapmaz.

Haftalık ders planında:

- geçmiş program saatleri `Programa göre geçildi` gibi planlama diliyle gösterilebilir;
- mevcut planlanan saat `ŞU AN` olarak işaretlenebilir;
- gerçek konum farklıysa `GERÇEK` ve `PLANLANAN` ayrımı açıkça gösterilir;
- hiçbir otomatik görsel durum teacher-local `completed` kaydı yazamaz.

Tracking kontrolleri ikincildir; normal akışta her satır için `İşlendi` tıklaması beklenmez.

Program henüz kurulmamışsa uygulama canonical haftalık ders içeriğini göstermeye devam eder ve program kurma aksiyonu sunabilir. Program eksikliği ana içeriği error state'e çeviremez.

## 7. Ders planı ilerleme sözleşmesi

Canonical plan içeriği read-only runtime bilgisidir. Explicit ders durumu teacher-local state'tir.

Assignment-aware kimlik:

```text
assignment_id + package_id + package_hour
```

Semantik:

```text
kayıt yok                   = explicit takip yok
matching hash + in_progress = Kısmen işlendi
matching hash + completed   = İşlendi
missing/mismatched hash     = Plan güncellendi / yeniden gözden geçirilecek
```

`payload_sha256` identity değildir; canonical package content binding kanıtıdır.

Ders planını yalnız görüntülemek progress kaydı oluşturmaz. Önceki/sonraki derse gezinmek de otomatik completion üretmez.

Explicit durum mutationları gerçek Undo sunmalıdır.

## 8. Outcome/kazanım takibi

Assignment-aware outcome identity:

```text
assignment_id + outcome_id + planned_week_number
```

Valid statuslar:

```text
planned
in_progress
completed
partially_completed
carried_over
```

`planned` storage/domain fallback'ıdır; kullanıcı borcu veya eksik iş değildir.

Outcome tracking ile ders-planı progress'i ayrı kanallardır. Biri diğerini otomatik değiştirmez.

## 9. Continuity / Kaldığın Yer

Continuity son görüntülenen bağlamdır; tracking değildir.

Assignment seçiliyken assignment-scoped continuity tutulabilir. Kaynaklar ve yıllık plan gibi course-scoped yüzeylerin bağlam kaybetmemesi için son görüntülenen curriculum bağlamı ayrıca course-scoped convenience state olarak aynalanabilir.

Continuity hatası canonical içerik veya navigation'ı bloke edemez.

## 10. Eski teacher-state verisinin geçişi

Legacy tablolar mevcut kullanıcı verisini korumak için tutulur. Eski kayıtların hangi şubeye ait olduğu güvenilir biçimde bilinmiyorsa uygulama tahmin yapamaz.

Geçiş sözleşmesi:

```text
legacy kayıt bulundu
→ öğretmen şubeyi açıkça seçer
→ kayıtlar seçilen assignment'a kopyalanır
→ legacy kayıtlar silinmez
→ mevcut assignment kayıtları overwrite edilmez
```

Birden fazla şube olduğunda otomatik 9/A/9/B eşlemesi yasaktır.

Legacy migration decision yalnız duplicate-import guard'dır; curriculum authority değildir.

## 11. Teacher-local mutable state

`teacher_state.sqlite` güncel assignment-aware alanları:

```text
school_classes
teaching_assignments
bell_periods
lesson_schedule_slots
assignment_progress_cursor
assignment_lesson_progress
assignment_outcome_tracking
```

Geçiş güvenliği için legacy alanlar da korunur:

```text
lesson_plan_progress
outcome_tracking
```

SharedPreferences:

```text
last viewed continuity
course-scoped annual marker
legacy migration decision guard
UI preferences
```

Runtime/calendar güncellemesi teacher-state verisini sessizce silemez.

## 12. Kaynaklar ve yıllık plan

`Kaynaklar` canonical kaynak kataloğudur. Bağlam önceliği:

```text
son görüntülenen ders
→ mevcut öğretim haftası
→ güvenli tema fallback
```

`Yıllık` canonical öğretim sırasını gösterir. Konum tamamlanma yüzdesi değildir.

Assignment-aware tracking özetleri yalnız ilgili assignment scope'u açıkça belli olduğunda kullanılmalıdır. Course-wide legacy takip yeni şubelerin ortak gerçeği gibi sunulamaz.

## 13. Runtime/calendar invariants

Aktif TDE_9 2026-2027 profilinde runtime/planning authority'den gelen temel sözleşme korunur:

```text
weekly_hours = 5
annual_hours = 180
instructional_weeks = 36
active_week_37 = EVENT_WEEK
EVENT_WEEK new curriculum hours = 0
```

Lesson-plan-aware TDE_9/TDE_10 runtime doğrulaması mevcut runtime manifest ve contract testlerinin authority'sidir. Feature widget'ları package/hour sayılarını uyduramaz veya hardcode edemez.

## 14. Offline/privacy boundary

Core kullanım kurulum sonrası offline çalışır. Bu çalışma backend, hesap, telemetry veya AI zorunluluğu getirmez.

Scope dışı kalanlar ayrıca ürün kararı gerektirir:

```text
student roster / attendance / grades
student mastery analytics
cloud sync/backend
MEBBİS/e-Okul entegrasyonu
curriculum editing
```

## 15. Required UX invariants

- Öğretmenden her ders için `İşlendi` tıklaması beklenmez.
- Aynı dersin farklı şubeleri bağımsızdır.
- Program konumu completion değildir.
- Programdan otomatik hesaplanan geçmiş saatler DB'ye completed yazmaz.
- Gerçek ilerleme yalnız istisnada tek işlemle düzeltilir.
- Manuel başka şubeye bakmak takvim gerçeğini değiştirmez.
- Tracking isteğe bağlıdır.
- Bir dersi görüntülemek tracking oluşturmaz.
- Continuity tracking'den bağımsızdır.
- Lesson-plan capability yokluğu ana akışı bloke etmez.
- Stale hash explicit metinle gösterilir ve otomatik current sayılmaz.
- Legacy state şubeye tahmin yoluyla atanmaz.
- Konum completion yüzdesi değildir.
- Phone/tablet, large text ve dark mode kullanılabilir kalır.

## 16. Definition of success

V1.4 başarılıdır when a teacher can:

1. aynı dersi verdiği 9/A, 9/B, 9/C gibi şubeleri ayrı tanımlamak;
2. zil saatlerini ve haftalık programını bir kez girmek;
3. uygulamayı açınca programdan mevcut/sonraki sınıfı görmek;
4. hiçbir `İşlendi` tıklaması yapmadan haftanın doğru planlanan ders saatine ulaşmak;
5. gerçek ilerleme farklıysa tek seçimle düzeltmek ve farkın sonraki derslerde korunmasını sağlamak;
6. şubeler arasında progress/outcome state sızıntısı yaşamamak;
7. program değiştiğinde gerçek konumun zıplamamasını sağlamak;
8. eski teacher-state verisini yalnız açıkça seçtiği şubeye güvenli biçimde kopyalamak;
9. canonical curriculum ve lesson-plan içeriğini teacher-local state'ten bağımsız ve doğrulanmış biçimde kullanmaya devam etmek.
