#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def patch(path: str, old: str, new: str, count: int = 1) -> None:
    target = ROOT / path
    text = target.read_text(encoding='utf-8')
    actual = text.count(old)
    if actual != count:
        raise RuntimeError(f'{path}: expected {count}, found {actual}: {old[:80]!r}')
    target.write_text(text.replace(old, new, count), encoding='utf-8')

# Keep existing test/fake RuntimeManifest constructors source-compatible.
patch(
    'lib/domain/models/course_models.dart',
    '    required this.assessmentPayloadCapabilities,\n',
    '    this.assessmentPayloadCapabilities = const {},\n',
)

# Avoid Flutter material Theme vs course model Theme ambiguity.
patch(
    'lib/features/block/rubric_score_card.dart',
    "import '../../domain/models/course_models.dart';\n",
    "import '../../domain/models/course_models.dart' hide Theme;\n",
)

# Runtime package 1.1 is an additive extension of the 1.x DB base schema.
policy = ROOT / 'lib/domain/runtime/runtime_manifest_policy.dart'
policy_text = policy.read_text(encoding='utf-8')
policy_text += """

bool isRuntimeDatabaseSchemaCompatible(
  String databaseSchemaVersion,
  String manifestSchemaVersion,
) {
  final databaseMajor = databaseSchemaVersion.split('.').firstOrNull;
  final manifestMajor = manifestSchemaVersion.split('.').firstOrNull;
  return databaseMajor != null &&
      databaseMajor.isNotEmpty &&
      databaseMajor == manifestMajor;
}
"""
# Avoid relying on collection extensions for firstOrNull and satisfy strict lints.
policy_text = policy_text.replace(
    "  final databaseMajor = databaseSchemaVersion.split('.').firstOrNull;\n  final manifestMajor = manifestSchemaVersion.split('.').firstOrNull;\n  return databaseMajor != null &&\n      databaseMajor.isNotEmpty &&\n      databaseMajor == manifestMajor;\n",
    "  if (databaseSchemaVersion.isEmpty || manifestSchemaVersion.isEmpty) {\n    return false;\n  }\n  final databaseMajor = databaseSchemaVersion.split('.').first;\n  final manifestMajor = manifestSchemaVersion.split('.').first;\n  return databaseMajor == manifestMajor;\n",
)
policy.write_text(policy_text, encoding='utf-8')

patch(
    'lib/data/course/course_database_installer.dart',
    """      if (course.courseId != installed.manifest.courseId ||
          course.schemaVersion != installed.manifest.schemaVersion ||
          course.sourceManifestFingerprint != installed.manifest.canonicalContentFingerprint) {
""",
    """      if (course.courseId != installed.manifest.courseId ||
          !isRuntimeDatabaseSchemaCompatible(
            course.schemaVersion,
            installed.manifest.schemaVersion,
          ) ||
          course.sourceManifestFingerprint != installed.manifest.canonicalContentFingerprint) {
""",
)

patch(
    'tool/runtime_verifier/bin/verify_runtime.dart',
    """    _checkValue(
      course['schema_version'],
      manifestMap['schema_version'],
      'schema sürümü',
    );
""",
    """    _checkSchemaCompatibility(
      course['schema_version'],
      manifestMap['schema_version'],
    );
""",
)
verifier = ROOT / 'tool/runtime_verifier/bin/verify_runtime.dart'
verifier_text = verifier.read_text(encoding='utf-8')
verifier_text += """

void _checkSchemaCompatibility(Object? databaseVersion, Object? manifestVersion) {
  final database = databaseVersion?.toString() ?? '';
  final manifest = manifestVersion?.toString() ?? '';
  if (database.isEmpty || manifest.isEmpty || database.split('.').first != manifest.split('.').first) {
    throw StateError(
      'schema major uyumsuz (manifest: $manifest, database: $database)',
    );
  }
}
"""
verifier.write_text(verifier_text, encoding='utf-8')

# Keep the sync tool clean under strict flutter_lints.
sync = ROOT / 'tool/sync_course_runtime.dart'
text = sync.read_text(encoding='utf-8')
replacements = {
    "    if (!sourceManifest.existsSync()) throw StateError('Runtime manifest bulunamadı: ${sourceManifest.path}');\n": "    if (!sourceManifest.existsSync()) {\n      throw StateError('Runtime manifest bulunamadı: ${sourceManifest.path}');\n    }\n",
    "    if (!sourceDatabase.existsSync()) throw StateError('Runtime SQLite bulunamadı: ${sourceDatabase.path}');\n": "    if (!sourceDatabase.existsSync()) {\n      throw StateError('Runtime SQLite bulunamadı: ${sourceDatabase.path}');\n    }\n",
    "    if (manifestJson is! Map<String, dynamic>) throw StateError('Runtime manifest JSON nesnesi olmalı.');\n": "    if (manifestJson is! Map<String, dynamic>) {\n      throw StateError('Runtime manifest JSON nesnesi olmalı.');\n    }\n",
    "    if (sourceValidationReport.existsSync()) await sourceValidationReport.copy(targetValidationReport.path);\n": "    if (sourceValidationReport.existsSync()) {\n      await sourceValidationReport.copy(targetValidationReport.path);\n    }\n",
    "    if (!await _filesEqual(sourceDatabase, targetDatabase)) throw StateError('Runtime SQLite hedef doğrulaması başarısız.');\n": "    if (!await _filesEqual(sourceDatabase, targetDatabase)) {\n      throw StateError('Runtime SQLite hedef doğrulaması başarısız.');\n    }\n",
    "    if (!await _filesEqual(sourceManifest, targetManifest)) throw StateError('Runtime manifest hedef doğrulaması başarısız.');\n": "    if (!await _filesEqual(sourceManifest, targetManifest)) {\n      throw StateError('Runtime manifest hedef doğrulaması başarısız.');\n    }\n",
}
for old, new in replacements.items():
    if old not in text:
        raise RuntimeError(f'sync patch target missing: {old[:80]!r}')
    text = text.replace(old, new, 1)
sync.write_text(text, encoding='utf-8')

print('MULTICOURSE_TDE10_FIXES: APPLIED')
