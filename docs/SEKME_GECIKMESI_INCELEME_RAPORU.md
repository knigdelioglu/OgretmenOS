# Plan ve Kaynaklar Sekmelerinde Yaklaşık 5 Saniyelik Gecikme İnceleme Raporu

**Tarih:** 28 Ağustos 2026  
**Kapsam:** Android, iOS ve macOS'ta ortak Flutter akışı; özellikle TDE_9 üretim runtime'ı  
**İnceleme türü:** Statik kod ve yerel SQLite veri incelemesi; bu turda uygulama kodu değiştirilmedi.

## Yönetici özeti

Gecikmenin ana nedeni platforma özgü bir UI problemi değil, Plan ve Kaynaklar sekmelerine girildiğinde aynı ağır yıllık planın yeniden hesaplanmasıdır. Sekme değişimi `IndexedStack` ile yapılmasına rağmen sayfalar, etkin sekmeye her geçişte `_load()` çağırarak yeniden veri yüklemektedir.

Bu yeniden yüklemenin içindeki `OutcomePlanningService.buildPlan()` zinciri, 16 blokluk TDE_9 verisi için sorguları seri ve tekrarlı biçimde çalıştırıyor. Bir blok ayrıntısı tek bir sorgu değil; 16'ya kadar SQLite/platform çağrısından oluşuyor. Haftalık plan servisi aynı blok ayrıntılarını alıyor, ardından `OutcomePlanningService` bunları ikinci kez alıyor. Kaynaklar sekmesi ayrıca tam planın ardından seçili tema paketini de yeniden yüklüyor.

Sonuç: Kullanıcının gözlediği yaklaşık 5 saniyelik bekleme, yavaş bir SQL sorgusundan çok yüzlerce küçük `sqflite` çağrısının art arda beklenmesinden ve sekme aktivasyonundaki zorunlu yenilemeden kaynaklanıyor. Bu yapı Android'de daha görünür olabilir; ancak akış ortak olduğu için iOS ve macOS'ta da görülmesi beklenir.

## Kullanıcı akışının teknik izi

```text
Sekme tıklaması
  -> TeacherOsApp._selectDestination()
  -> _AppShell yeniden build edilir
  -> IndexedStack aynı sayfa state'lerini günceller
  -> Plan/Kaynaklar didUpdateWidget()
  -> active false -> true ise _future = _load()
  -> OutcomePlanningService.buildPlan()
  -> AssetWeeklyPlanningService.buildPlan()
  -> blok ayrıntıları ve takip kayıtları için seri SQLite çağrıları
  -> FutureBuilder tamamlanana kadar loading görünümü
```

İlgili kod noktaları:

- [`lib/app/app.dart`](/Users/kadir/Desktop/OgretmenOS/lib/app/app.dart:292) üç sayfayı her build'de oluşturup `IndexedStack` içine veriyor; sekme seçimi [`lib/app/app.dart`](/Users/kadir/Desktop/OgretmenOS/lib/app/app.dart:328) satırında yapılıyor.
- [`lib/features/annual_plan/annual_plan_page.dart`](/Users/kadir/Desktop/OgretmenOS/lib/features/annual_plan/annual_plan_page.dart:47) etkin sekmeye her dönüşte `_future = _load()` atıyor.
- [`lib/features/resources/resource_library_page.dart`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:44) aynı davranışı Kaynaklar için uyguluyor ve ayrıca seçili temayı sıfırlıyor.
- [`lib/features/resources/resource_library_page.dart`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:82) Kaynaklar açılırken tam `buildPlan()` çağırıyor.
- [`lib/features/annual_plan/annual_plan_page.dart`](/Users/kadir/Desktop/OgretmenOS/lib/features/annual_plan/annual_plan_page.dart:91) Plan görünümünde yardımcı takip özeti için tam `buildPlan()` çağırıyor.

## Kök neden bulguları

### 1. Sekme aktivasyonu gereksiz tam yenileme başlatıyor

`_AppShell` sayfaları `IndexedStack` içinde state'leri korunacak şekilde tutuyor; ancak Plan ve Kaynaklar sayfalarındaki `didUpdateWidget` koşulları, `active` değeri `false`'dan `true`'ya döndüğünde yeniden yükleme başlatıyor.

Bu nedenle kullanıcı ilk kez sekmeye girdiğinde ve başka sekmeden geri döndüğünde aynı maliyetli veri akışı tekrar çalışıyor. Mevcut `active` yaklaşımı son commit'lerde eklenmiş görünüyor; `git blame` çıktısı bu davranışı 25 ve 28 Ağustos 2026 tarihli değişikliklere bağlıyor.

### 2. `buildPlan()` blok ayrıntılarını seri biçimde ve iki kez okuyor

[`lib/data/calendar/asset_weekly_planning_service.dart`](/Users/kadir/Desktop/OgretmenOS/lib/data/calendar/asset_weekly_planning_service.dart:51) haftaları dolaşırken her yeni blok için `repository.getBlock()` çağırıyor. Repository implementasyonu bu çağrıyı basit blok sorgusuna değil, [`getBlockDetail()`](/Users/kadir/Desktop/OgretmenOS/lib/data/course/course_database_data_source.dart:339) metoduna yönlendiriyor.

`getBlockDetail()` içinde şu işlemler seri `await` ile yürütülüyor:

- blok ve tema;
- blok kazanımları;
- etkinlikler ve ders kitabı bölümleri;
- formlar;
- değerlendirme araçları, boşlukları ve görev bağları;
- kaynak kararları ve kaynak referansları;
- önceki ve sonraki blok.

Önceki ve sonraki blok için [`getAnnualSequence()`](/Users/kadir/Desktop/OgretmenOS/lib/data/course/course_database_data_source.dart:333) yeniden çağrılıyor. Ayrıca şema uyumluluğu için `PRAGMA table_info` kontrolleri de her blok ayrıntısında tekrar yapılıyor.

Haftalık plan tamamlandıktan sonra [`OutcomePlanningService.buildPlan()`](/Users/kadir/Desktop/OgretmenOS/lib/domain/services/outcome_planning_service.dart:40) haftaları tekrar dolaşıyor ve her blok için yine `repository.getBlock()` çağırıyor. Yerel `detailCache` yalnızca tek `buildPlan()` çağrısının kendi içini kapsıyor; haftalık plan servisi ile outcome servisi arasında paylaşılmıyor.

### 3. Kaynaklar sekmesi tam planı yalnızca tema bağlamını bulmak için kuruyor

Kaynaklar akışında [`_resolveLessonContext()`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:72) önce tam yıllık planı kuruyor. Buradaki amaç yalnızca son odak veya mevcut haftaya ait tema kimliğini bulmak. Ardından [`getTeacherPackage()`](/Users/kadir/Desktop/OgretmenOS/lib/data/course/course_database_data_source.dart:375) ile seçili temanın tüm paketi ayrıca yükleniyor.

Yani Kaynaklar için pahalı yol kabaca şöyledir:

```text
getThemes()
  -> buildPlan()       // tüm haftalar, tüm blok ayrıntıları
  -> getTeacherPackage(themeId)
```

Tam plan, kaynak ekranının çizilmesi için zorunlu bir veri değildir; yalnızca varsayılan tema seçimine yardımcı olan bir bağlam verisidir.

### 4. Plan sekmesindeki 4 saniyelik timeout gecikmeyi çözmüyor

Plan sayfasında takip özeti için `buildPlan().timeout(Duration(seconds: 4))` eklenmiş. Bu, yalnızca yardımcı takip özetinin sonucunu kesiyor; ana `_load()` akışı zaten bu çağrının tamamlanmasını bekliyor. Ayrıca timeout süresi kullanıcı gözlemindeki yaklaşık 5 saniyelik deneyimin bir parçası olabilir: önce yıllık sıra ve tercih okumaları, sonra dört saniyeye kadar beklenen yardımcı plan hesaplaması.

Bu timeout bir performans optimizasyonu değil, gecikmiş sonucu yok sayan bir güvenlik ağıdır. Altta yatan yüzlerce seri çağrıyı ortadan kaldırmıyor.

## Sayısal kanıt

Yerel TDE_9 runtime SQLite dosyası incelendi:

| Veri | Satır sayısı |
|---|---:|
| Tema | 4 |
| Blok | 16 |
| Blok-etkinlik bağlantılı blok | 16 |
| Blok-kazanım bağlantılı blok | 16 |
| Etkinlik | 61 |
| Ders kitabı bölümü | 24 |
| Değerlendirme aracı | 3 |
| Değerlendirme görev bağı | 7 |
| Kaynak kararı | 50 |

Bir `getBlockDetail()` çağrısı, mevcut uygulama koduna göre yaklaşık 16 SQLite operasyonu oluşturuyor. 16 blok için bu yaklaşık 256 operasyon demek. `AssetWeeklyPlanningService` ve `OutcomePlanningService` aynı 16 blokluk ayrıntı setini ayrı ayrı istediği için tek bir `OutcomePlanningService.buildPlan()` yaklaşık 516 kurs SQLite operasyonuna ulaşıyor.

Yaklaşık maliyet tablosu:

| Akış | Yaklaşık kurs DB operasyonu | Ek maliyet |
|---|---:|---|
| Plan sekmesi `_load()` | 517 | iki takip DB okuması; SharedPreferences okumaları |
| Kaynaklar sekmesi `_load()` | 531 | tam plan + seçili tema paketi; bir continuity okuması |

Bu sayılar ölçülmüş cihaz süresi değil, üretim TDE_9 satır sayıları ve kodun seri çağrı yapısı üzerinden çıkarılmış çağrı sayısıdır. Her bir `sqflite` çağrısının platform kanalındaki maliyeti cihaza göre değiştiği için toplam süre de değişir.

## Neden tüm platformlarda görülüyor?

- Sekme, Android/iOS/macOS'a özel native bir ekran açmıyor; aynı Flutter widget ve aynı repository katmanı kullanılıyor.
- Veri erişimi `sqflite` üzerinden yerel SQLite'a yapılıyor; her sorgu Dart ile platform veritabanı katmanı arasında asenkron çağrı oluşturuyor.
- Yüzlerce küçük çağrı seri `await` edildiği için toplam süre en yavaş cihaz/iş parçacığı/platform kanalına göre büyüyor.
- Bu nedenle sorun “Android'e özgü SQLite yavaşlığı” olarak sınıflandırılmamalı; Android'de daha belirginleşebilen ortak mimari performans sorunu olarak ele alınmalı.

## Katkıda bulunan ikincil sorunlar

1. **Şema kolon kontrolleri sıcak yolda:** `_hasColumn()` her blok ayrıntısı için `PRAGMA table_info` çalıştırıyor. Bu sonuçlar database data source ömrü boyunca önbelleklenmiyor.
2. **Önceki/sonraki blok sorgusu tekrarlı:** Her blok ayrıntısı iki kez tam yıllık sıra sorguluyor.
3. **Değerlendirme araçları tema filtresi olmadan okunuyor:** `getAssessmentArtifacts()` tüm araçları çekip Dart tarafında tema filtresi uyguluyor.
4. **Plan özeti iki kez takip okuyor:** `OutcomePlanningService.buildPlan()` kayıtları okuyor; Plan sayfası plan döndükten sonra aynı akademik yıl kayıtlarını tekrar okuyor.
5. **İlk build'de üç sayfanın Future'ı başlıyor:** `IndexedStack` tüm çocukları kurduğu için Bu Hafta, Plan ve Kaynaklar sayfalarının ilk `_load()` çağrıları aynı başlangıç döneminde başlatılıyor. Bu durum ilk açılışta kaynak rekabeti yaratabilir; sekme tıklamasındaki temel gecikmenin asıl nedeni ise aktivasyon sonrası tam yeniden yüklemedir.

## Muhtemel regresyon noktası

`active` parametresi ve `didUpdateWidget` içindeki `!oldWidget.active && widget.active` yenilemesi 25 Ağustos 2026 tarihli değişiklikte eklenmiş. Plan sayfasındaki dört saniyelik timeout ve `active` kablolaması 28 Ağustos 2026 tarihli son değişiklikte görünüyor. Bu zaman çizgisi, kullanıcının tarif ettiği sekme tıklaması gecikmesiyle uyumlu bir regresyon adayıdır; tek başına kesin kanıt değildir çünkü ağır `buildPlan()` zinciri daha önce de mevcuttur.

## Önerilen düzeltme sırası

### P0 — Sekmeye dönüşte tam reload'ı kaldır veya yalnızca veri değişiminde tetikle

`IndexedStack` state'i koruduğu için sekme görünür olduğunda otomatik `_load()` başlatılması varsayılan davranış olmamalı. Yenileme; açık kullanıcı yenilemesi, sınıf değişimi veya veri mutasyonu sonrasında yapılmalı. Sekmeye dönüşte gerekiyorsa yalnızca stale-cache kontrolü yapılmalı.

### P0 — Kaynaklar için plan kurmadan tema bağlamını çöz

Son odak temasını doğrudan continuity kaydından okuyup tema geçerli değilse `themes.first` kullanmak mümkün. Mevcut hafta temasına ihtiyaç varsa `AssetWeeklyPlanningService` için hafif bir “sequence + allocation” yolu veya önceden hesaplanmış/cached plan kullanılmalı; kaynak ekranı tam outcome tracking planını beklememeli.

### P1 — Plan verisini tek geçişte üret ve cache'le

`getBlockDetail()` sonucu repository veya planlama katmanında paylaşılmalı. Haftalık plan ve outcome planı aynı `Future`/memoized cache'i kullanmalı. Böylece aynı sekme ziyareti içinde 16 bloğun ayrıntısı ikinci kez okunmaz.

### P1 — Veri erişimini toplulaştır

Blok ayrıntıları için blok kimliklerini tek sorguda alıp modelleri birleştiren batch repository metotları eklenmeli. Özellikle önce/sonraki blok için tam `getAnnualSequence()` çağrıları tek bir sıralı listeyle çözülmeli.

### P2 — Sıcak yol sorgularını sadeleştir

Şema yetenekleri bir kez hesaplanıp önbelleklenmeli; assessment sorguları SQL seviyesinde tema ile filtrelenmeli; yardımcı takip özeti zaten mevcut yıllık plan verisinden türetilebiliyorsa ikinci tracking DB okuması kaldırılmalı.

## Doğrulama planı

Düzeltme sonrasında her platformda release/profile build ile şu ölçümler alınmalı:

1. Bu Hafta → Plan geçiş süresi.
2. Bu Hafta → Kaynaklar geçiş süresi.
3. Plan → Bu Hafta → Plan dönüş süresi.
4. Kaynaklar → Plan → Kaynaklar dönüş süresi.
5. Her akışta repository metod çağrı sayısı ve toplam SQLite/platform çağrı sayısı.
6. İlk yükleme ile cache'li ikinci yükleme ayrı ayrı.

Başarı kriteri: sekme görseli hemen değişmeli; yardımcı veri arka planda tamamlanabilmeli. Normal cihazlarda sekme geçişi için 5 saniyelik bloklayıcı bekleme kalmamalı; hedef ilk görünür içerik için 100–300 ms aralığı, zengin verinin tamamlanması için 1 saniyenin altıdır.

## Test ve inceleme sınırları

- SQLite runtime satır sayıları ve tablo/index yapısı doğrudan yerel TDE_9 runtime dosyasından doğrulandı.
- Kod yolları, `git blame` ve son değişiklik geçmişiyle incelendi.
- Mevcut widget testleri repository ve planning servislerini hafif mock'larla çalıştırıyor; gerçek üretim SQLite çağrı zincirini ve sekme aktivasyonundaki gecikmeyi ölçen bir performans testi yok.
- Flutter test komutu bu ortamda Flutter SDK cache'sine yazmaya çalışırken `Operation not permitted` ile başlatılamadı. Bu nedenle bu raporda cihaz/Frame timing ölçümü iddia edilmiyor; yaklaşık 5 saniyelik kullanıcı gözlemi kod ve çağrı zinciriyle açıklanıyor.

## Sonuç

En yüksek olasılıklı kök neden, sekmeye her dönüşte tetiklenen tam veri yenilemesinin, ortak `buildPlan()` yolunda yaklaşık 516 seri kurs veritabanı operasyonuna dönüşmesidir. İlk uygulanacak düzeltme sekme aktivasyonundaki zorunlu reload'ı kaldırmak; ikinci düzeltme ise plan blok ayrıntılarını tek geçişte üretip paylaşmaktır. Sorgu indeksleri tek başına yeterli çözüm olmayacaktır; problem öncelikle çağrı sayısı, seri bekleme ve gereksiz yeniden hesaplamadır.
