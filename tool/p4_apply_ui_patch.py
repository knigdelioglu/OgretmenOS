from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/features/this_week/this_week_page.dart',
    "import '../outcomes/outcome_detail_page.dart';\n",
    "import '../lesson_plan/lesson_plan_panels.dart';\nimport '../outcomes/outcome_detail_page.dart';\n",
)
replace_once(
    'lib/features/this_week/this_week_page.dart',
    "          if (summary.week.isEventWeek) ...[\n",
    "          WeeklyLessonPlanPanel(\n"
    "            repository: widget.repository,\n"
    "            annualPlan: plan,\n"
    "            weekNumber: summary.week.weekNumber,\n"
    "          ),\n"
    "          if (summary.week.isEventWeek) ...[\n",
)

replace_once(
    'lib/features/block/block_detail_page.dart',
    "import '../shared/feature_widgets.dart';\n",
    "import '../lesson_plan/lesson_plan_panels.dart';\nimport '../shared/feature_widgets.dart';\n",
)
replace_once(
    'lib/features/block/block_detail_page.dart',
    "      const SectionHeading(\n        'Plan sırası',\n",
    "      BlockLessonPlanPanel(\n"
    "        repository: repository,\n"
    "        blockId: detail.block.id,\n"
    "      ),\n"
    "      const SectionHeading(\n"
    "        'Plan sırası',\n",
)

print('P4 UI integration patch applied.')
