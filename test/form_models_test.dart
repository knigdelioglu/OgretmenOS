import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/form_models.dart';

void main() {
  test('FormDefinition tüm element türlerini JSON round-trip eder', () {
    final definition = FormDefinition(
      schemaVersion: '1.0',
      title: 'Türkçe Form',
      description: 'Açıklama',
      instructions: 'Yönerge',
      sections: [
        FormSection(
          title: 'Bölüm',
          elements: [
            const HeadingFormElement(text: 'Başlık'),
            const ParagraphFormElement(text: 'Paragraf'),
            const IdentityFieldsFormElement(
              fields: [IdentityField(label: 'Adı Soyadı')],
            ),
            const FreeTextFormElement(label: 'Yanıt', lines: 2),
            const ChecklistFormElement(items: ['Madde'], allowNotes: true),
            const RatingScaleFormElement(
              items: ['Ölçüt'],
              min: 1,
              max: 3,
              options: ['Evet', 'Kısmen', 'Hayır'],
            ),
            const TableFormElement(
              columns: [FormTableColumn(label: 'Sütun')],
              rows: [
                ['Satır'],
              ],
            ),
            const RubricFormElement(
              levels: ['İyi'],
              criteria: [
                RubricCriterion(label: 'Ölçüt', descriptors: ['Açıklama']),
              ],
            ),
            const NoteFormElement(text: 'Not'),
            const SignatureFormElement(fields: ['İmza']),
            const SpacerFormElement(),
          ],
        ),
      ],
    );

    final decoded = FormDefinition.fromJson(
      jsonDecode(jsonEncode(definition.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.title, definition.title);
    expect(decoded.sections.single.elements, hasLength(11));
    expect(
      decoded.sections.single.elements.whereType<RubricFormElement>(),
      hasLength(1),
    );
  });

  test('bozuk JSON ve desteklenmeyen schema açık hata verir', () {
    expect(
      () => FormDefinition.fromJsonString('{bozuk'),
      throwsA(isA<FormDefinitionException>()),
    );
    expect(
      () => FormDefinition.fromJsonString(
        jsonEncode({'schema_version': '9.0', 'title': 'Form'}),
      ),
      throwsA(isA<UnsupportedFormSchemaException>()),
    );
    expect(
      () => const FormDefinition(schemaVersion: '9.0', title: 'Form').validate(),
      throwsA(isA<FormDefinitionException>()),
    );
  });

  test('bilinmeyen element tipi güvenli fallback üretir', () {
    final definition = FormDefinition.fromJson({
      'schema_version': '1.0',
      'title': 'Güvenli Form',
      'sections': [
        {
          'elements': [
            {'type': 'futureElement', 'text': 'kaybolmasın'},
          ],
        },
      ],
    });
    final element = definition.sections.single.elements.single;
    expect(element, isA<UnknownFormElement>());
    expect(element.toJson()['type'], 'futureElement');
    expect(definition.validationErrors, isEmpty);
  });

  test('render sözleşmesi bozuk tablo, rubrik ve boş formu reddeder', () {
    final definition = FormDefinition(
      schemaVersion: '1.0',
      title: 'Bozuk form',
      sections: [
        FormSection(
          elements: [
            const TableFormElement(
              columns: [
                FormTableColumn(label: 'A'),
                FormTableColumn(label: 'B'),
              ],
              rows: [
                ['tek hücre'],
              ],
            ),
            const RubricFormElement(
              levels: ['İyi', 'Geliştirilmeli'],
              criteria: [
                RubricCriterion(label: 'Ölçüt', descriptors: ['tek açıklama']),
              ],
            ),
          ],
        ),
      ],
    );

    expect(
      definition.validationErrors,
      containsAll([
        contains('table satır/sütun'),
        contains('rubric düzey/descriptor'),
      ]),
    );
    expect(definition.validate, throwsA(isA<FormDefinitionException>()));
    expect(
      () => const FormDefinition(schemaVersion: '1.0', title: 'Boş').validate(),
      throwsA(isA<FormDefinitionException>()),
    );
  });

  test(
    'tablo ve rubrik satırları renderer için güvenli biçimde normalize edilir',
    () {
      const table = TableFormElement(
        columns: [
          FormTableColumn(label: 'A'),
          FormTableColumn(label: 'B'),
        ],
        rows: [
          ['1'],
          ['1', '2', 'fazla'],
        ],
      );
      const rubric = RubricFormElement(
        levels: ['İyi', 'Geliştirilmeli'],
        criteria: [
          RubricCriterion(label: 'Ölçüt', descriptors: ['Açıklama']),
        ],
      );

      expect(table.normalizedRows, [
        ['1', ''],
        ['1', '2'],
      ]);
      expect(rubric.normalizedRows, [
        ['Ölçüt', 'Açıklama', ''],
      ]);
    },
  );
}
