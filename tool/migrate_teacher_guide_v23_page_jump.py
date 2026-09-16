#!/usr/bin/env python3
"""Add direct textbook-page navigation to the book-first Teacher Guide V2.3 viewer.

The migration is fail-fast and idempotent. It only touches the already-materialized
V2.3 viewer and its widget fixture; legacy/non-V2.3 behavior remains unchanged.
"""
from __future__ import annotations

import argparse
from pathlib import Path


class MigrationError(RuntimeError):
    pass


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise MigrationError(f"{label}:EXPECTED_ONCE:found={count}")
    return text.replace(old, new, 1)


def migrate_viewer(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "book-first-page-jump" in text:
        return False

    text = replace_once(
        text,
        "                children: [\n"
        "                  search,\n"
        "                  const SizedBox(height: AppSpacing.md),\n"
        "                  if (searchResults.isNotEmpty)\n",
        "                children: [\n"
        "                  search,\n"
        "                  if (data.isBookFirstV23) ...[\n"
        "                    const SizedBox(height: AppSpacing.sm),\n"
        "                    _bookFirstPageJump(data),\n"
        "                  ],\n"
        "                  const SizedBox(height: AppSpacing.md),\n"
        "                  if (searchResults.isNotEmpty)\n",
        "phone-page-jump",
    )

    text = replace_once(
        text,
        "                  child: search,\n"
        "                ),\n"
        "                if (searchResults.isNotEmpty)\n",
        "                  child: Column(\n"
        "                    crossAxisAlignment: CrossAxisAlignment.stretch,\n"
        "                    children: [\n"
        "                      search,\n"
        "                      if (data.isBookFirstV23) ...[\n"
        "                        const SizedBox(height: AppSpacing.sm),\n"
        "                        _bookFirstPageJump(data),\n"
        "                      ],\n"
        "                    ],\n"
        "                  ),\n"
        "                ),\n"
        "                if (searchResults.isNotEmpty)\n",
        "wide-page-jump",
    )

    page_jump_method = """  Widget _bookFirstPageJump(_GuideViewData data) {
    final targets = data.pageTargets;
    final selectedLocator = data.itemById(_selectedItemId)?.pageLocator?.trim();
    final currentValue = targets.any(
      (target) => target.locator == selectedLocator,
    )
        ? selectedLocator
        : null;
    return DropdownButtonFormField<String>(
      key: const ValueKey('book-first-page-jump'),
      initialValue: currentValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kitap sayfasına git',
        prefixIcon: Icon(Icons.menu_book_outlined),
      ),
      items: [
        for (final target in targets)
          DropdownMenuItem(
            value: target.locator,
            child: Text(
              's. ${target.locator} — ${target.title}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (locator) {
        if (locator == null) return;
        final target = targets
            .where((candidate) => candidate.locator == locator)
            .firstOrNull;
        final item = target == null ? null : data.itemById(target.itemId);
        if (item != null) unawaited(_selectItem(item, data));
      },
    );
  }

"""
    text = replace_once(
        text,
        "  Widget _phoneSelectors(BuildContext context, _GuideViewData data) {\n",
        page_jump_method
        + "  Widget _phoneSelectors(BuildContext context, _GuideViewData data) {\n",
        "page-jump-method",
    )

    page_targets = """  List<_GuidePageTarget> get pageTargets {
    final byLocator = <String, _GuidePageTarget>{};
    for (final section in sections) {
      for (final unit in section.units) {
        for (final item in unit.items) {
          final locator = item.pageLocator?.trim();
          if (locator == null || locator.isEmpty) continue;
          byLocator.putIfAbsent(
            locator,
            () => _GuidePageTarget(
              locator: locator,
              itemId: item.itemId,
              title: unit.unit.title,
            ),
          );
        }
      }
    }
    final result = byLocator.values.toList(growable: false)..sort((a, b) {
      final pageCompare = _pageSortKey(a.locator).compareTo(
        _pageSortKey(b.locator),
      );
      return pageCompare != 0 ? pageCompare : a.locator.compareTo(b.locator);
    });
    return result;
  }

"""
    text = replace_once(
        text,
        "  bool get isBookFirstV23 => items.any(_isBookFirstV23Item);\n}\n\nclass _ReviewSummary",
        page_targets
        + "  bool get isBookFirstV23 => items.any(_isBookFirstV23Item);\n"
        + "}\n\n"
        + "class _GuidePageTarget {\n"
        + "  const _GuidePageTarget({\n"
        + "    required this.locator,\n"
        + "    required this.itemId,\n"
        + "    required this.title,\n"
        + "  });\n\n"
        + "  final String locator;\n"
        + "  final String itemId;\n"
        + "  final String title;\n"
        + "}\n\n"
        + "class _ReviewSummary",
        "page-target-data",
    )

    text = replace_once(
        text,
        "String _itemTypeLabel(String value) => switch (value.trim().toUpperCase()) {\n",
        "int _pageSortKey(String value) {\n"
        "  final match = RegExp(r'\\d+').firstMatch(value);\n"
        "  return int.tryParse(match?.group(0) ?? '') ?? 1 << 30;\n"
        "}\n\n"
        "String _itemTypeLabel(String value) => switch (value.trim().toUpperCase()) {\n",
        "page-sort-key",
    )

    path.write_text(text, encoding="utf-8")
    return True


def migrate_test(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "book-first page jump follows printed-page order" in text:
        return False

    test_anchor = """      expect(find.text('Belirtilmemiş'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
"""
    test_addition = test_anchor + """

  testWidgets(
    'book-first page jump follows printed-page order and opens the page item',
    (tester) async {
      _useSize(tester, const Size(412, 915));

      await tester.pumpWidget(_viewerApp(bookFirst: true));
      await tester.pumpAndSettle();

      final pageJump = find.byKey(const ValueKey('book-first-page-jump'));
      expect(pageJump, findsOneWidget);
      expect(find.text('Kitap sayfasına git'), findsOneWidget);
      expect(
        find.text('Soru 1 — Edebî eser gerçek hayatı nasıl yansıtır?'),
        findsOneWidget,
      );

      await tester.tap(pageJump);
      await tester.pumpAndSettle();
      expect(find.textContaining('s. 15 —'), findsOneWidget);
      await tester.tap(find.textContaining('s. 15 —').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Soru 2 — Edebî dil iletişimi nasıl etkiler?'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
"""
    text = replace_once(text, test_anchor, test_addition, "page-jump-test")

    item_anchor = """  static const teacherPackage = model.TeacherPackage(
"""
    second_item = """  static const bookFirstItemTwo = TeacherGuideItem(
    itemId: '__v23_item__T1_TEST_Q02',
    unitId: 'UNIT_OBSERVATION',
    order: 2,
    title: 'Soru 2 — Edebî dil iletişimi nasıl etkiler?',
    label: 'Konuya Başlarken',
    itemType: 'QUESTION',
    pageLocator: '15',
    sourceLocator: 'official_textbook_pdf#printed-p15',
    contentStatus: 'VERIFIED',
    expectedResponse: {
      'temel_yaklasim': 'Edebî dil anlamı ve iletişim biçimini zenginleştirir.',
    },
    acceptanceCriteria: [],
    teacherGuidance: [],
    commonMisconceptions: [],
    assessmentEvidence: [],
    differentiation: TeacherGuideDifferentiation(support: [], enrichment: []),
    provenance: TeacherGuideProvenance(
      sourceIds: ['official_textbook_pdf'],
      sourceLocators: ['basılı s.15'],
      contentClass: 'BOOK_FIRST_V2_3_ITEM',
      additional: {
        'architecture_version': '2.3.0',
        'prompt_mode': 'VERIFIED_SUMMARY',
        'rights_mode': 'PAGE_REFERENCE',
      },
    ),
    canonicalPayloadSha256:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  );

"""
    text = replace_once(
        text,
        item_anchor,
        second_item + item_anchor,
        "second-book-first-item",
    )

    text = replace_once(
        text,
        "      return bookFirst ? const [bookFirstItem] : const [observation];\n",
        "      return bookFirst\n"
        "          ? const [bookFirstItem, bookFirstItemTwo]\n"
        "          : const [observation];\n",
        "book-first-items-list",
    )

    text = replace_once(
        text,
        "    final items = bookFirst\n"
        "        ? const [bookFirstItem]\n"
        "        : const [observation, modelItem];\n",
        "    final items = bookFirst\n"
        "        ? const [bookFirstItem, bookFirstItemTwo]\n"
        "        : const [observation, modelItem];\n",
        "book-first-item-lookup",
    )

    path.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()
    root = Path(args.repo_root).resolve()
    viewer = root / "lib/features/resources/teacher_guide_viewer_page.dart"
    test = root / "test/teacher_guide_viewer_test.dart"
    updated_viewer = migrate_viewer(viewer)
    updated_test = migrate_test(test)
    status = "UPDATED" if updated_viewer or updated_test else "ALREADY_CURRENT"
    print(f"TEACHER_GUIDE_V23_PAGE_JUMP_MIGRATION: {status}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
