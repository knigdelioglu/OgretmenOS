#!/usr/bin/env python3
"""Normalize the V2.3 viewer migration without changing legacy guide key casing."""
from __future__ import annotations

from pathlib import Path

PATH = Path("lib/features/resources/teacher_guide_viewer_page.dart")
OLD = """  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return value;
  return normalized[0].toUpperCase() + normalized.substring(1);
}"""
NEW = """  final normalized = value.replaceAll('_', ' ').trim();
  return normalized.isEmpty ? value : normalized;
}"""


def main() -> int:
    text = PATH.read_text(encoding="utf-8")
    if NEW in text:
        print("TEACHER_GUIDE_V23_VIEWER_KEY_NORMALIZATION: ALREADY_CURRENT")
        return 0
    count = text.count(OLD)
    if count != 1:
        raise SystemExit(
            f"TEACHER_GUIDE_V23_VIEWER_KEY_NORMALIZATION: EXPECTED_ONCE found={count}"
        )
    PATH.write_text(text.replace(OLD, NEW, 1), encoding="utf-8")
    print("TEACHER_GUIDE_V23_VIEWER_KEY_NORMALIZATION: UPDATED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
