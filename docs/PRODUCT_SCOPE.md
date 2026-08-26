# PRODUCT_SCOPE.md — ÖğretmenOS V1.3

**Product:** ÖğretmenOS  
**Document version:** 1.3.1  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**Operation mode:** Offline-first, deterministic, local

## 1. Product definition

ÖğretmenOS öğretmenin derse girerken **şu anki ders bağlamını mümkün olan en az karar yüküyle** görmesini sağlar. Birincil akış:

```text
uygulamayı aç
→ Bu Hafta / ŞİMDİ
→ ders bağlamını ve gerekli doğrulanmış bilgiyi gör
→ gerekirse ayrıntı/kaynak/ders planı aç
→ çık
```

**Tracking isteğe bağlıdır.** Bir kazanımı veya ders planını görüntülemek, derse hazırlanmak ya da uygulamadan çıkmak için `Başla`, `İşlendi` veya başka bir tracking durumu zorunlu değildir.

## 2. Authority and truth boundary

Authority order:

```text
1. PRODUCT_SCOPE.md
2. FLUTTER_BLUEPRINT.md
3. AGENT.md
```

Canonical TYMM knowledge yalnız doğrulanmış runtime paketinden gelir:

```text
Canonical TYMM Knowledge
→ deterministic runtime compiler
→ course_runtime.sqlite
→ read-only CourseKnowledgeRepository
```

Ders planı paketleri de canonical runtime bilgisidir. Uygulama runtime outcome/theme/block/textbook/activity/assessment/lesson-plan ilişkilerini değiştirmez veya uydurmaz.

## 3. Primary navigation

Top-level navigation yalnız üç öğretmen işidir:

```text
Bu Hafta
Yıllık
Kaynaklar
```

Default surface `Bu Hafta`dır.

`Ders Planı` yeni bir top-level navigation item değildir; mevcut ders/hafta bağlamından açılan supporting detail yüzeyidir. Legacy `Kazanımlar / Haftalık / Paket` ekranları top-level ürün navigasyonu değildir. Tracking, haftalık ders akışının ikincil/isteğe bağlı bir özelliğidir.

## 4. Bu Hafta — single focus contract

`Bu Hafta` tek baskın `ŞİMDİ` odağı sunar. Birincil CTA:

```text
Ders ayrıntısını aç
```

Varsayılan `planned` durumu kullanıcıya eksik iş, ilerleme veya yapılacaklar listesi gibi sunulmaz. Explicit öğretmen durumları yalnız kullanıcı gerçekten işaretlediyse `Takip: ...` olarak görünür.

İsteğe bağlı işlemler:

```text
Devam ediyor olarak işaretle
İşlendi olarak işaretle
Kısmen işlendi
sonraki öğretim haftasına taşı
hızlı öğretmen notu
```

Bu işlemler ana CTA değildir.

Lesson-plan capability kullanılabilir olduğunda haftalık/blok bağlamı `Bu dersin planı` gibi ikincil bir entry sunabilir. Capability yoksa veya fail-closed ise bu entry gösterilmez; ana ders akışı hata vermez.

## 5. Continuity / Kaldığın Yer

`LastFocusState` **son görüntülenen ders bağlamıdır**, tracking durumu değildir.

- outcome detail açılması continuity kaydını günceller;
- status değişikliği continuity oluşturmaz veya silmez;
- `completed` olmak son görüntülenen dersi yok etmez;
- continuity okuma/yazma/temizleme hatası ana ders içeriğini bloke edemez;
- stale veya bozuk continuity state güvenle yok sayılır.

## 6. Ders ayrıntısı

Ders ayrıntısı bilgi-first yüzeydir. `Derste lazım` bölümü official outcome, hafta/blok/tema, kitap/etkinlik ipuçları ve varsa öğretmen notunu öne çıkarır.

Tracking kontrolleri yalnız `Daha fazla bilgi → Takip seçenekleri` altında bulunur. Varsayılan durum `İsteğe bağlı · Takip yok` olarak sunulur.

Öğretmen notu otomatik kaydolur; kayıt başarısızsa sessiz veri kaybına izin verilmez ve sayfadan çıkış engellenir.

## 7. Ders planı paketleri ve P5 ilerleme sözleşmesi

TDE_9/TDE_10 lesson-plan-aware runtime kullanılabilir olduğunda öğretmen, mevcut blok/hafta bağlamından `LessonPlanPage` açabilir. Yüzey:

```text
plan başlığı ve özeti
plan konumu / kalan blok saati
kazanımlar
sonraki adım
saat bazlı ders akışı
önceki / sonraki paket navigasyonu
isteğe bağlı ders durumu
```

Plan içeriği read-only canonical runtime bilgisidir. Progress ise teacher-local mutable state'tir ve canonical paketi değiştirmez.

Lesson-plan progress semantiği:

```text
kayıt yok      = Başlanmadı
in_progress     = Kısmen işlendi
completed       = İşlendi
```

`Başlanmadı` seçimi persisted progress kaydını siler. `Kısmen işlendi` ve `İşlendi` teacher-local kayıt oluşturur/günceller. Bu durumlar kullanıcının seçtiği explicit işaretlerdir; uygulama planı yalnız görüntülediği için otomatik progress üretmez.

**Her ders planı durum mutasyonu gerçek Undo sunar.** Undo, mutasyondan önceki persisted snapshot'ı geri yükler; önce kayıt yoksa oluşturulan kayıt tamamen silinir, önce kayıt varsa önceki `status/started_at/completed_at/updated_at` değerleri aynen geri gelir. Yeni bir mutasyon eski Undo teklifinin yerini alır.

TDE_11/TDE_12 curriculum-only runtime için lesson-plan CTA gösterilmez ve bu eksiklik hata state'i değildir.

## 8. Kaynaklar

Kaynak ekranı tema 1'e körlemesine sıfırlanmaz. Bağlam önceliği:

```text
1. son görüntülenen ders
2. mevcut öğretim haftası
3. güvenli ilk-tema fallback
```

Bağlam convenience state'tir; okunamazsa kaynak erişimi yine çalışır. Manuel tema seçimi ekranda kalındığı sürece korunur; sekmeye yeniden girişte güncel ders bağlamı tekrar çözülür.

## 9. Yıllık plan

Yıllık plan canonical öğretim sırasını gösterir. `ŞU AN BURADASIN` konumu:

```text
son görüntülenen ders
veya daha yeni geçici manuel konum işareti
```

Manuel işaret course-scoped ve geçicidir; daha sonra açılan yeni ders odağı eski manuel işareti otomatik geçersiz kılar.

**Konum ilerleme değildir.** Blok sırası yüzde/tamamlanma progress bar'ına dönüştürülemez.

Tracking kullanılmışsa ayrı `İSTEĞE BAĞLI TAKİP` özeti yalnız açıkça işaretlenen statü adetlerini gösterebilir. İşaretlenmemiş kazanımlar eksik sayılmaz ve denominator/yüzde üretilmez.

## 10. Teacher-local mutable state

Canonical runtime'dan ayrı tutulur:

```text
teacher_state.sqlite
  outcome_tracking
  lesson_plan_progress

SharedPreferences
  last viewed lesson continuity
  course-scoped temporary annual marker
  UI preferences
```

Outcome tracking record alanları:

```text
academic_year
outcome_id
planned_week_number
status
actual_hours (optional)
teacher_note (optional)
completed_at (optional)
carried_to_week_number (optional)
updated_at
```

Lesson-plan progress record alanları:

```text
course_id
academic_year
package_id
status
started_at (optional)
completed_at (optional)
updated_at
```

Runtime/calendar güncellemesi teacher state'i sessizce silemez. Lesson-plan progress, `course_id + academic_year + package_id` scope'unda tutulur.

## 11. Tracking semantics

Outcome tracking için valid storage states:

```text
planned
in_progress
completed
partially_completed
carried_over
```

`planned` domain/storage fallback'ıdır; kullanıcıya otomatik ilerleme borcu olarak gösterilmez. Canonical schedule ve classroom tracking iki ayrı gerçektir.

Carry-over canonical planned week'i değiştirmez, EVENT_WEEK'e hedeflenemez ve aynı original tracking identity üzerinden yürür.

Lesson-plan progress outcome tracking'den ayrı bir teacher-state capability'dir. İkisi birbirinin statusunu veya continuity state'ini otomatik değiştirmez.

## 12. Calendar/runtime invariants

Aktif TDE_9 2026-2027 profilinde:

```text
weekly_hours = 5
annual_hours = 180
theme_count = 4
theme_hours = 45
structured_theme_hours = 43
school_based_theme_hours = 2
instructional_weeks = 36
active_week_37 = EVENT_WEEK
EVENT_WEEK new curriculum hours = 0
```

Lesson-plan-aware TDE_9/TDE_10 runtime sözleşmesi:

```text
runtime_package_version = 1.3.0
runtime_schema_version = 1.2.0
lesson_plan_packages = 88
lesson_plan_instruction_hours = 172
validation = VERIFIED/PASS
```

Bu değerler feature widget'larında hardcode edilmez; versioned planning/runtime authority'den gelir.

## 13. Offline/privacy boundary

Core kullanım kurulum sonrası offline çalışır. V1.3 dışında kalanlar:

```text
student roster / attendance / grades
student mastery analytics
cloud account/backend/sync
MEBBİS/e-Okul
LLM/RAG/AI generation
OCR/PDF ingestion
curriculum editing
general-purpose notes/task manager
```

## 14. Required UX invariants

- Tek baskın mevcut ders odağı.
- Tracking zorunlu değildir.
- Bir dersi veya ders planını görüntülemek tracking kaydı oluşturmaz.
- Continuity tracking'den bağımsızdır.
- Lesson-plan capability yokluğu ana akışı bloke etmez.
- Ders planı yeni top-level navigation oluşturmaz.
- Convenience preference hataları authoritative içeriği bloke etmez.
- Notlarda sessiz veri kaybı yoktur.
- Outcome tracking/carry mutationları gerçek Undo sunar.
- Lesson-plan status mutationları önceki persisted snapshot'a gerçek Undo sunar.
- `planned` bir kullanıcı borcu gibi sunulmaz.
- Konum, tamamlanma yüzdesi değildir.
- Phone/tablet, large text ve dark mode kullanılabilir kalır.
- Touch target'lar Material minimumlarını korur.

## 15. Definition of success

V1.3 başarılıdır when a teacher can:

1. uygulamayı açıp `ŞİMDİ` dersini doğrudan görmek;
2. hiçbir tracking işlemi yapmadan ders ayrıntısına ve kaynaklara ulaşmak;
3. lesson-plan capability varsa mevcut dersin doğrulanmış planını açmak ve önceki/sonraki pakette ilerlemek;
4. kesinti sonrası son görüntülenen derse dönmek;
5. isterse outcome tracking/not/carry ve lesson-plan progress özelliklerini kullanmak ve mutasyonları Undo yapabilmek;
6. yıllık konumu ilerleme yüzdesiyle karıştırmamak;
7. runtime doğruluğunu bozmadan tüm core akışı offline kullanmak.

## 16. Change protocol

```text
scope → blueprint → implementation → regression tests → full CI
```

DEHB Faz 0–6 veya lesson-plan P4/P5 sözleşmesini değiştiren bir çalışma önce bu belgeyi bilinçli biçimde revize etmelidir; eski unrouted ekranları yeniden bağlamak scope değişikliği sayılır.
