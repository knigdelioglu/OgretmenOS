import 'package:sqflite/sqflite.dart';

import '../../domain/models/assignment_lesson_progress_models.dart';
import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/repositories/assignment_lesson_progress_repository.dart';

class SqfliteAssignmentLessonProgressRepository
    implements AssignmentLessonProgressRepository {
  const SqfliteAssignmentLessonProgressRepository(this._database);

  final Database _database;

  @override
  Future<List<AssignmentLessonProgressRecord>> getForAssignment(
    String assignmentId,
  ) async {
    final rows = await _database.query(
      'assignment_lesson_progress',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      orderBy: 'updated_at ASC, package_id ASC, package_hour ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<AssignmentLessonProgressRecord?> get({
    required String assignmentId,
    required String packageId,
    required int packageHour,
  }) async {
    final rows = await _database.query(
      'assignment_lesson_progress',
      where:
          'assignment_id = ? AND package_id = ? AND package_hour = ?',
      whereArgs: [assignmentId, packageId, packageHour],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> save(AssignmentLessonProgressRecord record) async {
    await _database.insert(
      'assignment_lesson_progress',
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete({
    required String assignmentId,
    required String packageId,
    required int packageHour,
  }) async {
    await _database.delete(
      'assignment_lesson_progress',
      where:
          'assignment_id = ? AND package_id = ? AND package_hour = ?',
      whereArgs: [assignmentId, packageId, packageHour],
    );
  }

  AssignmentLessonProgressRecord _fromRow(Map<String, Object?> row) =>
      AssignmentLessonProgressRecord(
        assignmentId: row['assignment_id']! as String,
        packageId: row['package_id']! as String,
        packageHour: row['package_hour']! as int,
        payloadSha256: _clean(row['payload_sha256'] as String?),
        status: LessonPlanProgressStatus.fromStorage(row['status']! as String),
        startedAt: _date(row['started_at']),
        completedAt: _date(row['completed_at']),
        updatedAt: DateTime.parse(row['updated_at']! as String).toLocal(),
      );

  Map<String, Object?> _toRow(AssignmentLessonProgressRecord record) => {
    'assignment_id': record.assignmentId,
    'package_id': record.packageId,
    'package_hour': record.packageHour,
    'payload_sha256': _clean(record.payloadSha256),
    'status': record.status.storageValue,
    'started_at': record.startedAt?.toUtc().toIso8601String(),
    'completed_at': record.completedAt?.toUtc().toIso8601String(),
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
