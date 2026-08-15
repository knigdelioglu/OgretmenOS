import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late CourseDatabaseDataSource dataSource;
  late Map<String, dynamic> manifest;

  setUpAll(() async {
    final runtimeRoot = p.join(
      Directory.current.path,
      'assets',
      'courses',
      'TDE_9',
    );
    final manifestFile = File(p.join(runtimeRoot, 'runtime_manifest.json'));
    final databaseFile = File(p.join(runtimeRoot, 'course_runtime.sqlite'));

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
    dataSource = CourseDatabaseDataSource(database);
  });

  tearDownAll(() async {
    await database.close();
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
    expect(candidate!.outcomes, isNotEmpty);
    expect(candidate.activities, isNotEmpty);
    expect(candidate.theme.id, candidate.block.themeId);
  });

  test('bundled canonical runtime gerçek öğretmen paketi üretir', () async {
    final themes = await dataSource.getThemes();
    expect(themes, isNotEmpty);

    final package = await dataSource.getTeacherPackage(themes.first.id);

    expect(package.blocks, isNotEmpty);
    expect(package.outcomes, isNotEmpty);
    expect(package.activities, isNotEmpty);
    expect(package.resourceDecisions, isNotEmpty);
  });
}
