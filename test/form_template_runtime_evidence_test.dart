import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('form projector canonical authority Python regressions pass', () async {
    final result = await Process.run('python3', [
      'tool/test_build_form_templates.py',
    ]);
    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  });

  for (final courseId in const ['TDE_9', 'TDE_10']) {
    test('$courseId form status ve UI evidence contractı eşleşir', () async {
      final descriptor = runtimeForCourse(courseId);
      final runtimeDirectory = Directory.current.path;
      final manifest =
          jsonDecode(
                await File(
                  p.join(runtimeDirectory, descriptor.manifestAsset),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final database = await databaseFactoryFfi.openDatabase(
        p.join(runtimeDirectory, descriptor.databaseAsset),
        options: OpenDatabaseOptions(readOnly: true),
      );
      addTearDown(database.close);
      final source = CourseDatabaseDataSource(database);
      final rows = await database.rawQuery('''
        SELECT ft.form_id, ft.render_status, ft.provenance_json,
               f.source_id AS canonical_source_id,
               f.printed_page AS canonical_printed_page,
               f.pdf_page AS canonical_pdf_page,
               f.verification_status AS canonical_verification_status
        FROM form_templates ft
        INNER JOIN forms f ON f.form_id = ft.form_id
        ORDER BY ft.form_id
      ''');
      final ready = rows.where((row) => row['render_status'] == 'ready').toList();
      final needsReview = rows
          .where((row) => row['render_status'] == 'needs_review')
          .toList();
      final manifestCounts =
          manifest['form_template_status_counts'] as Map<String, dynamic>;
      expect(ready.length, manifestCounts['ready']);
      expect(needsReview.length, manifestCounts['needs_review']);

      for (final row in ready) {
        final provenance =
            jsonDecode(row['provenance_json']! as String)
                as Map<String, dynamic>;
        expect(
          provenance['source_id'],
          row['canonical_source_id'],
          reason: '${row['form_id']} source identity canonical row ile eşleşmeli',
        );
        expect(
          provenance['verification_status'],
          row['canonical_verification_status'],
          reason:
              '${row['form_id']} verification status catalog tarafından yükseltilemez',
        );
        final hasLocatorOrPage = [
          provenance['source_locator'],
          provenance['source_page'],
          row['canonical_printed_page'],
          row['canonical_pdf_page'],
        ].any((value) => value?.toString().trim().isNotEmpty ?? false);
        expect(
          hasLocatorOrPage,
          isTrue,
          reason: '${row['form_id']} ready olmak için source locator/page taşımalı',
        );
      }

      expect(
        await source.getFormDefinition(ready.first['form_id']! as String),
        isNotNull,
      );
      expect(
        await source.getFormDefinition(needsReview.first['form_id']! as String),
        isNull,
      );
    });
  }
}
