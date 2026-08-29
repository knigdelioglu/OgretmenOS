import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../domain/models/form_models.dart';
import 'form_document_layout.dart';

typedef FormPdfFontLoader = Future<ByteData> Function(String asset);

class FormPdfRenderer {
  const FormPdfRenderer({this.fontLoader});

  final FormPdfFontLoader? fontLoader;

  Future<Uint8List> generate(FormDefinition definition) async {
    final load = fontLoader ?? rootBundle.load;
    final fontData = await load('assets/fonts/Roboto-Variable.ttf');
    final regular = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(fontData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      title: definition.title,
      author: 'Öğretmen OS',
      creator: 'Öğretmen OS Form Renderer',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(FormDocumentLayout.pageMarginPoints),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              definition.title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (definition.description case final description?)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                description,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          if (definition.instructions case final instructions?)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey500),
              ),
              child: pw.Text(
                instructions,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          for (final section in definition.sections) ...[
            if (section.title case final title?)
              pw.Header(
                level: 1,
                text: title,
                textStyle: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            for (final element in section.elements) ..._renderElement(element),
          ],
          if (definition.sections.isEmpty)
            pw.Text('Bu formda gösterilecek bölüm bulunmuyor.'),
        ],
      ),
    );
    return document.save();
  }

  List<pw.Widget> _renderElement(FormElement element) {
    final widget = switch (element) {
      HeadingFormElement value => pw.Text(
        value.text,
        style: pw.TextStyle(
          fontSize: value.level <= 2 ? 14 : 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      ParagraphFormElement value => pw.Text(value.text),
      IdentityFieldsFormElement value => _identityFields(value),
      FreeTextFormElement value => _freeText(value),
      ChecklistFormElement value => _checklist(value),
      RatingScaleFormElement value => _ratingScale(value),
      TableFormElement value => _table(value),
      RubricFormElement value => _rubric(value),
      NoteFormElement value => _note(value.text),
      SignatureFormElement value => _signatures(value),
      SpacerFormElement value => pw.SizedBox(height: value.height.toDouble()),
      UnknownFormElement value => _note(
        '“${value.rawType}” öğesi bu uygulama sürümünde görüntülenemiyor.',
      ),
    };
    return [
      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 12), child: widget),
    ];
  }

  pw.Widget _identityFields(IdentityFieldsFormElement element) => pw.Wrap(
    spacing: 18,
    runSpacing: 10,
    children: [
      for (final field in element.fields)
        pw.SizedBox(
          width: 220,
          child: pw.Row(
            children: [
              pw.Text(
                '${field.label}: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Expanded(
                child: pw.Container(
                  height: 14,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  pw.Widget _freeText(FreeTextFormElement element) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (element.label case final label?)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      for (var line = 0; line < element.lines; line++)
        pw.Container(
          height: 20,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600)),
          ),
        ),
    ],
  );

  pw.Widget _checklist(ChecklistFormElement element) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (element.label case final label?)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      for (final item in element.items)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 11,
                height: 11,
                margin: const pw.EdgeInsets.only(top: 1),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
              ),
              pw.SizedBox(width: 7),
              pw.Expanded(child: pw.Text(item)),
            ],
          ),
        ),
      if (element.allowNotes)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: _freeText(
            const FreeTextFormElement(label: 'Notlar', lines: 2),
          ),
        ),
    ],
  );

  pw.Widget _ratingScale(RatingScaleFormElement element) =>
      pw.TableHelper.fromTextArray(
        headers: ['Ölçüt', ...element.displayOptions],
        data: [
          for (final item in element.items)
            [item, for (final _ in element.displayOptions) '○'],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignments: {
          for (var index = 1; index <= element.displayOptions.length; index++)
            index: pw.Alignment.center,
        },
        columnWidths: {
          0: const pw.FlexColumnWidth(5),
          for (var index = 1; index <= element.displayOptions.length; index++)
            index: const pw.FlexColumnWidth(1),
        },
      );

  pw.Widget _table(TableFormElement element) {
    if (element.columns.isEmpty) {
      return _note('Bu tablonun sütun bilgisi bulunmuyor.');
    }
    return pw.TableHelper.fromTextArray(
      headers: element.header
          ? element.columns.map((column) => column.label).toList()
          : null,
      headerCount: element.header ? 1 : 0,
      data: element.rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      columnWidths: {
        for (var i = 0; i < element.columns.length; i++)
          i: pw.FlexColumnWidth(element.columns[i].flex.toDouble()),
      },
    );
  }

  pw.Widget _rubric(RubricFormElement element) {
    if (element.levels.isEmpty || element.criteria.isEmpty) {
      return _note('Bu rubriğin ölçüt veya düzey bilgisi eksik.');
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Ölçüt', ...element.levels],
      data: [
        for (final criterion in element.criteria)
          [criterion.label, ...criterion.descriptors],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        for (var index = 1; index <= element.levels.length; index++)
          index: const pw.FlexColumnWidth(3),
      },
    );
  }

  pw.Widget _note(String text) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey400),
    ),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  pw.Widget _signatures(SignatureFormElement element) => pw.Wrap(
    spacing: 24,
    runSpacing: 16,
    children: [
      for (final field in element.fields)
        pw.SizedBox(
          width: 190,
          child: pw.Column(
            children: [
              pw.SizedBox(height: 34),
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey700),
                  ),
                ),
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(field, textAlign: pw.TextAlign.center),
              ),
            ],
          ),
        ),
    ],
  );
}
