import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/form_models.dart';
import 'package:ogretmen_os/features/resources/forms/form_export_service.dart';
import 'package:ogretmen_os/features/resources/forms/form_pdf_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF renderer A4 Türkçe form için geçerli byte üretir', () async {
    const definition = FormDefinition(
      schemaVersion: '1.0',
      title: 'Türkçe Öz Değerlendirme',
      instructions: 'Çalışmanı dikkatle değerlendir.',
      sections: [
        FormSection(
          elements: [
            IdentityFieldsFormElement(
              fields: [IdentityField(label: 'Adı Soyadı')],
            ),
            ChecklistFormElement(items: ['Çalışmamı tamamladım.']),
            RatingScaleFormElement(
              items: ['Akıcılık ve anlatım'],
              min: 1,
              max: 3,
              options: ['Evet', 'Kısmen', 'Hayır'],
            ),
            TableFormElement(
              columns: [
                FormTableColumn(label: 'Ölçüt'),
                FormTableColumn(label: 'Not'),
              ],
              rows: [
                ['Türkçe karakter: ğüşİıöç', ''],
              ],
            ),
            RubricFormElement(
              levels: ['Başlangıç', 'Gelişiyor', 'Yetkin'],
              criteria: [
                RubricCriterion(
                  label: 'İfade',
                  descriptors: ['Kısa', 'Orta', 'Açık'],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final bytes = await const FormPdfRenderer().generate(definition);
    expect(bytes.take(5), [37, 80, 68, 70, 45]);
    expect(bytes.length, greaterThan(1000));
  });

  test('filename teknik ID ve Türkçe noktalama üretmez', () {
    expect(
      sanitizeFormPdfFilename('9. Sınıf Öz Değerlendirme: Çalışma!'),
      '9_Sinif_Oz_Degerlendirme_Calisma.pdf',
    );
  });

  test('çok sayfalı serbest metin formu page-break ile üretilir', () async {
    final definition = FormDefinition(
      schemaVersion: '1.0',
      title: 'Uzun Türkçe Çalışma Formu',
      instructions: 'Ç, ğ, ı, İ, ö, ş, ü ve tırnak işaretlerini koruyunuz.',
      sections: [
        FormSection(
          elements: [
            for (var index = 1; index <= 24; index++)
              FreeTextFormElement(
                label:
                    '$index. Uzun soru: “Düşüncenizi açık ve anlaşılır biçimde açıklayınız.”',
                lines: 8,
              ),
          ],
        ),
      ],
    );

    final bytes = await const FormPdfRenderer().generate(definition);
    expect(_pageCount(bytes), greaterThanOrEqualTo(3));
    expect(bytes.length, greaterThan(5000));
  });

  test('uzun rubric ve geniş tablo gerçek renderer üzerinden taşar', () async {
    final longText =
        'Çalışma; özgünlük, tutarlılık, bağlam, yazım ve noktalama bakımından '
        'gerekçeli ve anlaşılır biçimde değerlendirilmiştir.';
    final rubricDefinition = FormDefinition(
      schemaVersion: '1.0',
      title: 'Uzun Türkçe Rubrik Stres Formu',
      sections: [
        FormSection(
          elements: [
            RubricFormElement(
              levels: ['Başlangıç', 'Gelişiyor', 'Yetkin', 'İleri'],
              criteria: [
                for (var index = 1; index <= 8; index++)
                  RubricCriterion(
                    label: 'Ölçüt $index',
                    descriptors: List.filled(4, longText),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
    final rubricBytes = await const FormPdfRenderer().generate(
      rubricDefinition,
    );
    expect(_pageCount(rubricBytes), greaterThanOrEqualTo(1));

    final tableDefinition = FormDefinition(
      schemaVersion: '1.0',
      title: 'Geniş Türkçe Tablo Stres Formu',
      description: 'Sekiz sütun, yirmi satır ve uzun Türkçe hücre değerleri.',
      sections: [
        FormSection(
          elements: [
            TableFormElement(
              columns: [
                for (var index = 1; index <= 8; index++)
                  FormTableColumn(label: 'Uzun sütun $index', flex: 2),
              ],
              rows: [
                for (var row = 1; row <= 60; row++)
                  [
                    for (var column = 1; column <= 8; column++)
                      'Uzun değer: çğışİöü $row/$column',
                  ],
              ],
            ),
          ],
        ),
      ],
    );

    final tableBytes = await const FormPdfRenderer().generate(tableDefinition);
    expect(_pageCount(tableBytes), greaterThanOrEqualTo(2));
    expect(tableBytes.length, greaterThan(5000));
  });

  test('mixed form tüm element türleriyle birden fazla sayfa üretir', () async {
    final definition = FormDefinition(
      schemaVersion: '1.0',
      title: 'Karma Türkçe Değerlendirme Formu',
      description: 'Uzun cümleler, tırnaklar ve Türkçe karakterler: “Çalışma”.',
      sections: [
        FormSection(
          title: 'Kimlik ve hazırlık',
          elements: [
            const IdentityFieldsFormElement(
              fields: [
                IdentityField(label: 'Adı Soyadı'),
                IdentityField(label: 'Sınıfı / Şubesi'),
                IdentityField(label: 'Tarih'),
              ],
            ),
            const ParagraphFormElement(
              text: 'Duygu ve düşüncelerinizi kanıtlarıyla açıklayınız.',
            ),
            const ChecklistFormElement(
              label: 'Kontrol listesi',
              items: [
                'Plan yaptım.',
                'Türkçeyi doğru kullandım.',
                'Kaynak belirttim.',
              ],
              allowNotes: true,
            ),
            const RatingScaleFormElement(
              label: 'Derecelendirme',
              min: 1,
              max: 5,
              options: ['Hiç', 'Az', 'Orta', 'Çok', 'Tam'],
              items: ['Açıklamam açık ve tutarlı.'],
            ),
          ],
        ),
        FormSection(
          title: 'Ürün ve sonuç',
          elements: [
            TableFormElement(
              columns: const [
                FormTableColumn(label: 'Bölüm'),
                FormTableColumn(label: 'Açıklama', flex: 3),
              ],
              rows: [
                for (var index = 1; index <= 12; index++)
                  [
                    'Bölüm $index',
                    'Çözümünüzü ayrıntılı ve gerekçeli yazınız.',
                  ],
              ],
            ),
            RubricFormElement(
              levels: const ['Başlangıç', 'Gelişiyor', 'Yetkin', 'İleri'],
              criteria: [
                for (var index = 1; index <= 6; index++)
                  RubricCriterion(
                    label: 'Kriter $index',
                    descriptors: const [
                      'Temel düzeyde.',
                      'Gelişmekte.',
                      'Beklenen düzeyde.',
                      'Ayrıntılı ve özgün.',
                    ],
                  ),
              ],
            ),
            const FreeTextFormElement(label: 'Sonuç ve yansıtma', lines: 12),
            const SignatureFormElement(fields: ['Öğrenci', 'Öğretmen']),
          ],
        ),
      ],
    );

    final bytes = await const FormPdfRenderer().generate(definition);
    expect(_pageCount(bytes), greaterThanOrEqualTo(2));
  });
}

int _pageCount(List<int> bytes) {
  const page = [47, 84, 121, 112, 101, 47, 80, 97, 103, 101];
  const pages = [47, 84, 121, 112, 101, 47, 80, 97, 103, 101, 115];

  var pageObjects = 0;
  var pagesObjects = 0;
  for (var index = 0; index <= bytes.length - page.length; index++) {
    if (_matchesAt(bytes, page, index)) pageObjects++;
    if (index <= bytes.length - pages.length &&
        _matchesAt(bytes, pages, index)) {
      pagesObjects++;
    }
  }
  return pageObjects - pagesObjects;
}

bool _matchesAt(List<int> bytes, List<int> pattern, int offset) {
  for (var index = 0; index < pattern.length; index++) {
    if (bytes[offset + index] != pattern[index]) return false;
  }
  return true;
}
