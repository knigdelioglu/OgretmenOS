import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/instruction_context_repository_impl.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:ogretmen_os/domain/models/instruction_context_models.dart';
import 'package:ogretmen_os/domain/repositories/instruction_context_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Memory ve SQLite başarılı atomic class+assignment oluşturur', () async {
    await _expectSuccessfulCreation(MemoryInstructionContextRepository());
    await _withSqlite((repository, _) => _expectSuccessfulCreation(repository));
  });

  test(
    'assignment insert hatası class satırını rollback eder ve retry çalışır',
    () async {
      final memory = MemoryInstructionContextRepository();
      final invalidAssignment = _assignment(
        id: 'assignment-invalid',
        classId: 'class-retry-memory',
        year: '2027-2028',
      );
      final schoolClass = _class(
        id: 'class-retry-memory',
        year: '2026-2027',
        displayName: '9/C',
      );
      await expectLater(
        memory.createClassWithAssignment(
          schoolClass: schoolClass,
          assignment: invalidAssignment,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await memory.getClass(schoolClass.id), isNull);
      expect(await memory.getAssignment(invalidAssignment.id), isNull);
      await memory.createClassWithAssignment(
        schoolClass: schoolClass,
        assignment: _assignment(
          id: invalidAssignment.id,
          classId: schoolClass.id,
          year: schoolClass.academicYear,
        ),
      );
      expect(await memory.getClass(schoolClass.id), isNotNull);

      await _withSqlite((repository, database) async {
        await database.execute('''
        CREATE TRIGGER fail_assignment_insert
        BEFORE INSERT ON teaching_assignments
        WHEN NEW.assignment_id = 'assignment-fail'
        BEGIN
          SELECT RAISE(ABORT, 'injected assignment failure');
        END
      ''');
        final sqliteClass = _class(
          id: 'class-retry-sqlite',
          year: '2026-2027',
          displayName: '9/D',
        );
        final failingAssignment = _assignment(
          id: 'assignment-fail',
          classId: sqliteClass.id,
          year: sqliteClass.academicYear,
        );
        await expectLater(
          repository.createClassWithAssignment(
            schoolClass: sqliteClass,
            assignment: failingAssignment,
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect(await repository.getClass(sqliteClass.id), isNull);
        expect(await repository.getAssignment(failingAssignment.id), isNull);

        await repository.createClassWithAssignment(
          schoolClass: sqliteClass,
          assignment: _assignment(
            id: 'assignment-retry',
            classId: sqliteClass.id,
            year: sqliteClass.academicYear,
          ),
        );
        expect(await repository.getClass(sqliteClass.id), isNotNull);
        expect(await repository.getAssignment('assignment-retry'), isNotNull);
      });
    },
  );

  test('duplicate class ve year mismatch DB yi değiştirmez', () async {
    for (final setup in [
      () async => _runAtomicConflict(MemoryInstructionContextRepository()),
      () async =>
          _withSqlite((repository, _) => _runAtomicConflict(repository)),
    ]) {
      await setup();
    }
  });
}

Future<void> _expectSuccessfulCreation(
  InstructionContextRepository repository,
) async {
  final schoolClass = _class(
    id: 'class-success',
    year: '2026-2027',
    displayName: '9/A',
  );
  final assignment = _assignment(
    id: 'assignment-success',
    classId: schoolClass.id,
    year: schoolClass.academicYear,
  );
  expect(await repository.getClass(schoolClass.id), isNull);
  expect(await repository.getAssignment(assignment.id), isNull);
  await repository.createClassWithAssignment(
    schoolClass: schoolClass,
    assignment: assignment,
  );
  expect(await repository.getClass(schoolClass.id), isNotNull);
  expect(await repository.getAssignment(assignment.id), isNotNull);
}

Future<void> _runAtomicConflict(InstructionContextRepository repository) async {
  final existing = _class(
    id: 'class-existing',
    year: '2026-2027',
    displayName: '9/A',
  );
  await repository.createClassWithAssignment(
    schoolClass: existing,
    assignment: _assignment(
      id: 'assignment-existing',
      classId: existing.id,
      year: existing.academicYear,
    ),
  );

  final duplicate = _class(
    id: 'class-duplicate',
    year: existing.academicYear,
    displayName: '9/A',
  );
  await expectLater(
    repository.createClassWithAssignment(
      schoolClass: duplicate,
      assignment: _assignment(
        id: 'assignment-duplicate',
        classId: duplicate.id,
        year: duplicate.academicYear,
      ),
    ),
    throwsA(isA<StateError>()),
  );
  expect(await repository.getClass(duplicate.id), isNull);
  expect(await repository.getAssignment('assignment-duplicate'), isNull);

  final mismatch = _class(
    id: 'class-mismatch',
    year: existing.academicYear,
    displayName: '9/B',
  );
  final mismatchedAssignment = _assignment(
    id: 'assignment-mismatch',
    classId: mismatch.id,
    year: '2027-2028',
  );
  await expectLater(
    repository.createClassWithAssignment(
      schoolClass: mismatch,
      assignment: mismatchedAssignment,
    ),
    throwsA(isA<StateError>()),
  );
  expect(await repository.getClass(mismatch.id), isNull);
  expect(await repository.getAssignment(mismatchedAssignment.id), isNull);
  expect(await repository.getClasses(existing.academicYear), hasLength(1));
}

Future<void> _withSqlite(
  Future<void> Function(
    SqfliteInstructionContextRepository repository,
    dynamic database,
  )
  action,
) async {
  final directory = await Directory.systemTemp.createTemp(
    'ogretmen_os_atomic_context_',
  );
  final state = await OutcomeTrackingDatabase.open(
    pathOverride: '${directory.path}/teacher_state.sqlite',
  );
  addTearDown(() async {
    await state.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  final repository = SqfliteInstructionContextRepository(state.database);
  await action(repository, state.database);
}

SchoolClass _class({
  required String id,
  required String year,
  required String displayName,
}) {
  final now = DateTime.utc(2026, 8, 1);
  return SchoolClass(
    id: id,
    academicYear: year,
    grade: 9,
    section: displayName.split('/').last,
    displayName: displayName,
    createdAt: now,
    updatedAt: now,
  );
}

TeachingAssignment _assignment({
  required String id,
  required String classId,
  required String year,
}) {
  final now = DateTime.utc(2026, 8, 1);
  return TeachingAssignment(
    id: id,
    academicYear: year,
    courseId: 'TDE_9',
    classId: classId,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
