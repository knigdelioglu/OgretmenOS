import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../tool/sync_course_runtime.dart' as sync;

void main() {
  test('projection failure hedef runtime ve manifesti değiştirmez', () async {
    await _withRuntimeFixture((fixture) async {
      final beforeManifest = await fixture.targetManifest.readAsBytes();
      final invalidCatalog = File(p.join(fixture.root.path, 'invalid.json'))
        ..writeAsStringSync('{ invalid json');

      await expectLater(
        sync.syncRuntimePackage(
          sync.RuntimeSyncRequest(
            courseId: 'TDE_9',
            sourceRoot: fixture.sourceRuntime.path,
            targetRoot: fixture.targetRuntime.path,
            catalogPath: invalidCatalog.path,
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await fixture.targetManifest.readAsBytes(), beforeManifest);
      expect(
        await fixture.targetDatabase.readAsBytes(),
        fixture.oldDatabaseBytes,
      );
      expect(
        await Directory('${fixture.targetRuntime.path}.staging').exists(),
        isFalse,
      );
      expect(
        await Directory('${fixture.targetRuntime.path}.backup').exists(),
        isFalse,
      );
    });
  });

  test('staging validation failure hedef runtimeı değiştirmez', () async {
    await _withRuntimeFixture((fixture) async {
      final beforeManifest = await fixture.targetManifest.readAsBytes();
      await expectLater(
        sync.syncRuntimePackage(
          sync.RuntimeSyncRequest(
            courseId: 'TDE_9',
            sourceRoot: fixture.sourceRuntime.path,
            targetRoot: fixture.targetRuntime.path,
            catalogPath: fixture.catalog.path,
          ),
          beforeStagingValidation: (_) {
            throw StateError('injected staging validation failure');
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(await fixture.targetManifest.readAsBytes(), beforeManifest);
      expect(
        await fixture.targetDatabase.readAsBytes(),
        fixture.oldDatabaseBytes,
      );
    });
  });

  test(
    'başarılı sync tutarlı staged package üretir ve stale temp temizler',
    () async {
      await _withRuntimeFixture((fixture) async {
        await Directory('${fixture.targetRuntime.path}.staging').create();
        await Directory('${fixture.targetRuntime.path}.backup').create();
        await sync.syncRuntimePackage(
          sync.RuntimeSyncRequest(
            courseId: 'TDE_9',
            sourceRoot: fixture.sourceRuntime.path,
            targetRoot: fixture.targetRuntime.path,
            catalogPath: fixture.catalog.path,
          ),
        );

        final runtimeManifest =
            jsonDecode(await fixture.targetManifest.readAsString())
                as Map<String, dynamic>;
        final packageManifest =
            jsonDecode(await fixture.packageManifest.readAsString())
                as Map<String, dynamic>;
        expect(packageManifest['course_id'], 'TDE_9');
        expect(
          packageManifest['runtime_canonical_content_fingerprint'],
          runtimeManifest['canonical_content_fingerprint'],
        );
        expect(runtimeManifest['form_template_status_counts'], {
          'ready': 0,
          'needs_review': 28,
        });
        expect(
          await Directory('${fixture.targetRuntime.path}.staging').exists(),
          isFalse,
        );
        expect(
          await Directory('${fixture.targetRuntime.path}.backup').exists(),
          isFalse,
        );
      });
    },
  );
}

Future<void> _withRuntimeFixture(
  Future<void> Function(_RuntimeFixture fixture) action,
) async {
  final root = await Directory.systemTemp.createTemp('ogretmen_os_sync_');
  addTearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  final sourceRuntime = Directory(p.join(root.path, 'source', 'runtime'))
    ..createSync(recursive: true);
  final targetRuntime = Directory(p.join(root.path, 'target', 'runtime'))
    ..createSync(recursive: true);
  final repositoryRuntime = Directory(
    p.join(
      Directory.current.path,
      'tymm-verileri',
      'turk-dili-ve-edebiyati',
      'TDE_9',
      'runtime',
    ),
  );
  for (final name in [
    'course_runtime.sqlite',
    'runtime_manifest.json',
    'runtime_validation_report.md',
  ]) {
    await File(
      p.join(repositoryRuntime.path, name),
    ).copy(p.join(sourceRuntime.path, name));
    await File(
      p.join(repositoryRuntime.path, name),
    ).copy(p.join(targetRuntime.path, name));
  }
  final packageManifest = File(
    p.join(targetRuntime.parent.path, 'package_manifest.json'),
  );
  await File(
    p.join(
      Directory.current.path,
      'tymm-verileri',
      'turk-dili-ve-edebiyati',
      'TDE_9',
      'package_manifest.json',
    ),
  ).copy(packageManifest.path);
  final formsIndex = File(
    p.join(sourceRuntime.parent.path, 'textbook_forms_index.json'),
  )..writeAsStringSync(jsonEncode({'course_id': 'TDE_9', 'forms': []}));
  final catalog = File(p.join(root.path, 'catalog.json'))
    ..writeAsStringSync(jsonEncode({'course_id': 'TDE_9', 'templates': {}}));
  final fixture = _RuntimeFixture(
    root: root,
    sourceRuntime: sourceRuntime,
    targetRuntime: targetRuntime,
    targetManifest: File(p.join(targetRuntime.path, 'runtime_manifest.json')),
    targetDatabase: File(p.join(targetRuntime.path, 'course_runtime.sqlite')),
    oldDatabaseBytes: await File(
      p.join(targetRuntime.path, 'course_runtime.sqlite'),
    ).readAsBytes(),
    packageManifest: packageManifest,
    catalog: catalog,
    formsIndex: formsIndex,
  );
  await action(fixture);
}

class _RuntimeFixture {
  const _RuntimeFixture({
    required this.root,
    required this.sourceRuntime,
    required this.targetRuntime,
    required this.targetManifest,
    required this.targetDatabase,
    required this.oldDatabaseBytes,
    required this.packageManifest,
    required this.catalog,
    required this.formsIndex,
  });

  final Directory root;
  final Directory sourceRuntime;
  final Directory targetRuntime;
  final File targetManifest;
  final File targetDatabase;
  final List<int> oldDatabaseBytes;
  final File packageManifest;
  final File catalog;
  final File formsIndex;
}
