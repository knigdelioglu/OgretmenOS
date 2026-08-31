import '../models/instruction_context_models.dart';

abstract interface class InstructionContextRepository {
  Future<List<SchoolClass>> getClasses(String academicYear);

  Future<SchoolClass?> getClass(String classId);

  Future<void> saveClass(SchoolClass schoolClass);

  Future<void> createClassWithAssignment({
    required SchoolClass schoolClass,
    required TeachingAssignment assignment,
  });

  Future<void> deleteClass(String classId);

  Future<List<TeachingAssignment>> getAssignments({
    required String academicYear,
    String? courseId,
    bool activeOnly = true,
  });

  Future<TeachingAssignment?> getAssignment(String assignmentId);

  Future<void> saveAssignment(TeachingAssignment assignment);

  Future<void> deleteAssignment(String assignmentId);

  Future<List<BellPeriod>> getBellPeriods();

  Future<void> replaceBellPeriods(List<BellPeriod> periods);

  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignment(
    String assignmentId,
  );

  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignments(
    Iterable<String> assignmentIds,
  );

  Future<void> replaceScheduleSlotsForAssignment({
    required String assignmentId,
    required List<LessonScheduleSlot> slots,
  });

  Future<AssignmentProgressCursor?> getProgressCursor(String assignmentId);

  Future<void> saveProgressCursor(AssignmentProgressCursor cursor);

  Future<void> deleteProgressCursor(String assignmentId);
}

class MemoryInstructionContextRepository
    implements InstructionContextRepository {
  final Map<String, SchoolClass> _classes = {};
  final Map<String, TeachingAssignment> _assignments = {};
  final Map<int, BellPeriod> _periods = {};
  final Map<String, LessonScheduleSlot> _slots = {};
  final Map<String, AssignmentProgressCursor> _cursors = {};

  @override
  Future<List<SchoolClass>> getClasses(String academicYear) async {
    final items =
        _classes.values
            .where((item) => item.academicYear == academicYear)
            .toList(growable: false)
          ..sort((a, b) {
            final gradeCompare = a.grade.compareTo(b.grade);
            if (gradeCompare != 0) return gradeCompare;
            return a.displayName.compareTo(b.displayName);
          });
    return items;
  }

  @override
  Future<SchoolClass?> getClass(String classId) async => _classes[classId];

  @override
  Future<void> saveClass(SchoolClass schoolClass) async {
    _validateClass(schoolClass);
    final existing = _classes[schoolClass.id];
    if (existing != null && existing.academicYear != schoolClass.academicYear) {
      throw StateError('Sınıfın akademik yılı değiştirilemez.');
    }
    final duplicate = _classes.values.any(
      (item) =>
          item.id != schoolClass.id &&
          item.academicYear == schoolClass.academicYear &&
          item.displayName.trim().toUpperCase() ==
              schoolClass.displayName.trim().toUpperCase(),
    );
    if (duplicate) {
      throw StateError('Aynı akademik yılda aynı sınıf/şube zaten var.');
    }
    _classes[schoolClass.id] = schoolClass;
  }

  @override
  Future<void> createClassWithAssignment({
    required SchoolClass schoolClass,
    required TeachingAssignment assignment,
  }) async {
    _validateClass(schoolClass);
    _validateAssignment(assignment);
    if (assignment.classId != schoolClass.id) {
      throw StateError('Ders ataması oluşturulan sınıfa ait olmalı.');
    }
    if (assignment.academicYear != schoolClass.academicYear) {
      throw StateError('Sınıf ve ders ataması akademik yılı uyuşmuyor.');
    }
    _validateNewClass(schoolClass);
    _validateNewAssignment(assignment);
    _classes[schoolClass.id] = schoolClass;
    _assignments[assignment.id] = assignment;
  }

  @override
  Future<void> deleteClass(String classId) async {
    final assignmentIds = _assignments.values
        .where((item) => item.classId == classId)
        .map((item) => item.id)
        .toList(growable: false);
    for (final assignmentId in assignmentIds) {
      await deleteAssignment(assignmentId);
    }
    _classes.remove(classId);
  }

  @override
  Future<List<TeachingAssignment>> getAssignments({
    required String academicYear,
    String? courseId,
    bool activeOnly = true,
  }) async {
    final items =
        _assignments.values
            .where((item) {
              if (item.academicYear != academicYear) return false;
              if (courseId != null && item.courseId != courseId) return false;
              if (activeOnly && !item.isActive) return false;
              return true;
            })
            .toList(growable: false)
          ..sort((a, b) => a.id.compareTo(b.id));
    return items;
  }

  @override
  Future<TeachingAssignment?> getAssignment(String assignmentId) async =>
      _assignments[assignmentId];

  @override
  Future<void> saveAssignment(TeachingAssignment assignment) async {
    _validateAssignment(assignment);
    final schoolClass = _classes[assignment.classId];
    if (schoolClass == null) {
      throw StateError('Ders atamasının sınıfı bulunamadı.');
    }
    if (schoolClass.academicYear != assignment.academicYear) {
      throw StateError('Sınıf ve ders ataması akademik yılı uyuşmuyor.');
    }
    final existing = _assignments[assignment.id];
    if (existing != null &&
        (existing.academicYear != assignment.academicYear ||
            existing.courseId != assignment.courseId ||
            existing.classId != assignment.classId)) {
      throw StateError('Ders atamasının kapsam kimliği değiştirilemez.');
    }
    final duplicate = _assignments.values.any(
      (item) =>
          item.id != assignment.id &&
          item.academicYear == assignment.academicYear &&
          item.courseId == assignment.courseId &&
          item.classId == assignment.classId,
    );
    if (duplicate) {
      throw StateError('Bu ders bu sınıfa zaten atanmış.');
    }
    _assignments[assignment.id] = assignment;
  }

  void _validateNewClass(SchoolClass schoolClass) {
    final existing = _classes[schoolClass.id];
    if (existing != null) {
      throw StateError('Sınıf kimliği zaten kullanılıyor.');
    }
    final duplicate = _classes.values.any(
      (item) =>
          item.academicYear == schoolClass.academicYear &&
          item.displayName.trim().toUpperCase() ==
              schoolClass.displayName.trim().toUpperCase(),
    );
    if (duplicate) {
      throw StateError('Aynı akademik yılda aynı sınıf/şube zaten var.');
    }
  }

  void _validateNewAssignment(TeachingAssignment assignment) {
    if (_assignments.containsKey(assignment.id)) {
      throw StateError('Ders ataması kimliği zaten kullanılıyor.');
    }
    final duplicate = _assignments.values.any(
      (item) =>
          item.academicYear == assignment.academicYear &&
          item.courseId == assignment.courseId &&
          item.classId == assignment.classId,
    );
    if (duplicate) {
      throw StateError('Bu ders bu sınıfa zaten atanmış.');
    }
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    _assignments.remove(assignmentId);
    _slots.removeWhere((_, slot) => slot.assignmentId == assignmentId);
    _cursors.remove(assignmentId);
  }

  @override
  Future<List<BellPeriod>> getBellPeriods() async {
    final items = _periods.values.toList(growable: false)
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    return items;
  }

  @override
  Future<void> replaceBellPeriods(List<BellPeriod> periods) async {
    _validatePeriods(periods);
    final desired = periods.map((period) => period.periodNumber).toSet();
    final used = _slots.values.map((slot) => slot.periodNumber).toSet();
    if (used.any((number) => !desired.contains(number))) {
      throw StateError('Programda kullanılan bir ders saati silinemez.');
    }
    _periods
      ..clear()
      ..addEntries(
        periods.map((period) => MapEntry(period.periodNumber, period)),
      );
  }

  @override
  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignment(
    String assignmentId,
  ) async {
    final items = _slots.values
        .where((slot) => slot.assignmentId == assignmentId)
        .toList(growable: false);
    _sortSlots(items);
    return items;
  }

  @override
  Future<List<LessonScheduleSlot>> getScheduleSlotsForAssignments(
    Iterable<String> assignmentIds,
  ) async {
    final ids = assignmentIds.toSet();
    if (ids.isEmpty) return const [];
    final items = _slots.values
        .where((slot) => ids.contains(slot.assignmentId))
        .toList(growable: false);
    _sortSlots(items);
    return items;
  }

  @override
  Future<void> replaceScheduleSlotsForAssignment({
    required String assignmentId,
    required List<LessonScheduleSlot> slots,
  }) async {
    final assignment = _assignments[assignmentId];
    if (assignment == null) {
      throw StateError('Ders ataması bulunamadı.');
    }
    final cells = <String>{};
    final slotIds = <String>{};
    for (final slot in slots) {
      _validateSlot(slot, assignmentId);
      if (!_periods.containsKey(slot.periodNumber)) {
        throw StateError('${slot.periodNumber}. ders saati tanımlı değil.');
      }
      if (!slotIds.add(slot.id)) {
        throw ArgumentError('Aynı program kaydı birden fazla kez seçildi.');
      }
      final otherSlot = _slots[slot.id];
      if (otherSlot != null && otherSlot.assignmentId != assignmentId) {
        throw StateError('Program kaydı kimliği başka bir şubeye ait.');
      }
      final cell = '${slot.weekday}:${slot.periodNumber}';
      if (!cells.add(cell)) {
        throw ArgumentError('Aynı program hücresi birden fazla kez seçildi.');
      }
    }

    for (final slot in slots) {
      for (final existing in _slots.values) {
        if (existing.assignmentId == assignmentId ||
            existing.weekday != slot.weekday ||
            existing.periodNumber != slot.periodNumber) {
          continue;
        }
        final otherAssignment = _assignments[existing.assignmentId];
        if (otherAssignment?.academicYear == assignment.academicYear) {
          throw ScheduleSlotConflictException(
            academicYear: assignment.academicYear,
            weekday: slot.weekday,
            periodNumber: slot.periodNumber,
            conflictingAssignmentId: existing.assignmentId,
          );
        }
      }
    }

    _slots.removeWhere((_, slot) => slot.assignmentId == assignmentId);
    for (final slot in slots) {
      _slots[slot.id] = slot;
    }
  }

  @override
  Future<AssignmentProgressCursor?> getProgressCursor(
    String assignmentId,
  ) async => _cursors[assignmentId];

  @override
  Future<void> saveProgressCursor(AssignmentProgressCursor cursor) async {
    if (!_assignments.containsKey(cursor.assignmentId)) {
      throw StateError('Ders ataması bulunamadı.');
    }
    _cursors[cursor.assignmentId] = cursor;
  }

  @override
  Future<void> deleteProgressCursor(String assignmentId) async {
    _cursors.remove(assignmentId);
  }

  void _validateSlot(LessonScheduleSlot slot, String assignmentId) {
    if (slot.id.trim().isEmpty) {
      throw ArgumentError.value(slot.id, 'slot.id');
    }
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

  void _validateClass(SchoolClass schoolClass) {
    if (schoolClass.id.trim().isEmpty ||
        schoolClass.academicYear.trim().isEmpty) {
      throw ArgumentError('Sınıf kimliği ve akademik yıl boş olamaz.');
    }
    if (schoolClass.grade < 1 || schoolClass.grade > 12) {
      throw ArgumentError.value(schoolClass.grade, 'grade');
    }
    if (schoolClass.section.trim().isEmpty ||
        schoolClass.displayName.trim().isEmpty) {
      throw ArgumentError('Sınıf/şube adı boş olamaz.');
    }
  }

  void _validateAssignment(TeachingAssignment assignment) {
    if (assignment.id.trim().isEmpty ||
        assignment.academicYear.trim().isEmpty ||
        assignment.courseId.trim().isEmpty ||
        assignment.classId.trim().isEmpty) {
      throw ArgumentError('Ders ataması kapsam alanları boş olamaz.');
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

  void _sortSlots(List<LessonScheduleSlot> items) {
    items.sort((a, b) {
      final dayCompare = a.weekday.compareTo(b.weekday);
      if (dayCompare != 0) return dayCompare;
      final periodCompare = a.periodNumber.compareTo(b.periodNumber);
      if (periodCompare != 0) return periodCompare;
      return a.assignmentId.compareTo(b.assignmentId);
    });
  }
}
