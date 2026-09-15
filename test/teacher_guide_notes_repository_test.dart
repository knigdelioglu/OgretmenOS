import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/tracking/outcome_tracking_database.dart';
import 'package:ogretmen_os/data/tracking/teacher_guide_notes_repository_impl.dart';
import 'package:ogretmen_os/domain/models/teacher_guide_note_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'teacher-guide notes are assignment-scoped and survive refresh',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ogretmen_os_guide_notes_',
      );
      final path = '${directory.path}/teacher_state.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final state = await OutcomeTrackingDatabase.open(pathOverride: path);
      addTearDown(state.close);
      final now = DateTime.utc(2026, 9, 14, 10);
      for (final entry in const [
        ('assignment-11a', 'class-11a', '11/A'),
        ('assignment-11b', 'class-11b', '11/B'),
      ]) {
        await state.database.insert('school_classes', {
          'class_id': entry.$2,
          'academic_year': '2026-2027',
          'grade': 11,
          'section': entry.$3.substring(3),
          'display_name': entry.$3,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        await state.database.insert('teaching_assignments', {
          'assignment_id': entry.$1,
          'academic_year': '2026-2027',
          'course_id': 'TDE_11',
          'class_id': entry.$2,
          'is_active': 1,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }

      final repository = SqfliteTeacherGuideNotesRepository(state.database);
      await repository.save(
        TeacherGuideNote(
          assignmentId: 'assignment-11a',
          guideItemId: 'GUIDE_ITEM_1',
          note: '11/A için not',
          canonicalPayloadSha256: 'a' * 64,
          updatedAt: now,
        ),
      );
      await repository.save(
        TeacherGuideNote(
          assignmentId: 'assignment-11b',
          guideItemId: 'GUIDE_ITEM_1',
          note: '11/B için not',
          canonicalPayloadSha256: 'b' * 64,
          updatedAt: now,
        ),
      );

      expect(
        (await repository.get(
          assignmentId: 'assignment-11a',
          guideItemId: 'GUIDE_ITEM_1',
        ))?.note,
        '11/A için not',
      );
      expect(
        (await repository.get(
          assignmentId: 'assignment-11b',
          guideItemId: 'GUIDE_ITEM_1',
        ))?.note,
        '11/B için not',
      );
      expect(
        (await repository.get(
          assignmentId: 'assignment-11a',
          guideItemId: 'GUIDE_ITEM_1',
        ))!.isStaleFor('c' * 64),
        isTrue,
      );

      await state.close();
      final reopened = await OutcomeTrackingDatabase.open(pathOverride: path);
      addTearDown(reopened.close);
      final reopenedRepository = SqfliteTeacherGuideNotesRepository(
        reopened.database,
      );
      expect(
        (await reopenedRepository.get(
          assignmentId: 'assignment-11a',
          guideItemId: 'GUIDE_ITEM_1',
        ))?.note,
        '11/A için not',
      );
    },
  );

  test('note save without a known assignment fails visibly', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ogretmen_os_guide_notes_missing_',
    );
    final path = '${directory.path}/teacher_state.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final state = await OutcomeTrackingDatabase.open(pathOverride: path);
    addTearDown(state.close);
    final repository = SqfliteTeacherGuideNotesRepository(state.database);

    expect(
      () => repository.save(
        TeacherGuideNote(
          assignmentId: 'missing',
          guideItemId: 'GUIDE_ITEM_1',
          note: 'not',
          canonicalPayloadSha256: 'a' * 64,
          updatedAt: DateTime.now(),
        ),
      ),
      throwsStateError,
    );
  });
}
