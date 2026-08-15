const supportedRuntimeCourseId = 'TDE_9';
const supportedRuntimeSchemaMajor = '1.';
const requiredRuntimeStatus = 'RUNTIME_FRESH';
const requiredRuntimeDatabasePath = 'runtime/course_runtime.sqlite';

void validateRuntimeManifest(Map<String, dynamic> manifest) {
  if (manifest['course_id'] != supportedRuntimeCourseId) {
    throw StateError('Beklenmeyen course_id: ${manifest['course_id']}');
  }

  final schemaVersion = manifest['schema_version']?.toString() ?? '';
  if (!schemaVersion.startsWith(supportedRuntimeSchemaMajor)) {
    throw StateError('Desteklenmeyen schema_version: $schemaVersion');
  }

  final runtimePackageVersion =
      manifest['runtime_package_version']?.toString().trim() ?? '';
  if (runtimePackageVersion.isEmpty) {
    throw StateError('runtime_package_version eksik.');
  }

  if (manifest['validation_status'] != 'PASS') {
    throw StateError(
      'Runtime validation PASS değil: ${manifest['validation_status']}',
    );
  }

  if (manifest['runtime_status'] != requiredRuntimeStatus) {
    throw StateError(
      'Runtime package fresh değil: ${manifest['runtime_status']}',
    );
  }

  final fingerprint =
      manifest['canonical_content_fingerprint']?.toString().trim() ?? '';
  if (fingerprint.isEmpty) {
    throw StateError('canonical_content_fingerprint eksik.');
  }

  if (manifest['runtime_database_path'] != requiredRuntimeDatabasePath) {
    throw StateError('Runtime database yolu manifest ile uyumlu değil.');
  }
}
