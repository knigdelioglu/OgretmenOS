from pathlib import Path

path = Path('lib/app/app.dart')
text = path.read_text()
old = '''      AnnualPlanPage(
        repository: repository,
        preferences: widget.dependencies.preferences,
        continuity: _continuity,
        lessonPlanProgress: _lessonPlanProgress,
        courseId: widget.activeCourseId,
        outcomePlanning: _outcomePlanning,
      ),'''
new = '''      AnnualPlanPage(
        repository: repository,
        preferences: widget.dependencies.preferences,
        continuity: _continuity,
        courseId: widget.activeCourseId,
        outcomePlanning: _outcomePlanning,
      ),'''
if old not in text:
    raise SystemExit('AnnualPlanPage P5 snippet not found')
path.write_text(text.replace(old, new, 1))
