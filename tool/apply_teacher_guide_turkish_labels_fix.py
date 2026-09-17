from pathlib import Path

VIEWER = Path("lib/features/resources/teacher_guide_viewer_page.dart")
TEST = Path("test/teacher_guide_viewer_test.dart")

OLD_HUMANIZE = """String _humanizeKey(String value) {
  final known = switch (value) {
    'canonical_ref' => 'Kaynak maddesi',
    'label' => 'Başlık',
    'value' => 'İçerik',
    _ => null,
  };
  if (known != null) return known;
  final normalized = value.replaceAll('_', ' ').trim();
  return normalized.isEmpty ? value : normalized;
}
"""

NEW_HUMANIZE = """String _humanizeKey(String value) {
  final key = value.trim();
  final known = switch (key) {
    'canonical_ref' => 'Kaynak maddesi',
    'label' => 'Başlık',
    'value' => 'İçerik',
    'book_prompt' => 'Kitaptaki soru / yönerge',
    'source_context' => 'Kaynak bağlamı',
    'expected_answer' => 'Beklenen cevap',
    'expected_response' => 'Beklenen cevap / öğrenci tepkisi',
    'acceptable_answers' => 'Kabul edilebilir cevaplar',
    'answer_explanation' => 'Cevabın açıklaması',
    'teacher_background' => 'Öğretmen için arka plan',
    'student_explanation' => 'Öğrenciye açıklama',
    'why_it_matters' => 'Neden önemli?',
    'teacher_moves' => 'Öğretmen adımları',
    'follow_up_questions' => 'Takip soruları',
    'common_misconceptions' => 'Yaygın yanlış anlamalar',
    'misconception_interventions' => 'Yanlış anlamalara müdahale',
    'evidence_anchor' => 'Kanıt dayanağı',
    'assessment_look_fors' => 'Değerlendirmede aranacaklar',
    'assessment_evidence' => 'Değerlendirme kanıtı',
    'support' => 'Destek',
    'enrichment' => 'Zenginleştirme',
    'board_notes' => 'Tahta notları',
    'source_limitations' => 'Kaynak sınırlılıkları',
    'source_locator' => 'Kaynak konumu',
    'source_locators' => 'Kaynak konumları',
    'prompt_mode' => 'Soru aktarım biçimi',
    'answer_component_keys' => 'Cevap bileşenleri',
    'review_status' => 'İnceleme durumu',
    'review_reason' => 'İnceleme gerekçesi',
    'generation_profile' => 'Üretim profili',
    'v3_profile' => 'Pedagoji profili',
    'v3_focus' => 'Pedagojik odak',
    'printed_page_range' => 'Basılı sayfa aralığı',
    'pdf_page_range' => 'PDF sayfa aralığı',
    'book_heading' => 'Kitap başlığı',
    'activity_id' => 'Etkinlik kimliği',
    'question_number' => 'Soru numarası',
    'group_id' => 'Grup kimliği',
    'parent_prompt_id' => 'Üst soru kimliği',
    'observations' => 'Gözlemler',
    'claim' => 'Yargı',
    'prompt' => 'Yönerge',
    'model' => 'Model',
    'force' => 'Kuvvet',
    'speed' => 'Hız',
    'temel_yaklasim' => 'Temel yaklaşım',
    'organizasyon' => 'Organizasyon',
    'kart_ornekleri' => 'Kart örnekleri',
    'paylasim' => 'Paylaşım',
    _ => null,
  };
  if (known != null) return known;

  final withoutQuestionPrefix = key.replaceFirst(RegExp(r'^q\\d+_'), '');
  final normalized = withoutQuestionPrefix.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return value;
  final words = normalized
      .split(RegExp(r'\\s+'))
      .map(_turkishizeKeyToken)
      .toList(growable: false);
  final humanized = words.join(' ');
  if (humanized.isEmpty) return value;
  return humanized[0].toUpperCase() + humanized.substring(1);
}

String _turkishizeKeyToken(String token) => switch (token.toLowerCase()) {
  'paylasim' => 'paylaşım',
  'ornek' => 'örnek',
  'ornekler' => 'örnekler',
  'ornekleri' => 'örnekleri',
  'surec' => 'süreç',
  'sureci' => 'süreci',
  'degisim' => 'değişim',
  'degisimi' => 'değişimi',
  'degerlendirme' => 'değerlendirme',
  'dusunce' => 'düşünce',
  'davranis' => 'davranış',
  'ogretmen' => 'öğretmen',
  'ogrenci' => 'öğrenci',
  'aciklama' => 'açıklama',
  'yaklasim' => 'yaklaşım',
  'kanit' => 'kanıt',
  'karsilastirma' => 'karşılaştırma',
  'ozet' => 'özet',
  'icerik' => 'içerik',
  'gorsel' => 'görsel',
  'gozlem' => 'gözlem',
  'gozlemler' => 'gözlemler',
  'baslik' => 'başlık',
  'baglam' => 'bağlam',
  'yonerge' => 'yönerge',
  'tanim' => 'tanım',
  _ => token,
};
"""

viewer_text = VIEWER.read_text(encoding="utf-8")
if NEW_HUMANIZE not in viewer_text:
    if OLD_HUMANIZE not in viewer_text:
        raise SystemExit("viewer _humanizeKey anchor not found")
    viewer_text = viewer_text.replace(OLD_HUMANIZE, NEW_HUMANIZE, 1)
    VIEWER.write_text(viewer_text, encoding="utf-8")

text = TEST.read_text(encoding="utf-8")
text = text.replace(
    "      expect(find.text('observations'), findsOneWidget);",
    "      expect(find.text('Gözlemler'), findsOneWidget);",
    1,
)

OLD_GUIDANCE = "    teacherGuidance: 'Değişkenleri sabit tut.',"
NEW_GUIDANCE = """    teacherGuidance: {
      'answer_explanation': 'Cevabın neden geçerli olduğunu açıkla.',
      'board_notes': ['Tahtaya temel ayrımı yaz.'],
      'follow_up_questions': ['Bu çıkarımı hangi kanıt destekliyor?'],
      'q4_paylasim': 'Ürünü uygun ortamda paylaş.',
    },"""
if NEW_GUIDANCE not in text:
    if OLD_GUIDANCE not in text:
        raise SystemExit("test teacherGuidance anchor not found")
    text = text.replace(OLD_GUIDANCE, NEW_GUIDANCE, 1)

TEST_NAME = "V3 alan adları kullanıcıya Türkçe etiketlerle gösterilir"
if TEST_NAME not in text:
    anchor = "  testWidgets('guide item exposes form deep-link and review summary', (\n"
    if anchor not in text:
        raise SystemExit("test insertion anchor not found")
    test_case = """  testWidgets('V3 alan adları kullanıcıya Türkçe etiketlerle gösterilir', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));

    await tester.pumpWidget(_viewerApp());
    await tester.pumpAndSettle();

    expect(find.text('Cevabın açıklaması'), findsOneWidget);
    expect(find.text('Tahta notları'), findsOneWidget);
    expect(find.text('Takip soruları'), findsOneWidget);
    expect(find.text('Paylaşım'), findsOneWidget);
    expect(find.text('answer explanation'), findsNothing);
    expect(find.text('board notes'), findsNothing);
    expect(find.text('follow up questions'), findsNothing);
    expect(find.textContaining('paylasim'), findsNothing);
    expect(tester.takeException(), isNull);
  });

"""
    text = text.replace(anchor, test_case + anchor, 1)

# The richer mock guidance makes this existing navigation test scroll farther
# after editing the note. Ensure the selector is actually on-screen before tap;
# this stabilizes the test without changing production behavior.
OLD_DROPDOWN_TAP = """    final unitDropdown = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.tap(unitDropdown);
"""
NEW_DROPDOWN_TAP = """    final unitDropdown = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(unitDropdown);
    await tester.pumpAndSettle();
    await tester.tap(unitDropdown);
"""
if NEW_DROPDOWN_TAP not in text:
    if OLD_DROPDOWN_TAP not in text:
        raise SystemExit("unit dropdown test anchor not found")
    text = text.replace(OLD_DROPDOWN_TAP, NEW_DROPDOWN_TAP, 1)

TEST.write_text(text, encoding="utf-8")
