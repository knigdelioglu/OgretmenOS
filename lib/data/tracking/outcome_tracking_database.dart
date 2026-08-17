import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/outcome_tracking_repository.dart';

class OutcomeTrackingDatabase {
  OutcomeTrackingDatabase._(this.database);

  static const fileName = 'ogretmen_os_teacher_state.sqlite';
  static const schemaVersion = 1;

  final Database database;

  static Future<OutcomeTrackingDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, fileName),
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE outcome_tracking (
            academic_year TEXT NOT NULL,
            outcome_id TEXT NOT NULL,
            planned_week_number INTEGER NOT NULL,
            status TEXT NOT NULL,
            actual_hours INTEGER,
            teacher_note TEXT,
            completed_at TEXT,
            carried_to_week_number INTEGER,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (academic_year, outcome_id, planned_week_number)
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_outcome_tracking_carry
          ON outcome_tracking (academic_year, carried_to_week_number)
        ''');
      },
    );
    return OutcomeTrackingDatabase._(database);
  }

  Future<void> close() => database.close();
}

class SqfliteOutcomeTrackingRepository implements OutcomeTrackingRepository {
  const SqfliteOutcomeTrackingRepository(this._database);

  final Database _database;

  @override
  Future<List<LearningOutcomeTrackingRecord>> getForAcademicYear(
    String academicYear,
  ) async {
    final rows = await _database.query(
      'outcome_tracking',
      where: 'academic_year = ?',
      whereArgs: [academicYear],
      orderBy: 'planned_week_number ASC, outcome_id ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> save(LearningOutcomeTrackingRecord record) async {
    await _database.insert(
      'outcome_tracking',
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete({
    required String academicYear,
    required String outcomeId,
    required int plannedWeekNumber,
  }) async {
    await _database.delete(
      'outcome_tracking',
      where:
          'academic_year = ? AND outcome_id = ? AND planned_week_number = ?',
      whereArgs: [academicYear, outcomeId, plannedWeekNumber],
    );
  }

  LearningOutcomeTrackingRecord _fromRow(Map<String, Object?> row) =>
      LearningOutcomeTrackingRecord(
        academicYear: row['academic_year']! as String,
        outcomeId: row['outcome_id']! as String,
        plannedWeekNumber: row['planned_week_number']! as int,
        status: OutcomeTrackingStatus.fromStorage(row['status']! as String),
        actualHours: row['actual_hours'] as int?,
        teacherNote: row['teacher_note'] as String?,
        completedAt: _parseDate(row['completed_at']),
        carriedToWeekNumber: row['carried_to_week_number'] as int?,
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );

  Map<String, Object?> _toRow(LearningOutcomeTrackingRecord record) => {
    'academic_year': record.academicYear,
    'outcome_id': record.outcomeId,
    'planned_week_number': record.plannedWeekNumber,
    'status': record.status.storageValue,
    'actual_hours': record.actualHours,
    'teacher_note': _cleanText(record.teacherNote),
    'completed_at': record.completedAt?.toUtc().toIso8601String(),
    'carried_to_week_number': record.carriedToWeekNumber,
    'updated_at': record.updatedAt.toUtc().toIso8601String(),
  };

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String? _cleanText(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
