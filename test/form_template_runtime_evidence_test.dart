import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

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
      final rows = await database.query(
        'form_templates',
        columns: ['form_id', 'render_status'],
        orderBy: 'form_id',
      );
      final ready = rows.where((row) => row['render_status'] == 'ready');
      final needsReview = rows.where(
        (row) => row['render_status'] == 'needs_review',
      );
      final manifestCounts =
          manifest['form_template_status_counts'] as Map<String, dynamic>;
      expect(ready.length, manifestCounts['ready']);
      expect(needsReview.length, manifestCounts['needs_review']);
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
