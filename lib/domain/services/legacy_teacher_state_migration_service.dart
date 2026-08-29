import '../models/assignment_lesson_progress_models.dart';
import '../models/assignment_outcome_tracking_models.dart';
import '../repositories/assignment_lesson_progress_repository.dart';
import '../repositories/assignment_outcome_tracking_repository.dart';
import '../repositories/instruction_context_repository.dart';
import '../repositories/lesson_plan_progress_repository.dart';
import '../repositories/outcome_tracking_repository.dart';

class LegacyTeacherStateMigrationService {
  const LegacyTeacherStateMigrationService({
    required this.legacyLessonProgress,
    required this.legacyOutcomeTracking,
    required this.assignmentLessonProgress,
    required this.assignmentOutcomeTracking,
    this.instructionContext,
  });

  final LessonPlanProgressRepository legacyLessonProgress;
  final OutcomeTrackingRepository legacyOutcomeTracking;
  final AssignmentLessonProgressRepository assignmentLessonProgress;
  final AssignmentOutcomeTrackingRepository assignmentOutcomeTracking;

  /// Optional for backwards-compatible tests/adapters. Production supplies the
  /// instruction context so an explicit target cannot accidentally receive
  /// legacy records belonging to another course or academic year.
  final InstructionContextRepository? instructionContext;

  Future<LegacyTeacherStateMigrationPreview> preview({
    required String courseId,
    required String academicYear,
    required Set<String> allowedOutcomeIds,
  }) async {
    final legacyLessons = await legacyLessonProgress.getForCourseAcademicYear(
      courseId: courseId,
      academicYear: academicYear,
    );
    var migratableLessons = 0;
    for (final record in legacyLessons) {
      if (_parseLessonIdentity(record.packageId) != null) migratableLessons++;
    }

    final legacyOutcomes = await legacyOutcomeTracking.getForAcademicYear(
      academicYear,
    );
    final matchingOutcomes = legacyOutcomes
        .where((record) => allowedOutcomeIds.contains(record.outcomeId))
        .length;

    return LegacyTeacherStateMigrationPreview(
      legacyLessonRecordCount: legacyLessons.length,
      migratableLessonRecordCount: migratableLessons,
      skippedLessonRecordCount: legacyLessons.length - migratableLessons,
      matchingOutcomeRecordCount: matchingOutcomes,
    );
  }

  Future<LegacyTeacherStateMigrationReport> migrateToAssignment({
    required String assignmentId,
    required String courseId,
    required String academicYear,
    required Set<String> allowedOutcomeIds,
  }) async {
    if (assignmentId.trim().isEmpty) {
      throw ArgumentError.value(assignmentId, 'assignmentId');
    }
    await _validateTargetScope(
      assignmentId: assignmentId,
      courseId: courseId,
      academicYear: academicYear,
    );

    var lessonsCopied = 0;
    var lessonsSkippedMalformed = 0;
    var lessonsSkippedExisting = 0;
    final legacyLessons = await legacyLessonProgress.getForCourseAcademicYear(
      courseId: courseId,
      academicYear: academicYear,
    );
    for (final source in legacyLessons) {
      final identity = _parseLessonIdentity(source.packageId);
      if (identity == null) {
        lessonsSkippedMalformed++;
        continue;
      }
      final existing = await assignmentLessonProgress.get(
        assignmentId: assignmentId,
        packageId: identity.packageId,
        packageHour: identity.packageHour,
      );
      if (existing != null) {
        lessonsSkippedExisting++;
        continue;
      }
      await assignmentLessonProgress.save(
        AssignmentLessonProgressRecord(
          assignmentId: assignmentId,
          packageId: identity.packageId,
          packageHour: identity.packageHour,
          payloadSha256: source.payloadSha256,
          status: source.status,
          startedAt: source.startedAt,
          completedAt: source.completedAt,
          updatedAt: source.updatedAt,
        ),
      );
      lessonsCopied++;
    }

    var outcomesCopied = 0;
    var outcomesSkippedOutsideCourse = 0;
    var outcomesSkippedExisting = 0;
    final legacyOutcomes = await legacyOutcomeTracking.getForAcademicYear(
      academicYear,
    );
    for (final source in legacyOutcomes) {
      if (!allowedOutcomeIds.contains(source.outcomeId)) {
        outcomesSkippedOutsideCourse++;
        continue;
      }
      final existing = await assignmentOutcomeTracking.get(
        assignmentId: assignmentId,
        outcomeId: source.outcomeId,
        plannedWeekNumber: source.plannedWeekNumber,
      );
      if (existing != null) {
        outcomesSkippedExisting++;
        continue;
      }
      await assignmentOutcomeTracking.save(
        AssignmentOutcomeTrackingRecord(
          assignmentId: assignmentId,
          outcomeId: source.outcomeId,
          plannedWeekNumber: source.plannedWeekNumber,
          status: source.status,
          actualHours: source.actualHours,
          teacherNote: source.teacherNote,
          completedAt: source.completedAt,
          carriedToWeekNumber: source.carriedToWeekNumber,
          updatedAt: source.updatedAt,
        ),
      );
      outcomesCopied++;
    }

    return LegacyTeacherStateMigrationReport(
      lessonsCopied: lessonsCopied,
      lessonsSkippedMalformed: lessonsSkippedMalformed,
      lessonsSkippedExisting: lessonsSkippedExisting,
      outcomesCopied: outcomesCopied,
      outcomesSkippedOutsideCourse: outcomesSkippedOutsideCourse,
      outcomesSkippedExisting: outcomesSkippedExisting,
    );
  }

  Future<void> _validateTargetScope({
    required String assignmentId,
    required String courseId,
    required String academicYear,
  }) async {
    final context = instructionContext;
    if (context == null) return;
    final assignment = await context.getAssignment(assignmentId);
    if (assignment == null) {
      throw StateError('Legacy aktarım hedefi bulunamadı.');
    }
    if (assignment.courseId != courseId ||
        assignment.academicYear != academicYear) {
      throw StateError(
        'Legacy aktarım hedefi ders/akademik yıl kapsamıyla uyuşmuyor.',
      );
    }
  }

  _LegacyLessonIdentity? _parseLessonIdentity(String storedPackageId) {
    const marker = '::lesson-hour:';
    final markerIndex = storedPackageId.lastIndexOf(marker);
    if (markerIndex <= 0) return null;
    final packageId = storedPackageId.substring(0, markerIndex).trim();
    final hourText = storedPackageId.substring(markerIndex + marker.length);
    final packageHour = int.tryParse(hourText);
    if (packageId.isEmpty || packageHour == null || packageHour < 1) return null;
    return _LegacyLessonIdentity(
      packageId: packageId,
      packageHour: packageHour,
    );
  }
}

class LegacyTeacherStateMigrationPreview {
  const LegacyTeacherStateMigrationPreview({
    required this.legacyLessonRecordCount,
    required this.migratableLessonRecordCount,
    required this.skippedLessonRecordCount,
    required this.matchingOutcomeRecordCount,
  });

  final int legacyLessonRecordCount;
  final int migratableLessonRecordCount;
  final int skippedLessonRecordCount;
  final int matchingOutcomeRecordCount;

  int get migratableRecordCount =>
      migratableLessonRecordCount + matchingOutcomeRecordCount;

  bool get hasMigratableData => migratableRecordCount > 0;
}

class LegacyTeacherStateMigrationReport {
  const LegacyTeacherStateMigrationReport({
    required this.lessonsCopied,
    required this.lessonsSkippedMalformed,
    required this.lessonsSkippedExisting,
    required this.outcomesCopied,
    required this.outcomesSkippedOutsideCourse,
    required this.outcomesSkippedExisting,
  });

  final int lessonsCopied;
  final int lessonsSkippedMalformed;
  final int lessonsSkippedExisting;
  final int outcomesCopied;
  final int outcomesSkippedOutsideCourse;
  final int outcomesSkippedExisting;

  int get copiedCount => lessonsCopied + outcomesCopied;
}

class _LegacyLessonIdentity {
  const _LegacyLessonIdentity({
    required this.packageId,
    required this.packageHour,
  });

  final String packageId;
  final int packageHour;
}
