# TYMM Teacher OS — Flutter Uygulama Blueprint'i

**Belge sürümü:** 1.1.0  
**Durum:** Bağlayıcı teknik blueprint  
**Uygulama teknolojisi:** Flutter + Dart + Material 3  
**İlk dağıtım hedefi:** Android  
**İlk course package:** `TDE_9`  
**Çalışma modu:** Offline-first / yerel / deterministik

Bu belge `docs/PRODUCT_SCOPE.md` altındadır. Çelişkide product scope geçerlidir.

---

## 1. Architecture summary

ÖğretmenOS iki ayrı doğrulanabilir veri eksenini birleştirir:

```text
TYMM canonical knowledge
        ↓
runtime compiler
        ↓
course_runtime.sqlite
        ↓
CourseKnowledgeRepository

versioned academic calendar assets
        ↓
AcademicCalendarService
        ↓
WeeklyPlanningService

CourseKnowledgeRepository + WeeklyPlanningService
        ↓
Flutter feature UI
```

Curriculum knowledge ile yıllık tarih/scheduling verisi aynı dosyada tutulmaz.

---

## 2. Runtime course package

`course_runtime.sqlite`:

- read-only açılır,
- canonical source değildir,
- verified projection'dır,
- outcomes, themes, blocks, textbook sections, activities, forms, assessment ve resource decision ilişkilerini taşır,
- uygulama tarafından değiştirilmez.

Flutter presentation katmanı curriculum ilişkilerini yeniden üretmez.

---

## 3. Academic calendar package

Takvim verileri source code içine gömülmez.

Asset yapısı:

```text
assets/
├── courses/
│   └── TDE_9/
│       ├── course_runtime.sqlite
│       └── runtime_manifest.json
└── calendars/
    ├── calendar_index.json
    └── academic_calendar_2026_2027.json
```

`calendar_index.json` aktif akademik yılı ve ilgili asset yolunu gösterir.

Yeni eğitim öğretim yılında:

1. yeni calendar JSON eklenir,
2. gerekiyorsa course scheduling profile güncellenir,
3. index içindeki aktif yıl değiştirilir,
4. service ve invariant testleri çalıştırılır.

Feature kodunun tarih sabitleri değiştirilmez.

---

## 4. Calendar data contract

Bir academic calendar package en az şunları taşır:

```text
schema_version
academic_year
term date ranges
break date ranges
orientation/guidance metadata
special weeks
course scheduling profiles
```

2026-2027 TDE_9 profile:

```text
weekly_lesson_hours = 5
annual_hours = 180
theme_hours = 45
structured_hours_per_theme = 43
school_based_hours_per_theme = 2
instructional_week_count = 36
final active week = EVENT_WEEK
```

Service `36 × 5 = 180` ve `4 × 45 = 180` invariantlarını doğrular.

---

## 5. Block scheduling policy

Canonical runtime block order verir fakat blok başına resmî ders saati vermemektedir.

Bu nedenle scheduling service iki kavramı ayırır:

```text
verified curriculum fact
vs
derived scheduling allocation
```

İlk profile göre her temanın 43 yapılandırılmış saati dört sıralı bloğa:

```text
12, 11, 10, 10
```

olarak planlama amacıyla dağıtılır. Ardından 2 saat `SCHOOL_BASED_PLANNING` segmenti gelir.

Bu değerler Dart widget'larında hardcode edilmez; calendar/planning profile'dan okunur.

UI bu süreleri "planlama dağıtımı" olarak ifade eder.

---

## 6. Weekly plan algorithm

`WeeklyPlanningService` şu algoritmayı uygular:

```text
1. active academic year calendar'ı yükle
2. term tarih aralıklarını üret
3. ara tatil ve yarıyıl tatili haftalarını çıkar
4. active school weeks listesini sırala
5. EVENT_WEEK'i curriculum budget dışında bırak
6. annual runtime sequence'i theme/block sırasıyla al
7. theme başına scheduling profile hour budget oluştur
8. block segmentlerini profile'daki derived allocation ile sırala
9. her instructional week'e weekly_lesson_hours kadar segment tüket
10. segmentlerde geçen block'ların verified outcome'larını repository'den al
11. haftalık planı UI'ya dön
```

Bir hafta blok sınırını kesebilir. Örnek:

```text
3. hafta
2 saat: Blok 1
3 saat: Blok 2
```

Bu desteklenmesi gereken normal bir durumdur.

---

## 7. Week semantics

Academic school week numarası yalnız aktif okul haftaları üzerinden artar.

Break haftaları curriculum budget tüketmez.

2026-2027 için:

```text
active school weeks = 37
TDE instructional weeks = 36
week 37 = EVENT_WEEK
```

Etkinlik haftasında:

```text
planned curriculum lesson hours = 0
new block allocation = 0
new outcomes = []
```

Event week UI'da görünür fakat curriculum içeriği uydurulmaz.

---

## 8. Domain/data types

Takvim-planning tarafı course domain'den ayrı modeller kullanır:

```text
AcademicCalendarDefinition
AcademicTerm
AcademicBreak
CourseScheduleProfile
AcademicWeekPlan
WeeklyPlanSegment
AnnualWeeklyPlan
```

`WeeklyPlanSegment` iki ana tür taşır:

```text
BLOCK
SCHOOL_BASED_PLANNING
```

BLOCK segmenti runtime `Theme` ve `Block` ile bağlanır.

Weekly outcomes sadece BLOCK segmentlerinden ve `CourseKnowledgeRepository.getBlock()` üzerinden elde edilir.

---

## 9. Dependency wiring

Production dependency graph:

```text
CourseDatabase.open()
        ↓
CourseKnowledgeRepositoryImpl
        ↓
AssetAcademicPlanningService(repository)
        ↓
AppDependencies
```

Takvim service testlerde fake/in-memory bağımlılıkla değiştirilebilir olmalıdır.

---

## 10. Navigation

Top-level navigation:

```text
Ana Sayfa
Haftalık Plan
Yıllık Plan
Öğretmen Paketi
```

`Haftalık Plan` öğretmenin tarih/hafta odaklı ana scheduling ekranıdır.

`Yıllık Plan` curriculum sequence ve manuel gerçek-dünya sapma override'ı için korunabilir.

---

## 11. Weekly Plan screen

Ekran şunları göstermelidir:

```text
academic year
week number
date range
week type
planned lesson hours
active theme(s)
block segments + segment hours
school-based planning segment
weekly outcomes/kazanımlar
```

Öğretmen herhangi bir active school week'i seçebilmelidir.

Block segmentine dokununca mevcut `BlockDetailPage` açılabilir.

Event week için ayrı durum paneli gösterilir.

---

## 12. Existing features

Aşağıdaki mevcut feature'lar korunur:

```text
Home / Course Dashboard
Annual Plan
Block Detail
Book First / Materials
Teacher Package
```

Takvim feature'ı bunların curriculum logic'ini kopyalamaz; yalnız zaman eksenini ekler.

---

## 13. User state

`course_runtime.sqlite` ve calendar assets user state değildir.

Minimal mutable state ayrı tutulur:

```text
manual_position_override
UI preferences
```

Manual position override planned calendar output'u değiştiren authoritative data değildir; gerçek sınıf ilerlemesini işaretlemek için optional user override'dır.

---

## 14. Error handling

Weekly planning fail-fast davranmalıdır.

Reject examples:

```text
missing active calendar
invalid date ranges
weekly_hours <= 0
annual_hours mismatch
wrong active-school-week count
instructional weeks × weekly hours != annual hours
block allocation sum != structured theme hours
theme count incompatible with annual profile
```

Invalid profile varsa UI açık Error/Unresolved durumu göstermelidir; tarih veya saat uydurmamalıdır.

---

## 15. Test strategy

Minimum automated tests:

1. 2026-2027 calendar term/break parsing,
2. 37 active school week üretimi,
3. 16-20 Kasım ara tatilinin course budget tüketmemesi,
4. 25 Ocak-5 Şubat yarıyıl tatilinin course budget tüketmemesi,
5. 8-12 Mart ara tatilinin course budget tüketmemesi,
6. 36 instructional week × 5 = 180,
7. theme başına 45 saat,
8. 43 structured + 2 school-based conservation,
9. derived block allocation 12+11+10+10=43,
10. week 3 için block segmentleri ve verified outcomes,
11. week 37 EVENT_WEEK ve zero curriculum assignment,
12. weekly-plan widget smoke test,
13. existing runtime/integration tests regression.

CI gate sırası korunur:

```text
Analyze
Runtime Contract
Tests
Android Release Build
```

---

## 16. Offline guarantee

Calendar planning core feature tamamen offline çalışır.

Yıllık güncelleme app release ile gelen versioned asset update'idir. Runtime sırasında network, API, authentication veya remote calendar zorunlu değildir.

---

## 17. 2026-2027 calendar facts

Bundled package:

```text
Orientation/guidance: 7-11 September 2026
Term 1: 14 September 2026 - 22 January 2027
Break 1: 16-20 November 2026
Semester break: 25 January - 5 February 2027
Term 2: 8 February - 25 June 2027
Break 2: 8-12 March 2027
Event week: 21-25 June 2027
Academic year end: 25 June 2027
```

Bu tarihler calendar asset'ten okunur; feature code içinde tekrar edilmez.

---

## 18. Acceptance criteria

Feature complete kabulü için:

```text
teacher can open week 3
teacher sees week 3 date range
teacher sees 5 planned TDE hours
teacher sees one or more planned block segments
teacher sees outcomes belonging to those blocks
school-based planning appears as a distinct segment at each theme boundary
all 180 hours are conserved across first 36 active weeks
week 37 is shown as Event Week with no fabricated curriculum outcomes
new academic year can be introduced via calendar data/index update
existing block/textbook/assessment/resource navigation continues to work
```
