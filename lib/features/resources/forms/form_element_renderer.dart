import 'package:flutter/material.dart';

import '../../../domain/models/form_models.dart';
import 'form_document_layout.dart';

class FormElementRenderer extends StatelessWidget {
  const FormElementRenderer({
    super.key,
    required this.element,
    required this.compact,
  });

  final FormElement element;
  final bool compact;

  @override
  Widget build(BuildContext context) => switch (element) {
    HeadingFormElement value => Text(
      value.text,
      style: value.level <= 2
          ? Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
          : Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    ParagraphFormElement value => Text(value.text),
    IdentityFieldsFormElement value => _IdentityFields(
      fields: value.fields,
      compact: compact,
    ),
    FreeTextFormElement value => _FreeText(element: value),
    ChecklistFormElement value => _Checklist(element: value),
    RatingScaleFormElement value => _RatingScale(
      element: value,
      compact: compact,
    ),
    TableFormElement value => _DocumentTable(element: value, compact: compact),
    RubricFormElement value => _Rubric(element: value, compact: compact),
    NoteFormElement value => _Note(text: value.text),
    SignatureFormElement value => _Signatures(
      fields: value.fields,
      compact: compact,
    ),
    SpacerFormElement value => SizedBox(height: value.height.toDouble()),
    UnknownFormElement value => _Note(
      text:
          'Bu formdaki “${value.rawType}” öğesi bu uygulama sürümünde görüntülenemiyor.',
    ),
  };
}

class _IdentityFields extends StatelessWidget {
  const _IdentityFields({required this.fields, required this.compact});

  final List<IdentityField> fields;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LabeledLine(label: field.label),
            ),
        ],
      );
    }
    final children = fields
        .map(
          (field) =>
              SizedBox(width: 240, child: _LabeledLine(label: field.label)),
        )
        .toList(growable: false);
    return Wrap(spacing: 20, runSpacing: 14, children: children);
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Flexible(
        child: Text(
          '$label: ',
          softWrap: true,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      const Expanded(child: Divider(color: Colors.black54)),
    ],
  );
}

class _FreeText extends StatelessWidget {
  const _FreeText({required this.element});

  final FreeTextFormElement element;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (element.label case final label?) ...[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
      ],
      for (var line = 0; line < element.lines; line++)
        const SizedBox(
          height: FormDocumentLayout.fieldLineHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Divider(color: Colors.black45, height: 1),
          ),
        ),
    ],
  );
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.element});

  final ChecklistFormElement element;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (element.label case final label?) ...[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
      for (final item in element.items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Boş onay kutusu',
                child: Container(
                  width: 17,
                  height: 17,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(border: Border.all()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item)),
            ],
          ),
        ),
      if (element.allowNotes) ...[
        const SizedBox(height: 8),
        const _FreeText(
          element: FreeTextFormElement(label: 'Notlar', lines: 2),
        ),
      ],
    ],
  );
}

class _RatingScale extends StatelessWidget {
  const _RatingScale({required this.element, required this.compact});

  final RatingScaleFormElement element;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (element.items.isEmpty) return const SizedBox.shrink();
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (element.label case final label?) ...[
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          for (final item in element.items)
            _CompactScaleRow(item: item, options: element.displayOptions),
        ],
      );
    }
    return _TableFrame(
      label: element.label,
      child: Table(
        border: TableBorder.all(color: Colors.black45),
        columnWidths: {
          0: const FlexColumnWidth(5),
          for (var i = 0; i < element.displayOptions.length; i++)
            i + 1: const FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F3F5)),
            children: [
              const _TableCell(text: 'Ölçüt', bold: true),
              for (final option in element.displayOptions)
                _TableCell(text: option, bold: true, centered: true),
            ],
          ),
          for (final item in element.items)
            TableRow(
              children: [
                _TableCell(text: item),
                for (final _ in element.displayOptions)
                  const _TableCell(text: '○', centered: true),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactScaleRow extends StatelessWidget {
  const _CompactScaleRow({required this.item, required this.options});

  final String item;
  final List<String> options;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [for (final option in options) Text('○ $option')],
          ),
        ],
      ),
    ),
  );
}

class _DocumentTable extends StatelessWidget {
  const _DocumentTable({required this.element, required this.compact});

  final TableFormElement element;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (element.columns.isEmpty) {
      return const _Note(text: 'Bu tablonun sütun bilgisi bulunmuyor.');
    }
    if (element.normalizedRows.isEmpty && !element.header) {
      return const _Note(text: 'Bu tabloda gösterilecek satır bulunmuyor.');
    }
    if (compact) {
      return _CompactRows(
        label: element.label,
        columns: element.columns.map((column) => column.label).toList(),
        rows: element.normalizedRows,
      );
    }
    return _TableFrame(
      label: element.label,
      child: Table(
        border: TableBorder.all(color: Colors.black45),
        columnWidths: {
          for (var i = 0; i < element.columns.length; i++)
            i: FlexColumnWidth(element.columns[i].flex.toDouble()),
        },
        children: [
          if (element.header)
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F3F5)),
              children: [
                for (final column in element.columns)
                  _TableCell(
                    text: column.label,
                    bold: true,
                    centered: column.alignment == FormTableAlignment.center,
                  ),
              ],
            ),
          for (final row in element.normalizedRows)
            TableRow(
              children: [
                for (var i = 0; i < element.columns.length; i++)
                  _TableCell(
                    text: i < row.length ? row[i] : '',
                    centered:
                        element.columns[i].alignment ==
                        FormTableAlignment.center,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Rubric extends StatelessWidget {
  const _Rubric({required this.element, required this.compact});

  final RubricFormElement element;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (element.criteria.isEmpty || element.levels.isEmpty) {
      return const _Note(text: 'Bu rubriğin ölçüt veya düzey bilgisi eksik.');
    }
    final rows = element.normalizedRows;
    final columns = ['Ölçüt', ...element.levels];
    if (compact) {
      return _CompactRows(label: element.label, columns: columns, rows: rows);
    }
    return _TableFrame(
      label: element.label,
      child: Table(
        border: TableBorder.all(color: Colors.black45),
        columnWidths: {
          0: const FlexColumnWidth(2),
          for (var i = 0; i < element.levels.length; i++)
            i + 1: const FlexColumnWidth(3),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F3F5)),
            children: [
              for (final column in columns)
                _TableCell(text: column, bold: true, centered: true),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                for (var i = 0; i < columns.length; i++)
                  _TableCell(text: i < row.length ? row[i] : ''),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactRows extends StatelessWidget {
  const _CompactRows({
    required this.label,
    required this.columns,
    required this.rows,
  });

  final String? label;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label case final value?) ...[
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
        Card.outlined(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${columns[i]}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: rows[rowIndex][i].isEmpty
                                ? '—'
                                : rows[rowIndex][i],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _TableFrame extends StatelessWidget {
  const _TableFrame({required this.label, required this.child});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label case final value?) ...[
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
      child,
    ],
  );
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.text,
    this.bold = false,
    this.centered = false,
  });

  final String text;
  final bool bold;
  final bool centered;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(FormDocumentLayout.tableCellPadding),
    child: Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
  );
}

class _Signatures extends StatelessWidget {
  const _Signatures({required this.fields, required this.compact});

  final List<String> fields;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final field in fields)
        SizedBox(
          width: compact ? double.infinity : 220,
          child: Column(
            children: [
              const SizedBox(height: 36),
              const Divider(color: Colors.black54),
              Text(field, textAlign: TextAlign.center),
            ],
          ),
        ),
    ];
    return compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          )
        : Wrap(spacing: 24, runSpacing: 20, children: children);
  }
}
