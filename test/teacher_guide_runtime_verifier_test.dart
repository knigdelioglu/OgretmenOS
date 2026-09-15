import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'runtime verifier FK bozuk generic teacher-guide relationı yakalar',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'teacher_guide_verify_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final packageRoot = await _copyTde9Package(root);

      final valid = await _runVerifier(packageRoot);
      expect(
        valid.exitCode,
        0,
        reason: 'stdout:\n${valid.stdout}\nstderr:\n${valid.stderr}',
      );

      final databasePath = p.join(
        packageRoot.path,
        'runtime',
        'course_runtime.sqlite',
      );
      final database = await databaseFactoryFfi.openDatabase(databasePath);
      await database.execute('PRAGMA foreign_keys = OFF');
      await database.update(
        'teacher_guide_item_relations',
        {'target_id': 'MISSING_CANONICAL_ENTITY'},
        where: 'item_id = ?',
        whereArgs: ['TG_ITEM_1'],
      );
      await database.close();

      final invalid = await _runVerifier(packageRoot);
      expect(invalid.exitCode, isNot(0));
      expect(
        '${invalid.stdout}\n${invalid.stderr}',
        contains('teacher_guide foreign key bütünlüğü bozuk'),
      );
    },
  );

  test('runtime verifier invalid structured JSON payloadı reddeder', () async {
    final root = await Directory.systemTemp.createTemp('teacher_guide_json_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final packageRoot = await _copyTde9Package(root);
    final database = await databaseFactoryFfi.openDatabase(
      p.join(packageRoot.path, 'runtime', 'course_runtime.sqlite'),
    );
    await database.update(
      'teacher_guide_items',
      {'expected_response_json': '{not-json'},
      where: 'item_id = ?',
      whereArgs: ['TG_ITEM_1'],
    );
    await database.close();

    final invalid = await _runVerifier(packageRoot);
    expect(invalid.exitCode, isNot(0));
    expect('${invalid.stdout}\n${invalid.stderr}', contains('geçersiz JSON'));
  });

  test(
    'runtime verifier seal fingerprint evidence mismatchini reddeder',
    () async {
      final root = await Directory.systemTemp.createTemp('teacher_guide_seal_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final packageRoot = await _copyTde9Package(root);
      final manifestPath = File(
        p.join(packageRoot.path, 'runtime', 'runtime_manifest.json'),
      );
      final manifest = Map<String, dynamic>.from(
        jsonDecode(await manifestPath.readAsString()) as Map,
      );
      final validation = Map<String, dynamic>.from(
        manifest['teacher_guide_validation'] as Map,
      )..['seal_sha256'] = '0' * 64;
      manifest['teacher_guide_validation'] = validation;
      await manifestPath.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      );

      final invalid = await _runVerifier(packageRoot);
      expect(invalid.exitCode, isNot(0));
      expect(
        '${invalid.stdout}\n${invalid.stderr}',
        contains('teacher_guide seal sha256'),
      );
    },
  );

  test(
    'runtime verifier seal guide fingerprint mismatchini reddeder',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'teacher_guide_seal_content_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final packageRoot = await _copyTde9Package(root);
      final manifestPath = File(
        p.join(packageRoot.path, 'runtime', 'runtime_manifest.json'),
      );
      final manifest = Map<String, dynamic>.from(
        jsonDecode(await manifestPath.readAsString()) as Map,
      );
      final sealFile = File(
        p.join(
          packageRoot.path,
          'runtime',
          'teacher_guide_validation_seal.json',
        ),
      );
      final seal = Map<String, dynamic>.from(
        jsonDecode(await sealFile.readAsString()) as Map,
      )..['teacher_guide_content_fingerprint'] = 'different';
      await sealFile.writeAsString(jsonEncode(seal));
      final validation =
          Map<String, dynamic>.from(manifest['teacher_guide_validation'] as Map)
            ..['seal_sha256'] = sha256
                .convert(await sealFile.readAsBytes())
                .toString();
      manifest['teacher_guide_validation'] = validation;
      await manifestPath.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      );

      final invalid = await _runVerifier(packageRoot);
      expect(invalid.exitCode, isNot(0));
      expect(
        '${invalid.stdout}\n${invalid.stderr}',
        contains('teacher_guide seal content fingerprint'),
      );
    },
  );
}

Future<Directory> _copyTde9Package(Directory root) async {
  final sourceRoot = Directory(
    p.join(
      Directory.current.path,
      'tymm-verileri',
      'turk-dili-ve-edebiyati',
      'TDE_9',
    ),
  );
  final packageRoot = Directory(p.join(root.path, 'TDE_9'))..createSync();
  final runtimeRoot = Directory(p.join(packageRoot.path, 'runtime'))
    ..createSync();
  for (final name in [
    'course_runtime.sqlite',
    'runtime_manifest.json',
    'runtime_validation_report.md',
  ]) {
    await File(
      p.join(sourceRoot.path, 'runtime', name),
    ).copy(p.join(runtimeRoot.path, name));
  }
  await File(
    p.join(sourceRoot.path, 'package_manifest.json'),
  ).copy(p.join(packageRoot.path, 'package_manifest.json'));

  final database = await databaseFactoryFfi.openDatabase(
    p.join(runtimeRoot.path, 'course_runtime.sqlite'),
  );
  try {
    final schema = await File(
      p.join(
        Directory.current.path,
        'tool',
        'teacher_guide',
        'teacher_guide_runtime_schema.sql',
      ),
    ).readAsString();
    for (final statement in schema.split(';')) {
      final sql = statement
          .split('\n')
          .where((line) => !line.trim().startsWith('--'))
          .join('\n')
          .trim();
      if (sql.isNotEmpty) await database.execute(sql);
    }

    final themeId = (await database.rawQuery(
      'SELECT theme_id FROM themes ORDER BY theme_order LIMIT 1',
    )).single['theme_id']!.toString();
    final blockId = (await database.rawQuery(
      'SELECT block_id FROM blocks ORDER BY block_id LIMIT 1',
    )).single['block_id']!.toString();
    final outcomeId = (await database.rawQuery(
      'SELECT outcome_id FROM outcomes ORDER BY outcome_id LIMIT 1',
    )).single['outcome_id']!.toString();
    final activityId = (await database.rawQuery(
      'SELECT activity_id FROM activities ORDER BY activity_id LIMIT 1',
    )).single['activity_id']!.toString();
    for (final entity in [
      ['course', 'TDE_9'],
      ['theme', themeId],
      ['block', blockId],
      ['outcome', outcomeId],
      ['activity', activityId],
    ]) {
      await database.insert('canonical_entities', {
        'entity_type': entity[0],
        'entity_id': entity[1],
      });
    }
    final provenance = jsonEncode({
      'source_ids': ['verified_fixture'],
      'source_locators': ['fixture#1'],
      'content_class': 'MIXED',
    });
    await database.insert('teacher_guides', {
      'guide_id': 'TG_GUIDE_1',
      'course_id': 'TDE_9',
      'scope_type': 'theme',
      'scope_id': themeId,
      'title': 'Generic verifier fixture',
      'content_status': 'VERIFIED',
      'schema_version': '1.0.0',
      'provenance_json': provenance,
    });
    await database.insert('teacher_guide_sections', {
      'section_id': 'TG_SECTION_1',
      'guide_id': 'TG_GUIDE_1',
      'section_order': 1,
      'title': 'Section',
      'section_type': 'INQUIRY',
      'page_locator': '1',
      'source_locator': 'fixture#1',
      'content_status': 'VERIFIED',
      'provenance_json': provenance,
    });
    await database.insert('teacher_guide_units', {
      'unit_id': 'TG_UNIT_1',
      'section_id': 'TG_SECTION_1',
      'unit_order': 1,
      'title': 'Unit',
      'page_locator': '1',
      'source_locator': 'fixture#1',
      'content_status': 'VERIFIED',
      'purpose_json': jsonEncode('verify explicit relation'),
      'provenance_json': provenance,
    });
    await database.insert('teacher_guide_items', {
      'item_id': 'TG_ITEM_1',
      'unit_id': 'TG_UNIT_1',
      'item_order': 1,
      'title': 'Item',
      'label': 'Generic item',
      'item_type': 'PERFORMANCE_TASK',
      'page_locator': '1',
      'source_locator': 'fixture#1',
      'content_status': 'REVIEW_REQUIRED',
      'expected_response_json': jsonEncode({
        'steps': ['observe', 'model'],
      }),
      'acceptance_criteria_json': jsonEncode(['evidence']),
      'teacher_guidance_json': jsonEncode(['guide']),
      'common_misconceptions_json': jsonEncode([]),
      'assessment_evidence_json': jsonEncode(['record']),
      'differentiation_json': jsonEncode({
        'support': ['template'],
        'enrichment': ['extension'],
      }),
      'provenance_json': provenance,
      'canonical_payload_sha256': 'a' * 64,
    });
    await database.insert('teacher_guide_item_relations', {
      'item_id': 'TG_ITEM_1',
      'target_type': 'activity',
      'target_id': activityId,
      'relation_type': 'supports',
      'relation_order': 1,
    });
  } finally {
    await database.close();
  }

  final manifestPath = File(p.join(runtimeRoot.path, 'runtime_manifest.json'));
  final manifest = Map<String, dynamic>.from(
    jsonDecode(await manifestPath.readAsString()) as Map,
  );
  final canonicalFingerprint =
      manifest['canonical_content_fingerprint']?.toString() ?? '';
  final capabilities = Map<String, dynamic>.from(
    (manifest['capabilities'] as Map?) ?? const {},
  )..['teacher_guide'] = true;
  manifest['capabilities'] = capabilities;
  manifest['teacher_guide_capabilities'] = {
    'available': true,
    'schema_version': '1.0.0',
    'validation_status': 'PASS',
    'source_bound': true,
  };
  manifest['teacher_guide_validation'] = {
    'status': 'PASS',
    'scope': 'COURSE',
    'content_fingerprint': 'sha256:fixture',
    'canonical_content_fingerprint': canonicalFingerprint,
    'source_bound': true,
  };
  final rowCounts = Map<String, dynamic>.from(manifest['row_counts'] as Map)
    ..addAll({
      'canonical_entities': 5,
      'teacher_guides': 1,
      'teacher_guide_sections': 1,
      'teacher_guide_units': 1,
      'teacher_guide_items': 1,
      'teacher_guide_item_relations': 1,
    });
  manifest['row_counts'] = rowCounts;
  final sealFile = File(
    p.join(runtimeRoot.path, 'teacher_guide_validation_seal.json'),
  );
  await sealFile.writeAsString(
    jsonEncode({
      'seal_type': 'TEACHER_GUIDE_COURSE_VALIDATION_SEAL',
      'canonical_content_fingerprint': canonicalFingerprint,
      'teacher_guide_content_fingerprint': 'fixture',
      'status': 'PASS',
    }),
  );
  final validation =
      Map<String, dynamic>.from(manifest['teacher_guide_validation'] as Map)
        ..['seal_path'] = 'runtime/teacher_guide_validation_seal.json'
        ..['seal_sha256'] = sha256
            .convert(await sealFile.readAsBytes())
            .toString();
  manifest['teacher_guide_validation'] = validation;
  await manifestPath.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  return packageRoot;
}

Future<ProcessResult> _runVerifier(Directory packageRoot) => Process.run(
  _dartExecutable,
  [
    '--disable-analytics',
    'run',
    'bin/verify_runtime.dart',
    '--course',
    'TDE_9',
    '--package-root',
    packageRoot.path,
  ],
  workingDirectory: p.join(Directory.current.path, 'tool', 'runtime_verifier'),
  environment: <String, String>{
    ...Platform.environment,
    'DART_SUPPRESS_ANALYTICS': 'true',
  },
);

String get _dartExecutable {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final flutterDart = p.join(
      flutterRoot,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      'dart',
    );
    if (File(flutterDart).existsSync()) return flutterDart;
  }
  return Platform.executable;
}
