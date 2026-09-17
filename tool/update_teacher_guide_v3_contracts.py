#!/usr/bin/env python3
"""Update source-level OgretmenOS tests to the materialized TDE11 V3 runtime contract.

The migration is deliberately idempotent because the runtime publishing workflow runs it
both before and after rebasing the generated commit onto the latest main branch.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "test" / "teacher_guide_repository_test.dart"

text = PATH.read_text(encoding="utf-8")
replacements = {
    "final bookFirstRaw = capabilities['book_first_v23'];": "final bookFirstRaw = capabilities['book_first_v3'];",
    "'20860e3165d5e9de18913364286e6f89f28f6046',": "'bb345b0c51074aa351b1b88b6b889cebf6a2af48',",
    "expect(bookFirst['architecture_version'], '2.3.0');": "expect(bookFirst['architecture_version'], '3.0.0');",
    "expect(bookFirst['projection_version'], '1.2.0+book-first-v2.3-snapshot');": "expect(bookFirst['projection_version'], '1.0.0+textbook-first-v3-snapshot');",
    "expect(bookFirst['entries'], 573);": "expect(bookFirst['entries'], 576);",
    "expect(bookFirst['questions'], 404);": "expect(bookFirst['questions'], 407);",
    "expect(capability.itemCount, 573);": "expect(capability.itemCount, 576);",
    "expect(capability.relationCount, 7547);": "expect(capability.relationCount, manifest.rowCounts['teacher_guide_item_relations']);",
    "      573,\n    );": "      576,\n    );",
    "      404,\n    );": "      407,\n    );",
}

changed = False
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)
        changed = True
    elif new in text:
        continue
    else:
        raise SystemExit(f"expected old or migrated contract text missing: {old!r}")

if changed:
    PATH.write_text(text, encoding="utf-8")
    print("TDE11 V3 repository test contract updated")
else:
    print("TDE11 V3 repository test contract already current")
