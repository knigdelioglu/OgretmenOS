# PRODUCT_SCOPE.md — ÖğretmenOS V1.4

**Product:** ÖğretmenOS  
**Document version:** 1.4.1  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**Operation mode:** Offline-first, deterministic, local

## 1. Product definition

ÖğretmenOS öğretmenin uygulamayı açtığında mümkün olan en az karar yüküyle **hangi ders/sınıf bağlamında olması gerektiğini, o sınıfın planlanan ders konumunu ve gerekli doğrulanmış ders bilgisini** görmesini sağlar.

Birincil akış:

```text
uygulamayı aç
→ akademik takvim + resmî ders istisnaları + öğretmen programından bağlamı çöz
→ gerekirse ders/sınıf düzeyini otomatik değiştir
→ ŞİMDİ / SONRAKİ DERS
→ doğrulanmış ders planını veya ders ayrıntısını aç
→ yalnız gerekirse gerçek ilerlemeyi düzelt
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

Versioned akademik takvim asset'i okul yılı, tatil/ara tatil ve düzenli ders occurrence'ını iptal eden tarih/saat istisnalarının authority'sidir.

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

Assignment bazında ayrılan bilgiler:

- haftalık ders programı bağlantısı;
- gerçek ilerleme cursor'u;
- saat bazlı ders-planı işaretleri;
- outcome/kazanım takibi.

9/A'daki bir durum değişikliği 9/B veya 9/C'yi değiştiremez.

## 4. Ders programı, takvim istisnaları ve planlanan konum

Öğretmen bir kez okulun zil saatlerini ve haftalık programını tanımlar:

```text
BellPeriod
  period_number
  start_minute
  end_minute

LessonScheduleSlot
  assignment_id
  weekday
  period_number
```

Aynı akademik yılda öğretmenin iki farklı assignment'ı aynı `weekday + period_number` hücresini kullanamaz. Farklı akademik yıllar birbirini bloke etmez.

Düzenli haftalık slot tek başına ders occurrence üretmek için yeterli değildir. Takvim authority'si ayrıca dersin o gün/saat gerçekten yapılabilir olmasını doğrular:

```text
SchoolScheduleException
  date
  start_minute
  end_minute
  label
```

- Tam günlük tatil o tarihteki bütün normal ders occurrence'larını kaldırır.
- Yarım günlük/saate bağlı istisna yalnız zaman aralığıyla çakışan dersleri kaldırır.
- İptal edilen occurrence curriculum ordinal'ını tüketmez; sonraki gerçek ders bir sonraki ordinal olur.
- Ara tatil/event week mantığı ile günlük istisna birbirinden ayrıdır.

Takvim + program + zil saati yalnız **planlanan konumu** üretir. Ders saatinin geçmiş olması, dersin gerçekten işlendiğinin kanıtı değildir ve otomatik `completed` kaydı oluşturamaz.

## 5. Planlanan konum, gerçek konum ve explicit takip ayrımı

Üç ayrı kavram korunur:

```text
Planlanan konum
  → takvim, istisnalar ve ders programından deterministik hesaplanır

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

## 6. Otomatik ders/sınıf düzeyi bağlamı

Normal mod **ders programına göre otomatik**tir. Uygulama aktif akademik yıldaki bütün öğretmen assignment'larını aynı teacher-state üzerinden inceler.

Resolution:

```text
şu anda süren geçerli ders
→ yoksa bugün sıradaki geçerli ders
→ yoksa mevcut course context'i koru
```

Geçerli ders için:

- assignment aktif olmalı;
- haftalık program eksiksiz olmalı;
- slot o gün/saat için calendar exception ile iptal edilmemiş olmalı;
- aynı anda birden fazla aktif assignment bulunması veri tutarsızlığıdır.

Resolver başka desteklenen TDE course'u bulursa örneğin `TDE_9 → TDE_10` runtime context'i otomatik değişebilir. Böylece öğretmen 9. sınıf dersinden sonra 10. sınıf dersine geçerken course selector'ı elle değiştirmek zorunda kalmaz.

Kullanıcı course selector'dan bir sınıf düzeyini açıkça seçerse **manuel pin** oluşur ve otomatik course switching o oturumda durur. `Ders programına göre otomatik` seçimi pini kaldırır.

Bu resolver convenience/navigation context'tir. Hatası mevcut yüklenmiş canonical course içeriğini kapatamaz; uygulama mevcut bağlamla çalışmaya devam eder.

V1.4'te desteklenen TDE_9–TDE_12 profillerinin haftalık ders saati aynı olduğundan cross-course tam-program doğrulaması ortak weekly-hour sözleşmesini kullanabilir. Farklı haftalık saate sahip yeni ders alanları eklenirse resolver course-specific profile ile genişletilmelidir.

## 7. Bu Hafta UX sözleşmesi

Program kurulmuşsa `Bu Hafta` yüzeyi program bağlamını öne çıkarır:

```text
ŞİMDİKİ / SONRAKİ DERS
9/A
3. ders saati
Ders planını aç
```

Course düzeyi ve assignment seçimi varsayılan olarak programdan otomatik çözülür. Kullanıcı isterse geçici olarak başka bir şubeye bakabilir; başka şubeyi görüntülemek o şubeyi timetable gerçeğinde "şu anki ders" yapmaz.

Haftalık ders planında:

- geçmiş program saatleri `Programa göre geçildi` gibi planlama diliyle gösterilebilir;
- mevcut planlanan saat `ŞU AN` olarak işaretlenebilir;
- gerçek konum farklıysa `GERÇEK` ve `PLANLANAN` ayrımı açıkça gösterilir;
- hiçbir otomatik görsel durum teacher-local `completed` kaydı yazamaz.

Program eksikse schedule-aware `ŞİMDİ` üretilemez. Canonical haftalık içerik çalışmaya devam eder ve programı tamamlama aksiyonu sunulur.

Tracking kontrolleri ikincildir; normal akışta her satır için `İşlendi` tıklaması beklenmez.

## 8. Ders planı ilerleme sözleşmesi

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

Ders planını yalnız görüntülemek veya önceki/sonraki derse gezinmek progress kaydı oluşturmaz. Explicit durum mutationları gerçek Undo sunmalıdır.

## 9. Outcome/kazanım takibi

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

## 10. Continuity / Kaldığın Yer

Continuity son görüntülenen bağlamdır; tracking değildir.

Assignment seçiliyken assignment-scoped continuity tutulabilir. Kaynaklar ve yıllık plan gibi course-scoped yüzeylerin bağlam kaybetmemesi için son görüntülenen curriculum bağlamı ayrıca course-scoped convenience state olarak aynalanabilir.

Continuity hatası canonical içerik veya navigation'ı bloke edemez.

## 11. Eski teacher-state verisinin geçişi

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

## 12. Teacher-local mutable state

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

## 13. Kaynaklar ve yıllık plan

`Kaynaklar` canonical kaynak kataloğudur. Bağlam önceliği:

```text
son görüntülenen ders
→ mevcut öğretim haftası
→ güvenli tema fallback
```

`Yıllık` canonical öğretim sırasını gösterir. Konum tamamlanma yüzdesi değildir.

Assignment-aware tracking özetleri yalnız ilgili assignment scope'u açıkça belli olduğunda kullanılmalıdır. Course-wide legacy takip yeni şubelerin ortak gerçeği gibi sunulamaz.

### 13.1 Teacher Guide capability

Teacher Guide, ders ve sınıftan bağımsız, optional bir canonical runtime
capability'sidir. Kaynak zinciri:

```text
TYMM canonical Teacher Guide
→ validation
→ runtime projection/seal
→ read-only course_runtime.sqlite
→ TeacherGuideKnowledgeRepository
```

`Kaynaklar` Teacher Guide'ın primary UI sahibidir. Capability unavailable ise
Öğretmen Rehberi kategorisi hiç gösterilmez. Ders Planı ve Ders Bloğu tam rehber
içeriğini kopyalamaz; yalnız explicit canonical relation bulunduğunda ilgili
maddeye context action verir.

Teacher Guide item'ları herhangi bir canonical entity türüne açık relation
kayıtlarıyla bağlanabilir. Flutter başlık, sayfa veya ID benzerliğiyle bağ
kurmaz. Structured response, provenance ve `REVIEW_REQUIRED` durumu kayıpsız
taşınır ve öğretmene uygun rozet/metinle gösterilir. AI, PDF/EPUB viewer ve
canonical JSON asset okuma bu capability'nin parçası değildir.

Öğretmen notu canonical veri değildir. Notlar yalnız
`teacher_state.sqlite` içinde `(assignment_id, guide_item_id)` kapsamıyla
tutulur; runtime yenilense de silinmez. Canonical payload hash değişirse not
stale olarak işaretlenir ve öğretmenin gözden geçirmesi istenir.

## 14. Runtime/calendar invariants

Aktif 2026-2027 TDE profillerinde planning authority'den gelen temel sözleşme korunur:

```text
weekly_hours = 5
annual_hours = 180
instructional_weeks = 36
active_week_37 = EVENT_WEEK
EVENT_WEEK new curriculum hours = 0
```

Daily/partial-day `schedule_exceptions` 180 saatlik canonical yıllık curriculum budgetini yeniden yazmaz; yalnız öğretmenin gerçek takvim slotlarından türetilen occurrence/ordinal projeksiyonunu düzeltir.

Lesson-plan-aware TDE_9/TDE_10 runtime doğrulaması mevcut runtime manifest ve contract testlerinin authority'sidir. Feature widget'ları package/hour sayılarını uyduramaz veya hardcode edemez.

## 15. Offline/privacy boundary

Core kullanım kurulum sonrası offline çalışır. Bu çalışma backend, hesap, telemetry veya AI zorunluluğu getirmez.

Scope dışı kalanlar ayrıca ürün kararı gerektirir:

```text
student roster / attendance / grades
student mastery analytics
cloud sync/backend
MEBBİS/e-Okul entegrasyonu
curriculum editing
```

## 16. Required UX invariants

- Öğretmenden her ders için `İşlendi` tıklaması beklenmez.
- Aynı dersin farklı şubeleri bağımsızdır.
- Program konumu completion değildir.
- Takvimde iptal edilen normal ders ordinal tüketmez.
- Yarım günlük istisna yalnız çakışan zil aralıklarını iptal eder.
- Programdan otomatik hesaplanan geçmiş saatler DB'ye completed yazmaz.
- Normal course selection mode ders programına göre otomatiktir.
- Kullanıcının explicit course seçimi otomatik switching'i pinleyebilir; otomatik moda dönüş görünür olmalıdır.
- Otomatik course resolver hatası mevcut canonical içeriği bloke etmez.
- Gerçek ilerleme yalnız istisnada tek işlemle düzeltilir.
- Manuel başka şubeye bakmak takvim gerçeğini değiştirmez.
- Tracking isteğe bağlıdır.
- Bir dersi görüntülemek tracking oluşturmaz.
- Continuity tracking'den bağımsızdır.
- Lesson-plan capability yokluğu ana akışı bloke etmez.
- Teacher Guide capability yokluğu ana akışı bloke etmez; kategori görünmez.
- Teacher Guide capability truth'i manifest, projection tabloları, row count,
  validation ve seal kanıtlarıyla tutarlı olmalıdır.
- Stale hash explicit metinle gösterilir ve otomatik current sayılmaz.
- Legacy state şubeye tahmin yoluyla atanmaz.
- Konum completion yüzdesi değildir.
- Phone/tablet, large text ve dark mode kullanılabilir kalır.

## 17. Definition of success

V1.4 başarılıdır when a teacher can:

1. aynı veya farklı sınıf düzeylerinde verdiği dersleri/şubeleri ayrı tanımlamak;
2. zil saatlerini ve haftalık programını bir kez girmek;
3. uygulamayı açınca geçerli mevcut ya da bugünkü sonraki dersin course/şube bağlamına otomatik ulaşmak;
4. resmî tam/yarım günlük tatilde normal dersin yanlışlıkla `ŞİMDİ` görünmemesini sağlamak;
5. hiçbir `İşlendi` tıklaması yapmadan doğru planlanan ders ordinal'ına ulaşmak;
6. gerçek ilerleme farklıysa tek seçimle düzeltmek ve farkın sonraki derslerde korunmasını sağlamak;
7. şubeler arasında progress/outcome state sızıntısı yaşamamak;
8. program değiştiğinde gerçek konumun zıplamamasını sağlamak;
9. eski teacher-state verisini yalnız açıkça seçtiği şubeye güvenli biçimde kopyalamak;
10. canonical curriculum, lesson-plan ve mevcutsa Teacher Guide içeriğini
    teacher-local state'ten bağımsız ve doğrulanmış biçimde kullanmaya devam etmek;
11. Teacher Guide notlarının assignment'lar arasında sızmadığını ve runtime
    yenilemesinde kaybolmadığını görmek.
