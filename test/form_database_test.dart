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
      await database.execute(
        'CREATE TABLE forms (form_id TEXT PRIMARY KEY, title TEXT NOT NULL)',
      );
      await database.insert('forms', {'form_id': 'F1', 'title': 'Form'});
      final source = CourseDatabaseDataSource(database);
      expect(await source.getFormDefinition('F1'), isNull);

      await database.execute('''
      CREATE TABLE form_templates (
        form_id TEXT PRIMARY KEY REFERENCES forms(form_id),
        schema_version TEXT NOT NULL,
        template_json TEXT NOT NULL,
        instructions TEXT,
        render_status TEXT NOT NULL,
        provenance_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
      final definition = const FormDefinition(
        schemaVersion: '1.0',
        title: 'Gerçek Form',
        sections: [
          FormSection(elements: [ParagraphFormElement(text: 'İçerik')]),
        ],
      );
      await database.insert('form_templates', {
        'form_id': 'F1',
        'schema_version': '1.0',
        'template_json': jsonEncode(definition.toJson()),
        'render_status': 'ready',
        'provenance_json': '{}',
      });
      expect((await source.getFormDefinition('F1'))?.title, 'Gerçek Form');
      final malformed = const FormDefinition(
        schemaVersion: '1.0',
        title: 'Bozuk Form',
        sections: [FormSection()],
      );
      await database.update('form_templates', {
        'template_json': jsonEncode(malformed.toJson()),
      });
      expect(
        () => source.getFormDefinition('F1'),
        throwsA(isA<FormDefinitionException>()),
      );
      await database.update('form_templates', {
        'render_status': 'needs_review',
      });
      expect(await source.getFormDefinition('F1'), isNull);
    },
  );
}
