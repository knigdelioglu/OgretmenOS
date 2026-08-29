import 'package:sqflite/sqflite.dart';

import '../../domain/models/instruction_context_models.dart';
import '../../domain/repositories/instruction_context_repository.dart';

class SqfliteInstructionContextRepository
    implements InstructionContextRepository {
  const SqfliteInstructionContextRepository(this._database);

  final Database _database;

  @override
  Future<List<SchoolClass>> getClasses(String academicYear) async {
    final rows = await _database.query(
      'school_classes',
      where: 'academic_year = ?',
      whereArgs: [academicYear],
      orderBy: 'grade ASC, display_name ASC',
    );
    return rows.map(_classFromRow).toList(growable: false);
  }

  @override
  Future<SchoolClass?> getClass(String classId) async {
    final rows = await _database.query(
      'school_classes',
      where: 'class_id = ?',
      whereArgs: [classId],
      limit: 1,
    );
    return rows.isEmpty ? null : _classFromRow(rows.first);
  }

  @override
  Future<void> saveClass(SchoolClass schoolClass) async {
    final values = _classToRow(schoolClass);
    final updated = await _database.update(
      'school_classes',
      values,
      where: 'class_id = ?',
      whereArgs: [schoolClass.id],
    );
    if (updated == 0) {
      await _database.insert(
        'school_classes',
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  @override
  Future<void> deleteClass(String classId) async {
    await _database.delete(
      'school_classes',
      where: 'class_id = ?',
      whereArgs: [classId],
    );
  }

  @override
  Future<List<TeachingAssignment>> getAssignments({
    required String academicYear,
    String? courseId,
    bool activeOnly = true,
  }) async {
    final clauses = <String>['academic_year = ?'];
    final args = <Object?>[academicYear];
    if (courseId != null) {
      clauses.add('course_id = ?');
      args.add(courseId);
    }
    if (activeOnly) {
      clauses.add('is_active = 1');
    }
    final rows = await _database.query(
      'teaching_assignments',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'course_id ASC, class_id ASC',
    );
    return rows.map(_assignmentFromRow).toList(growable: false);
  }

  @override
  Future<TeachingAssignment?> getAssignment(String assignmentId) async {
    final rows = await _database.query(
      'teaching_assignments',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      limit: 1,
    );
    return rows.isEmpty ? null : _assignmentFromRow(rows.first);
  }

  @override
  Future<void> saveAssignment(TeachingAssignment assignment) async {
    final schoolClass = await getClass(assignment.classId);
    if (schoolClass == null) {
      throw StateError('Ders atamasının sınıfı bulunamadı.');
    }
    if (schoolClass.academicYear != assignment.academicYear) {
      throw StateError('Sınıf ve ders ataması akademik yılı uyuşmuyor.');
    }
    final values = _assignmentToRow(assignment);
    final updated = await _database.update(
      'teaching_assignments',
      values,
      where: 'assignment_id = ?',
      whereArgs: [assignment.id],
    );
    if (updated == 0) {
      await _database.insert(
        'teaching_assignments',
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    await _database.delete(
      'teaching_assignments',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
    );
  }

  @override
  Future<List<BellPeriod>> getBellPeriods() async {
    final rows = await _database.query(
      'bell_periods',
      orderBy: 'period_number ASC',
    );
    return rows.map(_periodFromRow).toList(growable: false);
  }

  @override
  Future<void> replaceBellPeriods(List<BellPeriod> periods) async {
    _validatePeriods(periods);
    await _database.transaction((txn) async {
      final desired = periods.map((period) => period.periodNumber).toSet();
      for (final period in periods) {
        final values = _periodToRow(period);
        final updated = await txn.update(
          'bell_periods',
          values,
          where: 'period_number = ?',
          whereArgs: [period.periodNumber],
        );
        if (updated == 0) {
          await txn.insert(
            'bell_periods',
            values,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }
      final existing = await txn.query(
        'bell_periods',
        columns: ['period_number'],
      );
      for (final row in existing) {
        final number = row['period_number']! as int;
        if (!desired.contains(number)) {
          await txn.delete(
            'bell_periods',
            where: 'period_number = ?',
            whereArgs: [number],
          );
        }
      }
    });
  }

  @override
  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignment(
    String assignmentId,
  ) async {
    final rows = await _database.query(
      'lesson_schedule_slots',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      orderBy: 'weekday ASC, period_number ASC',
    );
    return rows.map(_slotFromRow).toList(growable: false);
  }

  @override
  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignments(
    Iterable<String> assignmentIds,
  ) async {
    final ids = assignmentIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _database.query(
      'lesson_schedule_slots',
      where: 'assignment_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'weekday ASC, period_number ASC, assignment_id ASC',
    );
    return rows.map(_slotFromRow).toList(growable: false);
  }

  @override
  Future<void> replaceScheduleSlotsForAssignment({
    required String assignmentId,
    required List<LessonScheduleSlot> slots,
  }) async {
    final assignmentRows = await _database.query(
      'teaching_assignments',
      columns: ['academic_year'],
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      limit: 1,
    );
    if (assignmentRows.isEmpty) {
      throw StateError('Ders ataması bulunamadı.');
    }
    final academicYear = assignmentRows.first['academic_year']! as String;
    final cells = <String>{};
    for (final slot in slots) {
      _validateSlot(slot, assignmentId);
      final cell = '${slot.weekday}:${slot.periodNumber}';
      if (!cells.add(cell)) {
        throw ArgumentError('Aynı program hücresi birden fazla kez seçildi.');
      }
      final conflicts = await _database.query(
        'lesson_schedule_slots',
        columns: ['assignment_id'],
        where:
            'academic_year = ? AND weekday = ? AND period_number = ? AND assignment_id != ?',
        whereArgs: [
          academicYear,
          slot.weekday,
          slot.periodNumber,
          assignmentId,
        ],
        limit: 1,
      );
      if (conflicts.isNotEmpty) {
        throw ScheduleSlotConflictException(
          academicYear: academicYear,
          weekday: slot.weekday,
          periodNumber: slot.periodNumber,
          conflictingAssignmentId: conflicts.first['assignment_id'] as String?,
        );
      }
    }

    await _database.transaction((txn) async {
      await txn.delete(
        'lesson_schedule_slots',
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
      );
      for (final slot in slots) {
        await txn.insert(
          'lesson_schedule_slots',
          _slotToRow(slot, academicYear: academicYear),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  @override
  Future<AssignmentProgressCursor?> getProgressCursor(
    String assignmentId,
  ) async {
    final rows = await _database.query(
      'assignment_progress_cursor',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      limit: 1,
    );
    return rows.isEmpty ? null : _cursorFromRow(rows.first);
  }

  @override
  Future<void> saveProgressCursor(AssignmentProgressCursor cursor) async {
    await _database.insert(
      'assignment_progress_cursor',
      _cursorToRow(cursor),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteProgressCursor(String assignmentId) async {
    await _database.delete(
      'assignment_progress_cursor',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
    );
  }

  SchoolClass _classFromRow(Map<String, Object?> row) => SchoolClass(
    id: row['class_id']! as String,
    academicYear: row['academic_year']! as String,
    grade: row['grade']! as int,
    section: row['section']! as String,
    displayName: row['display_name']! as String,
    createdAt: _parseRequiredDate(row['created_at']),
    updatedAt: _parseRequiredDate(row['updated_at']),
  );

  Map<String, Object?> _classToRow(SchoolClass item) => {
    'class_id': item.id,
    'academic_year': item.academicYear,
    'grade': item.grade,
    'section': item.section.trim(),
    'display_name': item.displayName.trim(),
    'created_at': item.createdAt.toUtc().toIso8601String(),
    'updated_at': item.updatedAt.toUtc().toIso8601String(),
  };

  TeachingAssignment _assignmentFromRow(Map<String, Object?> row) =>
      TeachingAssignment(
        id: row['assignment_id']! as String,
        academicYear: row['academic_year']! as String,
        courseId: row['course_id']! as String,
        classId: row['class_id']! as String,
        isActive: (row['is_active']! as int) != 0,
        createdAt: _parseRequiredDate(row['created_at']),
        updatedAt: _parseRequiredDate(row['updated_at']),
      );

  Map<String, Object?> _assignmentToRow(TeachingAssignment item) => {
    'assignment_id': item.id,
    'academic_year': item.academicYear,
    'course_id': item.courseId,
    'class_id': item.classId,
    'is_active': item.isActive ? 1 : 0,
    'created_at': item.createdAt.toUtc().toIso8601String(),
    'updated_at': item.updatedAt.toUtc().toIso8601String(),
  };

  BellPeriod _periodFromRow(Map<String, Object?> row) => BellPeriod(
    periodNumber: row['period_number']! as int,
    startMinute: row['start_minute']! as int,
    endMinute: row['end_minute']! as int,
  );

  Map<String, Object?> _periodToRow(BellPeriod item) => {
    'period_number': item.periodNumber,
    'start_minute': item.startMinute,
    'end_minute': item.endMinute,
  };

  LessonScheduleSlot _slotFromRow(Map<String, Object?> row) =>
      LessonScheduleSlot(
        id: row['slot_id']! as String,
        assignmentId: row['assignment_id']! as String,
        weekday: row['weekday']! as int,
        periodNumber: row['period_number']! as int,
        createdAt: _parseRequiredDate(row['created_at']),
        updatedAt: _parseRequiredDate(row['updated_at']),
      );

  Map<String, Object?> _slotToRow(
    LessonScheduleSlot item, {
    required String academicYear,
  }) => {
    'slot_id': item.id,
    'assignment_id': item.assignmentId,
    'academic_year': academicYear,
    'weekday': item.weekday,
    'period_number': item.periodNumber,
    'created_at': item.createdAt.toUtc().toIso8601String(),
    'updated_at': item.updatedAt.toUtc().toIso8601String(),
  };

  AssignmentProgressCursor _cursorFromRow(Map<String, Object?> row) =>
      AssignmentProgressCursor(
        assignmentId: row['assignment_id']! as String,
        mode: AssignmentProgressMode.fromStorage(row['mode']! as String),
        plannedOrdinalAtAnchor: row['planned_ordinal_at_anchor']! as int,
        actualOrdinalAtAnchor: row['actual_ordinal_at_anchor']! as int,
        anchoredAt: _parseRequiredDate(row['anchored_at']),
        updatedAt: _parseRequiredDate(row['updated_at']),
      );

  Map<String, Object?> _cursorToRow(AssignmentProgressCursor item) => {
    'assignment_id': item.assignmentId,
    'mode': item.mode.storageValue,
    'planned_ordinal_at_anchor': item.plannedOrdinalAtAnchor,
    'actual_ordinal_at_anchor': item.actualOrdinalAtAnchor,
    'anchored_at': item.anchoredAt.toUtc().toIso8601String(),
    'updated_at': item.updatedAt.toUtc().toIso8601String(),
  };

  void _validateSlot(LessonScheduleSlot slot, String assignmentId) {
    if (slot.assignmentId != assignmentId) {
      throw ArgumentError.value(
        slot.assignmentId,
        'slot.assignmentId',
        'Must match assignmentId',
      );
    }
    if (slot.weekday < DateTime.monday || slot.weekday > DateTime.sunday) {
      throw ArgumentError.value(slot.weekday, 'slot.weekday');
    }
    if (slot.periodNumber < 1) {
      throw ArgumentError.value(slot.periodNumber, 'slot.periodNumber');
    }
  }

  void _validatePeriods(List<BellPeriod> periods) {
    final numbers = <int>{};
    BellPeriod? previous;
    final ordered = [...periods]
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    for (final period in ordered) {
      if (period.periodNumber < 1 || !numbers.add(period.periodNumber)) {
        throw ArgumentError.value(period.periodNumber, 'periodNumber');
      }
      if (period.startMinute < 0 ||
          period.endMinute > 1440 ||
          period.startMinute >= period.endMinute) {
        throw ArgumentError('Invalid bell period time range');
      }
      if (previous != null && previous.endMinute > period.startMinute) {
        throw ArgumentError('Bell periods must not overlap');
      }
      previous = period;
    }
  }

  DateTime _parseRequiredDate(Object? value) {
    if (value is! String) throw const FormatException('Missing date');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const FormatException('Invalid date');
    return parsed.toLocal();
  }
}
