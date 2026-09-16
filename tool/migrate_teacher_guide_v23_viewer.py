#!/usr/bin/env python3
"""Materialize the Teacher Guide V2.3 book-first viewer refinements.

The migration is deliberately textual and fail-fast: every replacement is pinned to the
current generic viewer/test shape so future drift cannot silently produce a partial UI.
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
    if "String _expectedResponseTitle(TeacherGuideItem item)" in text:
        return False

    text = replace_once(
        text,
        "            decoration: const InputDecoration(labelText: 'Ünite'),",
        "            decoration: InputDecoration(\n"
        "              labelText: data.isBookFirstV23 ? 'Sayfa / etkinlik' : 'Ünite',\n"
        "            ),",
        "phone-unit-label",
    )

    text = replace_once(
        text,
        "  TeacherGuideItem? itemById(String? itemId) => itemId == null\n"
        "      ? null\n"
        "      : items.where((value) => value.itemId == itemId).firstOrNull;\n",
        "  TeacherGuideItem? itemById(String? itemId) => itemId == null\n"
        "      ? null\n"
        "      : items.where((value) => value.itemId == itemId).firstOrNull;\n\n"
        "  bool get isBookFirstV23 => items.any(_isBookFirstV23Item);\n",
        "guide-data-v23-flag",
    )

    text = replace_once(
        text,
        "    final scheme = Theme.of(context).colorScheme;\n\n"
        "    return Card.outlined(",
        "    final scheme = Theme.of(context).colorScheme;\n"
        "    final bookFirst = data.isBookFirstV23;\n\n"
        "    return Card.outlined(",
        "review-summary-book-first-flag",
    )

    text = replace_once(
        text,
        "            Icon(\n"
        "              needsReview\n"
        "                  ? Icons.rate_review_outlined\n"
        "                  : Icons.verified_outlined,\n"
        "              color: needsReview ? scheme.error : scheme.primary,\n"
        "            ),",
        "            Icon(\n"
        "              bookFirst\n"
        "                  ? Icons.fact_check_outlined\n"
        "                  : needsReview\n"
        "                  ? Icons.rate_review_outlined\n"
        "                  : Icons.verified_outlined,\n"
        "              color: bookFirst\n"
        "                  ? scheme.tertiary\n"
        "                  : needsReview\n"
        "                  ? scheme.error\n"
        "                  : scheme.primary,\n"
        "            ),",
        "review-summary-icon",
    )

    text = replace_once(
        text,
        "                  Text(\n"
        "                    needsReview\n"
        "                        ? 'İnceleme durumu: Öğretmen incelemesi gerekli'\n"
        "                        : 'İnceleme durumu: Doğrulandı',\n"
        "                    style: Theme.of(context).textTheme.titleSmall?.copyWith(\n"
        "                      fontWeight: FontWeight.w700,\n"
        "                      color: needsReview ? scheme.error : scheme.primary,\n"
        "                    ),\n"
        "                  ),",
        "                  Text(\n"
        "                    bookFirst\n"
        "                        ? needsReview\n"
        "                              ? 'Kaynak denetimi sürüyor'\n"
        "                              : 'Kitap odaklı rehber doğrulandı'\n"
        "                        : needsReview\n"
        "                        ? 'İnceleme durumu: Öğretmen incelemesi gerekli'\n"
        "                        : 'İnceleme durumu: Doğrulandı',\n"
        "                    style: Theme.of(context).textTheme.titleSmall?.copyWith(\n"
        "                      fontWeight: FontWeight.w700,\n"
        "                      color: bookFirst\n"
        "                          ? scheme.tertiary\n"
        "                          : needsReview\n"
        "                          ? scheme.error\n"
        "                          : scheme.primary,\n"
        "                    ),\n"
        "                  ),",
        "review-summary-title",
    )

    text = replace_once(
        text,
        "    final enrichment =\n"
        "        item.provenance.contentClass?.toUpperCase() == 'PEDAGOGICAL_ENRICHMENT';\n",
        "    final enrichment =\n"
        "        item.provenance.contentClass?.toUpperCase() == 'PEDAGOGICAL_ENRICHMENT';\n"
        "    final bookFirst = _isBookFirstV23Item(item);\n",
        "item-detail-book-first-flag",
    )

    text = replace_once(
        text,
        "            if (item.contentStatus.toUpperCase() == 'REVIEW_REQUIRED')\n"
        "              const _ReviewBadge(),",
        "            if (item.contentStatus.toUpperCase() == 'REVIEW_REQUIRED')\n"
        "              _ReviewBadge(bookFirst: bookFirst),",
        "item-review-badge",
    )

    text = replace_once(
        text,
        "        _ContentBlock(\n"
        "          title: 'Beklenen cevap / öğrenci tepkisi',\n"
        "          icon: Icons.forum_outlined,\n"
        "          value: item.expectedResponse,\n"
        "        ),\n"
        "        _ContentBlock(\n"
        "          title: 'Öğretmene not',\n"
        "          icon: Icons.lightbulb_outline,\n"
        "          value: item.teacherGuidance,\n"
        "        ),",
        "        if (_hasContent(item.expectedResponse))\n"
        "          _ContentBlock(\n"
        "            title: _expectedResponseTitle(item),\n"
        "            icon: Icons.forum_outlined,\n"
        "            value: item.expectedResponse,\n"
        "          )\n"
        "        else if (_isSourceBoundUnanswered(item))\n"
        "          const _SourceBoundAnswerNotice(),\n"
        "        if (_hasContent(item.teacherGuidance))\n"
        "          _ContentBlock(\n"
        "            title: bookFirst ? 'Öğretmen yönlendirmesi' : 'Öğretmene not',\n"
        "            icon: Icons.lightbulb_outline,\n"
        "            value: item.teacherGuidance,\n"
        "          ),",
        "selective-primary-content",
    )

    detail_old = """              _ContentBlock(
                title: 'Kabul ölçütleri',
                value: item.acceptanceCriteria,
              ),
              _ContentBlock(
                title: 'Sık yapılan hata',
                value: item.commonMisconceptions,
              ),
              _ContentBlock(
                title: 'Değerlendirme kanıtı',
                value: item.assessmentEvidence,
              ),
              _ContentBlock(
                title: 'Destek',
                value: item.differentiation.support,
              ),
              _ContentBlock(
                title: 'Zenginleştirme',
                value: item.differentiation.enrichment,
              ),
              _ProvenanceBlock(provenance: item.provenance),"""
    detail_new = """              if (_hasContent(item.acceptanceCriteria))
                _ContentBlock(
                  title: 'Kabul ölçütleri',
                  value: item.acceptanceCriteria,
                ),
              if (_hasContent(item.commonMisconceptions))
                _ContentBlock(
                  title: 'Sık yapılan hata',
                  value: item.commonMisconceptions,
                ),
              if (_hasContent(item.assessmentEvidence))
                _ContentBlock(
                  title: 'Değerlendirme kanıtı',
                  value: item.assessmentEvidence,
                ),
              if (_hasContent(item.differentiation.support))
                _ContentBlock(
                  title: 'Destek',
                  value: item.differentiation.support,
                ),
              if (_hasContent(item.differentiation.enrichment))
                _ContentBlock(
                  title: 'Zenginleştirme',
                  value: item.differentiation.enrichment,
                ),
              _ProvenanceBlock(provenance: item.provenance),"""
    text = replace_once(text, detail_old, detail_new, "selective-detail-content")

    text = replace_once(
        text,
        "                  Text(\n"
        "                    entry.key.toString(),\n"
        "                    style: Theme.of(context).textTheme.labelLarge,\n"
        "                  ),",
        "                  Text(\n"
        "                    _humanizeKey(entry.key.toString()),\n"
        "                    style: Theme.of(context).textTheme.labelLarge,\n"
        "                  ),",
        "humanize-json-keys",
    )

    review_badge_old = """class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge();

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.rate_review_outlined, size: 16),
    label: const Text('Öğretmen incelemesi gerekli'),
  );
}
"""
    review_badge_new = """class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({this.bookFirst = false});

  final bool bookFirst;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      bookFirst ? Icons.fact_check_outlined : Icons.rate_review_outlined,
      size: 16,
    ),
    label: Text(bookFirst ? 'Kaynak kontrolü' : 'Öğretmen incelemesi gerekli'),
  );
}

class _SourceBoundAnswerNotice extends StatelessWidget {
  const _SourceBoundAnswerNotice();

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.image_search_outlined, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Cevap, ders kitabındaki görsel veya kaynak katmanına bağlı. '
              'Rehber doğrulanmamış bir cevap üretmez; kabul ölçütü ve kaynak '
              'bilgisi Ayrıntılar bölümünde gösterilir.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}
"""
    text = replace_once(text, review_badge_old, review_badge_new, "review-badge-widget")

    helpers_old = """bool _isReviewStatus(String value) =>
    value.trim().toUpperCase() == 'REVIEW_REQUIRED';

String _itemTypeLabel(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'İçerik';
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}
"""
    helpers_new = """bool _isReviewStatus(String value) =>
    value.trim().toUpperCase() == 'REVIEW_REQUIRED';

bool _isBookFirstV23Item(TeacherGuideItem item) =>
    item.provenance.contentClass?.trim().toUpperCase() == 'BOOK_FIRST_V2_3_ITEM';

bool _hasContent(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

bool _isSourceBoundUnanswered(TeacherGuideItem item) =>
    _isBookFirstV23Item(item) &&
    item.itemType.trim().toUpperCase() == 'QUESTION' &&
    !_hasContent(item.expectedResponse) &&
    item.provenance.additional['rights_mode'] == 'PAGE_REFERENCE';

String _expectedResponseTitle(TeacherGuideItem item) {
  if (!_isBookFirstV23Item(item)) return 'Beklenen cevap / öğrenci tepkisi';
  return switch (item.itemType.trim().toUpperCase()) {
    'QUESTION' => 'Cevap / kabul edilebilir yaklaşım',
    'PROCESS' => 'Uygulama / beklenen süreç',
    'REFERENCE' => 'Başvuru bilgisi',
    'VOCABULARY' => 'Söz varlığı / açıklama',
    'TABLE' => 'Tablo / örnek çözüm',
    'COMPARISON' => 'Karşılaştırma',
    'ASSESSMENT' => 'Değerlendirme anahtarı',
    _ => 'Beklenen çıktı',
  };
}

String _humanizeKey(String value) {
  final known = switch (value) {
    'canonical_ref' => 'Kaynak maddesi',
    'label' => 'Başlık',
    'value' => 'İçerik',
    _ => null,
  };
  if (known != null) return known;
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return value;
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _itemTypeLabel(String value) => switch (value.trim().toUpperCase()) {
  'QUESTION' => 'Soru',
  'PROCESS' => 'Süreç',
  'REFERENCE' => 'Kaynak',
  'VOCABULARY' => 'Söz varlığı',
  'TABLE' => 'Tablo',
  'COMPARISON' => 'Karşılaştırma',
  'ASSESSMENT' => 'Değerlendirme',
  _ => () {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'İçerik';
    return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
  }(),
};
"""
    text = replace_once(text, helpers_old, helpers_new, "book-first-helpers")

    path.write_text(text, encoding="utf-8")
    return True


def migrate_test(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "book-first V2.3 hides empty pedagogy" in text:
        return False

    test_anchor = """  testWidgets('failed note save is visible instead of silent loss', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));
    final notes = _MemoryNotes(failSaves: true);

    await tester.pumpWidget(
      _viewerApp(assignmentId: 'assignment-A', notes: notes),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Kaydedilemeyen not');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.textContaining('Not kaydedilemedi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
"""
    test_addition = test_anchor + """

  testWidgets(
    'book-first V2.3 hides empty pedagogy and uses textbook-first labels',
    (tester) async {
      _useSize(tester, const Size(412, 915));

      await tester.pumpWidget(_viewerApp(bookFirst: true));
      await tester.pumpAndSettle();

      expect(find.text('Sayfa / etkinlik'), findsOneWidget);
      expect(find.text('Soru'), findsOneWidget);
      expect(find.text('Cevap / kabul edilebilir yaklaşım'), findsOneWidget);
      expect(find.text('Kaynak kontrolü'), findsWidgets);
      expect(find.text('Kaynak denetimi sürüyor'), findsOneWidget);
      expect(find.text('Öğretmene not'), findsNothing);
      expect(find.text('Öğretmen yönlendirmesi'), findsNothing);
      expect(find.text('Belirtilmemiş'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
"""
    text = replace_once(text, test_anchor, test_addition, "v23-widget-test")

    text = replace_once(
        text,
        "Widget _viewerApp({String? assignmentId, _MemoryNotes? notes}) => MaterialApp(\n"
        "  home: TeacherGuideViewerPage(\n"
        "    repository: _GuideRepository(),",
        "Widget _viewerApp({\n"
        "  String? assignmentId,\n"
        "  _MemoryNotes? notes,\n"
        "  bool bookFirst = false,\n"
        "}) => MaterialApp(\n"
        "  home: TeacherGuideViewerPage(\n"
        "    repository: _GuideRepository(bookFirst: bookFirst),",
        "viewer-app-book-first",
    )

    text = replace_once(
        text,
        "  _GuideRepository({this.guideAvailable = true, this.templateStatus});\n\n"
        "  final bool guideAvailable;\n"
        "  final FormTemplateStatus? templateStatus;",
        "  _GuideRepository({\n"
        "    this.guideAvailable = true,\n"
        "    this.templateStatus,\n"
        "    this.bookFirst = false,\n"
        "  });\n\n"
        "  final bool guideAvailable;\n"
        "  final FormTemplateStatus? templateStatus;\n"
        "  final bool bookFirst;",
        "repository-book-first-field",
    )

    model_item_anchor = """  static const modelItem = TeacherGuideItem(
    itemId: 'ITEM_MODEL',
    unitId: 'UNIT_MODEL',
    order: 2,
    title: 'Modeli değiştir',
    label: 'Modeli değiştir',
    itemType: 'INVESTIGATION',
    pageLocator: '43',
    sourceLocator: 'physics_textbook#43',
    contentStatus: 'VERIFIED',
    expectedResponse: {'model': 'değişken'},
    acceptanceCriteria: ['Yeni model açıklanır.'],
    teacherGuidance: 'Grafik ile değişkeni karşılaştır.',
    commonMisconceptions: null,
    assessmentEvidence: ['model açıklaması'],
    differentiation: TeacherGuideDifferentiation(
      support: ['Örnek grafik ver.'],
      enrichment: ['İkinci değişken ekle.'],
    ),
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 43'],
      contentClass: 'PEDAGOGICAL_ENRICHMENT',
    ),
    canonicalPayloadSha256: 'model-hash',
  );
"""
    v23_item = model_item_anchor + """

  static const bookFirstItem = TeacherGuideItem(
    itemId: '__v23_item__T1_TEST_Q01',
    unitId: 'UNIT_OBSERVATION',
    order: 1,
    title: 'Soru 1 — Edebî eser gerçek hayatı nasıl yansıtır?',
    label: 'Konuya Başlarken',
    itemType: 'QUESTION',
    pageLocator: '14',
    sourceLocator: 'official_textbook_pdf#printed-p14',
    contentStatus: 'REVIEW_REQUIRED',
    expectedResponse: {
      'temel_yaklasim': 'Edebî eser hayatı seçerek ve dönüştürerek yansıtır.',
    },
    acceptanceCriteria: [],
    teacherGuidance: [],
    commonMisconceptions: [],
    assessmentEvidence: [],
    differentiation: TeacherGuideDifferentiation(
      support: [],
      enrichment: [],
    ),
    provenance: TeacherGuideProvenance(
      sourceIds: ['official_textbook_pdf'],
      sourceLocators: ['basılı s.14'],
      contentClass: 'BOOK_FIRST_V2_3_ITEM',
      additional: {
        'architecture_version': '2.3.0',
        'prompt_mode': 'VERIFIED_SUMMARY',
        'rights_mode': 'PAGE_REFERENCE',
      },
    ),
    canonicalPayloadSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );
"""
    text = replace_once(text, model_item_anchor, v23_item, "book-first-fixture")

    text = replace_once(
        text,
        "  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async =>\n"
        "      sectionId == section.sectionId && guideAvailable\n"
        "      ? const [unit, modelUnit]\n"
        "      : [];",
        "  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async =>\n"
        "      sectionId == section.sectionId && guideAvailable\n"
        "      ? bookFirst\n"
        "            ? const [unit]\n"
        "            : const [unit, modelUnit]\n"
        "      : [];",
        "book-first-units",
    )

    text = replace_once(
        text,
        "  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async {\n"
        "    if (!guideAvailable) return const [];\n"
        "    if (unitId == unit.unitId) return const [observation];\n"
        "    if (unitId == modelUnit.unitId) return const [modelItem];\n"
        "    return const [];\n"
        "  }",
        "  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async {\n"
        "    if (!guideAvailable) return const [];\n"
        "    if (unitId == unit.unitId) {\n"
        "      return bookFirst ? const [bookFirstItem] : const [observation];\n"
        "    }\n"
        "    if (!bookFirst && unitId == modelUnit.unitId) return const [modelItem];\n"
        "    return const [];\n"
        "  }",
        "book-first-items",
    )

    text = replace_once(
        text,
        "  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId) async =>\n"
        "      guideAvailable ? _itemById(itemId) : null;",
        "  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId) async =>\n"
        "      guideAvailable ? _itemById(itemId) : null;",
        "book-first-get-item-anchor",
    )

    text = replace_once(
        text,
        "  TeacherGuideItem? _itemById(String itemId) {\n"
        "    for (final item in const [observation, modelItem]) {\n"
        "      if (item.itemId == itemId) return item;\n"
        "    }\n"
        "    return null;\n"
        "  }",
        "  TeacherGuideItem? _itemById(String itemId) {\n"
        "    final items = bookFirst\n"
        "        ? const [bookFirstItem]\n"
        "        : const [observation, modelItem];\n"
        "    for (final item in items) {\n"
        "      if (item.itemId == itemId) return item;\n"
        "    }\n"
        "    return null;\n"
        "  }",
        "book-first-item-by-id",
    )

    path.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--viewer",
        type=Path,
        default=Path("lib/features/resources/teacher_guide_viewer_page.dart"),
    )
    parser.add_argument(
        "--test",
        type=Path,
        default=Path("test/teacher_guide_viewer_test.dart"),
    )
    args = parser.parse_args()
    viewer_changed = migrate_viewer(args.viewer.resolve())
    test_changed = migrate_test(args.test.resolve())
    state = "UPDATED" if viewer_changed or test_changed else "ALREADY_CURRENT"
    print(f"TEACHER_GUIDE_V23_VIEWER_MIGRATION: {state}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
