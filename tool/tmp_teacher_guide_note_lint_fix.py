from pathlib import Path

path = Path('lib/features/resources/teacher_guide_viewer_page.dart')
text = path.read_text(encoding='utf-8')

old = '        return _saveNote();'
if text.count(old) != 1:
    raise SystemExit(f'expected one recursive save return, found {text.count(old)}')
text = text.replace(old, '        return await _saveNote();', 1)

old = 'notes.save(snapshot).onError((Object _, StackTrace __) {'
if text.count(old) != 1:
    raise SystemExit(f'expected one onError callback, found {text.count(old)}')
text = text.replace(
    old,
    'notes.save(snapshot).onError((Object _, StackTrace _) {',
    1,
)

path.write_text(text, encoding='utf-8')
