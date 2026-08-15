const supportedRuntimeCourseId = 'TDE_9';
const supportedRuntimeSchemaMajor = '1.';
const requiredRuntimeFreshStatus = 'RUNTIME_FRESH';
const requiredRuntimeDatabasePath = 'runtime/course_runtime.sqlite';

/// Validates the compatibility contract that must hold every time the app opens.
///
/// Freshness is intentionally not required here. Freshness is a build/sync
/// concern and can be proven either by a manifest field or by the compiler's
/// runtime validation report. The packaged manifest remains byte-identical to
/// the canonical TYMM runtime manifest.
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

  final fingerprint =
      manifest['canonical_content_fingerprint']?.toString().trim() ?? '';
  if (fingerprint.isEmpty) {
    throw StateError('canonical_content_fingerprint eksik.');
  }

  if (manifest['runtime_database_path'] != requiredRuntimeDatabasePath) {
    throw StateError('Runtime database yolu manifest ile uyumlu değil.');
  }
}

/// Validates the build-time freshness evidence produced by the runtime compiler.
///
/// Newer compiler packages may expose `runtime_status` directly in the manifest.
/// The current canonical TDE_9 package records the same authoritative result in
/// `runtime_validation_report.md` under the `source fingerprint status` check.
void validateRuntimeFreshnessEvidence(
  Map<String, dynamic> manifest, {
  String? validationReport,
}) {
  validateRuntimeManifest(manifest);

  final manifestStatus = manifest['runtime_status']?.toString().trim();
  if (manifestStatus == requiredRuntimeFreshStatus) return;

  final reportLine = validationReport
      ?.split('\n')
      .where(
        (line) => line.toLowerCase().contains('source fingerprint status'),
      )
      .cast<String?>()
      .firstOrNull;

  if (reportLine != null) {
    final normalized = reportLine.toUpperCase();
    if (normalized.contains('PASS') &&
        normalized.contains(requiredRuntimeFreshStatus)) {
      return;
    }
  }

  throw StateError(
    'Runtime package freshness kanıtı yok veya geçersiz: '
    '${manifestStatus ?? 'manifest runtime_status yok'}',
  );
}
