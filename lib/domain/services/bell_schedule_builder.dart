import '../models/instruction_context_models.dart';

/// The temporary inputs used to create a school's bell-period timetable.
///
/// The generated periods are the persisted source of truth. This configuration
/// is intentionally not stored separately so that editing a timetable never
/// creates a second, potentially stale representation of the same schedule.
class BellScheduleConfiguration {
  const BellScheduleConfiguration({
    required this.firstLessonStartMinute,
    required this.lessonCount,
    required this.lessonsBeforeLunch,
    required this.lunchBreakMinutes,
    required this.lessonDurationMinutes,
    this.passingBreakMinutes = 10,
  });

  final int firstLessonStartMinute;
  final int lessonCount;
  final int lessonsBeforeLunch;
  final int lunchBreakMinutes;
  final int lessonDurationMinutes;
  final int passingBreakMinutes;
}

/// Creates sequential bell periods from the small set of school-level inputs.
///
/// The ordinary passing break remains 10 minutes by default. The lunch break
/// is inserted after [BellScheduleConfiguration.lessonsBeforeLunch] periods.
List<BellPeriod> buildBellPeriods(BellScheduleConfiguration configuration) {
  _validateConfiguration(configuration);

  final periods = <BellPeriod>[];
  var startMinute = configuration.firstLessonStartMinute;
  for (var index = 0; index < configuration.lessonCount; index++) {
    final endMinute = startMinute + configuration.lessonDurationMinutes;
    if (endMinute > 24 * 60) {
      throw ArgumentError('Bell periods must end by midnight');
    }
    periods.add(
      BellPeriod(
        periodNumber: index + 1,
        startMinute: startMinute,
        endMinute: endMinute,
      ),
    );

    if (index == configuration.lessonCount - 1) continue;
    final isLunchBoundary = index + 1 == configuration.lessonsBeforeLunch;
    startMinute =
        endMinute +
        (isLunchBoundary
            ? configuration.lunchBreakMinutes
            : configuration.passingBreakMinutes);
  }
  return List.unmodifiable(periods);
}

void _validateConfiguration(BellScheduleConfiguration configuration) {
  if (configuration.firstLessonStartMinute < 0 ||
      configuration.firstLessonStartMinute >= 24 * 60) {
    throw ArgumentError.value(
      configuration.firstLessonStartMinute,
      'firstLessonStartMinute',
    );
  }
  if (configuration.lessonCount < 2) {
    throw ArgumentError.value(configuration.lessonCount, 'lessonCount');
  }
  if (configuration.lessonsBeforeLunch < 1 ||
      configuration.lessonsBeforeLunch >= configuration.lessonCount) {
    throw ArgumentError.value(
      configuration.lessonsBeforeLunch,
      'lessonsBeforeLunch',
    );
  }
  if (configuration.lunchBreakMinutes < 1 ||
      configuration.lunchBreakMinutes > 180) {
    throw ArgumentError.value(
      configuration.lunchBreakMinutes,
      'lunchBreakMinutes',
    );
  }
  if (configuration.lessonDurationMinutes < 1 ||
      configuration.lessonDurationMinutes > 180) {
    throw ArgumentError.value(
      configuration.lessonDurationMinutes,
      'lessonDurationMinutes',
    );
  }
  if (configuration.passingBreakMinutes < 0 ||
      configuration.passingBreakMinutes > 60) {
    throw ArgumentError.value(
      configuration.passingBreakMinutes,
      'passingBreakMinutes',
    );
  }
}
