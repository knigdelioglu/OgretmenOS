import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/domain/models/form_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'form_templates lazy sorgusu ve eski runtime fallback çalışır',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      addTearDown(database.close);
      await database.execute('''
        CREATE TABLE forms (
          form_id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          structural_type TEXT,
          assessment_type TEXT,
          printed_page INTEGER,
          pdf_page INTEGER,
          evaluator TEXT,
          source_id TEXT,
          verification_status TEXT
        )
        ''');
      await database.insert('forms', {'form_id': 'F1', 'title': 'Form'});
      final source = CourseDatabaseDataSource(database);
      expect((await source.getForm('F1'))?.title, 'Form');
      expect(await source.getFormTemplateStatus('F1'), isNull);
      expect(await source.getFormDefinition('F1'), isNull);

      await database.execute('''
      CREATE TABLE form_templates (
        form_id TEXT PRIMARY KEY REFERENCES forms(form_id),
        schema_version TEXT NOT NULL,
        template_json TEXT NOT NULL,
        instructions TEXT,
        render_status TEXT NOT NULL,
        review_reason TEXT,
        provenance_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
      final definition = const FormDefinition(
        schemaVersion: '1.0',
        title: 'Gerçek Form',
        provenance: {
          'content_basis': 'verified_printed_form_transcription',
          'source_id': 'canonical-test-source',
          'source_page': 's.1',
          'verification_status': 'VERIFIED',
        },
        sections: [
          FormSection(elements: [ParagraphFormElement(text: 'İçerik')]),
        ],
      );
      await database.insert('form_templates', {
        'form_id': 'F1',
        'schema_version': '1.0',
        'template_json': jsonEncode(definition.toJson()),
        'render_status': 'ready',
        'review_reason': null,
        'provenance_json': '{}',
      });
      expect((await source.getFormDefinition('F1'))?.title, 'Gerçek Form');
      final readyStatus = await source.getFormTemplateStatus('F1');
      expect(readyStatus?.isReady, isTrue);
      expect(readyStatus?.displayLabel, 'Hazır');
      final malformed = const FormDefinition(
        schemaVersion: '1.0',
        title: 'Bozuk Form',
        provenance: {
          'content_basis': 'verified_printed_form_transcription',
          'source_id': 'canonical-test-source',
          'source_page': 's.1',
          'verification_status': 'VERIFIED',
        },
        sections: [FormSection()],
      );
      await database.update('form_templates', {
        'template_json': jsonEncode(malformed.toJson()),
      });
      await expectLater(
        () => source.getFormDefinition('F1'),
        throwsA(isA<FormDefinitionException>()),
      );
      await database.update('form_templates', {
        'template_json': jsonEncode(
          const FormDefinition(
            schemaVersion: '1.0',
            title: 'Kanıtı Bozuk Form',
            provenance: {
              'content_basis': 'generated_guess',
              'source_id': 'canonical-test-source',
              'source_page': 's.1',
              'verification_status': 'VERIFIED',
            },
            sections: [
              FormSection(elements: [ParagraphFormElement(text: 'İçerik')]),
            ],
          ).toJson(),
        ),
      });
      await expectLater(
        () => source.getFormDefinition('F1'),
        throwsA(isA<FormDefinitionException>()),
      );
      await database.update('form_templates', {
        'render_status': 'needs_review',
        'review_reason': 'unresolved_form_reference',
        'provenance_json': jsonEncode({
          'target_url': 'https://example.test/form',
          'target_probe': 'unresolved',
          'verification_status':
              'OFFICIAL_QR_ASSESSMENT_TARGET_PRESENT_STRUCTURE_UNRESOLVED',
        }),
      });
      expect(await source.getFormDefinition('F1'), isNull);
      final externalStatus = await source.getFormTemplateStatus('F1');
      expect(externalStatus?.isExternalReference, isTrue);
      expect(externalStatus?.targetUrl, 'https://example.test/form');
    },
  );
}
