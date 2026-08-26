from pathlib import Path

path = Path('lib/features/this_week/this_week_page.dart')
text = path.read_text()
replacements = [
    (
        "import '../../domain/repositories/course_knowledge_repository.dart';\nimport '../../domain/services/outcome_planning_service.dart';",
        "import '../../domain/repositories/course_knowledge_repository.dart';\nimport '../../domain/repositories/lesson_plan_progress_repository.dart';\nimport '../../domain/services/outcome_planning_service.dart';",
    ),
    (
        "    required this.service,\n    this.onOutcomeViewed,",
        "    required this.service,\n    this.lessonPlanProgress,\n    this.onOutcomeViewed,",
    ),
    (
        "  final CourseKnowledgeRepository repository;\n  final OutcomePlanningService service;\n  final Future<void> Function(TrackedOutcome item)? onOutcomeViewed;",
        "  final CourseKnowledgeRepository repository;\n  final OutcomePlanningService service;\n  final LessonPlanProgressRepository? lessonPlanProgress;\n  final Future<void> Function(TrackedOutcome item)? onOutcomeViewed;",
    ),
    (
        "          WeeklyLessonPlanPanel(\n            repository: widget.repository,\n            annualPlan: plan,\n            weekNumber: summary.week.weekNumber,\n          ),",
        "          WeeklyLessonPlanPanel(\n            repository: widget.repository,\n            annualPlan: plan,\n            weekNumber: summary.week.weekNumber,\n            progressRepository: widget.lessonPlanProgress,\n          ),",
    ),
]
for old, new in replacements:
    if old not in text:
        raise SystemExit(f'missing expected snippet: {old[:80]!r}')
    text = text.replace(old, new, 1)
path.write_text(text)
