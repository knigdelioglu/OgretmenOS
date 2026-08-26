import '../models/lesson_plan_models.dart';
import '../models/outcome_tracking_models.dart';
import '../repositories/course_knowledge_repository.dart';

class WeeklyLessonPlanSelection {
  const WeeklyLessonPlanSelection({
    required this.package,
    required this.weekNumber,
    required this.blockId,
    required this.segmentHours,
    required this.segmentStartHour,
    required this.segmentEndHour,
    required this.packageStartHour,
    required this.packageEndHour,
  });

  final LessonPlanPackage package;
  final int weekNumber;
  final String blockId;
  final int segmentHours;

  /// 1-based inclusive hour range of this week's segment inside the block.
  final int segmentStartHour;
  final int segmentEndHour;

  /// 1-based inclusive hour range covered by the package inside the block.
  final int packageStartHour;
  final int packageEndHour;

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
    final seenPackages = <String>{};

    for (final segment in summary.week.segments) {
      final block = segment.block;
      if (block == null || segment.hours <= 0) continue;

      final consumedBefore = _consumedBlockHoursBefore(
        annualPlan,
        weekNumber,
        block.id,
      );
      final segmentEndExclusive = consumedBefore + segment.hours;
      final packages = await repository.getLessonPlansForBlock(block.id);
      if (packages.isEmpty) return const [];

      var packageStart = 0;
      for (final package in packages) {
        if (package.lessonHours <= 0 || package.validationStatus != 'PASS') {
          return const [];
        }
        final packageEndExclusive = packageStart + package.lessonHours;
        final overlaps =
            packageStart < segmentEndExclusive &&
            packageEndExclusive > consumedBefore;
        if (overlaps && seenPackages.add(package.packageId)) {
          selections.add(
            WeeklyLessonPlanSelection(
              package: package,
              weekNumber: weekNumber,
              blockId: block.id,
              segmentHours: segment.hours,
              segmentStartHour: consumedBefore + 1,
              segmentEndHour: segmentEndExclusive,
              packageStartHour: packageStart + 1,
              packageEndHour: packageEndExclusive,
            ),
          );
        }
        packageStart = packageEndExclusive;
      }

      // The runtime may advertise lesson plans while the selected segment falls
      // outside their validated hour coverage. Do not guess a package in that case.
      if (packageStart < segmentEndExclusive) return const [];
    }

    return List<WeeklyLessonPlanSelection>.unmodifiable(selections);
  }

  Future<LessonPlanPackage?> primaryPlanForWeek(
    AnnualOutcomePlan annualPlan,
    int weekNumber,
  ) async {
    final selections = await plansForWeek(annualPlan, weekNumber);
    return selections.isEmpty ? null : selections.first.package;
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
