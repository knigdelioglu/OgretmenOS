import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
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
      'TDE_10',
    );
    final manifestFile = File(p.join(runtimeRoot, 'runtime_manifest.json'));
    final databaseFile = File(p.join(runtimeRoot, 'course_runtime.sqlite'));
    expect(manifestFile.existsSync(), isTrue);
    expect(databaseFile.existsSync(), isTrue);
    manifest = Map<String, dynamic>.from(
      jsonDecode(await manifestFile.readAsString()) as Map,
    );
    validateRuntimeManifest(manifest);
    database = await databaseFactoryFfi.openDatabase(
      databaseFile.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    dataSource = CourseDatabaseDataSource(database);
  });

  tearDownAll(() => database.close());

  test('TDE10 runtime temel ÖğretmenOS ilişki sözleşmesini karşılar', () async {
    final course = await dataSource.getCourse();
    expect(course.courseId, 'TDE_10');
    expect((await dataSource.getThemes()).length, 4);
    expect((await dataSource.getAnnualSequence()).length, 16);
    final package = await dataSource.getTeacherPackage('TEMA_03');
    expect(package.outcomes, isNotEmpty);
    expect(package.activities, isNotEmpty);
    expect(package.resourceDecisions, isNotEmpty);
    expect(package.sourceReferences, isNotEmpty);
    expect(package.assessmentTaskBindings, isNotEmpty);
  });

  test(
    'Fabl Yazma rubriği 8 görev ölçütü ve 3 düzeyli modelle okunur',
    () async {
      final detail = await dataSource.getBlockDetail('BLOCK_T3_04_YAZMA');
      final binding = detail.assessmentTaskBindings.singleWhere(
        (item) => item.gapInstanceId == 'REQ_T10_T3_YAZMA_DPA',
      );
      final artifact = detail.assessmentArtifacts.singleWhere(
        (item) => item.id == 'TDE10_YAZMA_RUBRIC',
      );
      expect(binding.taskTitle, 'Fabl Yazma');
      expect(binding.taskSpecificCriteria, hasLength(8));
      expect(binding.taskSpecificCriteria, contains('Özgünlük'));
      expect(binding.taskSpecificCriteria, contains('Biçim/tür özellikleri'));
      expect(
        artifact.levels.map((level) => level.score),
        orderedEquals([3, 2, 1]),
      );
      expect(artifact.criteria, isNotEmpty);
      expect(artifact.provenance, isNotEmpty);
    },
  );
}
