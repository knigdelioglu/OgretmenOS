import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Database? database;
  late CourseDatabaseDataSource dataSource;
  late Map<String, dynamic> manifest;

  setUpAll(() async {
    final descriptor = runtimeForCourse('TDE_9');
    final manifestFile = File(
      p.join(Directory.current.path, descriptor.manifestAsset),
    );
    final databaseFile = File(
      p.join(Directory.current.path, descriptor.databaseAsset),
    );

    expect(manifestFile.existsSync(), isTrue);
    expect(databaseFile.existsSync(), isTrue);
    expect(databaseFile.lengthSync(), greaterThan(0));

    final decoded = jsonDecode(await manifestFile.readAsString());
    expect(decoded, isA<Map<String, dynamic>>());
    manifest = Map<String, dynamic>.from(decoded as Map<String, dynamic>);
    validateRuntimeManifest(manifest);

    database = await databaseFactoryFfi.openDatabase(
      databaseFile.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    dataSource = CourseDatabaseDataSource(database!);
  });

  tearDownAll(() async {
    final opened = database;
    if (opened != null) await opened.close();
  });

  test('bundled canonical runtime manifest ve course kaydı birbiriyle uyumludur', () async {
    final course = await dataSource.getCourse();

    expect(course.courseId, manifest['course_id']);
    expect(course.schemaVersion, manifest['schema_version']);
    expect(
      course.sourceManifestFingerprint,
      manifest['canonical_content_fingerprint'],
    );
  });

  test('bundled canonical runtime 4 tema ve 16 blokluk yıllık sırayı taşır', () async {
    final themes = await dataSource.getThemes();
    final sequence = await dataSource.getAnnualSequence();
    final rowCounts = Map<String, dynamic>.from(manifest['row_counts'] as Map);

    expect(themes.length, rowCounts['themes']);
    expect(sequence.length, rowCounts['timeline_blocks']);
    expect(themes, hasLength(4));
    expect(sequence, hasLength(16));
    expect(
      sequence.map((entry) => entry.sequencePosition),
      orderedEquals(List<int>.generate(16, (index) => index + 1)),
    );
  });

  test('bundled canonical runtime gerçek block ilişkilerini repository girdisi olarak sağlar', () async {
    final sequence = await dataSource.getAnnualSequence();
    BlockDetail? candidate;

    for (final entry in sequence) {
      final detail = await dataSource.getBlockDetail(entry.block.id);
      if (detail.outcomes.isNotEmpty && detail.activities.isNotEmpty) {
        candidate = detail;
        break;
      }
    }

    expect(candidate, isNotNull);
    final detail = candidate!;
    expect(detail.outcomes, isNotEmpty);
    expect(detail.activities, isNotEmpty);
    expect(detail.theme.id, detail.block.themeId);
  });

  test('bundled canonical runtime en az bir dolu gerçek öğretmen paketi üretir', () async {
    final themes = await dataSource.getThemes();
    expect(themes, isNotEmpty);

    TeacherPackage? candidate;
    for (final theme in themes) {
      final package = await dataSource.getTeacherPackage(theme.id);
      if (package.blocks.isNotEmpty &&
          package.outcomes.isNotEmpty &&
          package.activities.isNotEmpty &&
          package.resourceDecisions.isNotEmpty) {
        candidate = package;
        break;
      }
    }

    expect(candidate, isNotNull);
  });
}
