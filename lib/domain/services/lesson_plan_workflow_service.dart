import '../models/lesson_plan_models.dart';
import '../models/outcome_tracking_models.dart';
import '../repositories/course_knowledge_repository.dart';

class WeeklyLessonPlanSelection {
  const WeeklyLessonPlanSelection({
    required this.package,
    required this.weekNumber,
    required this.weekHour,
    required this.blockId,
    required this.segmentHours,
    required this.segmentStartHour,
    required this.segmentEndHour,
    required this.packageStartHour,
    required this.packageEndHour,
    required this.blockHour,
    required this.packageHour,
    this.lesson,
  });

  final LessonPlanPackage package;
  final LessonPlanLesson? lesson;
  final int weekNumber;

  /// Exact 1-based course hour represented by this row inside the week.
  final int weekHour;

  final String blockId;
  final int segmentHours;

  /// 1-based inclusive hour range of this week's segment inside the block.
  final int segmentStartHour;
  final int segmentEndHour;

  /// 1-based inclusive hour range covered by the source package inside the block.
  final int packageStartHour;
  final int packageEndHour;

  /// Exact 1-based lesson hour represented by this row inside the block.
  final int blockHour;

  /// Exact 1-based lesson hour represented by this row inside the source package.
  final int packageHour;

  bool get beginsInSelectedWeek => packageStartHour >= segmentStartHour;
}

class LessonPlanWorkflowService {
  const LessonPlanWorkflowService({required this.repository});

  final CourseKnowledgeRepository repository;

  Future<List<WeeklyLessonPlanSelection>> plansForWeek(
    AnnualOutcomePlan annualPlan,
    int weekNumber,
  ) async {
    final summary = annualPlan.week(weekNumber);
    if (summary == null || summary.week.isEventWeek) return const [];

    final capability = await repository.getLessonPlanCapability();
    if (!capability.usable) return const [];

    final selections = <WeeklyLessonPlanSelection>[];
    final consumedInSelectedWeek = <String, int>{};
    var weekHourCursor = 0;

    for (final segment in summary.week.segments) {
      final block = segment.block;
      if (block == null || segment.hours <= 0) {
        weekHourCursor += segment.hours;
        continue;
      }

      final consumedBefore =
          _consumedBlockHoursBefore(annualPlan, weekNumber, block.id) +
          (consumedInSelectedWeek[block.id] ?? 0);
      final segmentEndExclusive = consumedBefore + segment.hours;
      final packages = await repository.getLessonPlansForBlock(block.id);
      if (packages.isEmpty) return const [];

      var packageStart = 0;
      for (final package in packages) {
        if (package.lessonHours <= 0 || package.validationStatus != 'PASS') {
          return const [];
        }
        final packageEndExclusive = packageStart + package.lessonHours;
        final overlapStart = packageStart > consumedBefore
            ? packageStart
            : consumedBefore;
        final overlapEnd = packageEndExclusive < segmentEndExclusive
            ? packageEndExclusive
            : segmentEndExclusive;

        for (var blockHourIndex = overlapStart;
            blockHourIndex < overlapEnd;
            blockHourIndex++) {
          final packageHour = blockHourIndex - packageStart + 1;
          final weekHour = weekHourCursor + (blockHourIndex - consumedBefore) + 1;
          selections.add(
            WeeklyLessonPlanSelection(
              package: package,
              lesson: _lessonForPackageHour(package, packageHour),
              weekNumber: weekNumber,
              weekHour: weekHour,
              blockId: block.id,
              segmentHours: segment.hours,
              segmentStartHour: consumedBefore + 1,
              segmentEndHour: segmentEndExclusive,
              packageStartHour: packageStart + 1,
              packageEndHour: packageEndExclusive,
              blockHour: blockHourIndex + 1,
              packageHour: packageHour,
            ),
          );
        }
        packageStart = packageEndExclusive;
      }

      // The runtime may advertise lesson plans while the selected segment falls
      // outside their validated hour coverage. Do not guess a lesson in that case.
      if (packageStart < segmentEndExclusive) return const [];
      consumedInSelectedWeek.update(
        block.id,
        (value) => value + segment.hours,
        ifAbsent: () => segment.hours,
      );
      weekHourCursor += segment.hours;
    }

    return List<WeeklyLessonPlanSelection>.unmodifiable(selections);
  }

  Future<WeeklyLessonPlanSelection?> selectionForInstructionOrdinal(
    AnnualOutcomePlan annualPlan,
    int instructionOrdinal,
  ) async {
    if (instructionOrdinal < 1) return null;
    var remaining = instructionOrdinal;
    for (final summary in annualPlan.weeks) {
      if (summary.week.isEventWeek) continue;
      final hours = summary.week.plannedLessonHours;
      if (remaining > hours) {
        remaining -= hours;
        continue;
      }
      final selections = await plansForWeek(
        annualPlan,
        summary.week.weekNumber,
      );
      for (final selection in selections) {
        if (selection.weekHour == remaining) return selection;
      }
      return null;
    }
    return null;
  }

  Future<LessonPlanPackage?> primaryPlanForWeek(
    AnnualOutcomePlan annualPlan,
    int weekNumber,
  ) async {
    final selections = await plansForWeek(annualPlan, weekNumber);
    return selections.isEmpty ? null : selections.first.package;
  }

  LessonPlanLesson? _lessonForPackageHour(
    LessonPlanPackage package,
    int packageHour,
  ) {
    var consumed = 0;
    for (final lesson in package.lessons) {
      final duration = lesson.durationLessonHours > 0
          ? lesson.durationLessonHours
          : 1;
      final end = consumed + duration;
      if (packageHour > consumed && packageHour <= end) return lesson;
      consumed = end;
    }
    return null;
  }

  int _consumedBlockHoursBefore(
    AnnualOutcomePlan annualPlan,
    int weekNumber,
    String blockId,
  ) {
    var consumed = 0;
    for (final summary in annualPlan.weeks) {
      if (summary.week.weekNumber >= weekNumber) break;
      for (final segment in summary.week.segments) {
        if (segment.block?.id == blockId) consumed += segment.hours;
      }
    }
    return consumed;
  }
}
