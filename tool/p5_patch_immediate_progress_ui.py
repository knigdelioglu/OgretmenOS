from pathlib import Path

path = Path('lib/features/lesson_plan/lesson_plan_page.dart')
text = path.read_text()
replacements = [
    (
        "  late String _packageId;\n  late Future<_LessonPlanViewData> _future;",
        "  late String _packageId;\n  late Future<_LessonPlanViewData> _future;\n  LessonPlanProgressStatus? _localProgressStatus;",
    ),
    (
        "    setState(() {\n      _packageId = packageId;\n      _future = _load(packageId);\n    });",
        "    setState(() {\n      _packageId = packageId;\n      _localProgressStatus = null;\n      _future = _load(packageId);\n    });",
    ),
    (
        "      if (status == LessonPlanProgressStatus.completed) {\n        HapticFeedback.mediumImpact();\n      }\n      _reload();\n      showTeacherFeedback(context, '${status.teacherLabel} olarak kaydedildi.');",
        "      if (status == LessonPlanProgressStatus.completed) {\n        HapticFeedback.mediumImpact();\n      }\n      setState(() => _localProgressStatus = status);\n      showTeacherFeedback(context, '${status.teacherLabel} olarak kaydedildi.');",
    ),
    (
        "        return _LessonPlanContent(\n          data: snapshot.data!,\n          progressEnabled: _progressService != null,",
        "        return _LessonPlanContent(\n          data: snapshot.data!,\n          progressEnabled: _progressService != null,\n          progressStatusOverride: _localProgressStatus,",
    ),
    (
        "    required this.data,\n    required this.progressEnabled,\n    required this.onSetProgress,",
        "    required this.data,\n    required this.progressEnabled,\n    required this.progressStatusOverride,\n    required this.onSetProgress,",
    ),
    (
        "  final _LessonPlanViewData data;\n  final bool progressEnabled;",
        "  final _LessonPlanViewData data;\n  final bool progressEnabled;\n  final LessonPlanProgressStatus? progressStatusOverride;",
    ),
    (
        "            status:\n                data.progress?.status ?? LessonPlanProgressStatus.notStarted,",
        "            status: progressStatusOverride ??\n                data.progress?.status ??\n                LessonPlanProgressStatus.notStarted,",
    ),
]
for old, new in replacements:
    if old not in text:
        raise SystemExit(f'missing expected snippet: {old[:100]!r}')
    text = text.replace(old, new, 1)
path.write_text(text)
