import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/repositories/outcome_tracking_repository.dart';

class OutcomeTrackingDatabase {
  OutcomeTrackingDatabase._(this.database);

  static const fileName = 'ogretmen_os_teacher_state.sqlite';
  static const schemaVersion = 5;

  final Database database;

  static Future<OutcomeTrackingDatabase> open({String? pathOverride}) async {
    final path = pathOverride ?? p.join(await getDatabasesPath(), fileName);
    final database = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createOutcomeTracking(db);
        await _createLessonPlanProgress(db);
        await _createInstructionContext(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createLessonPlanProgress(db);
        } else if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE lesson_plan_progress ADD COLUMN payload_sha256 TEXT',
          );
        }
        if (oldVersion < 4) {
          await _createInstructionContext(db);
        } else if (oldVersion < 5) {
          await _migrateScheduleSlotsToAcademicYear(db);
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

  static Future<void> _createInstructionContext(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS school_classes (
        class_id TEXT PRIMARY KEY,
        academic_year TEXT NOT NULL,
        grade INTEGER NOT NULL,
        section TEXT NOT NULL,
        display_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (academic_year, display_name)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_school_classes_year
      ON school_classes (academic_year, grade, display_name)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS teaching_assignments (
        assignment_id TEXT PRIMARY KEY,
        academic_year TEXT NOT NULL,
        course_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (academic_year, course_id, class_id),
        FOREIGN KEY (class_id) REFERENCES school_classes(class_id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_teaching_assignments_scope
      ON teaching_assignments (academic_year, course_id, is_active)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bell_periods (
        period_number INTEGER PRIMARY KEY,
        start_minute INTEGER NOT NULL,
        end_minute INTEGER NOT NULL,
        CHECK (period_number > 0),
        CHECK (start_minute >= 0 AND start_minute < 1440),
        CHECK (end_minute > start_minute AND end_minute <= 1440)
      )
    ''');

    await _createScheduleSlots(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS assignment_progress_cursor (
        assignment_id TEXT PRIMARY KEY,
        mode TEXT NOT NULL,
        planned_ordinal_at_anchor INTEGER NOT NULL,
        actual_ordinal_at_anchor INTEGER NOT NULL,
        anchored_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
          ON DELETE CASCADE,
        CHECK (planned_ordinal_at_anchor >= 0),
        CHECK (actual_ordinal_at_anchor >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS assignment_lesson_progress (
        assignment_id TEXT NOT NULL,
        package_id TEXT NOT NULL,
        package_hour INTEGER NOT NULL,
        payload_sha256 TEXT,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (assignment_id, package_id, package_hour),
        FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
          ON DELETE CASCADE,
        CHECK (package_hour > 0)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_assignment_lesson_progress_scope
      ON assignment_lesson_progress (assignment_id, status, updated_at)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS assignment_outcome_tracking (
        assignment_id TEXT NOT NULL,
        outcome_id TEXT NOT NULL,
        planned_week_number INTEGER NOT NULL,
        status TEXT NOT NULL,
        actual_hours INTEGER,
        teacher_note TEXT,
        completed_at TEXT,
        carried_to_week_number INTEGER,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (assignment_id, outcome_id, planned_week_number),
        FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_assignment_outcome_tracking_scope
      ON assignment_outcome_tracking (
        assignment_id,
        planned_week_number,
        status
      )
    ''');
  }

  static Future<void> _createScheduleSlots(
    DatabaseExecutor db, {
    String tableName = 'lesson_schedule_slots',
  }) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        slot_id TEXT PRIMARY KEY,
        assignment_id TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        weekday INTEGER NOT NULL,
        period_number INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (academic_year, weekday, period_number),
        FOREIGN KEY (assignment_id) REFERENCES teaching_assignments(assignment_id)
          ON DELETE CASCADE,
        FOREIGN KEY (period_number) REFERENCES bell_periods(period_number)
          ON DELETE RESTRICT,
        CHECK (weekday >= 1 AND weekday <= 7)
      )
    ''');
    if (tableName == 'lesson_schedule_slots') {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_lesson_schedule_assignment
        ON lesson_schedule_slots (assignment_id, weekday, period_number)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_lesson_schedule_year
        ON lesson_schedule_slots (academic_year, weekday, period_number)
      ''');
    }
  }

  static Future<void> _migrateScheduleSlotsToAcademicYear(Database db) async {
    await db.transaction((txn) async {
      await _createScheduleSlots(txn, tableName: 'lesson_schedule_slots_v5');
      await txn.execute('''
        INSERT INTO lesson_schedule_slots_v5 (
          slot_id,
          assignment_id,
          academic_year,
          weekday,
          period_number,
          created_at,
          updated_at
        )
        SELECT
          s.slot_id,
          s.assignment_id,
          a.academic_year,
          s.weekday,
          s.period_number,
          s.created_at,
          s.updated_at
        FROM lesson_schedule_slots s
        INNER JOIN teaching_assignments a
          ON a.assignment_id = s.assignment_id
      ''');
      await txn.execute('DROP TABLE lesson_schedule_slots');
      await txn.execute(
        'ALTER TABLE lesson_schedule_slots_v5 RENAME TO lesson_schedule_slots',
      );
      await txn.execute('''
        CREATE INDEX idx_lesson_schedule_assignment
        ON lesson_schedule_slots (assignment_id, weekday, period_number)
      ''');
      await txn.execute('''
        CREATE INDEX idx_lesson_schedule_year
        ON lesson_schedule_slots (academic_year, weekday, period_number)
      ''');
    });
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
