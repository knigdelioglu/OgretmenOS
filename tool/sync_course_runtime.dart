import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const _defaultSourceRoot = '/Users/kadir/Desktop/tymm/courses/TDE_9/runtime';
const _defaultTargetRoot = 'assets/courses/TDE_9';
const _courseId = 'TDE_9';
const _supportedSchemaMajor = '1.';

Future<void> main(List<String> args) async {
  try {
    final sourceRoot = _valueFor(args, '--source-root') ?? _defaultSourceRoot;
    final targetRoot = _valueFor(args, '--target-root') ?? _defaultTargetRoot;

    final sourceManifest = File(p.join(sourceRoot, 'runtime_manifest.json'));
    final sourceDatabase = File(p.join(sourceRoot, 'course_runtime.sqlite'));
    if (!sourceManifest.existsSync()) {
      throw StateError('Runtime manifest bulunamadı: ${sourceManifest.path}');
    }
    if (!sourceDatabase.existsSync()) {
      throw StateError('Runtime SQLite bulunamadı: ${sourceDatabase.path}');
    }

    final manifestJson = jsonDecode(await sourceManifest.readAsString());
    if (manifestJson is! Map<String, dynamic>) {
      throw StateError('Runtime manifest JSON nesnesi olmalı.');
    }
    _validateManifest(manifestJson);

    final targetDirectory = Directory(targetRoot);
    await targetDirectory.create(recursive: true);
    final targetDatabase = File(p.join(targetRoot, 'course_runtime.sqlite'));
    final targetManifest = File(p.join(targetRoot, 'runtime_manifest.json'));

    await sourceDatabase.copy(targetDatabase.path);
    await sourceManifest.copy(targetManifest.path);

    if (!targetDatabase.existsSync() ||
        targetDatabase.lengthSync() != sourceDatabase.lengthSync()) {
      throw StateError('Runtime SQLite hedef doğrulaması başarısız.');
    }
    if (!targetManifest.existsSync() || targetManifest.lengthSync() == 0) {
      throw StateError('Runtime manifest hedef doğrulaması başarısız.');
    }

    stdout.writeln('RUNTIME_SYNC: PASS');
    stdout.writeln('COURSE_ID: ${manifestJson['course_id']}');
    stdout.writeln(
      'RUNTIME_PACKAGE_VERSION: ${manifestJson['runtime_package_version']}',
    );
    stdout.writeln('SCHEMA_VERSION: ${manifestJson['schema_version']}');
    stdout.writeln('VALIDATION_STATUS: ${manifestJson['validation_status']}');
    stdout.writeln('DATABASE_BYTES: ${targetDatabase.lengthSync()}');
  } catch (error, stackTrace) {
    stderr.writeln('RUNTIME_SYNC: FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

String? _valueFor(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

void _validateManifest(Map<String, dynamic> manifest) {
  if (manifest['course_id'] != _courseId) {
    throw StateError('Beklenmeyen course_id: ${manifest['course_id']}');
  }
  final schemaVersion = manifest['schema_version']?.toString() ?? '';
  if (!schemaVersion.startsWith(_supportedSchemaMajor)) {
    throw StateError('Desteklenmeyen schema_version: $schemaVersion');
  }
  if (manifest['validation_status'] != 'PASS') {
    throw StateError(
      'Runtime validation PASS değil: ${manifest['validation_status']}',
    );
  }
  if (manifest['runtime_database_path'] != 'runtime/course_runtime.sqlite') {
    throw StateError('Runtime database yolu manifest ile uyumlu değil.');
  }
}
