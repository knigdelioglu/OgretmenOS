import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'course_database_data_source.dart';
import '../../domain/models/course_models.dart';
import '../../domain/runtime/course_runtime_registry.dart';
import '../../domain/runtime/runtime_manifest_policy.dart';

class InstalledRuntime {
  const InstalledRuntime({required this.manifest, required this.databasePath});

  final RuntimeManifest manifest;
  final String databasePath;
}

class CourseDatabaseInstaller {
  const CourseDatabaseInstaller({this.courseId = 'TDE_9'});

  final String courseId;

  CourseRuntimeDescriptor get descriptor => runtimeForCourse(courseId);

  Future<InstalledRuntime> install() async {
    final manifest = await _readBundledManifest();
    if (!manifest.isCompatible || manifest.courseId != courseId) {
      throw StateError(
        'Desteklenmeyen veya doğrulanmamış runtime paketi: '
        '${manifest.courseId}/${manifest.schemaVersion}/${manifest.validationStatus}',
      );
    }

    final databasesDirectory = await getDatabasesPath();
    final runtimeDirectory = Directory(
      p.join(databasesDirectory, 'course_runtime', manifest.courseId),
    );
    await runtimeDirectory.create(recursive: true);

    final databaseFile = File(
      p.join(runtimeDirectory.path, 'course_runtime.sqlite'),
    );
    final manifestFile = File(
      p.join(runtimeDirectory.path, 'runtime_manifest.json'),
    );
    final shouldInstall = await _needsInstall(
      manifestFile,
      databaseFile,
      manifest,
    );
    if (shouldInstall) {
      final databaseBytes = (await rootBundle.load(
        descriptor.databaseAsset,
      )).buffer.asUint8List();
      final manifestBytes = (await rootBundle.load(
        descriptor.manifestAsset,
      )).buffer.asUint8List();
      await _replaceFile(databaseFile, databaseBytes);
      await _replaceFile(manifestFile, manifestBytes);
    }

    if (!databaseFile.existsSync() || await databaseFile.length() == 0) {
      throw StateError('Runtime SQLite yerel kopyası oluşturulamadı.');
    }
    return InstalledRuntime(
      manifest: manifest,
      databasePath: databaseFile.path,
    );
  }

  Future<RuntimeManifest> _readBundledManifest() async {
    final manifestString = await rootBundle.loadString(
      descriptor.manifestAsset,
    );
    final decoded = jsonDecode(manifestString);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Bundled runtime manifest geçersiz.');
    }
    validateRuntimeManifest(decoded);
    return RuntimeManifest.fromJson(decoded);
  }

  Future<bool> _needsInstall(
    File manifestFile,
    File databaseFile,
    RuntimeManifest expected,
  ) async {
    if (!manifestFile.existsSync() || !databaseFile.existsSync()) return true;
    if (await databaseFile.length() == 0) return true;
    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map<String, dynamic>) return true;
      validateRuntimeManifest(decoded);
      final local = RuntimeManifest.fromJson(decoded);
      return local.runtimePackageVersion != expected.runtimePackageVersion ||
          local.schemaVersion != expected.schemaVersion ||
          local.courseId != expected.courseId ||
          local.canonicalContentFingerprint !=
              expected.canonicalContentFingerprint ||
          local.validationStatus != expected.validationStatus;
    } on Object {
      return true;
    }
  }

  Future<void> _replaceFile(File destination, List<int> bytes) async {
    final temporary = File('${destination.path}.tmp');
    if (temporary.existsSync()) await temporary.delete();
    await temporary.writeAsBytes(bytes, flush: true);
    if (destination.existsSync()) await destination.delete();
    await temporary.rename(destination.path);
  }
}

class CourseDatabase {
  CourseDatabase._({required this.manifest, required this.database})
    : dataSource = CourseDatabaseDataSource(database);

  static Future<CourseDatabase> open({
    String courseId = 'TDE_9',
    CourseDatabaseInstaller? installer,
  }) async {
    final selectedInstaller =
        installer ?? CourseDatabaseInstaller(courseId: courseId);
    final installed = await selectedInstaller.install();
    final database = await openDatabase(
      installed.databasePath,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final dataSource = CourseDatabaseDataSource(database);
      final course = await dataSource.getCourse();
      if (course.courseId != installed.manifest.courseId ||
          !isRuntimeDatabaseSchemaCompatible(
            course.schemaVersion,
            installed.manifest.schemaVersion,
          ) ||
          course.sourceManifestFingerprint !=
              installed.manifest.canonicalContentFingerprint) {
        await database.close();
        throw StateError('Runtime DB manifest ile uyumlu değil.');
      }
      return CourseDatabase._(manifest: installed.manifest, database: database);
    } on Object {
      if (database.isOpen) await database.close();
      rethrow;
    }
  }

  final RuntimeManifest manifest;
  final Database database;
  final CourseDatabaseDataSource dataSource;

  Future<void> close() => database.close();
}
