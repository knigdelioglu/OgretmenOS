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
}
