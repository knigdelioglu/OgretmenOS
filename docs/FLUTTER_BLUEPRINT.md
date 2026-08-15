# TYMM Teacher OS — Flutter Uygulama Blueprint'i

**Belge sürümü:** 1.0.0  
**Durum:** Tasarım / uygulama öncesi bağlayıcı blueprint  
**Uygulama teknolojisi:** Flutter + Dart + Material 3  
**İlk dağıtım hedefi:** Android  
**İlk course package:** `TDE_9`  
**LLM gereksinimi:** Yok  
**Backend gereksinimi:** Yok  
**Çalışma modu:** Offline-first / yerel / deterministik  
**Ana veri kaynağı:** TYMM canonical knowledge → deterministic runtime course package

---

## 1. Belgenin Amacı

Bu belge, TYMM Teacher OS uygulamasının **ürün sınırlarını, veri mimarisini, Flutter mimarisini, runtime veritabanı ilişkisini, ekranlarını, veri güncelleme zincirini, geliştirme sırasını ve kabul kriterlerini** baştan sona tanımlar.

Bu bir fikir listesi değildir. Codex, Antigravity veya başka bir coding agent uygulamada çalışırken bu belgeyi **ürün ve mimari referansı** olarak kullanmalıdır.

Temel hedef:

> Öğretmenin günlük veri girmesine bağımlı olmadan, doğrulanmış TYMM programı ve ders kitabı knowledge package'ını kullanarak öğretmene planlanan öğretim sırasını, ilgili program çıktıları ile ders kitabı karşılıklarını, gerekli değerlendirme araçlarını ve gerçekten ihtiyaç duyulan ek materyal durumunu deterministik biçimde göstermek.

---

## 2. Ürünün Kesin Tanımı

TYMM Teacher OS V1:

- bir öğrenci bilgi sistemi değildir,
- not/yoklama sistemi değildir,
- okul yönetim sistemi değildir,
- içerik üreticisi değildir,
- LLM/chat uygulaması değildir,
- PDF/OCR uygulaması değildir,
- curriculum editor değildir,
- generic teacher productivity suite değildir.

V1'in görevi dardır:

```text
Doğrulanmış TYMM knowledge
        ↓
Uygulama için derlenmiş runtime package
        ↓
Flutter uygulamasında sade operasyonel görünüm
```

Öğretmen uygulamayı açtığında şu soruların cevabına hızlıca ulaşmalıdır:

1. Program sırasının neresindeyim?
2. Bu blokta ne var?
3. Ders kitabında nereye bakacağım?
4. Hangi etkinlikleri kullanacağım?
5. Hangi form/değerlendirme aracı ilgili?
6. Ek materyale gerçekten ihtiyaç var mı?
7. Bundan sonra ne geliyor?

---

## 3. Ürün Tezi

Uygulamanın asıl değeri UI değil, doğrulanmış knowledge katmanıdır.

TDE_9 için mevcut bilgi modeli aşağıdaki ilişkileri taşır:

```text
theme
→ block
→ outcome
→ process component
→ textbook section/page
→ activity
→ form
→ resource decision
→ assessment artifact
→ gap resolution
→ source/provenance
→ annual sequence
```

Flutter uygulaması bu ilişkileri yeniden kurmayacaktır.

### Bağlayıcı kural

**Uygulama knowledge modelini okur; öğretim programını yeniden yorumlamaz.**

Şunlar Widget, Controller, StateNotifier, ViewModel benzeri presentation katmanlarında yapılamaz:

- outcome ile activity arasında yeni ilişki icat etmek,
- bir block'a saat uydurmak,
- eksik assessment kararı üretmek,
- textbook coverage'ı yeniden yorumlamak,
- “bu materyal gerekli” kararını UI mantığıyla çıkarmak.

Bu kararların kaynağı canonical knowledge veya onun deterministic runtime projection'ı olmalıdır.

---

## 4. Mevcut Veri Altyapısı

TDE_9 altyapısı üç ayrı katmana ayrılır.

### 4.1 Canonical Knowledge — Source of Truth

Konum:

```text
/Users/kadir/Desktop/tymm/courses/TDE_9/
```

Başlıca kaynaklar:

```text
curriculum_map.json
textbook_map.json
textbook_forms_index.json
source_manifest.json
themes/
production/
planning/
```

Bu katman doğrulanmış esas bilgidir.

Flutter uygulaması canonical knowledge'i değiştirmez.

### 4.2 Semantic/Search Index

```text
knowledge.sqlite
```

Amaç:

- RAG,
- semantic retrieval,
- FTS/vector arama,
- resolver desteği.

Bu veritabanı Flutter V1 runtime database değildir.

V1 uygulamasına taşınması gerekmez.

V1 için:

- embedding yok,
- ONNX yok,
- sqlite-vec yok,
- model dosyası yok,
- Python runtime yok.

### 4.3 Runtime Course Package

Konum:

```text
/Users/kadir/Desktop/tymm/courses/TDE_9/runtime/course_runtime.sqlite
```

Durum:

```text
RUNTIME_COURSE_PACKAGE: PASS
RUNTIME_STATUS: RUNTIME_FRESH
RUNTIME_PACKAGE_VERSION: 1.0.0
SCHEMA_VERSION: 1.0.0
```

Mevcut doğrulanmış kapsam:

```text
19 tablo
4 tema
16 blok
54 outcome
61 activity
28 form
50 resource decision
3 assessment artifact
7 assessment gap mapping
197 activity-outcome relation
61 block-activity relation
```

Validation:

```text
FOREIGN_KEY_INTEGRITY: PASS
ORPHAN_RELATIONS: 0
CANONICAL_ID_UNIQUENESS: PASS
COPYRIGHT_PAYLOAD: PASS
USER_STATE_INCLUDED: NO
VECTOR_RUNTIME_INCLUDED: NO
KNOWLEDGE_SQLITE_USED: NO
```

Beş hedef application query'si PASS durumundadır.

---

## 5. Runtime Database'in Rolü

`course_runtime.sqlite`, Flutter uygulaması açısından **read-only course knowledge package** olacaktır.

```text
course_runtime.sqlite
        ↓
CourseDatabaseDataSource
        ↓
CourseKnowledgeRepository
        ↓
Domain Queries / Services
        ↓
Feature State
        ↓
Flutter Widgets
```

Runtime DB:

- kullanıcı veritabanı değildir,
- öğretmen günlük ilerleme veritabanı değildir,
- canonical source değildir,
- semantic vector index değildir,
- uygulama tarafından edit edilecek içerik değildir.

Ana amaç, Flutter tarafının:

- birçok canonical JSON dosyasını açmaması,
- relation'ları yeniden çözmemesi,
- gap logic'i Dart'ta yeniden kurmaması,
- assessment consolidation mantığını tekrar uygulamaması

ve doğrudan sorgulanabilir projection kullanmasıdır.

---

## 6. Runtime Build Zinciri

Runtime package elle düzenlenmez.

```text
Canonical TDE_9 Knowledge
        ↓
build_runtime_course_package.py
        ↓
validation
        ↓
runtime_manifest.json
runtime_schema.sql
runtime_validation_report.md
course_runtime.sqlite
```

Compiler:

```text
skill/tymm-material-planner/scripts/build_runtime_course_package.py
```

Runtime package canonical source fingerprint'larını taşır.

Durumlar:

```text
RUNTIME_FRESH
RUNTIME_STALE
FAIL
```

---

## 7. Flutter Repo ile Knowledge Repo Ayrımı

Knowledge engine ile uygulama kodu ayrı tutulmalıdır.

Knowledge repo:

```text
/Users/kadir/Desktop/tymm
```

İçerik:

```text
canonical knowledge
skill
compiler
runtime projection
validation
```

Flutter repo önerisi:

```text
/Users/kadir/Desktop/tymm_teacher
```

İçerik:

```text
Flutter app
Dart domain/data katmanları
runtime DB erişimi
minimal local preferences
runtime sync tooling
tests
```

Bu ayrım sayesinde curriculum değişiklikleri ile uygulama feature geliştirmesi birbirine karışmaz.

---

## 8. Flutter Runtime Asset Stratejisi

Android APK/AAB içinde SQLite veritabanı authoritative kaynak değildir.

Önerilen asset yapısı:

```text
assets/
└── courses/
    └── TDE_9/
        ├── course_runtime.sqlite
        └── runtime_manifest.json
```

`pubspec.yaml` içinde bu asset'ler açıkça tanımlanır.

### Önemli

SQLite asset'i bundle içinden doğrudan normal writable dosya gibi kullanılmaz.

Önerilen runtime akışı:

```text
Flutter asset
      ↓
first launch / package version change
      ↓
Application Support dizininde local copy
      ↓
read-only SQLite open
```

Kopya yalnız çalışma kopyasıdır.

Canonical source yine `/Users/kadir/Desktop/tymm` reposudur.

---

## 9. Runtime Sync Tooling

Flutter repo içinde küçük bir sync script/task bulunabilir.

Örnek:

```text
tool/sync_course_runtime.dart
```

veya:

```text
scripts/sync_course_runtime.sh
```

Görev:

1. source runtime path'i doğrula,
2. `runtime_manifest.json` içindeki durum/fingerprint'i doğrula,
3. `RUNTIME_FRESH` değilse dur,
4. `course_runtime.sqlite` dosyasını Flutter asset klasörüne kopyala,
5. `runtime_manifest.json` dosyasını da kopyala,
6. mümkünse hash doğrula.

Kaynak:

```text
/Users/kadir/Desktop/tymm/courses/TDE_9/runtime/
```

Hedef:

```text
assets/courses/TDE_9/
```

Sync script canonical dosyaları değiştiremez.

---

## 10. Runtime Asset Git Politikası

Preferred V1 policy:

**TYMM repo:**
`courses/TDE_9/runtime/course_runtime.sqlite`
→ **VERSIONED**

**OgretmenOS repo:**
`assets/courses/TDE_9/course_runtime.sqlite`
→ **VERSIONED**

Her iki dosya:
- derived artifact
- canonical değil
- deterministic compiler output
- hash/fingerprint ile doğrulanabilir

Sync tool hâlâ gereklidir:
```text
TYMM runtime
    ↓ sync
OgretmenOS asset
```

Sync sonucu elde edilen asset Git'te tutulabilir ve versiyonlanması onaylıdır.

Bu karar özellikle şunları kolaylaştırmak içindir:
- Clean clone
- Codex remote workspace
- Antigravity workspace
- CI / build ortamları

Önemli ilkeler:
- `course_runtime.sqlite` derived/rebuildable olmaya devam eder; canonical source of truth değildir.
- `knowledge.sqlite` (RAG/search cache), vector index'ler ve ham PDF'ler kesinlikle OgretmenOS repo'suna taşınmaz ve versiyonlanmaz.
- Source runtime ile app asset divergence kabul edilmez (hash/fingerprint eşitliği korunur).

---

## 11. V1'in Beş Çekirdek Capability'si

### Capability A — Ders Yürütme Merkezi

Ana operasyon ekranıdır.

Gösterir:

- theme,
- block,
- block sırası,
- outcome'lar,
- textbook section/page,
- activity'ler,
- form'lar,
- assessment artifact,
- resource decision,
- önceki/sonraki block.

Örnek:

```text
2. Tema — Anlam Arayışı

Planlanan Blok
Konuşma Atölyesi

Öğrenme Çıktıları
TDE3.1
TDE3.2
TDE3.3
TDE3.4

Ders Kitabı
s. 125–130

Değerlendirme
TDE9_KONUSMA_RUBRIC

Materyal Durumu
Kitapta karşılığı var.
Ek materyal gerekli değil.
```

### Capability B — Bugünkü Ders / Current Block Brief

Bir block'un öğretmen için tek ekranda özetidir.

Gösterir:

```text
theme
block
textbook pages
activities
outcomes
forms/tools
resource status
next block
```

#### Kritik timeline sınırlaması

Mevcut timeline:

```text
TIMELINE_RESOLUTION: THEME_TIME_RESOLVED
BLOCK_HOUR_RESOLUTION: ORDER_ONLY
WEEKLY_LESSON_HOURS: UNRESOLVED
ACADEMIC_CALENDAR_BINDING: UNRESOLVED
```

Bu nedenle uygulama bugün hangi block'ta olunması gerektiğini tarih üzerinden henüz güvenilir biçimde çözemez.

İki çalışma modu:

**Sequence Mode:** mevcut veriyle çalışır.

```text
selected/current sequence position
→ block brief
→ next block
```

**Calendar-bound Mode:** ancak academic calendar + weekly lesson schedule + block time allocation doğrulanınca aktive edilir.

Calendar verisi yokken sahte “Bugün burada olmalısın” üretilmez.

### Capability C — Yaşayan Yıllık Plan

Öğrenci başarısını değil **planlanan öğretim sırasını** gösterir.

Gösterir:

- 4 tema,
- 16 block,
- sequence order,
- theme-time metadata,
- current/selected position,
- previous/next positions.

Doğru dil:

```text
Planlanan ilerleme
Beklenen sıra
Programdaki konum
```

Yanlış dil:

```text
Öğrenildi
Kazanıldı
Mastery
Başarı %
```

Block saatleri unresolved olduğundan keyfi block yüzdeleri hesaplanamaz.

Gerekirse:

```text
7 / 16 plan sırası
```

gibi sequence progress gösterilir.

### Capability D — Kitap-Önce / Materyal Gerekliliği

Sistem yeni materyal üretmez.

Mevcut resource decision'ı öğretmen diline çevirir.

Canonical karar örnekleri:

```text
REUSE_TEXTBOOK
REUSE_WITH_TEACHER_GUIDE
ADAPT_TEXTBOOK_ACTIVITY
GENERATE
GENERATE_ASSESSMENT_SUPPORT
GENERATE_DIFFERENTIATION
GENERATE_ENRICHMENT
NO_ACTION
```

App-facing deterministic mapping örneği:

```text
BOOK_SUFFICIENT
USE_EXISTING_TEXTBOOK_ACTIVITY
USE_EXISTING_FORM
USE_ANNUAL_ASSESSMENT_ARTIFACT
ADDITIONAL_SUPPORT_REQUIRED
```

Bu mapping runtime/compiler contract'ına bağlıdır.

Widget kendi pedagojik kararını üretmez.

### Capability E — Otomatik Öğretmen Paketi

Theme veya block için structured knowledge'dan derlenmiş görünüm sunar.

İçerik:

```text
Program kapsamı
Block'lar
Outcome'lar
Kitap haritası
Etkinlikler
Formlar
Assessment araçları
Resource decision'lar
Source locator'lar
```

Yeni pedagojik metin üretmez.

V1'de on-screen package yeterlidir.

PDF/DOCX export scope dışıdır.

---

## 12. Flutter Navigation Blueprint

Önerilen V1 navigation:

```text
App Start
   │
   ▼
Home / Course Dashboard
   │
   ├── Ders Yürütme
   │      └── Theme
   │           └── Block Detail
   │
   ├── Yıllık Plan
   │      └── Theme
   │           └── Block
   │
   ├── Kitap-Önce
   │      └── Resource Decision Detail
   │
   └── Öğretmen Paketi
          └── Theme Package
```

V1 küçük olduğu için önce Flutter'ın built-in navigation imkanları değerlendirilir.

`go_router` yalnız route yapısı gerçekten fayda sağlayacaksa eklenir.

---

## 13. Ana Ekran Blueprint'i

Önerilen içerik:

```text
TDE 9

Plan Sırası
Tema 2 → Konuşma

[Bloku Aç]

Ders Kitabı
s. xxx–yyy

İlgili Araç
Yıllık Konuşma Rubriği

Materyal
Ek materyal gerekli değil.

Sonraki
Tema 2 → Yazma
```

Top-level navigation en fazla:

```text
Ana Sayfa
Yıllık Plan
Öğretmen Paketi
```

Flutter `NavigationBar` kullanılabilir.

---

## 14. Theme Detail Blueprint

Theme ekranı:

```text
Theme Title

Program zamanı
Known / unresolved state

Blocks
1. ...
2. ...
3. ...
4. ...

Outcome summary
Textbook coverage summary
Assessment tools
Resource decisions
```

---

## 15. Block Detail Blueprint

### Header

```text
theme
block title
block order
skill domain
```

### Program

```text
outcomes[]
process components[]
```

### Ders Kitabı

```text
sections[]
page ranges
activities[]
forms[]
```

### Değerlendirme

```text
assessment artifact
gap mapping
task binding
```

### Materyal Durumu

```text
coverage
resource decision
book-first interpretation
```

### Kaynak

```text
source locator
printed page
pdf page
```

### Navigation

```text
previous block
next block
```

---

## 16. Annual Plan Screen

Runtime'daki stable sequence doğrudan kullanılır.

```text
Tema 1
  1. Block A
  2. Block B
  3. Block C
  4. Block D

Tema 2
  5. ...
  6. ...
```

Opsiyonel kullanıcı state'i:

```text
“Ben burada kaldım”
```

yalnız:

```text
manual_position_override
```

saklar.

Clear:

```text
“Plan sırasına dön”
```

Course runtime DB'ye yazılmaz.

---

## 17. User State Tasarımı

Course knowledge ile local user state kesin ayrılır.

### Runtime course knowledge

Read-only:

```text
course_runtime.sqlite
```

### Mutable local state

V1 için en fazla:

```text
manual_position_override
basic UI preferences
```

Flutter için önerilen seçenek:

```text
shared_preferences
```

V1 için ikinci SQLite veritabanı, Hive/Isar/Drift user store veya kapsamlı local persistence gereksizdir.

V1'de saklanmaz:

- lesson history,
- teacher diary,
- notes,
- attendance,
- class roster,
- student data,
- grades,
- assessment scores,
- completion history.

---

## 18. Flutter Teknik Mimari

Önerilen sade katman:

```text
Flutter Widgets
      ↓
Feature State / Controller
      ↓
Domain Query / Service
      ↓
CourseKnowledgeRepository
      ↓
CourseDatabaseDataSource
      ↓
course_runtime.sqlite
```

User state:

```text
Flutter Widgets
      ↓
Feature State
      ↓
UserPreferencesRepository
      ↓
shared_preferences
```

### Mimari ilke

Clean Architecture adı altında gereksiz DTO, mapper, base repository ve dozens-of-use-cases yapısı kurulmaz.

Katman ayrımı gerçek sınırı korumak içindir; dosya sayısını büyütmek için değil.

---

## 19. State Management Kararı

V1 için state yönetimi küçük tutulmalıdır.

İlk tercih:

```text
ChangeNotifier / ValueNotifier
```

veya Flutter'ın mevcut basit state mekanizmaları.

`Riverpod`, `Bloc`, `Provider` gibi paketler yalnız uygulamanın gerçek karmaşıklığı gerektirirse eklenir.

Repository/domain katmanı framework bağımsız kalmalıdır.

---

## 20. Önerilen Flutter Proje Yapısı

```text
lib/
├── app/
│   ├── app.dart
│   ├── navigation/
│   └── theme/
│
├── data/
│   ├── course/
│   │   ├── course_database.dart
│   │   ├── course_database_data_source.dart
│   │   └── course_knowledge_repository_impl.dart
│   └── preferences/
│       └── user_preferences_repository.dart
│
├── domain/
│   ├── models/
│   ├── repositories/
│   └── services/
│
├── features/
│   ├── home/
│   ├── block/
│   ├── annual_plan/
│   ├── book_first/
│   └── teacher_package/
│
└── main.dart

assets/
└── courses/
    └── TDE_9/
        ├── course_runtime.sqlite
        └── runtime_manifest.json

test/
integration_test/
tool/
```

V1'de ayrı Dart packages/monorepo/modular feature packages oluşturulmaz.

---

## 21. SQLite Teknoloji Kararı

Runtime package mevcut relational SQLite database olduğu için Flutter'da DB katmanı yeni schema üretmemelidir.

### Seçenek A — `sqflite`

Avantaj:

- mobil Flutter için yaygın,
- mevcut SQLite dosyasını açabilir,
- basit SQL query yeterli,
- read-only açma yaklaşımı uygundur.

### Seçenek B — `sqlite3`

Avantaj:

- SQL'e daha doğrudan erişim,
- ileride desktop hedeflenirse faydalı olabilir.

### Seçenek C — Drift

Güçlüdür ama V1'de riskleri:

- 19 tablo için gereksiz mapping/codegen,
- existing prebuilt schema ile fazla abstraction,
- query katmanını gereğinden büyük hale getirme.

### Blueprint tercihi

**İlk Integration Spike için `sqflite` en küçük çözüm olarak değerlendirilmelidir.**

Kesin dependency kararı spike sırasında doğrulanır.

---

## 22. Asset SQLite Açma Akışı

Önerilen servis:

```text
CourseDatabaseInstaller
```

Sorumluluk:

1. bundled manifest'i oku,
2. local runtime DB kopyası var mı bak,
3. runtime package version/hash aynı mı kontrol et,
4. yoksa veya farklıysa asset DB'yi local application support dizinine kopyala,
5. DB'yi read-only aç.

Mantık:

```text
assets/course_runtime.sqlite
        ↓
rootBundle.load(...)
        ↓
ApplicationSupportDirectory
        ↓
course_runtime.sqlite
        ↓
openDatabase(..., readOnly: true)
```

`path_provider` gerekebilir.

App DB içine write query göndermemelidir.

---

## 23. Runtime DB Integrity Koruması

Course database katmanı yalnız query API sunmalıdır.

Yasak:

```text
INSERT
UPDATE
DELETE
ALTER
DROP
```

Repository API write method içermemelidir.

Mümkünse database read-only açılır.

---

## 24. Repository Contract

Widget'lar doğrudan SQL bilmez.

Örnek Dart contract:

```dart
abstract interface class CourseKnowledgeRepository {
  Future<Course> getCourse();
  Future<List<Theme>> getThemes();
  Future<ThemeDetail> getTheme(String themeId);
  Future<List<Block>> getBlocks(String themeId);
  Future<BlockDetail> getBlock(String blockId);
  Future<Block?> getPreviousBlock(String blockId);
  Future<Block?> getNextBlock(String blockId);
  Future<List<TimelineEntry>> getAnnualSequence();
  Future<List<ResourceDecision>> getResourceDecisions(String blockId);
  Future<TeacherPackage> getTeacherPackage(String themeId);
}
```

İsimler bağlayıcı değildir; sorumluluk sınırı bağlayıcıdır.

---

## 25. Runtime Query A–E'nin Flutter Karşılığı

### Query A — Ders Yürütme Merkezi

Input:

```text
theme/block
```

Output:

```text
block
outcomes
textbook activities/pages
forms
assessment artifact
resource decision
```

### Query B — Current Block Brief

Input:

```text
block/sequence position
```

Output:

```text
brief
next block
```

### Query C — Annual Plan

Output:

```text
4 themes
16 ordered blocks
timeline metadata
unresolved temporal metadata
```

### Query D — Book First

Input:

```text
block/resource need
```

Output:

```text
coverage
resource decision
textbook counterpart
additional support state
```

### Query E — Teacher Package

Input:

```text
theme
```

Output:

```text
blocks
outcomes
activities
forms
assessment artifacts
resource decisions
sources
```

Flutter ilk sürümde farklı pedagojik query engine üretmez.

---

## 26. Domain Models

Önerilen domain kavramları:

```text
Course
Theme
ThemeDetail
Block
BlockDetail
Outcome
ProcessComponent
TextbookSection
Activity
Form
AssessmentArtifact
ResourceDecision
SourceReference
TimelineEntry
BlockBrief
TeacherPackage
```

UI state örnekleri:

```text
HomeState
BlockDetailState
AnnualPlanState
BookFirstState
TeacherPackageState
```

Runtime tablo satırları doğrudan Widget modeline dönüştürülmemelidir.

---

## 27. Timeline Gerçeği ve Mevcut Sınırlama

Doğrulanmış:

```text
ANNUAL_HOURS: 180
THEME_COUNT: 4
CORE_INSTRUCTION_HOURS_PER_THEME: 43
ANNUAL SCHOOL-BASED CAPACITY: 8
BLOCK_COUNT: 16
BLOCK_ORDER: PASS
BLOCK_HOUR_RESOLUTION: ORDER_ONLY
WEEKLY_LESSON_HOURS: UNRESOLVED
ACADEMIC_CALENDAR_BINDING: UNRESOLVED
TIMELINE_RESOLUTION: THEME_TIME_RESOLVED
```

Per-theme school-based placement unresolved'dır.

Uygulama şunu bilir:

```text
hangi theme/block hangi sırada?
```

Ama henüz şunu bilemez:

```text
14 Kasım günü hangi block'ta olunmalı?
```

Flutter katmanı bunu tahminle kapatamaz.

---

## 28. Calendar Binding İçin Gelecekte Gereken Veri

Date-based current position için ayrı versioned planning profile gerekir.

Örnek:

```text
course_calendar_profile.json
```

Muhtemel alanlar:

```text
academic_year
official school calendar
weekly TDE lesson hours
lesson weekdays
holiday interruptions
block hour allocation
school-based placement
```

Stable Course Sequence ile Year-specific Calendar Binding ayrı tutulur.

---

## 29. Zero-Input Kullanım İlkesi

Öğretmen günlük veri girmeden uygulama kullanılabilmelidir.

### Her zaman mümkün

- annual sequence,
- theme/block explorer,
- block brief,
- textbook pages,
- activities,
- forms,
- resource decisions,
- assessment artifacts,
- teacher packages.

### Calendar binding geldiğinde mümkün

- otomatik bugün planlanan block,
- date-based planned progression.

### Opsiyonel kullanıcı yardımı

```text
Ben burada kaldım
```

yalnız convenience override'dır.

---

## 30. Runtime Freshness ve Flutter Build

Flutter build'e girecek runtime DB canonical knowledge ile uyumlu olmalıdır.

Önerilen build öncesi zincir:

```text
sync_course_runtime
        ↓
runtime manifest check
        ↓
RUNTIME_FRESH?
        ↓ yes
copy assets
        ↓
flutter build
```

`RUNTIME_STALE` ise build/sync durmalıdır.

---

## 31. App Startup Validation

Uygulama açılışında manifest üzerinden hafif compatibility check yapılır.

Kontroller:

```text
asset/local DB mevcut mu?
course_id == TDE_9?
schema_version destekleniyor mu?
runtime_package_version okunabiliyor mu?
validation_status uygun mu?
```

Bozuk veya uyumsuz package ile sessiz devam edilmez.

---

## 32. Version Compatibility

Örnek politika:

```text
App 1.x
supports runtime schema 1.x
```

Incompatible runtime schema gelirse fail fast.

Runtime DB immutable/rebuildable olduğu için app tarafında course database migration sistemi geliştirilmez.

---

## 33. Copyright Sınırı

Uygulama gösterebilir:

- activity adı,
- bölüm adı,
- page locator,
- kısa metadata,
- form type,
- source reference.

V1'de app içine gömülmez:

- ders kitabının tam PDF'si,
- uzun ders kitabı pasajları,
- edebî eserlerin tam içerikleri.

---

## 34. Offline Davranış

V1 tamamen offline çalışır.

Gerekmez:

```text
internet
account
login
API key
cloud DB
backend
LLM
```

---

## 35. LLM Politikası

V1'de LLM yoktur.

Yasak:

- chat,
- prompt,
- local model,
- cloud AI,
- otomatik ders üretimi,
- çalışma kağıdı üretimi,
- rubrik oluşturma.

Gelecekte:

```text
course_runtime.sqlite
        ↓
deterministic context
        ↓
optional AI layer
```

AI canonical knowledge yerine geçemez.

---

## 36. Kesin Scope Dışı Alanlar

V1'e dahil değildir:

- student list,
- attendance,
- grade book,
- exam scores,
- student portfolio,
- mastery tracking,
- teacher diary,
- lesson history,
- notes system,
- e-Okul/MEBBİS,
- timetable sync,
- Google Calendar,
- notifications,
- cloud sync,
- account/auth,
- backend,
- analytics telemetry,
- PDF export,
- DOCX export,
- OCR,
- textbook ingestion,
- semantic search UI,
- general-purpose chatbot,
- curriculum editor,
- runtime DB editor.

---

## 37. UX İlkeleri

### Düşük etkileşim maliyeti

Yasak tasarım:

```text
Her ders sonrası form doldur
Her outcome'u tamamlandı işaretle
Her gün not gir
Uzun setup wizard
```

### Kaynak odaklılık

UI mümkün olduğunca şunu göstermeli:

```text
hangi program öğesi?
hangi kitap sayfası?
hangi etkinlik?
hangi araç?
neden ek materyal gerekiyor/gerekmiyor?
```

### Sade dashboard

Dekoratif chart ve gamification yerine operasyonel bilgi.

---

## 38. Material 3 Tasarım Kuralı

Flutter `MaterialApp` içinde Material 3 kullanılmalıdır.

Amaç:

- sade,
- düşük bakım maliyetli,
- accessibility ile uyumlu

bir UI oluşturmaktır.

Özel design system V1'de yapılmaz.

Sistem açık/koyu tema desteği kullanılabilir.

---

## 39. Responsive Tasarım

İlk hedef Android telefon/tablet olsa da Flutter layout sabit piksel varsayımlarına dayanmamalıdır.

Destek:

- telefon portrait,
- tablet portrait/landscape.

Adaptive multi-pane framework V1 zorunluluğu değildir.

---

## 40. Durum Dili

Doğru:

```text
Planlanan sıra
Planlanan ilerleme
Beklenen konum
Kitap karşılığı
Program karşılığı
Ek materyal gerekli değil
Değerlendirme desteği gerekli
```

Yanlış/kanıtsız:

```text
Öğrenci öğrendi
Kazanım tamamlandı
Mastery
Başarı oranı
Bu konu bitti
```

---

## 41. Loading / Empty / Error / Unresolved States

Her feature:

```text
Loading
Content
Error
```

durumlarını destekler.

Unresolved metadata ayrıca açık gösterilir.

Örnek:

```text
Blok süresi:
Programda doğrulanmış ayrı süre bulunmuyor.
```

`0 saat` gösterilmez.

---

## 42. Accessibility

Flutter/Material accessibility temelleri uygulanmalıdır:

- text scaling,
- `Semantics` gerektiğinde,
- yeterli touch target,
- yalnız renkle anlam taşımama,
- okunabilir kontrast,
- sistem font scale'ine direnç göstermeme.

---

## 43. İlk Development Milestone — Flutter Integration Spike

İlk coding görevi tam UI değildir.

Amaç:

```text
Flutter app açılıyor
        ↓
course_runtime.sqlite asset olarak geliyor
        ↓
local working copy oluşturuluyor
        ↓
read-only açılıyor
        ↓
4 theme sorgulanıyor
        ↓
TEMA_02 seçiliyor
        ↓
gerçek block/outcome/activity verisi okunuyor
        ↓
basit Material 3 ekranda gösteriliyor
```

Kabul:

```text
hard-coded curriculum data = 0
DB query = real runtime package
```

Bu PASS olmadan feature geliştirmeye geçilmez.

---

## 44. Milestone 2 — Capability A

Ders Yürütme Merkezi.

Tam vertical slice:

```text
SQLite
→ data source
→ repository
→ domain
→ feature state
→ Flutter UI
```

Kabul:

- 4 theme görünür,
- 16 block navigate edilebilir,
- Block Detail gerçek ilişkileri gösterir.

---

## 45. Milestone 3 — Capability C

Yaşayan Yıllık Plan.

Stable ordered sequence üzerinden.

Calendar/date uydurulmaz.

---

## 46. Milestone 4 — Capability D

Kitap-Önce.

Runtime resource decisions üzerinden.

Kabul:

```text
UI kendi pedagojik kararını üretmiyor.
```

---

## 47. Milestone 5 — Capability E

Öğretmen Paketi.

Theme-level query:

```text
theme
→ blocks
→ outcomes
→ activities
→ forms
→ assessments
→ resource decisions
→ source refs
```

---

## 48. Milestone 6 — Capability B

İki aşamalı.

### B1 — Current/Selected Block Brief

Calendar gerektirmez.

### B2 — Date-based Bugünkü Ders

Yalnız calendar binding verified hale geldikten sonra.

B2 veri hazır olmadan implement edilmez.

---

## 49. Milestone 7 — Hardening

- runtime compatibility tests,
- stale asset checks,
- empty/error states,
- accessibility,
- tablet layout sanity,
- performance,
- Android release build.

Yeni feature eklenmez.

---

## 50. Test Stratejisi

### Dart unit tests

- repository query mapping,
- next/previous block,
- resource decision mapping,
- manifest compatibility,
- unresolved value handling.

### Integration tests

Gerçek test runtime DB ile:

```text
getThemes() → 4
getAnnualSequence() → 16 blocks
```

### Widget tests

Kritik:

- Home render,
- Block Detail,
- Annual Plan,
- error/unresolved state.

### Contract tests

Flutter'ın desteklediği runtime schema ile compiler output uyuşmalıdır.

---

## 51. Hard-code Güvenlik Kuralı

Dart source içine elle gömülmemelidir:

```text
TDE3.4 şu block'tadır
Tema 2 şu sayfadadır
Bu activity bu formu kullanır
Bu gap bu rubrikle çözülür
```

Bunlar DB'den gelmelidir.

Hard-code edilebilir:

- UI labels,
- route names,
- generic status text mapping,
- supported schema version.

---

## 52. Performance

Dataset küçüktür:

```text
4 theme
16 block
54 outcome
61 activity
28 form
```

Bu nedenle gereksiz:

- pagination,
- remote cache,
- complex reactive DB streams,
- vector search optimization,
- background isolates for ordinary queries.

---

## 53. Async ve Isolate Politikası

SQLite query'leri async yapılabilir.

Dataset küçük olduğundan V1'de özel isolate mimarisi kurulmaz.

Gerçek profiling UI jank gösterirse optimize edilir.

---

## 54. Dependency Politikası

Her dependency gerçek gerekçeyle eklenir.

Muhtemel minimum:

```text
flutter
sqflite
path
path_provider
shared_preferences
```

Navigation veya state management için üçüncü taraf paketler yalnız gerekirse eklenir.

Yasak gerekçe:

```text
İleride lazım olur.
```

---

## 55. Build ve Distribution

İlk hedef:

```text
flutter run
debug APK
release APK
```

Sonrasında gerekirse AAB.

V1 için gerekli değildir:

- Firebase,
- Crashlytics,
- Analytics,
- Remote Config,
- auth service.

---

## 56. Veri Güncelleme Senaryosu

Canonical knowledge değiştiğinde:

```text
canonical update
    ↓
validation
    ↓
runtime compiler
    ↓
new course_runtime.sqlite
    ↓
RUNTIME_FRESH
    ↓
Flutter runtime sync
    ↓
asset package update
    ↓
new app build
```

Flutter business code'un değişmemesi hedeflenir.

---

## 57. App İçinde Runtime Package Güncelleme

V1'de internetten dynamic course package download yapılmaz.

Runtime update yeni uygulama build'iyle gelir.

Bunun avantajı:

- backend yok,
- sync servisi yok,
- signature/update protocol yok,
- scope küçük kalır.

---

## 58. Yeni Ders Ekleme Geleceği

V1 yalnız:

```text
TDE_9
```

Architecture generic `Course` modelini korur.

Ama V1'de yapılmaz:

- course marketplace,
- plugin system,
- remote package catalog,
- multi-course management UI.

---

## 59. Uygulamanın Başarı Tanımı

V1 başarılıdır eğer öğretmen:

1. uygulamayı açabiliyor,
2. TDE_9 yıllık sequence'ini görebiliyor,
3. theme/block'lar arasında gezebiliyor,
4. block için outcomes, textbook pages, activities ve forms görebiliyor,
5. ilgili assessment aracını görebiliyor,
6. kitap yeterli mi / ek destek gerekiyor mu kararını görebiliyor,
7. theme için teacher package görüntüleyebiliyor,
8. bunların hiçbiri için günlük veri girmek zorunda kalmıyorsa.

---

## 60. Uygulamanın Başarısızlık Tanımı

Scope drift:

- öğretmen günlük veri girmeden app anlamsızlaşıyor,
- calendar bilgisi yokken date-based progress uyduruluyor,
- progress mastery gibi sunuluyor,
- Dart kodu canonical curriculum logic'i yeniden kuruyor,
- Widget kendi pedagojik kararını icat ediyor,
- user state runtime DB'ye yazılıyor,
- LLM core dependency oluyor,
- backend gerekmeye başlıyor,
- student/school-management feature'ları ekleniyor,
- Flutter seçildi diye web/iOS/desktop feature'ları scope'a otomatik ekleniyor,
- kolay olduğu için scope dışı feature ekleniyor.

---

## 61. Flutter'ın Cross-Platform Olması Scope Değildir

Flutter seçilmiş olması:

```text
iOS
web
macOS
Windows
Linux
```

sürümlerinin V1 kapsamına girdiği anlamına gelmez.

V1 dağıtım hedefi:

```text
Android
```

olmaya devam eder.

Kod portable olabilir ancak diğer platformlar için feature/build/QA yapılmaz.

---

## 62. Codex / Antigravity Çalışma Kuralı

Her implementation görevi başlamadan agent:

```text
Hangi capability?
A / B / C / D / E
```

sorusunu cevaplamalıdır.

Hiçbiri değilse:

```text
OUT_OF_SCOPE
```

Görev sonunda rapor:

```text
CAPABILITY:
SCOPE_COMPLIANCE:
RUNTIME_DB_USED:
HARD_CODED_CURRICULUM_DATA:
NEW_USER_DATA_REQUIRED:
LLM_DEPENDENCY:
BACKEND_DEPENDENCY:
CANONICAL_KNOWLEDGE_MODIFIED:
OUT_OF_SCOPE_FEATURES_ADDED:
```

Beklenen:

```text
SCOPE_COMPLIANCE: PASS
RUNTIME_DB_USED: YES
HARD_CODED_CURRICULUM_DATA: NO
NEW_USER_DATA_REQUIRED: NO
LLM_DEPENDENCY: NO
BACKEND_DEPENDENCY: NO
CANONICAL_KNOWLEDGE_MODIFIED: NO
OUT_OF_SCOPE_FEATURES_ADDED: NONE
```

---

## 63. Scope Change Protocol

Yeni fikir doğrudan implement edilmez.

```text
1. Fikri tanımla
2. A/B/C/D/E capability'lerinden birine gerçekten hizmet ediyor mu?
3. Yeni user input gerektiriyor mu?
4. Backend gerektiriyor mu?
5. AI gerektiriyor mu?
6. Yeni canonical/runtime veri gerekiyor mu?
7. Blueprint/scope değişmeli mi?
8. Sonra implement et
```

---

## 64. Android MVP İçin Minimum Veri Gereksinimi

Mevcut runtime package:

```text
Capability A → yeterli
Capability C sequence mode → yeterli
Capability D → yeterli
Capability E → yeterli
Capability B block brief → yeterli
Capability B date-based today → YETERSİZ
```

Eksik:

```text
calendar binding
weekly lesson hours
block hour/time distribution
```

Bu eksiklik Flutter uygulamasını başlatmayı engellemez.

---

## 65. Pre-Development Gate

Flutter kodlamaya başlamadan:

```text
[ ] runtime package RUNTIME_FRESH
[ ] runtime schema 1.0.0
[ ] application query A–E PASS
[ ] PRODUCT_SCOPE.md repo'da
[ ] FLUTTER_BLUEPRINT.md repo'da
[ ] Flutter repo oluşturuldu
[ ] runtime sync strategy belirlendi
[ ] Android emulator/device çalışıyor
```

---

## 66. Önerilen Flutter Repo Dokümantasyonu

```text
docs/
├── PRODUCT_SCOPE.md
└── FLUTTER_BLUEPRINT.md
```

Başlangıçta daha fazla belge gerekmez.

---

## 67. Nihai Mimari Diyagram

```text
┌───────────────────────────────────────┐
│          OFFICIAL SOURCE LAYER        │
│ Curriculum / Textbook / Forms         │
└──────────────────┬────────────────────┘
                   │
                   ▼
┌───────────────────────────────────────┐
│        CANONICAL KNOWLEDGE            │
│ curriculum_map / textbook_map /       │
│ themes / production / planning        │
│ SOURCE OF TRUTH                       │
└──────────────┬───────────────┬────────┘
               │               │
               │               └─────────────┐
               ▼                             ▼
┌────────────────────────┐      ┌────────────────────────┐
│ knowledge.sqlite       │      │ Runtime Compiler       │
│ RAG / Search           │      │ deterministic          │
│ vector/FTS             │      └───────────┬────────────┘
└────────────────────────┘                  │
                                            ▼
                               ┌────────────────────────┐
                               │ course_runtime.sqlite  │
                               │ read-only projection   │
                               │ RUNTIME_FRESH          │
                               └───────────┬────────────┘
                                           │
                                  sync into assets
                                           │
                                           ▼
                               ┌────────────────────────┐
                               │ Flutter Application    │
                               │ Dart + Material 3      │
                               │ Android target         │
                               └───────────┬────────────┘
                                           │
                   ┌───────────────────────┼────────────────────────┐
                   │                       │                        │
                   ▼                       ▼                        ▼
          Ders Yürütme            Yıllık Plan              Kitap-Önce
                   │                       │                        │
                   └───────────────┬───────┴──────────────┬─────────┘
                                   ▼                      ▼
                           Block Brief            Öğretmen Paketi

Separate local state:
shared_preferences → manual_position_override / basic preferences
```

---

## 68. V1 Nihai Veri Akışı

Örnek Block Detail:

```text
Kullanıcı bir block'a dokunur
        ↓
BlockDetail feature state/controller
        ↓
CourseKnowledgeRepository.getBlock(blockId)
        ↓
CourseDatabaseDataSource
        ↓
course_runtime.sqlite
        ↓
block
outcomes
activities
pages
forms
assessment artifact
resource decisions
source refs
        ↓
Domain BlockDetail
        ↓
BlockDetailState
        ↓
Flutter Widget tree
```

Bu zincirde:

```text
LLM = 0
network = 0
canonical JSON parsing = 0
pedagogical inference in app = 0
```

---

## 69. Önerilen İlk Teknik Spike Dosya Yapısı

İlk milestone sonunda yaklaşık şu yapı yeterlidir:

```text
lib/
├── main.dart
├── data/
│   └── course/
│       ├── course_database_installer.dart
│       ├── course_database_data_source.dart
│       └── course_knowledge_repository_impl.dart
├── domain/
│   ├── models/
│   │   ├── theme.dart
│   │   ├── block.dart
│   │   └── outcome.dart
│   └── repositories/
│       └── course_knowledge_repository.dart
└── features/
    └── runtime_spike/
        └── runtime_spike_page.dart
```

Bu aşamada full navigation, state framework, design system ve production feature set kurulmaz.

---

## 70. İlk Spike Kabul Testi

Gerçek runtime database kullanılarak:

```text
APP_START:
PASS

RUNTIME_ASSET_FOUND:
PASS

RUNTIME_LOCAL_COPY:
PASS

RUNTIME_OPEN_READ_ONLY:
PASS

COURSE_ID:
TDE_9

SCHEMA_VERSION:
1.0.0

THEME_COUNT:
4

BLOCK_COUNT:
16

TEMA_02_QUERY:
PASS

REAL_OUTCOMES_RENDERED:
PASS

REAL_ACTIVITIES_RENDERED:
PASS

HARD_CODED_CURRICULUM_DATA:
NO

DB_WRITE_PATH:
NONE

LLM_DEPENDENCY:
NO

NETWORK_DEPENDENCY:
NO
```

Bu PASS olmadan Capability A geliştirilmez.

---

## 71. Blueprint Sonucu

Bugünkü knowledge ve runtime altyapısı Flutter uygulamasını başlatmak için yeterlidir.

Yeni pedagojik ontology veya yeni database genişletmesi **şu anda gerekli değildir**.

İzlenecek sıra:

```text
Knowledge engineering'i durdur.
        ↓
Flutter repo oluştur.
        ↓
Runtime sync mekanizmasını kur.
        ↓
Flutter Integration Spike yap.
        ↓
Gerçek DB'nin Android cihaz/emülatörde okunduğunu kanıtla.
        ↓
Capability A'yı vertical slice olarak tamamla.
        ↓
Capability C
        ↓
Capability D
        ↓
Capability E
        ↓
Capability B1
        ↓
Calendar binding hazır olduğunda B2
```

Flutter'ın cross-platform kapasitesi V1 scope'unu genişletmez.

Date-based “Bugünkü Ders” otomasyonu calendar binding çözülene kadar ertelenir.

Bu sınırlar korunduğunda uygulama küçük, offline, deterministik ve bakımı düşük bir TYMM teacher workflow aracı olarak kalır.
