import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/features/lesson_plan/lesson_plan_teacher_presentation.dart';

void main() {
  const theme = Theme(
    id: 'TEMA_01',
    order: 1,
    title: '1. TEMA: SÖZÜN İNCELİĞİ',
    pageRange: null,
    plannedHours: 43,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );
  const block = Block(
    id: 'BLOCK_T1_01_OKUMA',
    themeId: 'TEMA_01',
    order: 1,
    title: '1. Tema Okuma Bloğu: Şiir ve Deneme Metin Tahlili',
    skillDomain: 'OKUMA',
    learningArea: null,
    plannedHours: 15,
    timeStatus: 'RESOLVED',
    sourceLocators: [],
  );
  const outcome = Outcome(
    id: 'TDE9_T1_O2',
    themeId: 'TEMA_01',
    code: 'TDE2.2',
    officialText:
        'TDE2.2. “Sözün İnceliği” temasında ele alınan metinlerde anlam oluşturabilme',
    processComponents: null,
    sourceLocator: null,
    verificationStatus: 'VERIFIED',
  );
  const activity = Activity(
    id: 'T1_ACT_04_GUZEL_SANATLAR_DISIPLINLER',
    sectionId: 'T1_SEC_01_OKUMA_SIIR',
    themeId: 'TEMA_01',
    title: 'Güzel Sanatlar ve Disiplinler Arası İlişki Tahlili',
    activityType: null,
    studentAction: null,
    expectedEvidence: null,
    printedPage: '21-26',
    pdfPage: null,
    verificationStatus: 'VERIFIED',
  );
  const form = Form(
    id: 'FORM_BOB_01_T1_YAZMA_OZ',
    title: 'Öz Değerlendirme Formu (1. Tema: Yazma)',
    structuralType: null,
    assessmentType: null,
    printedPage: 302,
    pdfPage: null,
    evaluator: null,
    sourceId: null,
    verificationStatus: 'VERIFIED',
  );
  const detail = BlockDetail(
    theme: theme,
    block: block,
    outcomes: [outcome],
    textbookSections: [],
    activities: [activity],
    forms: [form],
    assessmentArtifacts: [],
    assessmentGaps: [],
    assessmentTaskBindings: [],
    resourceDecisions: [],
    sourceReferences: [],
    previousBlock: null,
    nextBlock: null,
  );
  final plans = [
    _package('BLOCK_T1_01_OKUMA_P01', 1),
    _package('BLOCK_T1_01_OKUMA_P02', 2),
  ];
  final presentation = LessonPlanTeacherPresentation(
    blockPlans: plans,
    blockDetail: detail,
  );

  test('paket kodu yerine gerçek ders saati aralığını gösterir', () {
    expect(presentation.packageLabel(plans[0]), '1–2. ders saatleri');
    expect(presentation.packageLabel(plans[1]), '3–4. ders saatleri');
  });

  test('teknik etkinlik ve paket kimliklerini öğretmen diline çevirir', () {
    final text = presentation.humanize(
      "P01'de T1_ACT_04_GUZEL_SANATLAR_DISIPLINLER kullanılır; P02'de devam edilir.",
    );

    expect(text, contains('1–2. ders saatlerinde'));
    expect(
      text,
      contains('Güzel Sanatlar ve Disiplinler Arası İlişki Tahlili'),
    );
    expect(text, contains('3–4. ders saatlerinde'));
    expect(text, isNot(contains('P01')));
    expect(text, isNot(contains('T1_ACT_04')));
  });

  test('öğrenme çıktısında açıklamayı öne, resmî kodu ikincil gösterir', () {
    expect(
      presentation.outcomeLabels(['TDE2.2']).single,
      'Metinlerde anlam oluşturabilme (TDE2.2)',
    );
  });

  test('etkinlik ve form adlarına ders kitabı sayfasını ekler', () {
    expect(
      presentation.activityLabels([activity.id]).single,
      'Güzel Sanatlar ve Disiplinler Arası İlişki Tahlili · Ders kitabı s. 21-26',
    );
    expect(
      presentation.formLabels([form.id]).single,
      'Öz Değerlendirme Formu (1. Tema: Yazma) · Ders kitabı s. 302',
    );
  });
}

LessonPlanPackage _package(String id, int number) => LessonPlanPackage(
  packageId: id,
  courseId: 'TDE_9',
  themeId: 'TEMA_01',
  blockId: 'BLOCK_T1_01_OKUMA',
  packageNo: number,
  lessonHours: 2,
  title: 'Plan $number',
  summary: '',
  remainingBlockHours: 15 - (number * 2),
  schemaVersion: '1.0.0',
  validationStatus: 'PASS',
  sourcePath: '',
  payloadSha256: 'sha-$number',
  outcomeCodes: const ['TDE2.2'],
  usedActivityIds: const [],
  usedFormIds: const [],
  lessons: const [],
  teacherNotes: null,
  continuation: const LessonPlanContinuation(
    plannedNowHours: 2,
    remainingBlockHours: 0,
    coveredOutcomeCodes: ['TDE2.2'],
    usedActivityIds: [],
    nextStepHint: null,
    raw: {},
  ),
  rawPayload: const {},
);
