import 'package:sqflite/sqflite.dart';

import '../../domain/models/course_models.dart';
import '../../domain/models/lesson_plan_models.dart';

class LessonPlanDatabaseDataSource {
  const LessonPlanDatabaseDataSource(this._database);

  final Database _database;

  Future<LessonPlanCapability> getCapability(RuntimeManifest manifest) async {
    final tableAvailable = await _hasTable('lesson_plan_packages');
    final manifestCount = manifest.rowCounts['lesson_plan_packages'] ?? 0;
    if (!tableAvailable) {
      return LessonPlanCapability(
        available: false,
        manifestAdvertised: manifestCount > 0,
        tableAvailable: false,
        packageCount: 0,
        instructionHours: 0,
        schemaVersion: null,
        validationStatus: manifest.validationStatus,
        reason: 'LESSON_PLAN_TABLE_MISSING',
      );
    }

    final countRows = await _database.rawQuery('''
      SELECT COUNT(*) AS package_count,
             COALESCE(SUM(lesson_hours), 0) AS instruction_hours,
             MIN(schema_version) AS schema_version
      FROM lesson_plan_packages
    ''');
    final row = countRows.first;
    final packageCount = _int(row['package_count']);
    final instructionHours = _int(row['instruction_hours']);
    final schemaVersion = row['schema_version']?.toString();
    final manifestAdvertised = manifestCount > 0;
    final rowCountMatches = manifestAdvertised && manifestCount == packageCount;
    final available =
        manifest.validationStatus == 'PASS' &&
        packageCount > 0 &&
        rowCountMatches;

    String? reason;
    if (manifest.validationStatus != 'PASS') {
      reason = 'RUNTIME_VALIDATION_NOT_PASS';
    } else if (!manifestAdvertised) {
      reason = 'LESSON_PLAN_NOT_ADVERTISED';
    } else if (manifestCount != packageCount) {
      reason = 'LESSON_PLAN_ROW_COUNT_MISMATCH';
    } else if (packageCount == 0) {
      reason = 'LESSON_PLAN_TABLE_EMPTY';
    }

    return LessonPlanCapability(
      available: available,
      manifestAdvertised: manifestAdvertised,
      tableAvailable: true,
      packageCount: packageCount,
      instructionHours: instructionHours,
      schemaVersion: schemaVersion,
      validationStatus: manifest.validationStatus,
      reason: reason,
    );
  }

  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId) async {
    if (!await _hasTable('lesson_plan_packages')) return const [];
    final rows = await _database.rawQuery(
      '''
      SELECT package_id, course_id, theme_id, block_id, package_no,
             lesson_hours, plan_title, plan_summary, remaining_block_hours,
             schema_version, validation_status, source_path, payload_sha256,
             payload_json
      FROM lesson_plan_packages
      WHERE block_id = ?
      ORDER BY package_no
    ''',
      [blockId],
    );
    return rows.map(LessonPlanPackage.fromRow).toList(growable: false);
  }

  Future<LessonPlanPackage?> getLessonPlan(String packageId) async {
    if (!await _hasTable('lesson_plan_packages')) return null;
    final rows = await _database.rawQuery(
      '''
      SELECT package_id, course_id, theme_id, block_id, package_no,
             lesson_hours, plan_title, plan_summary, remaining_block_hours,
             schema_version, validation_status, source_path, payload_sha256,
             payload_json
      FROM lesson_plan_packages
      WHERE package_id = ?
      LIMIT 1
    ''',
      [packageId],
    );
    return rows.isEmpty ? null : LessonPlanPackage.fromRow(rows.first);
  }

  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) async {
    final orderedIds = await _orderedPackageIds();
    final index = orderedIds.indexOf(packageId);
    if (index <= 0) return null;
    return getLessonPlan(orderedIds[index - 1]);
  }

  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) async {
    final orderedIds = await _orderedPackageIds();
    final index = orderedIds.indexOf(packageId);
    if (index < 0 || index >= orderedIds.length - 1) return null;
    return getLessonPlan(orderedIds[index + 1]);
  }

  Future<List<String>> _orderedPackageIds() async {
    if (!await _hasTable('lesson_plan_packages')) return const [];
    final rows = await _database.rawQuery('''
      SELECT lp.package_id
      FROM lesson_plan_packages lp
      INNER JOIN blocks b ON b.block_id = lp.block_id
      INNER JOIN themes t ON t.theme_id = lp.theme_id
      ORDER BY t.theme_order, b.block_order, lp.package_no
    ''');
    return rows
        .map((row) => row['package_id']?.toString())
        .whereType<String>()
        .toList(growable: false);
  }

  Future<bool> _hasTable(String table) async {
    final rows = await _database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
