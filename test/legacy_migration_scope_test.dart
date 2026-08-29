import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/instruction_context_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_progress_models.dart';
import 'package:ogretmen_os/domain/repositories/assignment_lesson_progress_repository.dart';
import 'package:ogretmen_os/domain/repositories/assignment_outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/repositories/instruction_context_repository.dart';
import 'package:ogretmen_os/domain/repositories/lesson_plan_progress_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/legacy_teacher_state_migration_service.dart';

void main() {
  test('legacy migration başka course assignmentına veri taşımaz', () async {
    final context = MemoryInstructionContextRepository();
    final legacyLessons = MemoryLessonPlanProgressRepository();
    final legacyOutcomes = MemoryOutcomeTrackingRepository();
    final targetLessons = MemoryAssignmentLessonProgressRepository();
    final targetOutcomes = MemoryAssignmentOutcomeTrackingRepository();
    final now = DateTime(2026, 9, 1, 10);

    await context.saveClass(
      SchoolClass(
        id: 'c10a',
        academicYear: '2026-2027',
        grade: 10,
        section: 'A',
        displayName: '10/A',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await context.saveAssignment(
      TeachingAssignment(
        id: 'a10a',
        academicYear: '2026-2027',
        courseId: 'TDE_10',
        classId: 'c10a',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await legacyLessons.save(
      LessonPlanProgressRecord(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: 'P01::lesson-hour:1',
        payloadSha256: 'hash',
        status: LessonPlanProgressStatus.completed,
        completedAt: now,
        updatedAt: now,
      ),
    );

    final service = LegacyTeacherStateMigrationService(
      legacyLessonProgress: legacyLessons,
      legacyOutcomeTracking: legacyOutcomes,
      assignmentLessonProgress: targetLessons,
      assignmentOutcomeTracking: targetOutcomes,
      instructionContext: context,
    );

    expect(
      () => service.migrateToAssignment(
        assignmentId: 'a10a',
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        allowedOutcomeIds: const {},
      ),
      throwsA(isA<StateError>()),
    );

    expect(await targetLessons.getForAssignment('a10a'), isEmpty);
    expect(
      await legacyLessons.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: 'P01::lesson-hour:1',
      ),
      isNotNull,
    );
  });

  test('legacy migration bulunmayan assignment hedefini reddeder', () async {
    final targetLessons = MemoryAssignmentLessonProgressRepository();
    final service = LegacyTeacherStateMigrationService(
      legacyLessonProgress: MemoryLessonPlanProgressRepository(),
      legacyOutcomeTracking: MemoryOutcomeTrackingRepository(),
      assignmentLessonProgress: targetLessons,
      assignmentOutcomeTracking: MemoryAssignmentOutcomeTrackingRepository(),
      instructionContext: MemoryInstructionContextRepository(),
    );

    expect(
      () => service.migrateToAssignment(
        assignmentId: 'missing',
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        allowedOutcomeIds: const {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(await targetLessons.getForAssignment('missing'), isEmpty);
  });
}
