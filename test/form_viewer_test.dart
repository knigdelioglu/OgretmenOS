import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/form_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
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
                        levels: ['Yetkin'],
                        criteria: [
                          RubricCriterion(
                            label: 'İfade',
                            descriptors: ['Açık'],
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
