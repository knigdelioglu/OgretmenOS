import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/data/course/course_knowledge_repository_impl.dart';
import 'package:ogretmen_os/data/course/lesson_plan_database_data_source.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pinnedTymmCommit = 'ceca539d29ad6d030d49c2426cfa1dee4017f083';

void main() {
  sqfliteFfiInit();

  for (final courseId in const ['TDE_9', 'TDE_10']) {
    group('$courseId lesson-plan-aware runtime', () {
      Database? database;
      late Map<String, dynamic> manifestJson;
      late Map<String, dynamic> packageJson;
      late RuntimeManifest manifest;
      late CourseKnowledgeRepository repository;

      setUpAll(() async {
        final descriptor = runtimeForCourse(courseId);
        final runtimeRoot = Directory.current.path;
        final manifestFile = File(p.join(runtimeRoot, descriptor.manifestAsset));
        final databaseFile = File(p.join(runtimeRoot, descriptor.databaseAsset));
        final validationFile = File(
          p.join(runtimeRoot, descriptor.runtimeRoot, 'runtime_validation_report.md'),
        );
        final packageFile = File(
          p.join(
            runtimeRoot,
            p.dirname(descriptor.runtimeRoot),
            'package_manifest.json',
          ),
        );

        expect(manifestFile.existsSync(), isTrue);
        expect(databaseFile.existsSync(), isTrue);
        expect(validationFile.existsSync(), isTrue);
        expect(packageFile.existsSync(), isTrue);

        manifestJson = Map<String, dynamic>.from(
          jsonDecode(await manifestFile.readAsString()) as Map,
        );
        packageJson = Map<String, dynamic>.from(
          jsonDecode(await packageFile.readAsString()) as Map,
        );
        validateRuntimeFreshnessEvidence(
          manifestJson,
          validationReport: await validationFile.readAsString(),
        );
        manifest = RuntimeManifest.fromJson(manifestJson);

        database = await databaseFactoryFfi.openDatabase(
          databaseFile.absolute.path,
          options: OpenDatabaseOptions(readOnly: true),
        );
        repository = CourseKnowledgeRepositoryImpl(
          dataSource: CourseDatabaseDataSource(database!),
          manifest: manifest,
          lessonPlanDataSource: LessonPlanDatabaseDataSource(database!),
        );
      });

      tearDownAll(() async {
        final opened = database;
        if (opened != null) {
          await opened.close();
        }
      });

      test('versioned package 1.3/1.2 ve 88 paket / 172 saat sözleşmesini taşır', () {
        expect(manifest.runtimePackageVersion, '1.3.0');
        expect(manifest.schemaVersion, '1.2.0');
        expect(manifest.validationStatus, 'PASS');
        expect(manifest.rowCounts['lesson_plan_packages'], 88);
        expect(manifestJson['lesson_plan_package_count'], 88);
        expect(manifestJson['lesson_plan_instruction_hours'], 172);

        final capabilities = manifestJson['lesson_plan_capabilities'] as Map;
        for (final key in const [
          'available',
          'package_payload_json',
          'block_package_navigation',
          'source_hash_per_package',
          'source_payload_parity',
          'validation_bound',
          'calendar_neutral',
        ]) {
          expect(capabilities[key], isTrue, reason: '$courseId/$key');
        }

        final validation = manifestJson['lesson_plan_validation'] as Map;
        expect(validation['status'], 'VERIFIED');
        expect(validation['scope'], 'COURSE');
        expect(
          validation['content_fingerprint'].toString(),
          startsWith('sha256:'),
        );
        expect(
          RegExp(r'^[0-9a-f]{40}$').hasMatch(
            validation['validated_commit_sha'].toString(),
          ),
          isTrue,
        );

        expect(packageJson['tymm_source_repository'], 'knigdelioglu/tymm');
        expect(packageJson['tymm_source_commit'], _pinnedTymmCommit);
        expect(packageJson['runtime_package_version'], '1.3.0');
        expect(packageJson['runtime_schema_version'], '1.2.0');
        expect(packageJson['lesson_plan_package_count'], 88);
        expect(packageJson['lesson_plan_instruction_hours'], 172);
        expect(packageJson['lesson_plan_validation_status'], 'VERIFIED');
        expect(
          packageJson['runtime_canonical_content_fingerprint'],
          manifest.canonicalContentFingerprint,
        );
      });

      test('gerçek SQLite 88 PASS paket ve 172 ders saati içerir', () async {
        final totals = (await database!.rawQuery('''
          SELECT COUNT(*) AS package_count,
                 COALESCE(SUM(lesson_hours), 0) AS instruction_hours,
                 SUM(CASE WHEN validation_status = 'PASS' THEN 0 ELSE 1 END) AS invalid_rows
          FROM lesson_plan_packages
        '''))
            .single;
        expect(totals['package_count'], 88);
        expect(totals['instruction_hours'], 172);
        expect(totals['invalid_rows'], 0);
        expect(await database!.rawQuery('PRAGMA foreign_key_check'), isEmpty);

        final course = (await database!.rawQuery('''
          SELECT course_id, schema_version, source_manifest_fingerprint
          FROM courses
          LIMIT 1
        '''))
            .single;
        expect(course['course_id'], courseId);
        expect(course['schema_version'], '1.2.0');
        expect(
          course['source_manifest_fingerprint'],
          manifest.canonicalContentFingerprint,
        );
      });

      test('repository gerçek payloadı okuyup yıllık paket navigasyonunu korur', () async {
        final capability = await repository.getLessonPlanCapability();
        expect(capability.usable, isTrue);
        expect(capability.packageCount, 88);
        expect(capability.instructionHours, 172);

        final firstRows = await database!.rawQuery('''
          SELECT lp.package_id, lp.block_id
          FROM lesson_plan_packages lp
          JOIN blocks b ON b.block_id = lp.block_id
          JOIN themes t ON t.theme_id = lp.theme_id
          ORDER BY t.theme_order, b.block_order, lp.package_no
          LIMIT 2
        ''');
        expect(firstRows, hasLength(2));

        final firstId = firstRows.first['package_id']! as String;
        final secondId = firstRows[1]['package_id']! as String;
        final blockId = firstRows.first['block_id']! as String;

        final blockPlans = await repository.getLessonPlansForBlock(blockId);
        expect(blockPlans, isNotEmpty);
        expect(blockPlans.first.packageId, firstId);
        expect(blockPlans.first.validationStatus, 'PASS');
        expect(blockPlans.first.payloadSha256, isNotEmpty);
        expect(blockPlans.first.rawPayload['package_id'], firstId);

        final first = await repository.getLessonPlan(firstId);
        expect(first, isNotNull);
        expect(first!.lessons, isNotEmpty);
        expect(first.courseId, courseId);

        expect(await repository.getPreviousLessonPlan(firstId), isNull);
        final next = await repository.getNextLessonPlan(firstId);
        expect(next?.packageId, secondId);
      });
    });
  }
}
