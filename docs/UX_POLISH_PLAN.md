# ÖğretmenOS — UX Polish Planı

**Belge sürümü:** 1.0.0  
**Durum:** Uygulama planı  
**Kapsam:** Flutter / Material 3 istemci UX iyileştirmeleri  
**Ürün otoritesi:** `PRODUCT_SCOPE.md` > `FLUTTER_BLUEPRINT.md` > `AGENT.md`  
**Ana hedef:** Öğretmenin derste uygulamayı açtıktan sonra en az etkileşimle “Bu hafta ne işleyeceğim, nerede kaldım ve deftere ne yazacağım?” sorularını cevaplayabilmesi.

---

## 0. Sprint özeti

- [ ] **UX-0 — Viewport, Safe Area ve klavye güvenliği**
- [ ] **UX-1 — Ortak tasarım sistemi ve ekran iskeleti**
- [ ] **UX-2 — Kazanım Takibi ana ekran polish**
- [ ] **UX-3 — Haftalık Plan polish**
- [ ] **UX-4 — Yıllık Plan polish**
- [ ] **UX-5 — Öğretmen Paketi polish**
- [ ] **UX-6 — Kazanım ve Blok detay ekranları polish**
- [ ] **UX-7 — Etkileşim, geri bildirim ve klavye davranışları**
- [ ] **UX-8 — Responsive, erişilebilirlik ve büyük metin**
- [ ] **UX-9 — Son UX regresyon matrisi ve release gate**

Önerilen uygulama grupları:

```text
Grup 1: UX-0 + UX-1
Grup 2: UX-2 + UX-3
Grup 3: UX-4 + UX-5
Grup 4: UX-6 + UX-7 + UX-8
Grup 5: UX-9 / toplu doğrulama
```

Bu plan uygulanırken ara sprintlerde test çalıştırılması zorunlu değildir. Kod değişiklikleri tamamlandıktan sonra UX-9’da toplu doğrulama yapılmalıdır.

---

## 1. UX hedefi

ÖğretmenOS bir içerik tarayıcısı değil, **ders sırasında kullanılan hızlı öğretmen aracı** gibi hissettirmelidir.

Birincil kullanım akışı:

```text
Uygulamayı aç
→ mevcut haftayı gör
→ kazanımları gör
→ gerekirse durum/not güncelle
→ defter bilgisini kopyala veya ayrıntıya git
```

Bu akışta kullanıcı:

- teknik runtime yapısını bilmek zorunda kalmamalı;
- gereksiz kart ve açıklamalar arasında kaybolmamalı;
- Android sistem çubukları veya klavye nedeniyle kontrole ulaşamama yaşamamalı;
- aynı işlemi farklı ekranlarda farklı biçimde öğrenmek zorunda kalmamalı;
- planlanan program ile gerçek sınıf takibini karıştırmamalı.

### Ana UX başarı ölçütleri

- Uygulama açıldığında mevcut haftanın kazanımları **ilk ekranda anlaşılır olmalı**.
- “İşlendi” gibi sık kullanılan durum değişiklikleri **1 dokunuşta** yapılabilmeli.
- Öğretmen notu **en fazla 2 dokunuşta** eklenebilmeli.
- Haftalar arasında geçiş sağ/sol swipe, oklar ve seçici ile tutarlı çalışmalı.
- “Bu haftaya dön” eylemi seçili hafta mevcut haftadan farklıysa görünür olmalı.
- Ders defteri için gereken doğrulanmış metne **uzun gezinme olmadan** ulaşılmalı.
- 360 px genişlikte taşma olmamalı.
- Android gesture navigation ve 3-button navigation modlarında içerik sistem çubuğunun altında kalmamalı.
- Sistem yazı ölçeği 2.0 olduğunda ana akış kullanılabilir kalmalı.
- Light ve dark mode aynı bilgi hiyerarşisini korumalı.

---

## 2. Mevcut güçlü yönler — korunacak

Aşağıdaki yapılar yeniden yazılmamalı; polish bunların üzerine kurulmalıdır:

- Material 3 tema kullanımı.
- `AppSpacing` ölçeği.
- Minimum 48×48 dokunma hedefi yaklaşımı.
- Telefon için `NavigationBar`, geniş ekran için `NavigationRail`.
- Kazanım odaklı ana navigasyon.
- Kart tabanlı kazanım takibi.
- Durum chipleri ve carry-over görünürlüğü.
- Uzun kazanım metni için progressive disclosure.
- Haftalar arasında swipe ve “Bu haftaya dön” davranışı.
- Karttan hızlı durum/not işlemleri.
- Dark mode ve büyük sistem yazısı desteği.
- Runtime bilgisini öğretmen diline dönüştüren presentation katmanı.
- Read-only canonical runtime / writable teacher-state ayrımı.

UX polish sırasında bu davranışların semantiği değiştirilmemelidir.

---

## 3. Tasarım ilkeleri

### 3.1 Classroom-first

Ekrandaki ilk öncelik “şimdi derste ne lazım?” olmalıdır. Arşiv, teknik durum veya veri kaynağı ikinci planda kalmalıdır.

### 3.2 Truth-first

UX sadeleşmesi uğruna:

- olmayan kazanım-saat ilişkisi üretilmez;
- block-level bilgi outcome-level gibi gösterilmez;
- teknik belirsizlik gizlenmez, öğretmen dilinde açıklanır;
- planlanan program ile gerçekleşen takip birleştirilmez.

### 3.3 Progressive disclosure

İlk ekranda:

- kod,
- kısa resmî metin,
- durum,
- hafta/blok bağlamı,
- kritik eylemler

görünür olmalı; uzun açıklamalar ve kaynak ayrıntıları kullanıcı istediğinde açılmalıdır.

### 3.4 One-hand phone use

Sık işlemler telefonun alt/orta erişim alanına yakın tutulmalıdır. Kritik eylem sadece sağ üst köşedeki küçük ikonlara bağlı olmamalıdır.

### 3.5 Consistency over novelty

Aynı kavram her yerde aynı bileşen ve dil ile temsil edilmelidir:

```text
hafta seçimi
status chip
section heading
empty state
copy feedback
save feedback
carry-over
blok bağlantısı
```

---

# UX-0 — Viewport, Safe Area ve klavye güvenliği

**Öncelik: P0**

Amaç: Hiçbir etkileşim alanının Android sistem UI’sı veya klavye altında kalmaması.

> Not: Alt sistem navigasyon alanını uygulama kökünde koruyan çözüm PR #6’da hazırlanmıştır. Bu sprint uygulanırken o değişiklik mevcutsa yeniden yazılmamalı; doğrulanıp baz alınmalıdır.

### İşler

- [ ] Uygulama kökünde bottom safe-area kontratını tek yerde garanti et.
- [ ] Top-level ve push route ekranlarının aynı sistem inset davranışını kullandığını doğrula.
- [ ] Gesture navigation ve 3-button navigation için alt inset’i doğrula.
- [ ] Landscape durumda yan sistem inset’lerinin kritik kontrolleri örtmediğini doğrula.
- [ ] TextField açıldığında `viewInsets.bottom` nedeniyle kaybolan save/action alanlarını düzelt.
- [ ] Dialog, dropdown ve gelecekte kullanılacak bottom-sheet bileşenlerinin klavyeyle çakışmamasını standardize et.
- [ ] Uygulama genelinde yazı alanı dışına dokunulduğunda klavyeyi kapatan tutarlı davranış getir.
- [ ] Scroll edilen ekranlarda son kart/buton ile ekran altı arasında yeterli rahatlık alanı bırak.
- [ ] Safe-area çözümünde gereksiz double-padding oluşmadığını doğrula.

### Kabul kriteri

360×640 ve 360×800 Android viewport’larında son erişilebilir kontrol sistem navigation alanının üstünde kalır; klavye açıkken kaydet/iptal eylemleri erişilebilir olur.

---

# UX-1 — Ortak tasarım sistemi ve ekran iskeleti

**Öncelik: P0/P1**

Amaç: Ekranların aynı uygulamanın parçaları gibi görünmesi ve yeni UX kararlarının tek tek feature dosyalarında çoğalmaması.

### 1.1 Shared component konsolidasyonu

- [ ] `AppPage` için standart yatay/dikey padding ve safe bottom spacing belirle.
- [ ] Top-level ekran başlıkları ile `AppBar` başlığının aynı metni tekrar etmesini engelle.
- [ ] Ortak `PageHero` / `ContextHero` bileşeni çıkarılması gerekiyorsa yalnız tekrar gerçekten varsa çıkar.
- [ ] Hafta seçici için ortak reusable bileşen oluştur: önceki / dropdown / sonraki / bu haftaya dön.
- [ ] `StatusPanel`, `InfoCard`, `MetricChip`, durum chipleri ve section heading kullanım kurallarını standardize et.
- [ ] Empty / Error / Loading / Unresolved görünüşlerini aynı dil ve spacing sistemiyle hizala.
- [ ] Primary / secondary / destructive action hiyerarşisini ortaklaştır.

### 1.2 Görsel tokenlar

- [ ] Kart radius, border ve elevation kullanımını tek standarda indir.
- [ ] Status renklerini `ColorScheme` üzerinden semantik hale getir; rastgele hard-coded renk kullanma.
- [ ] Başlık/body/label seviyeleri için net typography hiyerarşisi tanımla.
- [ ] Dense bilgi göstermek için chip kullanımını sınırlı tut; uzun metni chip içine sıkıştırma.
- [ ] Section aralıklarını ekranda gereksiz dikey boşluk üretmeyecek biçimde ayarla.
- [ ] Telefon ve tablet için içerik `maxWidth` davranışlarını standardize et.

### Kabul kriteri

Ana dört sekmede aynı kavramlar aynı bileşen diliyle görünür; ekran bazlı görsel sapmalar azalır ve ortak davranış feature dosyalarında tekrar edilmez.

---

# UX-2 — Kazanım Takibi ana ekran polish

**Öncelik: P1 — ürünün en kritik ekranı**

Amaç: Öğretmen uygulamayı açar açmaz haftanın kazanımlarını görsün; ikincil bilgiler ana işi aşağı itmesin.

### 2.1 İlk viewport hiyerarşisi

- [ ] AppBar + PageHeader tekrarını azalt; başlık alanını kompaktlaştır.
- [ ] Hafta seçiciyi ve haftanın bağlamını ilk viewport içinde tut.
- [ ] “Bu haftanın kazanımları” alanını Deftere Bakış gibi ikincil içeriklerin arkasına düşürme.
- [ ] Haftanın ders saati / blok dağılımını kompakt özet olarak göster.
- [ ] Filtreleri fazla dikey alan tüketmeden görünür tut.
- [ ] Mevcut haftadan uzaklaşınca “Bu haftaya dön” eylemini belirgin fakat baskın olmayan biçimde göster.

### 2.2 Outcome card sadeleştirme

- [ ] Kart üstünde: outcome code + status + resmî metin ana bilgi olsun.
- [ ] Tema/blok bağlamını ikinci seviye metadata olarak göster.
- [ ] “Bu hafta ilgili blok: X saat” bilgisini outcome’a ait resmî saat gibi algılanmayacak biçimde etiketle.
- [ ] Carry-in / carry-out durumunu tek bakışta ayırt ettir.
- [ ] Uzun outcome metninde mevcut expand/collapse davranışını koru.
- [ ] Tüm kartı detay navigasyonu için tappable tut; ayrı “Detay” butonu gereksiz tekrar oluşturuyorsa kaldır.
- [ ] Ana hızlı eylem `İşlendi` olsun.
- [ ] `Not` ikincil eylem olarak doğrudan erişilebilir kalsın.
- [ ] `Devam ediyor / Kısmen / Taşı / Sıfırla` overflow altında kalabilir.
- [ ] Öğretmen notu varsa kartta kısa ve anlaşılır bir indicator göster.

### 2.3 Deftere Bakış

- [ ] Deftere Bakış alanını kazanım listesini aşağı itmeyecek konuma taşı veya kompakt/collapsible hale getir.
- [ ] Kopyalama işlemi sonrası kısa snackbar geri bildirimi ver.
- [ ] Kopyalanan metnin yalnız authoritative veri içerdiğini koru.
- [ ] Birden fazla blok/tema olan hafta metninin okunabilirliğini doğrula.

### 2.4 State davranışı

- [ ] Yerel mutation sonrası tüm ekranı loading state’e düşürme.
- [ ] Durum/not kaydı sonrası kart state’ini mümkün olduğunca yerinde güncelle.
- [ ] Haftalar arasında geçişte scroll pozisyonu davranışını bilinçli belirle; yeni haftada listenin anlamlı başlangıcına git.
- [ ] Filtre değişiminde kullanıcıyı beklenmedik scroll konumunda bırakma.

### Kabul kriteri

Telefon portrait açılışında öğretmen mevcut hafta bağlamını ve ilk kazanım kartını gereksiz uzun scroll olmadan görebilir; outcome durumu tek dokunuşla güncellenebilir.

---

# UX-3 — Haftalık Plan polish

**Öncelik: P1**

Amaç: `Kazanımlar` ile `Haftalık Plan` ekranlarının rolünü net ayırmak.

`Kazanımlar` = öğretmenin execution/tracking ekranı.  
`Haftalık` = saat ve blok dağılımının schedule ekranı.

### İşler

- [ ] Kazanım ekranındaki ortak hafta navigator’ını yeniden kullan.
- [ ] Swipe + önceki/sonraki + “Bu haftaya dön” davranışını aynı hale getir.
- [ ] Haftanın toplam 5 saatlik dağılımını ekranın ana görsel bilgisi yap.
- [ ] Birden fazla segment varsa saat dağılımını daha kolay taranabilir göster.
- [ ] Blok segmentini açma eylemini kartın tamamında anlaşılır hale getir.
- [ ] Outcome listesini schedule ekranında ikincil referans olarak tut; ana Kazanımlar ekranını tekrar etme.
- [ ] “resmî blok saati değildir” uyarısını doğru fakat sürekli baskın olmayan bir bilgi sunumuna taşı.
- [ ] Event Week görünümünü diğer ekranlarla aynı empty/special-state diline getir.

### Kabul kriteri

Kullanıcı iki ekranın neden ayrı olduğunu ilk bakışta anlayabilir: biri **ne işleyeceğim/takip**, diğeri **haftanın saat ve blok dağılımı**.

---

# UX-4 — Yıllık Plan polish

**Öncelik: P1/P2**

Amaç: 16 blokluk yıllık sırayı uzun ve düz bir liste olmaktan çıkarıp “neredeyim / sırada ne var?” sorusuna cevap veren bir rotaya dönüştürmek.

### İşler

- [ ] Seçili “Burada kaldım” konumunu ekranın en güçlü öğesi yap.
- [ ] “Burada kaldım” yoksa yönlendirici empty state’i kısa ve eylem odaklı tut.
- [ ] Teknik timeline resolution bilgisini ana kartta gereğinden fazla öne çıkarma; açıklama/info seviyesine taşı.
- [ ] Yıllık listeyi tema bazında görsel olarak grupla.
- [ ] Seçili bloğa hızlı scroll/jump davranışı ekle.
- [ ] Geçmiş / seçili / sonraki bloklar arasında görsel fark oluştur.
- [ ] `Burada kaldım` eylemini 48dp+ ve açık bir dokunma hedefi olarak koru.
- [ ] Blok detayına geçiş ile “burada kaldım” eylemini görsel olarak karıştırma.
- [ ] Büyük metinde timeline kartlarının taşmadığını doğrula.

### Kabul kriteri

Kullanıcı Yıllık Plan’a girdiğinde 2–3 saniye içinde işaretlenmiş konumu ve sonraki bloğu anlayabilir.

---

# UX-5 — Öğretmen Paketi polish

**Öncelik: P2**

Amaç: Çok miktarda veriyi tek uzun sayfa gibi değil, hızlı açılan “tema dosyası” olarak kullanmak.

### İşler

- [ ] Tema seçiciyi kolay bulunur ve ekranda tutarlı bir konuma getir.
- [ ] Tema değişiminde tüm sayfanın sert loading flash vermesini azalt.
- [ ] İlk açılan bölümün gerçekten en yararlı bölüm olduğundan emin ol.
- [ ] Bölüm başlıklarında sayıların hızlı taranmasını sağla.
- [ ] 0 içerikli bölümleri görsel olarak geri plana al; kullanıcıyı gereksiz accordion kalabalığına boğma.
- [ ] Bölümler arasında hızlı jump/anchor ihtiyacını değerlendir; gerekiyorsa kompakt bölüm navigasyonu ekle.
- [ ] Nested card görünümünü azalt; card-inside-card hiyerarşisini sadeleştir.
- [ ] Kaynak/teknik dayanak bölümlerini öğretmenin sınıf içi kullanımından daha düşük görsel öncelikte tut.
- [ ] Blok, kitap, etkinlik, değerlendirme ve materyal bölümlerinde aynı boş/eksik veri dili kullan.

### Kabul kriteri

Öğretmen seçili tema içinde istediği “kitap / etkinlik / değerlendirme / materyal” alanına uzun bir görsel tarama yapmadan ulaşabilir.

---

# UX-6 — Kazanım ve Blok detay ekranları polish

**Öncelik: P1/P2**

Amaç: Detay ekranlarını veri dökümü olmaktan çıkarıp “ders yürütme” yüzeyi haline getirmek; hiçbir authoritative ilişkiyi değiştirmemek.

## 6.1 Kazanım detay

- [ ] Üstte outcome kodu, resmî metin ve tracking status’u net göster.
- [ ] Status eylemlerinin görsel önceliğini sadeleştir; aynı anda çok sayıda eşdeğer buton gösterme.
- [ ] Kaydetme sırasında ekranın tamamını kilitlemek yerine sadece ilgili eylemi disable et.
- [ ] Öğretmen notu alanında dışarı dokununca klavye kapanmalı.
- [ ] Klavye açıkken “Notu kaydet” görünür/erişilebilir kalmalı.
- [ ] Değişmemiş not için gereksiz save hissini azaltma seçeneğini değerlendir.
- [ ] Carry-over uyarılarını kısa ve planlanan/gerçekleşen ayrımını net anlatacak biçimde tut.
- [ ] Deftere Bakış kopyalama eylemini kolay erişilebilir tut.
- [ ] Block-level ilişkilerin etiketleri açıkça “blok bağlamı” demeli.

## 6.2 Block detail

- [ ] Uzun Block Detail sayfasını anlamlı bölümlere ayır ve progressive disclosure kullan.
- [ ] Outcome / kitap / etkinlik / form / değerlendirme / materyal / kaynak bölümlerinin görsel hiyerarşisini standardize et.
- [ ] Önceki/sonraki blok navigasyonunu kolay bulunur hale getir.
- [ ] Kaynak ID gibi öğretmene katkısı olmayan teknik metinleri ana yüzeyde baskın gösterme.
- [ ] Boş blok ilişkilerinde teknik placeholder yerine doğru empty state göster.
- [ ] Outcome’a geri dönülebilen akışlarda route/back davranışını tutarlı yap.

### Kabul kriteri

Detay sayfasında öğretmen önce sınıfta kullanacağı bilgiye ulaşır; kaynak ve teknik doğrulama ayrıntıları daha sonra gelir.

---

# UX-7 — Etkileşim, geri bildirim ve klavye davranışları

**Öncelik: P1**

### 7.1 Haptic policy

Haptic her dokunuşta değil, anlamlı state değişimlerinde kullanılmalıdır.

- [ ] `İşlendi`, carry-over ve önemli kayıt işlemlerinde haptic kullanılabilir.
- [ ] Basit filtre değişimi, sıradan navigasyon veya her küçük tap için gereksiz titreşimi azalt.
- [ ] Platform haptic Future’ı UI state güncellemesini bloke etmemeli.

### 7.2 Snackbar / feedback

- [ ] “Kaydedildi”, “Kopyalandı”, “Taşındı” gibi feedback kısa ve net olsun.
- [ ] Aynı işlem hem snackbar hem modal hem haptic ile aşırı feedback vermesin.
- [ ] Hata mesajları kullanıcı dilinde; teknik exception yalnız debug bağlamında olsun.
- [ ] Destructive işlem gerekiyorsa yalnız gerçek veri kaybı riski olduğunda confirmation kullan.

### 7.3 Keyboard / focus

- [ ] App genelinde boş alana dokunulduğunda aktif TextField focus’u kapanmalı.
- [ ] Route değişiminde klavye/focus geride kalmamalı.
- [ ] Dialog kapandıktan sonra controller/focus yaşam döngüsü güvenli olmalı.
- [ ] Klavye açıldığında aktif TextField görünür kalmalı.

### 7.4 Motion

- [ ] Expand/collapse hareketleri 150–250 ms aralığında sade tutulmalı.
- [ ] Büyük sayfa geçiş animasyonları eklenmemeli.
- [ ] `MediaQuery.accessibleNavigation` aktifken gereksiz motion azaltılmalı.

---

# UX-8 — Responsive, erişilebilirlik ve büyük metin

**Öncelik: P1**

### Responsive hedefler

Test viewport’ları en az:

```text
360×640   küçük Android telefon
360×800   standart dar telefon
412×915   büyük telefon
800×1280  tablet portrait
1280×800  tablet landscape
```

- [ ] 360 px genişlikte hiçbir `RenderFlex overflow` olmamalı.
- [ ] Büyük metinde chip ve action alanları wrap edebilmeli.
- [ ] Tablet görünümünde yalnız NavigationRail eklemekle yetinme; uygun ekranlarda içerik genişliğini/kolon kullanımını iyileştir.
- [ ] Çok geniş ekranlarda kartların gereksiz tam genişlikte uzamasını engelle.
- [ ] Landscape telefonda alt/yan sistem inset’lerini doğrula.

### Accessibility

- [ ] Bütün interaktif kontroller 48×48 minimum hedefi korusun.
- [ ] Icon-only butonlarda anlamlı tooltip/semantic label olsun.
- [ ] Durum yalnız renkle anlatılmasın; metin/ikon da taşısın.
- [ ] Light/dark mode kontrastını semantic status renkleriyle doğrula.
- [ ] Text scale 1.0 / 1.5 / 2.0 için ana ekranlar test edilsin.
- [ ] Screen reader okuma sırası: başlık → bağlam → ana içerik → eylemler şeklinde mantıklı olsun.
- [ ] Uzun resmî metin truncation olduğunda tam metne erişim daima mümkün olsun.

---

# UX-9 — Son UX regresyon matrisi ve release gate

**Öncelik: P0 final gate**

Kod polish tamamlandıktan sonra tek toplu validation yapılmalıdır.

### Otomatik doğrulama

- [ ] `flutter analyze`
- [ ] runtime contract doğrulaması
- [ ] mevcut unit/integration/widget testleri
- [ ] yeni UX widget regresyonları
- [ ] Android release APK build

### Zorunlu UX regresyon testleri

- [ ] Global bottom safe-area.
- [ ] Telefon bottom navigation görünümü.
- [ ] Tablet NavigationRail görünümü.
- [ ] 360 px genişlikte overflow yok.
- [ ] 2.0 text scale ana ekran kullanılabilir.
- [ ] Dark mode ana ekran kullanılabilir.
- [ ] Kazanım kartı status değişimi.
- [ ] Kazanım kartı not ekleme/düzenleme.
- [ ] Swipe ile hafta değişimi.
- [ ] “Bu haftaya dön”.
- [ ] Uzun outcome expand/collapse.
- [ ] Carry-over gösterimi.
- [ ] Deftere Bakış copy feedback.
- [ ] Yıllık Plan `Burada kaldım` minimum touch target.
- [ ] Öğretmen Paketi accordion davranışı.
- [ ] TextField açıldığında klavye altında action kalmaması için uygun widget/focus testi.

### Manuel cihaz kontrolü

En az bir gerçek Android cihaz veya emulator üzerinde:

```text
gesture navigation
3-button navigation
portrait
landscape
keyboard open/close
light mode
dark mode
font scale >= 1.5
```

kontrol edilmelidir.

---

## 10. Ekran bazlı öncelik sırası

| Sıra | Ekran | Neden |
|---|---|---|
| 1 | Kazanım Takibi | Uygulamanın ana kullanım yüzeyi |
| 2 | Kazanım Detay | Ders yürütme + tracking + not |
| 3 | Haftalık Plan | Güncel schedule bağlamı |
| 4 | Yıllık Plan | Öğretmenin sınıf ilerleme konumu |
| 5 | Block Detail | Yoğun authoritative ders bağlamı |
| 6 | Öğretmen Paketi | Hazırlık / referans yüzeyi |

Bu sıra görsel estetik değil, sınıf içi kullanım sıklığına göre belirlenmiştir.

---

## 11. Teknik borç oluşturmayı engelleyen UX kuralları

- Ortak davranış feature ekranlarında kopyalanmamalı.
- Yeni state-management framework sadece UX polish için eklenmemeli.
- Tasarım sistemi için üçüncü taraf UI framework eklenmemeli.
- Material 3 temel alınmalı.
- Tek kullanımlık “helper abstraction” üretmek yerine gerektiğinde widget içinde sade kod tercih edilmeli.
- Gerçek tekrar oluşmadan generic component çıkarılmamalı.
- `course_runtime.sqlite` veya canonical knowledge UX nedeniyle değiştirilmemeli.
- UX polish yeni curriculum ilişkileri türetmemeli.
- Ekran sadeleştirmek için authoritative veri silinmemeli; gerekiyorsa progressive disclosure kullanılmalı.

---

## 12. Out of scope

Bu UX planı aşağıdakileri kapsamaz:

- yeni öğrenci/şube yönetimi;
- notlandırma/ölçme özellikleri;
- cloud sync veya hesap sistemi;
- MEBBİS/e-Okul entegrasyonu;
- LLM/AI üretimi;
- OCR/PDF alma;
- canonical curriculum değişikliği;
- yeni akademik takvim üretimi;
- marka/logo yeniden tasarımı;
- ağır custom animasyon sistemi;
- genel amaçlı not/task modülü.

---

## 13. Definition of Done

UX Polish tamamlandı sayılmak için:

- [ ] Hiçbir ana veya detay ekranında Android sistem navigation alanının altında içerik/eylem kalmıyor.
- [ ] Klavye aktifken kritik kaydetme/iptal eylemleri erişilebilir.
- [ ] Ana ekran mevcut haftanın kazanımlarını hızlı gösteriyor.
- [ ] Ana ve Haftalık ekranların rolleri net biçimde ayrışıyor.
- [ ] Ortak hafta navigasyonu ve ortak feedback davranışları tutarlı.
- [ ] Yıllık Plan’da mevcut öğretmen konumu hızlı bulunuyor.
- [ ] Öğretmen Paketi yoğun bilgiyi progressive disclosure ile sunuyor.
- [ ] Detay ekranlarında sınıfta kullanılacak bilgi teknik dayanak bilgisinden önce geliyor.
- [ ] 360 px genişlikte overflow yok.
- [ ] 2.0 text scale ile temel işlemler tamamlanabiliyor.
- [ ] Dark mode kontrast ve hiyerarşi bozulmuyor.
- [ ] Tüm kritik touch target’lar en az 48×48.
- [ ] Planlanan ve gerçekleşen takip ayrımı UX polish sonrasında da korunuyor.
- [ ] Runtime authority ve read-only sınırı değişmiyor.
- [ ] Analyzer, runtime contract, full tests ve Android release build PASS.

---

## 14. Uygulama notu

Bu doküman `PRODUCT_SCOPE.md` yerine geçmez. UX işi sırasında ürün kapsamını değiştirecek bir ihtiyaç ortaya çıkarsa önce scope güncellenmelidir.

Uygulama sırasında checkbox’lar tamamlandıkça `[x]` olarak güncellenmeli; bir sprint ancak acceptance kriterlerinin tamamı karşılandığında bitmiş sayılmalıdır.
