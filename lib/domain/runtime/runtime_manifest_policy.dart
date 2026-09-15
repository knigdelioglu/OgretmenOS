import '../models/course_models.dart';
import '../models/teacher_guide_models.dart';
import 'course_runtime_registry.dart';

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
  final courseId = manifest['course_id']?.toString() ?? '';
  if (!isSupportedRuntimeCourse(courseId)) {
    throw StateError('Desteklenmeyen course_id: $courseId');
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

  _validateTeacherGuideManifestShape(manifest);
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
  if (manifestStatus != null && manifestStatus.isNotEmpty) {
    if (manifestStatus == requiredRuntimeFreshStatus) return;
    throw StateError('Runtime package fresh değil: $manifestStatus');
  }

  String? reportLine;
  if (validationReport != null) {
    for (final line in validationReport.split('\n')) {
      if (line.toLowerCase().contains('source fingerprint status')) {
        reportLine = line;
        break;
      }
    }
  }

  if (reportLine != null) {
    final normalized = reportLine.toUpperCase();
    if (normalized.contains('PASS') &&
        normalized.contains(requiredRuntimeFreshStatus)) {
      return;
    }
  }

  throw StateError('Runtime package freshness kanıtı yok veya geçersiz.');
}

bool isRuntimeDatabaseSchemaCompatible(
  String databaseSchemaVersion,
  String manifestSchemaVersion,
) {
  if (databaseSchemaVersion.isEmpty || manifestSchemaVersion.isEmpty) {
    return false;
  }
  final databaseMajor = databaseSchemaVersion.split('.').first;
  final manifestMajor = manifestSchemaVersion.split('.').first;
  return databaseMajor == manifestMajor;
}

/// Returns whether an already installed runtime is byte-contract equivalent to
/// the bundled package identity that the app is about to open.
///
/// Lesson-plan and enabled form-template row counts are included explicitly
/// even though a canonical source change should also alter the fingerprint.
/// This keeps additive runtime capabilities fail-closed if a malformed package
/// reuses an old fingerprint.
bool runtimePackageIdentityMatches(
  RuntimeManifest local,
  RuntimeManifest expected,
) {
  if (local.runtimePackageVersion != expected.runtimePackageVersion ||
      local.schemaVersion != expected.schemaVersion ||
      local.courseId != expected.courseId ||
      local.canonicalContentFingerprint !=
          expected.canonicalContentFingerprint ||
      local.validationStatus != expected.validationStatus ||
      local.rowCounts['lesson_plan_packages'] !=
          expected.rowCounts['lesson_plan_packages']) {
    return false;
  }
  final expectedHasFormTemplates = expected.hasCapability('form_templates');
  if (local.hasCapability('form_templates') != expectedHasFormTemplates) {
    return false;
  }
  if (expectedHasFormTemplates) {
    if (!local.hasCapability('form_templates') ||
        local.rowCounts['form_templates'] !=
            expected.rowCounts['form_templates']) {
      return false;
    }
    if (!_mapsEqual(
      local.formTemplateStatusCounts,
      expected.formTemplateStatusCounts,
    )) {
      return false;
    }
    if (!_mapsEqual(
      local.formTemplateReviewReasons,
      expected.formTemplateReviewReasons,
    )) {
      return false;
    }
  }
  if (local.hasCapability('teacher_guide') !=
      expected.hasCapability('teacher_guide')) {
    return false;
  }
  if (!_deepEqual(
    local.teacherGuideCapabilities,
    expected.teacherGuideCapabilities,
  )) {
    return false;
  }
  if (!_deepEqual(
    local.teacherGuideValidation,
    expected.teacherGuideValidation,
  )) {
    return false;
  }
  for (final table in teacherGuideRuntimeTableNames) {
    final expectedCount = expected.rowCounts[table];
    if (expectedCount != null && local.rowCounts[table] != expectedCount) {
      return false;
    }
  }
  return true;
}

bool runtimePackageRequiresInstall(
  RuntimeManifest local,
  RuntimeManifest expected,
) => !runtimePackageIdentityMatches(local, expected);

bool _mapsEqual<K, V>(Map<K, V> left, Map<K, V> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

void _validateTeacherGuideManifestShape(Map<String, dynamic> manifest) {
  final rawCapabilities = manifest['capabilities'];
  if (rawCapabilities is! Map ||
      !rawCapabilities.containsKey('teacher_guide')) {
    return;
  }
  if (rawCapabilities['teacher_guide'] is! bool) {
    throw StateError('teacher_guide capability boolean olmalı.');
  }
  final advertised = rawCapabilities['teacher_guide'] == true;
  final rawMetadata = manifest['teacher_guide_capabilities'];
  if (rawMetadata is Map) {
    final expectedStatus = advertised ? 'PASS' : 'NOT_PRESENT';
    if (rawMetadata['available'] != advertised ||
        rawMetadata['source_bound'] != advertised ||
        rawMetadata['validation_status'] != expectedStatus) {
      throw StateError(
        'teacher_guide capability metadata truth ile uyuşmuyor.',
      );
    }
  }
  final rawValidation = manifest['teacher_guide_validation'];
  if (!advertised) {
    if (rawValidation is Map &&
        (rawValidation['status'] != 'NOT_PRESENT' ||
            rawValidation['source_bound'] != false)) {
      throw StateError('teacher_guide_validation false truth ile uyuşmuyor.');
    }
    return;
  }

  final metadata = manifest['teacher_guide_capabilities'];
  if (metadata is! Map) {
    throw StateError('teacher_guide_capabilities eksik.');
  }
  if (metadata['available'] != true ||
      metadata['validation_status'] != 'PASS' ||
      metadata['source_bound'] != true) {
    throw StateError('teacher_guide capability doğrulama kanıtı eksik.');
  }
  if ((metadata['schema_version']?.toString().trim() ?? '').isEmpty) {
    throw StateError('teacher_guide schema_version eksik.');
  }

  final validation = manifest['teacher_guide_validation'];
  if (validation is! Map ||
      validation['status'] != 'PASS' ||
      validation['scope'] != 'COURSE' ||
      validation['source_bound'] != true ||
      (validation['content_fingerprint']?.toString().trim() ?? '').isEmpty ||
      validation['canonical_content_fingerprint'] !=
          manifest['canonical_content_fingerprint'] ||
      (validation['seal_path']?.toString().trim() ?? '').isEmpty ||
      (validation['seal_sha256']?.toString().trim() ?? '').isEmpty) {
    throw StateError('teacher_guide_validation kanıtı eksik.');
  }

  final rawCounts = manifest['row_counts'];
  if (rawCounts is! Map) {
    throw StateError('teacher_guide row_counts eksik.');
  }
  for (final table in teacherGuideRuntimeTableNames) {
    final value = rawCounts[table];
    if (value is! num || value < 0 || value != value.toInt()) {
      throw StateError('teacher_guide row count geçersiz: $table');
    }
  }
}

bool _deepEqual(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEqual(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEqual(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
