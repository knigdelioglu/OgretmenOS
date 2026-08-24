# TYMM Verileri

ÖğretmenOS'un ders verileri bu kökte ders ve sınıf bazında paketlenir.

```text
tymm-verileri/
  catalog.json
  <ders>/
    ders_manifest.json
    TDE_SHARED/                         # ders ailesi ortak normatif katmanı
      curriculum_process_component_catalog.json
    <course_id>/
      package_manifest.json
      runtime/
        course_runtime.sqlite
        runtime_manifest.json
        runtime_validation_report.md
      curriculum/                       # yalnız program-only paketlerde zorunlu
        curriculum_map.json
        source_manifest.json
        curriculum_validation_report.json
        curriculum_process_component_resolution.json
```

## Paket modları

- `FULL_RUNTIME`: Resmî öğretim programı ve ders kitabı işlenmiştir. Kitap bölümleri, etkinlikler, formlar ve diğer doğrulanmış runtime katmanları kullanılabilir.
- `CURRICULUM_ONLY`: Resmî öğretim programı doğrulanmıştır ancak ders kitabı henüz yoktur. Tema, kazanım, yıllık sıra ve haftalık plan kullanılabilir; kitap/etkinlik/form tabloları bilinçli olarak boş kalır.

`package_manifest.json` paketin modunu ve `textbook_status` değerini belirler. Curriculum-only runtime, `tool/build_curriculum_only_runtime.py` ile program verisinden üretilir. Blok başına `12+11+10+10` saat dağılımı ÖğretmenOS planlama politikasıdır; TYMM'nin resmî blok süreleri olarak yorumlanmaz.

## Süreç bileşeni canonical kuralı

Tema sayfasında subordinate süreç bileşenlerinin tekrar edilmemesi effective bileşen olmadığı anlamına gelmez. Curriculum-only paketler şu çözümleme sırasını kullanır:

```text
THEME_EXPLICIT varsa -> THEME_EXPLICIT
aksi halde shared normative ROOF varsa -> ROOF_INHERITED
aksi halde SOURCE_VERIFIED_NONE varsa -> []
aksi halde -> FAIL
```

Bu nedenle `curriculum_process_component_resolution.json` ile ders ailesi ortak `TDE_SHARED/curriculum_process_component_catalog.json` dosyaları runtime build girdisidir. İki dosya da canonical fingerprint'e katılır. Roof bileşeni bulunan bir outcome runtime'da boş `process_components` ile yayımlanamaz. Runtime ayrıca `process_component_origin` provenance alanını korur.

Yeni bir ders eklendiğinde yeni bir `<ders>/` klasörü, `ders_manifest.json` ve sınıf paketleri oluşturulur. Uygulama registry'si aynı paket köklerine yönlendirilir.
