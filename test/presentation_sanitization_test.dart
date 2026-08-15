import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/features/shared/teacher_presentation.dart';

void main() {
  test('teacher presentation maps machine codes to teacher language', () {
    expect(teacherResourcePriorityLabel('REQUIRED'), 'Gerekli');
    expect(teacherResourcePriorityLabel('RECOMMENDED'), 'Önerilen');
    expect(teacherResourcePriorityLabel('NOT_NEEDED'), isNull);
    expect(
      teacherTextbookCoverageLabel('PARTIALLY_COVERED'),
      'Ders kitabı kısmen karşılıyor',
    );
    expect(
      teacherBlockTimeLabel('ORDER_ONLY'),
      'Bu blok için yalnız plan sırası kullanılabilir.',
    );
    expect(
      teacherEvaluatorLabel('student_self'),
      'Öğrenci öz değerlendirmesi',
    );
    expect(teacherEvaluatorLabel('UNKNOWN_EVALUATOR'), isNull);
  });

  test('technical locator is reduced to useful page information', () {
    final label = teacherLocatorLabel(
      '9edb.pdf, s. 125-128 (PDF: 126-129), T2_ACT_08_KONUSMA_SIRASI',
    );

    expect(label, contains('Ders kitabı s. 125-128'));
    expect(label, contains('PDF s. 126-129'));
    expect(label, isNot(contains('T2_ACT_08')));
    expect(label, isNot(contains('9edb.pdf')));
  });

  test('source subtitle never exposes entity ids', () {
    const source = SourceReference(
      id: 'SRC_TEXTBOOK',
      sourceType: 'textbook',
      title: 'Türk Dili ve Edebiyatı 9 Ders Kitabı',
      locator: '9edb.pdf, s. 76-99 (PDF: 77-100), T2_ACT_01',
      provenanceCategory: 'PRIMARY',
      authorityRank: 1,
      verificationStatus: 'PASS',
      entityLocator: 'TEMA_02',
    );

    final subtitle = teacherSourceSubtitle(source);
    expect(subtitle, contains('Ders kitabı'));
    expect(subtitle, isNot(contains('TEMA_02')));
    expect(subtitle, isNot(contains('T2_ACT_01')));
    expect(subtitle, isNot(contains('SRC_TEXTBOOK')));
  });

  testWidgets('resource decision card hides runtime machine codes', (tester) async {
    const decision = ResourceDecision(
      id: 'RES_T2_08',
      themeId: 'TEMA_02',
      needId: 'NEED_T2_K4',
      resourceType: 'assessment_support',
      decisionCode: 'GENERATE_ASSESSMENT_SUPPORT',
      appCategory: 'ADDITIONAL_SUPPORT_REQUIRED',
      priority: 'REQUIRED',
      purpose: 'Konuşma performansı için değerlendirme desteği sağlamak.',
      expectedEvidence: 'Öğretmen puanlama çıktısı.',
      textbookCoverage: 'PARTIALLY_COVERED',
      locator: '9edb.pdf, s. 305 (PDF: 306), FORM_BOB_04_T2_KONUSMA_OZ',
      teacherReviewRequired: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherResourceDecisionCard(decision: decision),
          ),
        ),
      ),
    );

    expect(find.text('Ek destek gerekli'), findsOneWidget);
    expect(find.text('Gerekli'), findsOneWidget);
    expect(find.text('Ders kitabı kısmen karşılıyor'), findsOneWidget);
    expect(find.textContaining('Ders kitabı s. 305'), findsOneWidget);

    expect(find.textContaining('PARTIALLY_COVERED'), findsNothing);
    expect(find.textContaining('GENERATE_ASSESSMENT_SUPPORT'), findsNothing);
    expect(find.textContaining('NEED_T2_K4'), findsNothing);
    expect(find.textContaining('FORM_BOB_04'), findsNothing);
    expect(find.textContaining('RES_T2_08'), findsNothing);
  });
}
