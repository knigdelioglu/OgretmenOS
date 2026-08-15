import 'dart:convert';
import 'dart:io';

import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:path/path.dart' as p;

const _defaultSourceRoot = '/Users/kadir/Desktop/tymm/courses/TDE_9/runtime';
const _defaultTargetRoot = 'assets/courses/TDE_9';

Future<void> main(List<String> args) async {
  try {
    final sourceRoot = _valueFor(args, '--source-root') ?? _defaultSourceRoot;
    final targetRoot = _valueFor(args, '--target-root') ?? _defaultTargetRoot;

    final sourceManifest = File(p.join(sourceRoot, 'runtime_manifest.json'));
    final sourceDatabase = File(p.join(sourceRoot, 'course_runtime.sqlite'));
    final sourceValidationReport = File(
      p.join(sourceRoot, 'runtime_validation_report.md'),
    );
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
    final validationReport = sourceValidationReport.existsSync()
        ? await sourceValidationReport.readAsString()
        : null;
    validateRuntimeFreshnessEvidence(
      manifestJson,
      validationReport: validationReport,
    );

    final targetDirectory = Directory(targetRoot);
    await targetDirectory.create(recursive: true);
    final targetDatabase = File(p.join(targetRoot, 'course_runtime.sqlite'));
    final targetManifest = File(p.join(targetRoot, 'runtime_manifest.json'));
    final targetValidationReport = File(
      p.join(targetRoot, 'runtime_validation_report.md'),
    );

    await sourceDatabase.copy(targetDatabase.path);
    await sourceManifest.copy(targetManifest.path);
    if (sourceValidationReport.existsSync()) {
      await sourceValidationReport.copy(targetValidationReport.path);
    }

    if (!await _filesEqual(sourceDatabase, targetDatabase)) {
      throw StateError('Runtime SQLite hedef doğrulaması başarısız.');
    }
    if (!await _filesEqual(sourceManifest, targetManifest)) {
      throw StateError('Runtime manifest hedef doğrulaması başarısız.');
    }
    if (sourceValidationReport.existsSync() &&
        !await _filesEqual(sourceValidationReport, targetValidationReport)) {
      throw StateError('Runtime validation raporu hedef doğrulaması başarısız.');
    }

    stdout.writeln('RUNTIME_SYNC: PASS');
    stdout.writeln('COURSE_ID: ${manifestJson['course_id']}');
    stdout.writeln(
      'RUNTIME_PACKAGE_VERSION: ${manifestJson['runtime_package_version']}',
    );
    stdout.writeln('SCHEMA_VERSION: ${manifestJson['schema_version']}');
    stdout.writeln('VALIDATION_STATUS: ${manifestJson['validation_status']}');
    stdout.writeln('FRESHNESS_EVIDENCE: PASS');
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

Future<bool> _filesEqual(File source, File target) async {
  if (!source.existsSync() || !target.existsSync()) return false;
  if (await source.length() != await target.length()) return false;

  final sourceBytes = await source.readAsBytes();
  final targetBytes = await target.readAsBytes();
  for (var index = 0; index < sourceBytes.length; index++) {
    if (sourceBytes[index] != targetBytes[index]) return false;
  }
  return true;
}
