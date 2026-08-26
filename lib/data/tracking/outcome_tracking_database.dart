import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/repositories/outcome_tracking_repository.dart';

class OutcomeTrackingDatabase {
  OutcomeTrackingDatabase._(this.database);

  static const fileName = 'ogretmen_os_teacher_state.sqlite';
  static const schemaVersion = 3;

  final Database database;

  static Future<OutcomeTrackingDatabase> open({String? pathOverride}) async {
    final path = pathOverride ?? p.join(await getDatabasesPath(), fileName);
    final database = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await _createOutcomeTracking(db);
        await _createLessonPlanProgress(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createLessonPlanProgress(db);
        } else if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE lesson_plan_progress ADD COLUMN payload_sha256 TEXT',
          );
        }
      },
    );
    return OutcomeTrackingDatabase._(database);
  }

  static Future<void> _createOutcomeTracking(Database db) async {
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
  }

  static Future<void> _createLessonPlanProgress(Database db) async {
    await db.execute('''
      CREATE TABLE lesson_plan_progress (
        course_id TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        package_id TEXT NOT NULL,
        payload_sha256 TEXT,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (course_id, academic_year, package_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_lesson_plan_progress_scope
      ON lesson_plan_progress (course_id, academic_year, status)
    ''');
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
    return rows.map(_outcomeFromRow).toList(growable: false);
  }

  @override
  Future<void> save(LearningOutcomeTrackingRecord record) async {
    await _database.insert(
      'outcome_tracking',
      _outcomeToRow(record),
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

  LearningOutcomeTrackingRecord _outcomeFromRow(Map<String, Object?> row) =>
      LearningOutcomeTrackingRecord(
        academicYear: row['academic_year']! as String,
        outcomeId: row['outcome_id']! as String,
        plannedWeekNumber: row['planned_week_number']! as int,
        status: OutcomeTrackingStatus.fromStorage(row['status']! as String),
        actualHours: row['actual_hours'] as int?,
        teacherNote: row['teacher_note'] as String?,
        completedAt: _parseDate(row['completed_at']),
        carriedToWeekNumber: row['carried_to_week_number'] as int?,
        updatedAt: DateTime.parse(row['updated_at']! as String).toLocal(),
      );

  Map<String, Object?> _outcomeToRow(LearningOutcomeTrackingRecord record) => {
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
}

class SqfliteLessonPlanProgressRepository
    implements LessonPlanProgressRepository {
  const SqfliteLessonPlanProgressRepository(this._database);

  final Database _database;

  @override
  Future<List<LessonPlanProgressRecord>> getForCourseAcademicYear({
    required String courseId,
    required String academicYear,
  }) async {
    final rows = await _database.query(
      'lesson_plan_progress',
      where: 'course_id = ? AND academic_year = ?',
      whereArgs: [courseId, academicYear],
      orderBy: 'updated_at ASC, package_id ASC',
    );
    return rows.map(_progressFromRow).toList(growable: false);
  }

  @override
  Future<LessonPlanProgressRecord?> get({
    required String courseId,
    required String academicYear,
    required String packageId,
  }) async {
    final rows = await _database.query(
      'lesson_plan_progress',
      where: 'course_id = ? AND academic_year = ? AND package_id = ?',
      whereArgs: [courseId, academicYear, packageId],
      limit: 1,
    );
    return rows.isEmpty ? null : _progressFromRow(rows.first);
  }

  @override
  Future<void> save(LessonPlanProgressRecord record) async {
    await _database.insert(
      'lesson_plan_progress',
      _progressToRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete({
    required String courseId,
    required String academicYear,
    required String packageId,
  }) async {
    await _database.delete(
      'lesson_plan_progress',
      where: 'course_id = ? AND academic_year = ? AND package_id = ?',
      whereArgs: [courseId, academicYear, packageId],
    );
  }

  LessonPlanProgressRecord _progressFromRow(Map<String, Object?> row) =>
      LessonPlanProgressRecord(
        courseId: row['course_id']! as String,
        academicYear: row['academic_year']! as String,
        packageId: row['package_id']! as String,
        payloadSha256: _cleanText(row['payload_sha256'] as String?),
        status: LessonPlanProgressStatus.fromStorage(row['status']! as String),
        startedAt: _parseDate(row['started_at']),
        completedAt: _parseDate(row['completed_at']),
        updatedAt: DateTime.parse(row['updated_at']! as String).toLocal(),
      );

  Map<String, Object?> _progressToRow(LessonPlanProgressRecord record) => {
    'course_id': record.courseId,
    'academic_year': record.academicYear,
    'package_id': record.packageId,
    'payload_sha256': _cleanText(record.payloadSha256),
    'status': record.status.storageValue,
    'started_at': record.startedAt?.toUtc().toIso8601String(),
    'completed_at': record.completedAt?.toUtc().toIso8601String(),
    'updated_at': record.updatedAt.toUtc().toIso8601String(),
  };
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String? _cleanText(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
