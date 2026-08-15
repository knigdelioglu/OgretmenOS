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
  _check(
    manifestMap['runtime_status'] == 'RUNTIME_FRESH',
    'runtime_status RUNTIME_FRESH değil',
  );
  _check(
    (manifestMap['canonical_content_fingerprint']?.toString().trim() ?? '')
        .isNotEmpty,
    'canonical_content_fingerprint eksik',
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
    _checkValue(
      course['course_id'],
      manifestMap['course_id'],
      'course kimliği',
    );
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
    for (var index = 0; index < sequence.length; index++) {
      _checkValue(sequence[index]['block_order'], index % 4 + 1, 'blok sırası');
      if (index > 0) {
        _checkValue(
          sequence[index - 1]['block_id'] == sequence[index]['block_id'],
          false,
          'timeline blokları tekrar ediyor',
        );
      }
    }

    final tema2Blocks = database.select('''
      SELECT b.block_id
      FROM blocks b
      WHERE b.theme_id = 'TEMA_02'
        AND EXISTS (
          SELECT 1
          FROM block_activities ba
          INNER JOIN activity_forms af ON af.activity_id = ba.activity_id
          WHERE ba.block_id = b.block_id
        )
      ORDER BY block_order
    ''');
    _check(tema2Blocks.isNotEmpty, 'TEMA_02 blokları yok');
    final blockId = tema2Blocks.first['block_id'];
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
      'TEMA_02 outcome ilişkisi yok',
    );
    _check(activityIds.isNotEmpty, 'TEMA_02 etkinlik ilişkisi yok');
    _check(
      database
          .select(
            '''
        SELECT section_id
        FROM textbook_sections
        WHERE theme_id = 'TEMA_02'
          AND section_id IN (
            SELECT section_id
            FROM activities
            WHERE activity_id IN (
              SELECT activity_id FROM block_activities WHERE block_id = ?
            )
          )
      ''',
            [blockId],
          )
          .isNotEmpty,
      'TEMA_02 kitap bölümü yok',
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
      'TEMA_02 form ilişkisi yok',
    );
    _check(
      database.select(
        'SELECT resource_plan_id FROM resource_decisions WHERE theme_id = ?',
        ['TEMA_02'],
      ).isNotEmpty,
      'TEMA_02 kaynak kararı yok',
    );
    _check(
      database.select(
        'SELECT artifact_id FROM assessment_task_bindings WHERE theme_id = ?',
        ['TEMA_02'],
      ).isNotEmpty,
      'TEMA_02 ölçme bağlama yok',
    );
    _check(
      database.select('''
        SELECT sr.source_id
        FROM source_references sr
        INNER JOIN entity_source_references esr ON esr.source_id = sr.source_id
        WHERE esr.entity_type = 'theme' AND esr.entity_id = 'TEMA_02'
      ''').isNotEmpty,
      'TEMA_02 kaynak referansı yok',
    );

    _checkValue(
      _countWhere(database, 'blocks', 'theme_id = ?', ['TEMA_02']),
      4,
      'TEMA_02 paket blok sayısı',
    );
    _check(
      _countWhere(database, 'activities', 'theme_id = ?', ['TEMA_02']) > 0,
      'öğretmen paketi etkinliksiz',
    );
  } finally {
    database.close();
  }

  stdout.writeln('RUNTIME_VERIFIER: PASS');
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
