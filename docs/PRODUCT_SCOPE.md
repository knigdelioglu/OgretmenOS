# PRODUCT_SCOPE.md — ÖğretmenOS V1.3

**Product:** ÖğretmenOS  
**Document version:** 1.3.0  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**Operation mode:** Offline-first, deterministic, local

## 1. Product definition

ÖğretmenOS öğretmenin derse girerken **şu anki ders bağlamını mümkün olan en az karar yüküyle** görmesini sağlar. Birincil akış:

```text
uygulamayı aç
→ Bu Hafta / ŞİMDİ
→ ders bağlamını ve gerekli doğrulanmış bilgiyi gör
→ gerekirse ayrıntı/kaynak aç
→ çık
```

**Tracking isteğe bağlıdır.** Bir kazanımı görüntülemek, derse hazırlanmak veya uygulamadan çıkmak için `Başla`, `İşlendi` ya da başka bir tracking durumu zorunlu değildir.

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

Uygulama runtime outcome/theme/block/textbook/activity/assessment ilişkilerini değiştirmez veya uydurmaz.

## 3. Primary navigation

Top-level navigation yalnız üç öğretmen işidir:

```text
Bu Hafta
Yıllık
Kaynaklar
```

Default surface `Bu Hafta`dır.

Legacy `Kazanımlar / Haftalık / Paket` ekranları top-level ürün navigasyonu değildir. Tracking, haftalık ders akışının ikincil/isteğe bağlı bir özelliğidir.

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

## 7. Kaynaklar

Kaynak ekranı tema 1'e körlemesine sıfırlanmaz. Bağlam önceliği:

```text
1. son görüntülenen ders
2. mevcut öğretim haftası
3. güvenli ilk-tema fallback
```

Bağlam convenience state'tir; okunamazsa kaynak erişimi yine çalışır. Manuel tema seçimi ekranda kalındığı sürece korunur; sekmeye yeniden girişte güncel ders bağlamı tekrar çözülür.

## 8. Yıllık plan

Yıllık plan canonical öğretim sırasını gösterir. `ŞU AN BURADASIN` konumu:

```text
son görüntülenen ders
veya daha yeni geçici manuel konum işareti
```

Manuel işaret course-scoped ve geçicidir; daha sonra açılan yeni ders odağı eski manuel işareti otomatik geçersiz kılar.

**Konum ilerleme değildir.** Blok sırası yüzde/tamamlanma progress bar'ına dönüştürülemez.

Tracking kullanılmışsa ayrı `İSTEĞE BAĞLI TAKİP` özeti yalnız açıkça işaretlenen statü adetlerini gösterebilir. İşaretlenmemiş kazanımlar eksik sayılmaz ve denominator/yüzde üretilmez.

## 9. Teacher-local mutable state

Canonical runtime'dan ayrı tutulur:

```text
teacher_state.sqlite
  learning_outcome_tracking

SharedPreferences
  last viewed lesson continuity
  course-scoped temporary annual marker
  UI preferences
```

Tracking record alanları:

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

## 10. Tracking semantics

Valid storage states:

```text
planned
in_progress
completed
partially_completed
carried_over
```

`planned` domain/storage fallback'ıdır; kullanıcıya otomatik ilerleme borcu olarak gösterilmez. Canonical schedule ve classroom tracking iki ayrı gerçektir.

Carry-over canonical planned week'i değiştirmez, EVENT_WEEK'e hedeflenemez ve aynı original tracking identity üzerinden yürür.

## 11. Calendar/runtime invariants

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

Bu değerler feature widget'larında hardcode edilmez; versioned planning/runtime authority'den gelir.

## 12. Offline/privacy boundary

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

## 13. Required UX invariants

- Tek baskın mevcut ders odağı.
- Tracking zorunlu değildir.
- Bir dersi görüntülemek tracking kaydı oluşturmaz.
- Continuity tracking'den bağımsızdır.
- Convenience preference hataları authoritative içeriği bloke etmez.
- Notlarda sessiz veri kaybı yoktur.
- Tracking/carry mutationları gerçek Undo sunar.
- `planned` bir kullanıcı borcu gibi sunulmaz.
- Konum, tamamlanma yüzdesi değildir.
- Phone/tablet, large text ve dark mode kullanılabilir kalır.
- Touch target'lar Material minimumlarını korur.

## 14. Definition of success

V1.3 başarılıdır when a teacher can:

1. uygulamayı açıp `ŞİMDİ` dersini doğrudan görmek;
2. hiçbir tracking işlemi yapmadan ders ayrıntısına ve kaynaklara ulaşmak;
3. kesinti sonrası son görüntülenen derse dönmek;
4. isterse tracking/not/carry özelliklerini kullanmak ve Undo yapabilmek;
5. yıllık konumu ilerleme yüzdesiyle karıştırmamak;
6. runtime doğruluğunu bozmadan tüm core akışı offline kullanmak.

## 15. Change protocol

```text
scope → blueprint → implementation → regression tests → full CI
```

DEHB Faz 0–6 sözleşmesini değiştiren bir çalışma önce bu belgeyi bilinçli biçimde revize etmelidir; eski unrouted ekranları yeniden bağlamak scope değişikliği sayılır.
