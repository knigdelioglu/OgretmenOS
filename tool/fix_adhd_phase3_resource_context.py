from pathlib import Path

path = Path('lib/features/resources/resource_library_page.dart')
text = path.read_text()
old = '              context.eyebrow,\n'
new = '              this.context.eyebrow,\n'
if text.count(old) != 1:
    raise SystemExit(f'expected one eyebrow shadowing match, found {text.count(old)}')
path.write_text(text.replace(old, new, 1))
