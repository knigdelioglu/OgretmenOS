import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/form_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/resources/forms/form_document_view.dart';
import 'package:ogretmen_os/features/resources/forms/form_export_service.dart';
import 'package:ogretmen_os/features/resources/form_viewer_page.dart';

void main() {
  testWidgets(
    'viewer form başlığı, tablo/rubric ve PDF aksiyonlarını gösterir',
    (tester) async {
      final form = _form();
      await tester.pumpWidget(
        MaterialApp(
          home: FormViewerPage(
            form: form,
            repository: _FakeRepository(
              const FormDefinition(
                schemaVersion: '1.0',
                title: 'Öz Değerlendirme Formu',
                sections: [
                  FormSection(
                    elements: [
                      TableFormElement(
                        columns: [FormTableColumn(label: 'Ölçüt')],
                        rows: [
                          ['Çalışma'],
                        ],
                      ),
                      RubricFormElement(
                        levels: ['Yetkin', 'Geliştirilmeli'],
                        criteria: [
                          RubricCriterion(
                            label: 'İfade',
                            descriptors: ['Açık', 'Belirsiz'],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Öz Değerlendirme Formu'), findsWidgets);
      expect(find.text('PDF Önizle'), findsOneWidget);
      expect(find.text('PDF Kaydet / Paylaş'), findsOneWidget);
      expect(find.text('Yazdır'), findsOneWidget);
      expect(find.text('Çalışma'), findsOneWidget);
      expect(find.text('İfade'), findsOneWidget);
      expect(find.text('FORM_TECHNICAL_ID'), findsNothing);
    },
  );

  testWidgets('template olmayan eski runtime anlaşılır fallback gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FormViewerPage(
          form: _form(),
          repository: const _FakeRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bu formun görüntülenebilir içeriği mevcut veri paketinde bulunmuyor.',
      ),
      findsOneWidget,
    );
    expect(find.text('PDF Önizle'), findsNothing);
  });

  testWidgets(
    'viewer save/share ve print aksiyonlarını export servisine bağlar',
    (tester) async {
      final exporter = _FakeExportService();
      await tester.pumpWidget(
        MaterialApp(
          home: FormViewerPage(
            form: _form(),
            repository: _FakeRepository(_definition()),
            exportService: exporter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('PDF Kaydet / Paylaş'));
      await tester.pumpAndSettle();
      expect(exporter.savedFilenames, ['Oz_Degerlendirme_Formu.pdf']);
      expect(exporter.generated, 1);

      await tester.tap(find.text('Yazdır'));
      await tester.pumpAndSettle();
      expect(exporter.printedFilenames, ['Oz_Degerlendirme_Formu.pdf']);
      expect(exporter.generated, 2);
    },
  );

  testWidgets(
    'form document dar ekranda uzun tablo ve rubriği taşırmadan gösterir',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const definition = FormDefinition(
        schemaVersion: '1.0',
        title: 'Çok uzun başlıklı Türkçe değerlendirme formu',
        sections: [
          FormSection(
            elements: [
              IdentityFieldsFormElement(
                fields: [
                  IdentityField(label: 'Öğrencinin adı ve soyadı'),
                  IdentityField(label: 'Ders içi gözlem tarihi'),
                ],
              ),
              TableFormElement(
                columns: [
                  FormTableColumn(label: 'Uzun gözlem ölçütü', flex: 3),
                  FormTableColumn(label: 'Kanıt ve açıklama', flex: 2),
                  FormTableColumn(label: 'Sonraki adım', flex: 2),
                ],
                rows: [
                  [
                    'Metni Türkçe karakterlerle uzun biçimde açıklayan bir satır',
                    '',
                    'Bir sonraki derste yeniden gözden geçirilecek',
                  ],
                ],
              ),
              RubricFormElement(
                levels: ['Başlangıç', 'Gelişiyor', 'Yetkin'],
                criteria: [
                  RubricCriterion(
                    label: 'Açıklama ve kanıt kullanımı',
                    descriptors: [
                      'Ölçüt henüz yeterli kanıtla karşılanmamıştır.',
                      'Ölçüt büyük ölçüde karşılanmıştır; sınırlı eksikler vardır.',
                      'Ölçüt tam, doğru ve etkili biçimde karşılanmıştır.',
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormDocumentView(definition: definition),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uzun gözlem ölçütü'), findsOneWidget);
      expect(find.text('Başlangıç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

model.Form _form() => const model.Form(
  id: 'FORM_TECHNICAL_ID',
  title: 'Öz Değerlendirme Formu',
  structuralType: 'self_assessment_form',
  assessmentType: 'self_assessment_form',
  printedPage: null,
  pdfPage: null,
  evaluator: 'student_self',
  sourceId: 'source',
  verificationStatus: 'VERIFIED',
);

class _FakeRepository
    implements CourseKnowledgeRepository, FormTemplateKnowledgeRepository {
  const _FakeRepository(this.definition);

  final FormDefinition? definition;

  @override
  Future<FormDefinition?> getFormDefinition(String formId) async => definition;

  @override
  Future<model.Course> getCourse() => throw UnimplementedError();
  @override
  Future<model.RuntimeManifest> getManifest() => throw UnimplementedError();
  @override
  Future<List<model.Theme>> getThemes() => throw UnimplementedError();
  @override
  Future<model.Theme> getTheme(String themeId) => throw UnimplementedError();
  @override
  Future<List<model.Block>> getBlocks(String themeId) =>
      throw UnimplementedError();
  @override
  Future<model.BlockDetail> getBlock(String blockId) =>
      throw UnimplementedError();
  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() =>
      throw UnimplementedError();
  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(String themeId) =>
      throw UnimplementedError();
  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) =>
      throw UnimplementedError();
}

FormDefinition _definition() => const FormDefinition(
  schemaVersion: '1.0',
  title: 'Öz Değerlendirme Formu',
  sections: [
    FormSection(
      elements: [
        TableFormElement(
          columns: [FormTableColumn(label: 'Ölçüt')],
          rows: [
            ['Çalışma'],
          ],
        ),
      ],
    ),
  ],
);

class _FakeExportService implements FormExportService {
  int generated = 0;
  final savedFilenames = <String>[];
  final printedFilenames = <String>[];

  @override
  Future<Uint8List> generate(FormDefinition definition) async {
    generated++;
    return Uint8List.fromList(const [37, 80, 68, 70, 45]);
  }

  @override
  Future<FormExportOutcome> saveOrShare(
    Uint8List bytes, {
    required String filename,
  }) async {
    savedFilenames.add(filename);
    return FormExportOutcome.completed;
  }

  @override
  Future<FormExportOutcome> printPdf(
    Uint8List bytes, {
    required String filename,
  }) async {
    printedFilenames.add(filename);
    return FormExportOutcome.completed;
  }
}
