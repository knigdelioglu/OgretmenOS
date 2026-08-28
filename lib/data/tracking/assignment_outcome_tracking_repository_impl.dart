import 'package:sqflite/sqflite.dart';

import '../../domain/models/assignment_outcome_tracking_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/assignment_outcome_tracking_repository.dart';

class SqfliteAssignmentOutcomeTrackingRepository
    implements AssignmentOutcomeTrackingRepository {
  const SqfliteAssignmentOutcomeTrackingRepository(this._database);

  final Database _database;

  @override
  Future<List<AssignmentOutcomeTrackingRecord>> getForAssignment(
    String assignmentId,
  ) async {
    final rows = await _database.query(
      'assignment_outcome_tracking',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      orderBy: 'planned_week_number ASC, outcome_id ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<AssignmentOutcomeTrackingRecord?> get({
    required String assignmentId,
    required String outcomeId,
    required int plannedWeekNumber,
  }) async {
    final rows = await _database.query(
      'assignment_outcome_tracking',
      where:
          'assignment_id = ? AND outcome_id = ? AND planned_week_number = ?',
      whereArgs: [assignmentId, outcomeId, plannedWeekNumber],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> save(AssignmentOutcomeTrackingRecord record) async {
    await _database.insert(
      'assignment_outcome_tracking',
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete({
    required String assignmentId,
    required String outcomeId,
    required int plannedWeekNumber,
  }) async {
    await _database.delete(
      'assignment_outcome_tracking',
      where:
          'assignment_id = ? AND outcome_id = ? AND planned_week_number = ?',
      whereArgs: [assignmentId, outcomeId, plannedWeekNumber],
    );
  }

  AssignmentOutcomeTrackingRecord _fromRow(Map<String, Object?> row) =>
      AssignmentOutcomeTrackingRecord(
        assignmentId: row['assignment_id']! as String,
        outcomeId: row['outcome_id']! as String,
        plannedWeekNumber: row['planned_week_number']! as int,
        status: OutcomeTrackingStatus.fromStorage(row['status']! as String),
        actualHours: row['actual_hours'] as int?,
        teacherNote: _clean(row['teacher_note'] as String?),
        completedAt: _date(row['completed_at']),
        carriedToWeekNumber: row['carried_to_week_number'] as int?,
        updatedAt: DateTime.parse(row['updated_at']! as String).toLocal(),
      );

  Map<String, Object?> _toRow(AssignmentOutcomeTrackingRecord record) => {
    'assignment_id': record.assignmentId,
    'outcome_id': record.outcomeId,
    'planned_week_number': record.plannedWeekNumber,
    'status': record.status.storageValue,
    'actual_hours': record.actualHours,
    'teacher_note': _clean(record.teacherNote),
    'completed_at': record.completedAt?.toUtc().toIso8601String(),
    'carried_to_week_number': record.carriedToWeekNumber,
    'updated_at': record.updatedAt.toUtc().toIso8601String(),
  };

  DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
