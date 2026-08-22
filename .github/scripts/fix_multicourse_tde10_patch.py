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
