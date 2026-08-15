import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

Future<void> main() async {
  final projectRoot = File.fromUri(Platform.script).parent.parent.parent.parent;
  final runtimeDirectory = p.join(
    projectRoot.path,
    'assets',
    'courses',
    'TDE_9',
  );
  final manifestFile = File(p.join(runtimeDirectory, 'runtime_manifest.json'));
  final databaseFile = File(p.join(runtimeDirectory, 'course_runtime.sqlite'));
  final validationReportFile = File(
    p.join(runtimeDirectory, 'runtime_validation_report.md'),
  );
  _check(manifestFile.existsSync(), 'runtime manifest bulunamadı');
  _check(databaseFile.existsSync(), 'runtime SQLite bulunamadı');

  final manifest = jsonDecode(await manifestFile.readAsString());
  _check(manifest is Map<String, dynamic>, 'runtime manifest JSON geçersiz');
  final manifestMap = manifest as Map<String, dynamic>;
  _check(manifestMap['course_id'] == 'TDE_9', 'course_id TDE_9 değil');
  _check(
    (manifestMap['schema_version'] as String).startsWith('1.'),
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
    _checkValue(course['course_id'], manifestMap['course_id'], 'course kimliği');
    _checkValue(
      course['schema_version'],
      manifestMap['schema_version'],
      'schema sürümü',
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
      SELECT tb.block_id, tb.theme_id, tb.block_order,
             t.theme_order, b.title
      FROM timeline_blocks tb
      INNER JOIN themes t ON t.theme_id = tb.theme_id
      INNER JOIN blocks b ON b.block_id = tb.block_id
      ORDER BY t.theme_order, tb.block_order
    ''');
    final expectedTimeline = (counts['timeline_blocks'] as num).toInt();
    _checkValue(sequence.length, expectedTimeline, 'timeline sırası');

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
      _checkValue(
        row['block_order'],
        expectedBlockOrder,
        '$themeId blok sırası',
      );
      _check(
        seenBlockIds.add(row['block_id']),
        'timeline blokları tekrar ediyor',
      );
    }

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
          SELECT 1
          FROM textbook_sections ts
          WHERE ts.theme_id = b.theme_id
            AND ts.section_id IN (
              SELECT a.section_id
              FROM activities a
              INNER JOIN block_activities ba ON ba.activity_id = a.activity_id
              WHERE ba.block_id = b.block_id
                AND a.section_id IS NOT NULL
            )
        )
        AND EXISTS (
          SELECT 1 FROM resource_decisions rd WHERE rd.theme_id = b.theme_id
        )
        AND EXISTS (
          SELECT 1
          FROM assessment_task_bindings atb
          WHERE atb.theme_id = b.theme_id
        )
        AND EXISTS (
          SELECT 1
          FROM entity_source_references esr
          WHERE esr.entity_type = 'theme' AND esr.entity_id = b.theme_id
        )
      ORDER BY b.theme_id, b.block_order
      LIMIT 1
    ''');
    _check(
      verificationCandidates.isNotEmpty,
      'runtime ilişki doğrulaması için uygun theme/block bulunamadı',
    );

    final verificationThemeId =
        verificationCandidates.first['theme_id'] as String;
    final blockId = verificationCandidates.first['block_id'] as String;

    final activityIds = database.select(
      '''
      SELECT a.activity_id, a.section_id
      FROM activities a
      INNER JOIN block_activities ba ON ba.activity_id = a.activity_id
      WHERE ba.block_id = ?
      ORDER BY a.activity_id
    ''',
      [blockId],
    );
    _check(
      database.select(
        'SELECT outcome_id FROM block_outcomes WHERE block_id = ?',
        [blockId],
      ).isNotEmpty,
      'blok outcome ilişkisi yok',
    );
    _check(activityIds.isNotEmpty, 'blok etkinlik ilişkisi yok');
    _check(
      database
          .select(
            '''
        SELECT section_id
        FROM textbook_sections
        WHERE theme_id = ?
          AND section_id IN (
            SELECT section_id
            FROM activities
            WHERE activity_id IN (
              SELECT activity_id FROM block_activities WHERE block_id = ?
            )
          )
      ''',
            [verificationThemeId, blockId],
          )
          .isNotEmpty,
      'blok kitap bölümü yok',
    );
    _check(
      database
          .select(
            '''
        SELECT DISTINCT f.form_id
        FROM forms f
        INNER JOIN activity_forms af ON af.form_id = f.form_id
        WHERE af.activity_id IN (
          SELECT activity_id FROM block_activities WHERE block_id = ?
        )
      ''',
            [blockId],
          )
          .isNotEmpty,
      'blok form ilişkisi yok',
    );
    _check(
      database.select(
        'SELECT resource_plan_id FROM resource_decisions WHERE theme_id = ?',
        [verificationThemeId],
      ).isNotEmpty,
      'theme kaynak kararı yok',
    );
    _check(
      database.select(
        'SELECT artifact_id FROM assessment_task_bindings WHERE theme_id = ?',
        [verificationThemeId],
      ).isNotEmpty,
      'theme ölçme bağlama yok',
    );
    _check(
      database.select(
        '''
        SELECT sr.source_id
        FROM source_references sr
        INNER JOIN entity_source_references esr ON esr.source_id = sr.source_id
        WHERE esr.entity_type = 'theme' AND esr.entity_id = ?
      ''',
        [verificationThemeId],
      ).isNotEmpty,
      'theme kaynak referansı yok',
    );

    final themeBlockCount = _countWhere(
      database,
      'blocks',
      'theme_id = ?',
      [verificationThemeId],
    );
    final timelineBlockCount = _countWhere(
      database,
      'timeline_blocks',
      'theme_id = ?',
      [verificationThemeId],
    );
    _check(themeBlockCount > 0, 'theme paket blokları yok');
    _checkValue(
      themeBlockCount,
      timelineBlockCount,
      'theme block/timeline blok sayısı',
    );
    _check(
      _countWhere(database, 'activities', 'theme_id = ?', [verificationThemeId]) >
          0,
      'öğretmen paketi etkinliksiz',
    );
  } finally {
    database.close();
  }

  stdout.writeln('RUNTIME_VERIFIER: PASS');
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
      if (normalized.contains('PASS') &&
          normalized.contains('RUNTIME_FRESH')) {
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
