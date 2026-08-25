from pathlib import Path

path = Path('lib/features/annual_plan/annual_plan_page.dart')
text = path.read_text()
old = """  Future<_OptionalTrackingSummary?> _loadTrackingSummary() async {
    final service = widget.outcomePlanning;
    if (service == null) return null;
    try {
      final weeklyPlan = await service.weeklyPlanning.buildPlan();
      final records = await service.trackingRepository.getForAcademicYear(
        weeklyPlan.academicYear,
      );
      final summary = _OptionalTrackingSummary.fromRecords(records);
      return summary.hasExplicitStatus ? summary : null;
    } on Object {
      // Optional tracking summary must never block the annual lesson sequence.
      return null;
    }
  }
"""
new = """  Future<_OptionalTrackingSummary?> _loadTrackingSummary() async {
    final service = widget.outcomePlanning;
    if (service == null) return null;
    try {
      final plan = await service.buildPlan();
      final courseTrackingKeys = <String>{
        for (final week in plan.weeks)
          for (final item in week.outcomes) item.trackingKey,
      };
      final records = await service.trackingRepository.getForAcademicYear(
        plan.academicYear,
      );
      final scopedRecords = records
          .where(
            (record) => courseTrackingKeys.contains(
              '${record.academicYear}:${record.outcomeId}:${record.plannedWeekNumber}',
            ),
          )
          .toList();
      final summary = _OptionalTrackingSummary.fromRecords(scopedRecords);
      return summary.hasExplicitStatus ? summary : null;
    } on Object {
      // Optional tracking summary must never block the annual lesson sequence.
      return null;
    }
  }
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one tracking helper, found {count}')
path.write_text(text.replace(old, new, 1))
