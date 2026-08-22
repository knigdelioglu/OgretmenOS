import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  final courseId = _valueFor(args, '--course') ?? 'TDE_9';
  final subjectId = _valueFor(args, '--subject') ?? 'turk-dili-ve-edebiyati';
  final projectRoot = File.fromUri(Platform.script).parent.parent.parent.parent;
  final packageDirectory = p.join(
    projectRoot.path,
    'tymm-verileri',
    subjectId,
    courseId,
  );
  final packageManifestFile = File(
    p.join(packageDirectory, 'package_manifest.json'),
  );
  final runtimeDirectory = p.join(packageDirectory, 'runtime');
  final manifestFile = File(p.join(runtimeDirectory, 'runtime_manifest.json'));
  final databaseFile = File(p.join(runtimeDirectory, 'course_runtime.sqlite'));
  final validationReportFile = File(
    p.join(runtimeDirectory, 'runtime_validation_report.md'),
  );

  _check(packageManifestFile.existsSync(), 'package manifest bulunamadı');
  _check(manifestFile.existsSync(), 'runtime manifest bulunamadı');
  _check(databaseFile.existsSync(), 'runtime SQLite bulunamadı');

  final packageManifest = _decodeMap(await packageManifestFile.readAsString());
  final dataMode = packageManifest['data_mode']?.toString() ?? '';
  _check(
    dataMode == 'FULL_RUNTIME' || dataMode == 'CURRICULUM_ONLY',
    'bilinmeyen data_mode: $dataMode',
  );
  _check(packageManifest['course_id'] == courseId, 'package course_id uyuşmuyor');

  final manifestMap = _decodeMap(await manifestFile.readAsString());
  _check(manifestMap['course_id'] == courseId, 'course_id $courseId değil');
  _check(
    (manifestMap['schema_version']?.toString() ?? '').startsWith('1.'),
    'schema sürümü 1.x değil',
  );
  _check(
    manifestMap['validation_status'] == 'PASS',
    'validation_status PASS değil',
  );
  _checkFreshnessEvidence(
    manifestMap,
    validationReportFile.existsSync()
        ? await validationReportFile.readAsString()
        : null,
  );
  _check(
    (manifestMap['canonical_content_fingerprint']?.toString().trim() ?? '')
        .isNotEmpty,
    'canonical_content_fingerprint eksik',
  );
  _check(
    manifestMap['runtime_database_path'] == 'runtime/course_runtime.sqlite',
    'runtime_database_path beklenen değer değil',
  );
  final rawCounts = manifestMap['row_counts'];
  _check(rawCounts is Map, 'runtime manifest row_counts eksik');
  final counts = rawCounts as Map;

  final database = sqlite3.open(
    databaseFile.absolute.path,
    mode: OpenMode.readOnly,
  );
  try {
    final course = database.select('''
      SELECT course_id, schema_version, source_manifest_fingerprint
      FROM courses
      LIMIT 1
    ''').single;
    _checkValue(course['course_id'], courseId, 'course kimliği');
    _checkSchemaCompatibility(
      course['schema_version'],
      manifestMap['schema_version'],
    );
    _checkValue(
      course['source_manifest_fingerprint'],
      manifestMap['canonical_content_fingerprint'],
      'canonical fingerprint',
    );

    for (final entry in counts.entries) {
      final table = entry.key.toString();
      final expected = (entry.value as num).toInt();
      final actual = _count(database, table);
      _checkValue(actual, expected, '$table satır sayısı');
    }

    final sequence = database.select('''
      SELECT tb.block_id, tb.theme_id, tb.block_order, t.theme_order
      FROM timeline_blocks tb
      INNER JOIN themes t ON t.theme_id = tb.theme_id
      INNER JOIN blocks b ON b.block_id = tb.block_id
      ORDER BY t.theme_order, tb.block_order
    ''');
    _checkValue(
      sequence.length,
      (counts['timeline_blocks'] as num).toInt(),
      'timeline sırası',
    );
    _verifySequence(sequence);

    if (dataMode == 'CURRICULUM_ONLY') {
      _verifyCurriculumOnly(database, counts, packageManifest, manifestMap);
    } else {
      _verifyFullRuntime(database);
    }
  } finally {
    database.close();
  }

  stdout.writeln('RUNTIME_VERIFIER: PASS');
  stdout.writeln('COURSE_ID: $courseId');
  stdout.writeln('DATA_MODE: $dataMode');
}

void _verifyCurriculumOnly(
  Database database,
  Map counts,
  Map<String, dynamic> packageManifest,
  Map<String, dynamic> manifest,
) {
  _check(
    packageManifest['textbook_status'] == 'AWAITING_OFFICIAL_TEXTBOOK',
    'curriculum-only pakette textbook_status yanlış',
  );
  _check(
    manifest['data_mode'] == 'CURRICULUM_ONLY',
    'runtime manifest curriculum-only değil',
  );
  _checkValue(_count(database, 'themes'), 4, 'curriculum-only tema sayısı');
  _checkValue(_count(database, 'blocks'), 16, 'curriculum-only blok sayısı');
  _checkValue(_count(database, 'outcomes'), 64, 'curriculum-only kazanım sayısı');
  _checkValue(
    _count(database, 'block_outcomes'),
    64,
    'curriculum-only blok-kazanım bağı',
  );
  _checkValue(
    _count(database, 'timeline_themes'),
    4,
    'curriculum-only tema timeline',
  );
  _checkValue(
    _count(database, 'timeline_blocks'),
    16,
    'curriculum-only blok timeline',
  );
  _check(
    _count(database, 'entity_source_references') >= 4,
    'curriculum-only tema kaynak bağları eksik',
  );
  for (final table in [
    'textbook_sections',
    'activities',
    'block_activities',
    'forms',
    'activity_forms',
    'resource_decisions',
    'assessment_artifacts',
    'assessment_gap_mappings',
    'assessment_task_bindings',
  ]) {
    _checkValue(_count(database, table), 0, '$table curriculum-only pakette boş olmalı');
  }

  final blocksWithoutOutcome = database.select('''
    SELECT b.block_id
    FROM blocks b
    LEFT JOIN block_outcomes bo ON bo.block_id = b.block_id
    GROUP BY b.block_id
    HAVING COUNT(bo.outcome_id) = 0
  ''');
  _check(blocksWithoutOutcome.isEmpty, 'kazanımsız curriculum-only blok var');

  final skillDomains = database
      .select('SELECT DISTINCT skill_domain FROM blocks ORDER BY skill_domain')
      .map((row) => row['skill_domain'])
      .toSet();
  _check(
    skillDomains.containsAll({'Dinleme/İzleme', 'Okuma', 'Konuşma', 'Yazma'}),
    'dört beceri alanı planlama bloklarında yok',
  );

  final declaredCounts = <String, int>{
    for (final entry in counts.entries)
      entry.key.toString(): (entry.value as num).toInt(),
  };
  _checkValue(declaredCounts['themes'], 4, 'manifest tema sayısı');
  _checkValue(declaredCounts['outcomes'], 64, 'manifest kazanım sayısı');
}

void _verifyFullRuntime(Database database) {
  final verificationCandidates = database.select('''
    SELECT b.theme_id, b.block_id
    FROM blocks b
    WHERE EXISTS (
      SELECT 1 FROM block_outcomes bo WHERE bo.block_id = b.block_id
    )
      AND EXISTS (
        SELECT 1
        FROM block_activities ba
        INNER JOIN activity_forms af ON af.activity_id = ba.activity_id
        WHERE ba.block_id = b.block_id
      )
      AND EXISTS (
        SELECT 1 FROM textbook_sections ts
        WHERE ts.theme_id = b.theme_id
      )
      AND EXISTS (
        SELECT 1 FROM resource_decisions rd WHERE rd.theme_id = b.theme_id
      )
      AND EXISTS (
        SELECT 1 FROM assessment_task_bindings atb WHERE atb.theme_id = b.theme_id
      )
      AND EXISTS (
        SELECT 1 FROM entity_source_references esr
        WHERE esr.entity_type = 'theme' AND esr.entity_id = b.theme_id
      )
    ORDER BY b.theme_id, b.block_order
    LIMIT 1
  ''');
  _check(
    verificationCandidates.isNotEmpty,
    'full runtime ilişki doğrulaması için uygun theme/block bulunamadı',
  );
  final themeId = verificationCandidates.first['theme_id'] as String;
  final blockId = verificationCandidates.first['block_id'] as String;
  _check(
    _countWhere(database, 'block_outcomes', 'block_id = ?', [blockId]) > 0,
    'blok outcome ilişkisi yok',
  );
  _check(
    _countWhere(database, 'block_activities', 'block_id = ?', [blockId]) > 0,
    'blok etkinlik ilişkisi yok',
  );
  _check(
    _countWhere(database, 'textbook_sections', 'theme_id = ?', [themeId]) > 0,
    'theme kitap bölümü yok',
  );
  _check(
    _countWhere(database, 'resource_decisions', 'theme_id = ?', [themeId]) > 0,
    'theme kaynak kararı yok',
  );
  _check(
    _countWhere(database, 'assessment_task_bindings', 'theme_id = ?', [themeId]) > 0,
    'theme ölçme bağlama yok',
  );
}

void _verifySequence(ResultSet sequence) {
  final seenBlockIds = <Object?>{};
  String? currentThemeId;
  var expectedBlockOrder = 0;
  for (final row in sequence) {
    final themeId = row['theme_id'] as String;
    if (themeId != currentThemeId) {
      currentThemeId = themeId;
      expectedBlockOrder = 1;
    } else {
      expectedBlockOrder++;
    }
    _checkValue(row['block_order'], expectedBlockOrder, '$themeId blok sırası');
    _check(seenBlockIds.add(row['block_id']), 'timeline blokları tekrar ediyor');
  }
}

Map<String, dynamic> _decodeMap(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) throw StateError('JSON nesnesi bekleniyordu');
  return Map<String, dynamic>.from(decoded);
}

void _checkFreshnessEvidence(
  Map<String, dynamic> manifest,
  String? validationReport,
) {
  final manifestStatus = manifest['runtime_status']?.toString().trim();
  if (manifestStatus != null && manifestStatus.isNotEmpty) {
    if (manifestStatus == 'RUNTIME_FRESH') return;
    throw StateError('runtime_status fresh değil: $manifestStatus');
  }
  if (validationReport != null) {
    for (final line in validationReport.split('\n')) {
      if (!line.toLowerCase().contains('source fingerprint status')) continue;
      final normalized = line.toUpperCase();
      if (normalized.contains('PASS') && normalized.contains('RUNTIME_FRESH')) {
        return;
      }
    }
  }
  throw StateError('runtime freshness kanıtı bulunamadı');
}

int _count(Database database, String table) {
  final rows = database.select('SELECT COUNT(*) AS count FROM $table');
  return rows.single['count'] as int;
}

int _countWhere(
  Database database,
  String table,
  String where,
  List<Object?> parameters,
) {
  final rows = database.select(
    'SELECT COUNT(*) AS count FROM $table WHERE $where',
    parameters,
  );
  return rows.single['count'] as int;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _checkValue(Object? actual, Object? expected, String message) {
  if (actual != expected) {
    throw StateError('$message (beklenen: $expected, gerçek: $actual)');
  }
}

String? _valueFor(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

void _checkSchemaCompatibility(Object? databaseVersion, Object? manifestVersion) {
  final database = databaseVersion?.toString() ?? '';
  final manifest = manifestVersion?.toString() ?? '';
  if (database.isEmpty ||
      manifest.isEmpty ||
      database.split('.').first != manifest.split('.').first) {
    throw StateError(
      'schema major uyumsuz (manifest: $manifest, database: $database)',
    );
  }
}
