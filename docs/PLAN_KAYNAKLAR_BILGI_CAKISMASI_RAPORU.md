# Bu Hafta, Plan ve Kaynaklar Bilgi Çakışması Raporu

**Tarih:** 28 Ağustos 2026  
**Kapsam:** Aktif Flutter ürün kabuğundaki `Bu Hafta`, `Plan` ve `Kaynaklar` yüzeyleri; bu yüzeylerden açılan `Ders Bloğu`, `Kazanım Ayrıntısı` ve `Ders Planı` ayrıntıları  
**İnceleme türü:** Statik widget/servis incelemesi, ürün sözleşmesi karşılaştırması ve TDE_9 doğrulanmış runtime sayım kontrolü

## Yönetici özeti

Üç üst düzey sekme aynı kaynak listesini doğrudan göstermiyor. Ancak iki belirgin bilgi sahipliği problemi var:

1. `Bu Hafta` ve `Plan`, öğretmenin mevcut tema/blok konumunu benzer biçimde tekrar ediyor. `Bu Hafta`nin “ŞİMDİ” kartı ile `Plan`ın “ŞU AN BURADASIN” kutusu aynı süreklilik bilgisinden besleniyor; kullanıcı iki ayrı yerde aynı “neredeyim?” cevabını görüyor.
2. `Plan`dan açılan `Ders Bloğu` ayrıntısı, `Kaynaklar` ekranındaki kitap, etkinlik, form, değerlendirme ve kaynak referansı kategorilerini tekrar sunuyor. Bu tekrar üst düzey `Plan` kodunda değil, Plan akışının doğal devamında ortaya çıkıyor ve kullanıcı açısından yine aynı bilginin iki farklı yerde bulunmasına yol açıyor.

**Sonuç:** `RESTRUCTURE_RECOMMENDED` — veri doğruluğu açısından P0 yok; fakat bilgi mimarisi ve bağlam sahipliği P1/P2 düzeyinde sadeleştirilmeli. Kaynak ekranı program/çıktı ekranına dönüştürülmemeli; Plan da kaynak kataloğunun kopyası olmamalı.

## Ekranların gerçek görevleri

| Yüzey | Birincil görev | Kendine ait kalması gereken bilgi |
|---|---|---|
| `Bu Hafta` | Öğretmenin bugün/şimdi neye geçeceğini bulması | Seçili hafta, tek odak kazanım, “Ders ayrıntısını aç”, isteğe bağlı takip ve haftalık ders planı akışı |
| `Plan` | Yıllık öğretim sırasını ve mevcut konumu görmek | Tema → blok sırası, sıra numarası, geçici konum işareti, isteğe bağlı takip özeti |
| `Kaynaklar` | Seçili temaya ait doğrulanmış materyalleri bulmak | Ders kitabı bölümleri, etkinlikler, formlar, değerlendirme araçları/görevleri ve kaynak dayanakları |
| `Ders Bloğu` / `Kazanım Ayrıntısı` | Seçili bağlamda derse hazırlanmak | İlk bakışta gerekli özet; ayrıntılı ilişki ve öğretmen notu |
| `Ders Planı` | Saat bazlı uygulanabilir ders akışını takip etmek | Plan adımları, öğretmen/öğrenci aksiyonları, materyaller, plan ilerlemesi |

Üst düzey navigasyonun `Bu Hafta`, `Yıllık` ve `Kaynaklar` olması ürün sözleşmesinde tanımlı; kullanıcıya görünen etiket ise `Yıllık` yerine `Plan`. Bu nedenle raporda `Plan` adıyla `AnnualPlanPage` kastedilmiştir.

## Çakışma envanteri

### 1. Aynı “mevcut konum” bilgisinin iki kez sunulması — P1

`Bu Hafta`nin odak kartı hafta numarasını, tarih aralığını, ders saatini, blok başlığını ve temayı gösteriyor. Aynı akışta `Plan` ekranı ayrıca “ŞU AN BURADASIN” altında tema + blok ve “Öğretim sırası: N. blok / total” bilgisini gösteriyor.

Kanıt:

- `Bu Hafta`: [`this_week_page.dart:585-650`](/Users/kadir/Desktop/OgretmenOS/lib/features/this_week/this_week_page.dart:585)
- `Plan`: [`annual_plan_page.dart:448-528`](/Users/kadir/Desktop/OgretmenOS/lib/features/annual_plan/annual_plan_page.dart:448)
- Ortak süreklilik kaynağı: [`continuity_this_week_page.dart:118-132`](/Users/kadir/Desktop/OgretmenOS/lib/features/this_week/continuity_this_week_page.dart:118)

Bu tekrar tamamen gereksiz değildir: `Bu Hafta`de “şimdi ne yapacağım?”, `Plan`da “yıllık sırada neredeyim?” soruları farklıdır. Sorun, iki ekranın da aynı bilgiyi başlık düzeyinde “şu an” diliyle sahiplenmesidir. `Plan` ekranında aktif blok vurgusu yeterli olabilir; “ŞU AN BURADASIN” kutusu ve tekrar eden tema/blok metni daha kompakt bir konum satırına indirilebilir.

### 2. Tema adının üç yüzeyde tekrar edilmesi — P2

Tema adı:

- `Bu Hafta` odak kartında gösteriliyor;
- `Plan` ekranında tema kartının başlığı ve aktif konum kutusunda gösteriliyor;
- `Kaynaklar` ekranında tema seçicinin seçili değeri ve seçili paketin içeriği bağlamında kullanılıyor.

Bu, tanınabilirlik için kısmen gerekli bir tekrar. Ancak ekranlar arasında açık bir “bu kaynaklar şu haftadaki şu blok için” bağlantısı olmadığında aynı tema adı farklı kapsamların başlığı gibi algılanıyor. Özellikle `Kaynaklar` tema seviyesinde tüm paketi gösteriyor; `Bu Hafta` ve `Plan` ise hafta/blok seviyesinde çalışıyor.

Kanıt:

- `Plan` tema grupları: [`annual_plan_page.dart:658-675`](/Users/kadir/Desktop/OgretmenOS/lib/features/annual_plan/annual_plan_page.dart:658)
- `Kaynaklar` tema seçimi: [`resource_library_page.dart:507-540`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:507)
- `Kaynaklar` tema paketinin tüm kaynak kategorileri: [`resource_library_page.dart:376-458`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:376)

### 3. Plan akışında kaynak kayıtlarının Kaynaklar ekranında yeniden sunulması — P1

`Plan`ın kendisi yalnızca tema/blok sırası gösteriyor. Fakat Plan’dan bir blok açıldığında `BlockDetailPage` şu kaynak türlerini yeniden gösteriyor:

- kitap bölümleri ve etkinlikler;
- formlar;
- değerlendirme araçları;
- kaynak referansları;
- ayrıca “Derste lazım” kartında ilk kitap/etkinlik ve değerlendirme özeti.

`Kaynaklar` ise aynı türleri seçili tema paketi için ayrı ayrı listeliyor: `Ders kitabı`, `Etkinlikler`, `Formlar`, `Değerlendirme` ve `Kaynak dayanakları`.

Kanıt:

- Blok ayrıntısının hızlı özeti: [`block_detail_page.dart:92-175`](/Users/kadir/Desktop/OgretmenOS/lib/features/block/block_detail_page.dart:92)
- Blok ayrıntısının geniş kaynak bölümleri: [`block_detail_page.dart:238-308`](/Users/kadir/Desktop/OgretmenOS/lib/features/block/block_detail_page.dart:238)
- Kaynak kategorileri: [`resource_library_page.dart:391-458`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:391)
- Aynı runtime verisinin iki paketleme biçiminde okunması: [`course_database_data_source.dart:424-486`](/Users/kadir/Desktop/OgretmenOS/lib/data/course/course_database_data_source.dart:424)

Bu, içerik doğruluğu çakışması değil, sunum sahipliği çakışmasıdır. Kullanıcı aynı kitap bölümü veya etkinlik için “blok ayrıntısında mı, kaynaklarda mı?” kararını vermek zorunda kalıyor. En uygun sınır: Blok ayrıntısı yalnızca `Derste lazım` için kısa, bağlama bağlı özeti ve `Kaynaklarda aç` bağlantısını tutmalı; tam kaynak kataloğu `Kaynaklar`da kalmalı.

### 4. Ders Planı ayrıntısında etkinlik/form adlarının tekrar edilmesi — P2

`Bu Hafta` içindeki “Bu haftanın ders planı” paneli saat bazlı ders satırlarını gösteriyor ve `SingleLessonPlanPage`e açılıyor. Ders planı ayrıntısı, plan adımlarının içinde ders kitabı etkinliklerini ve değerlendirme formlarını yeniden listeliyor. `Kaynaklar` da aynı etkinlik ve formları tema envanteri olarak listeliyor.

Buradaki tekrarın bir kısmı göreve hizmet ediyor: Ders Planı “hangi adımda kullanacağım?”, Kaynaklar “hangi materyaller var?” sorusunu cevaplıyor. Buna rağmen ders planında tam kaynak açıklamasını kopyalamak yerine kaynak kimliği/adı ve `Kaynaklarda aç` bağlantısı kullanılması daha net bir ilişki kurar.

Kanıt:

- Haftalık panel: [`lesson_plan_panels.dart:130-195`](/Users/kadir/Desktop/OgretmenOS/lib/features/lesson_plan/lesson_plan_panels.dart:130)
- Ders planı adımlarındaki tekrar: [`lesson_plan_page.dart:448-526`](/Users/kadir/Desktop/OgretmenOS/lib/features/lesson_plan/lesson_plan_page.dart:448)
- Kaynak envanteri: [`resource_library_page.dart:604-645`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:604)

### 5. Hafta seçimi ile Kaynaklar bağlamının ayrışması — P2, doğrulanması gereken risk

`Bu Hafta` içinde `Hafta değiştir` ile seçilen hafta state'i `ThisWeekPage` içinde tutuluyor. `Kaynaklar` ise tema bağlamını şu sırayla çözüyor: son görüntülenen ders → mevcut öğretim haftası → ilk geçerli tema. Bu nedenle kullanıcı başka bir haftayı yalnızca inceleyip ardından `Kaynaklar`a geçerse, kaynak ekranının seçimi incelediği hafta yerine son görüntülenen veya mevcut haftaya göre kalabilir.

Bu mevcut ürün sözleşmesine aykırı olduğu kesinleşmiş bir bug değildir; çünkü kaynak ekranının sözleşmesi tema odaklıdır ve hafta seçimi ekranlar arasında paylaşılmıyor. Ancak kullanıcı zihinsel modelinde “seçtiğim haftanın kaynakları” beklentisi oluşur. Bu beklenti desteklenmeyecekse Kaynaklar girişinde bağlam metni açıkça `Tema kaynakları` olmalı; desteklenecekse tema/hafta bağlamı ortak bir resolver üzerinden taşınmalı.

Kanıt:

- Hafta seçiminin yerel state olması: [`this_week_page.dart:36-69`](/Users/kadir/Desktop/OgretmenOS/lib/features/this_week/this_week_page.dart:36)
- Kaynak bağlamı çözüm sırası: [`resource_library_page.dart:209-264`](/Users/kadir/Desktop/OgretmenOS/lib/features/resources/resource_library_page.dart:209)
- Ürün sözleşmesindeki kaynak bağlamı: [`PRODUCT_SCOPE.md:152-162`](/Users/kadir/Desktop/OgretmenOS/docs/PRODUCT_SCOPE.md:152)

## Doğrudan tekrar olmayan, korunması gereken ayrımlar

- `Kaynaklar`ın program çıktıları ve öğretim bloklarını göstermemesi doğru bir sınırdır. Mevcut test bunu açıkça doğruluyor: [`widget_test.dart:328-341`](/Users/kadir/Desktop/OgretmenOS/test/widget_test.dart:328).
- `Plan`daki “Öğretim sırası” bir tamamlanma yüzdesi değildir; kaynak/hafta ekranlarına tracking sayacı taşınmamalıdır. Bu ayrım [`annual_plan_page.dart:514-524`](/Users/kadir/Desktop/OgretmenOS/lib/features/annual_plan/annual_plan_page.dart:514) ve ürün sözleşmesinde korunuyor.
- `Bu Hafta`daki haftalık ders planı ile `Kaynaklar`daki tema envanteri aynı şey değildir. Birincisi zaman sıralı uygulama akışı, ikincisi kaynak keşfi olmalıdır.
- Ders planı ilerlemesi, kazanım takibi ve son görüntülenen ders birbirine otomatik karıştırılmamalıdır. Görsel sadeleştirme bu veri sınırlarını kaldırmamalı.

## Önerilen bilgi sahipliği

| Bilgi | Tek birincil sahibi | Diğer yüzeylerde gösterim |
|---|---|---|
| Şimdi/sonraki ders | `Bu Hafta` | Kısa bağlantı veya aktif vurgu |
| Yıllık tema/blok sırası | `Plan` | `Bu Hafta`de yalnız mevcut bağlam |
| Tema kaynak kataloğu | `Kaynaklar` | Ayrıntı ekranlarında kısa özet + bağlantı |
| Blok için ilk gerekli kitap/etkinlik | `Ders Bloğu` | Tam liste yerine `Kaynaklarda aç` |
| Saat bazlı öğretim adımları | `Ders Planı` | `Bu Hafta`de haftalık satır özeti |
| Tracking/progress durumu | İlgili kendi yüzeyi | Başka yüzeyde yalnız açıkça gerekli, yüzdesiz ve isteğe bağlı |

## Önceliklendirilmiş öneriler

### P1 — `Plan`daki mevcut konum özetini sıkıştır

`Bu Hafta` “ŞİMDİ” ve birincil eylem sahibi olarak kalsın. `Plan`da tema + blok tekrarını ayrı büyük kutu olarak göstermek yerine aktif blok vurgusu ve tek satırlık `Öğretim sırası: N / total` bilgisi yeterli olsun. “ŞU AN BURADASIN” dili yalnız bir yüzeyde kullanılmalı.

### P1 — Tam kaynak ayrıntısının sahibini `Kaynaklar` yap

`BlockDetailPage` ve `LessonPlanPage` içinde tam listeyi kopyalamak yerine bağlama özel kısa özet bırakılmalı. Her özet, seçili tema/blok korunarak `Kaynaklarda aç` eylemine bağlanmalı. Bu işlem kaynak erişimini azaltmaz; aynı içeriğin iki farklı listede taranmasını azaltır.

### P2 — “Plan” terminolojisini netleştir

Üst düzey `Plan` = yıllık sıra; supporting `Ders Planı` = saat bazlı uygulama akışı; `Bu haftanın ders planı` = haftalık giriş paneli. Bu üç terim başlık ve eylem metinlerinde tutarlı kullanılmalı. Kullanıcıya aynı kavramın üç ayrı ekranı varmış hissi verilmemeli.

### P2 — Kaynak kapsamını başlıkta görünür yap

Kaynaklar tema düzeyinde çalışmaya devam edecekse başlık/subtitle, örneğin `Seçili temanın kaynakları` şeklinde kapsamı açıkça belirtmeli. Kullanıcı bir haftayı Plan’dan incelemişse, Kaynaklar ekranında neden başka bir hafta/tema açıldığını açıklayan bağlam geri bildirimi olmalı.

### P2 — Ortak görsel bileşen değil, ortak bağlam sözleşmesi kullan

Üç ekranda aynı kartı çoğaltmak yerine ortak bir `LessonContext`/resolver üzerinden tema, blok ve hafta bağlamı taşınmalı. Görsel sunum ekranın görevine göre farklı kalmalı. Bu, hem yanlış bağlam riskini hem de ayrı ayrı yeniden veri çözümleme riskini azaltır.

## Doğrulama boşlukları

Mevcut testler kaynak ekranının program verisini tekrar çizmediğini doğruluyor; fakat şu davranışları henüz sözleşme olarak kanıtlamıyor:

- Plan’dan Blok Ayrıntısı → Kaynaklar geçişinde seçili tema/blok kapsamının korunması;
- seçili hafta değiştirildikten sonra Kaynaklar’ın hangi temayı açmasının beklenildiği;
- aynı kaynak kaydının iki ekranda tekrar gösterilmesinin kabul edilen/edilmeyen sınırı;
- `Plan` ve `Bu Hafta` arasında “mevcut konum” metninin tekilleştirilmesi.

Bu nedenle uygulama değişikliğinden önce bu dört beklenti için küçük widget sözleşme testleri yazılmalı. Mevcut sekme yükleme/yenileme maliyeti ayrıca [`SEKME_GECIKMESI_INCELEME_RAPORU.md`](/Users/kadir/Desktop/OgretmenOS/docs/SEKME_GECIKMESI_INCELEME_RAPORU.md) içinde ele alınmış durumda; o rapor performans tekrarını inceliyor, bu rapor ise kullanıcıya görünen bilgi sahipliğini inceliyor.

## Runtime kontrolü

TDE_9 doğrulanmış runtime’ında 4 tema, 16 blok, 88 ders planı paketi, 24 kitap bölümü, 61 etkinlik, 28 form, 3 değerlendirme aracı, 50 kaynak kararı ve 2 kaynak referansı bulunuyor. Tema başına kaynak paketi 6 kitap bölümü, 15–16 etkinlik, 8–9 form ve 6–16 kaynak kararı ölçeğinde; dolayısıyla `Kaynaklar`ın tema seviyesinde tam envanter sunması anlamlı, fakat bunu blok ayrıntısında tekrar etmek tarama yükünü artırıyor.

Bu sayımlar içerik doğrulaması içindir; cihaz üzerindeki görsel kullanılabilirlik veya görev süresi ölçümü değildir.

## Nihai karar

Kaynak ekranının program çıktıları ve blok listesini tekrar etmemesi korunmalı. Öncelikli düzenleme, `Bu Hafta`nin “şimdi” rolü ile `Plan`ın “yıllık sıra” rolünü ayırmak ve Plan akışındaki blok/lesson-plan ayrıntılarını tam kaynak kataloğuna dönüştürmemektir. Böylece öğretmen aynı veriyi iki kez taramaz; her ekranda hangi soruya cevap verildiği netleşir.
