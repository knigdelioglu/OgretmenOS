import 'dart:convert';

const supportedFormSchemaVersions = {'1.0'};

class FormDefinitionException implements Exception {
  const FormDefinitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnsupportedFormSchemaException extends FormDefinitionException {
  const UnsupportedFormSchemaException(String schemaVersion)
    : super('Desteklenmeyen form şema sürümü: $schemaVersion');
}

/// Runtime availability evidence for a canonical textbook form.
///
/// A form can be present in the textbook registry while its printable
/// template is unavailable or still needs review. Keeping that distinction in
/// a typed model prevents the UI from treating every registry row as an
/// actionable local form.
class FormTemplateStatus {
  const FormTemplateStatus({
    required this.formId,
    required this.renderStatus,
    required this.reviewReason,
    required this.provenance,
  });

  factory FormTemplateStatus.fromRow(Map<String, Object?> row) {
    final rawProvenance = row['provenance_json'];
    Map<String, dynamic> provenance = const {};
    if (rawProvenance is String && rawProvenance.trim().isNotEmpty) {
      final decoded = jsonDecode(rawProvenance);
      if (decoded is Map) {
        provenance = Map<String, dynamic>.from(decoded);
      }
    } else if (rawProvenance is Map) {
      provenance = Map<String, dynamic>.from(rawProvenance);
    }
    return FormTemplateStatus(
      formId: row['form_id']?.toString() ?? '',
      renderStatus: row['render_status']?.toString() ?? 'needs_review',
      reviewReason: nullableFormText(row['review_reason']),
      provenance: Map.unmodifiable(provenance),
    );
  }

  final String formId;
  final String renderStatus;
  final String? reviewReason;
  final Map<String, dynamic> provenance;

  bool get isReady => renderStatus == 'ready';

  bool get isExternalReference =>
      reviewReason == 'unresolved_form_reference' ||
      provenance['verification_status'] ==
          'OFFICIAL_QR_ASSESSMENT_TARGET_PRESENT_STRUCTURE_UNRESOLVED';

  String? get targetUrl {
    final value = provenance['target_url'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  List<String> get targetUrlCandidates {
    final value = provenance['target_url_candidates'];
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? get sourcePage {
    final value = provenance['source_page'] ?? provenance['printed_page'];
    return value?.toString().trim().isEmpty == true ? null : value?.toString();
  }

  String get displayLabel {
    if (isReady) return 'Hazır';
    if (isExternalReference) return 'Dış kaynak · yapı çözümlenmedi';
    return 'İnceleme bekliyor';
  }
}

String? nullableFormText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class FormDefinition {
  const FormDefinition({
    required this.schemaVersion,
    required this.title,
    this.description,
    this.instructions,
    this.sections = const [],
    this.provenance = const {},
  });

  factory FormDefinition.fromJsonString(String value) {
    Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException catch (error) {
      throw FormDefinitionException('Form içeriği geçerli JSON değil: $error');
    }
    if (decoded is! Map) {
      throw const FormDefinitionException(
        'Form içeriği bir JSON nesnesi olmalı.',
      );
    }
    return FormDefinition.fromJson(Map<String, dynamic>.from(decoded));
  }

  factory FormDefinition.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredText(json, 'schema_version');
    if (!supportedFormSchemaVersions.contains(schemaVersion)) {
      throw UnsupportedFormSchemaException(schemaVersion);
    }
    final title = _requiredText(json, 'title');
    return FormDefinition(
      schemaVersion: schemaVersion,
      title: title,
      description: _optionalText(json['description']),
      instructions: _optionalText(json['instructions']),
      sections: _objectList(
        json['sections'],
      ).map(FormSection.fromJson).toList(growable: false),
      provenance: json['provenance'] is Map
          ? Map<String, dynamic>.from(json['provenance'] as Map)
          : const {},
    );
  }

  final String schemaVersion;
  final String title;
  final String? description;
  final String? instructions;
  final List<FormSection> sections;
  final Map<String, dynamic> provenance;

  /// Returns structural issues that would make screen/PDF rendering unsafe.
  ///
  /// Parsing remains permissive so a newer runtime can still be inspected, but
  /// callers must validate a template before treating it as renderable.
  List<String> get validationErrors {
    final errors = <String>[];
    if (!supportedFormSchemaVersions.contains(schemaVersion)) {
      errors.add('desteklenmeyen schema_version: $schemaVersion');
    }
    if (schemaVersion.trim().isEmpty) errors.add('schema_version boş');
    if (title.trim().isEmpty) errors.add('title boş');
    if (sections.isEmpty) errors.add('sections boş');
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      if (section.elements.isEmpty) {
        errors.add('section[$sectionIndex] boş');
      }
      for (
        var elementIndex = 0;
        elementIndex < section.elements.length;
        elementIndex++
      ) {
        final element = section.elements[elementIndex];
        final location = 'section[$sectionIndex].element[$elementIndex]';
        switch (element) {
          case HeadingFormElement value:
            if (value.text.trim().isEmpty) errors.add('$location heading boş');
          case ParagraphFormElement value:
            if (value.text.trim().isEmpty) {
              errors.add('$location paragraph boş');
            }
          case IdentityFieldsFormElement value:
            if (value.fields.isEmpty) {
              errors.add('$location identityFields boş');
            }
            if (value.fields.any((field) => field.label.trim().isEmpty)) {
              errors.add('$location identityFields etiketi boş');
            }
          case FreeTextFormElement value:
            if (value.lines < 1 || value.lines > 200) {
              errors.add('$location freeText satır sayısı geçersiz');
            }
          case ChecklistFormElement value:
            if (value.items.isEmpty ||
                value.items.any((item) => item.trim().isEmpty)) {
              errors.add('$location checklist maddeleri eksik');
            }
          case RatingScaleFormElement value:
            final optionCount = value.displayOptions.length;
            if (value.items.isEmpty ||
                value.items.any((item) => item.trim().isEmpty) ||
                value.min > value.max ||
                value.max - value.min > 20 ||
                optionCount != value.max - value.min + 1 ||
                value.displayOptions.any((option) => option.trim().isEmpty)) {
              errors.add(
                '$location ratingScale aralığı veya maddeleri geçersiz',
              );
            }
          case TableFormElement value:
            if (value.columns.isEmpty ||
                value.columns.any(
                  (column) => column.label.trim().isEmpty || column.flex < 1,
                )) {
              errors.add('$location table sütunları eksik');
            }
            if (value.rows.any((row) => row.length != value.columns.length)) {
              errors.add('$location table satır/sütun sayısı uyuşmuyor');
            }
          case RubricFormElement value:
            if (value.levels.length < 2 ||
                value.levels.any((level) => level.trim().isEmpty) ||
                value.criteria.isEmpty ||
                value.criteria.any(
                  (criterion) =>
                      criterion.label.trim().isEmpty ||
                      criterion.descriptors.length != value.levels.length ||
                      criterion.descriptors.any(
                        (descriptor) => descriptor.trim().isEmpty,
                      ),
                )) {
              errors.add('$location rubric düzey/descriptor yapısı geçersiz');
            }
          case NoteFormElement value:
            if (value.text.trim().isEmpty) errors.add('$location note boş');
          case SignatureFormElement value:
            if (value.fields.isEmpty ||
                value.fields.any((field) => field.trim().isEmpty)) {
              errors.add('$location signature alanları eksik');
            }
          case SpacerFormElement value:
            if (value.height < 1 || value.height > 1000) {
              errors.add('$location spacer yüksekliği geçersiz');
            }
          case UnknownFormElement _:
            // Both screen and PDF renderers expose an explicit fallback note.
            // Keeping the template renderable prevents an unknown future
            // element from becoming a blank form or a hard crash.
            break;
        }
      }
    }
    return errors;
  }

  void validate() {
    final errors = validationErrors;
    if (errors.isNotEmpty) {
      throw FormDefinitionException(
        'Form render edilemez: ${errors.join('; ')}',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'title': title,
    if (description != null) 'description': description,
    if (instructions != null) 'instructions': instructions,
    'sections': sections.map((section) => section.toJson()).toList(),
    if (provenance.isNotEmpty) 'provenance': provenance,
  };
}

class FormSection {
  const FormSection({this.title, this.elements = const []});

  factory FormSection.fromJson(Map<String, dynamic> json) => FormSection(
    title: _optionalText(json['title']),
    elements: _objectList(
      json['elements'],
    ).map(FormElement.fromJson).toList(growable: false),
  );

  final String? title;
  final List<FormElement> elements;

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    'elements': elements.map((element) => element.toJson()).toList(),
  };
}

sealed class FormElement {
  const FormElement();

  String get type;

  Map<String, dynamic> toJson();

  factory FormElement.fromJson(Map<String, dynamic> json) {
    final type = _optionalText(json['type']) ?? 'unknown';
    return switch (type) {
      'heading' => HeadingFormElement.fromJson(json),
      'paragraph' => ParagraphFormElement.fromJson(json),
      'identityFields' => IdentityFieldsFormElement.fromJson(json),
      'freeText' => FreeTextFormElement.fromJson(json),
      'checklist' => ChecklistFormElement.fromJson(json),
      'ratingScale' => RatingScaleFormElement.fromJson(json),
      'table' => TableFormElement.fromJson(json),
      'rubric' => RubricFormElement.fromJson(json),
      'note' => NoteFormElement.fromJson(json),
      'signature' => SignatureFormElement.fromJson(json),
      'spacer' => SpacerFormElement.fromJson(json),
      _ => UnknownFormElement(rawType: type, raw: Map.of(json)),
    };
  }
}

class HeadingFormElement extends FormElement {
  const HeadingFormElement({required this.text, this.level = 2});

  factory HeadingFormElement.fromJson(Map<String, dynamic> json) =>
      HeadingFormElement(
        text: _optionalText(json['text']) ?? '',
        level: _positiveInt(json['level'], fallback: 2),
      );

  final String text;
  final int level;

  @override
  String get type => 'heading';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text, 'level': level};
}

class ParagraphFormElement extends FormElement {
  const ParagraphFormElement({required this.text});

  factory ParagraphFormElement.fromJson(Map<String, dynamic> json) =>
      ParagraphFormElement(text: _optionalText(json['text']) ?? '');

  final String text;

  @override
  String get type => 'paragraph';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};
}

class IdentityField {
  const IdentityField({required this.label, this.flex = 1});

  factory IdentityField.fromJson(Object? value) {
    if (value is String) return IdentityField(label: value);
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      return IdentityField(
        label: _optionalText(json['label']) ?? '',
        flex: _positiveInt(json['flex']),
      );
    }
    return const IdentityField(label: '');
  }

  final String label;
  final int flex;

  Map<String, dynamic> toJson() => {'label': label, 'flex': flex};
}

class IdentityFieldsFormElement extends FormElement {
  const IdentityFieldsFormElement({required this.fields});

  factory IdentityFieldsFormElement.fromJson(Map<String, dynamic> json) =>
      IdentityFieldsFormElement(
        fields: _list(json['fields'])
            .map(IdentityField.fromJson)
            .where((field) => field.label.isNotEmpty)
            .toList(growable: false),
      );

  final List<IdentityField> fields;

  @override
  String get type => 'identityFields';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

class FreeTextFormElement extends FormElement {
  const FreeTextFormElement({this.label, this.lines = 4});

  factory FreeTextFormElement.fromJson(Map<String, dynamic> json) =>
      FreeTextFormElement(
        label: _optionalText(json['label']),
        lines: _positiveInt(json['lines'], fallback: 4),
      );

  final String? label;
  final int lines;

  @override
  String get type => 'freeText';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (label != null) 'label': label,
    'lines': lines,
  };
}

class ChecklistFormElement extends FormElement {
  const ChecklistFormElement({
    this.label,
    required this.items,
    this.allowNotes = false,
  });

  factory ChecklistFormElement.fromJson(Map<String, dynamic> json) =>
      ChecklistFormElement(
        label: _optionalText(json['label']),
        items: _stringList(json['items']),
        allowNotes: json['allowNotes'] == true || json['allow_notes'] == true,
      );

  final String? label;
  final List<String> items;
  final bool allowNotes;

  @override
  String get type => 'checklist';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (label != null) 'label': label,
    'items': items,
    'allowNotes': allowNotes,
  };
}

class RatingScaleFormElement extends FormElement {
  const RatingScaleFormElement({
    this.label,
    required this.min,
    required this.max,
    this.minLabel,
    this.maxLabel,
    required this.items,
    this.options = const [],
  });

  factory RatingScaleFormElement.fromJson(Map<String, dynamic> json) =>
      RatingScaleFormElement(
        label: _optionalText(json['label']),
        min: _intValue(json['min'], fallback: 1),
        max: _intValue(json['max'], fallback: 5),
        minLabel: _optionalText(json['minLabel'] ?? json['min_label']),
        maxLabel: _optionalText(json['maxLabel'] ?? json['max_label']),
        items: _stringList(json['items']),
        options: _stringList(json['options']),
      );

  final String? label;
  final int min;
  final int max;
  final String? minLabel;
  final String? maxLabel;
  final List<String> items;
  final List<String> options;

  List<String> get displayOptions => options.isNotEmpty
      ? options
      : (min > max || max - min > 100)
      ? const []
      : [for (var value = min; value <= max; value++) '$value'];

  @override
  String get type => 'ratingScale';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (label != null) 'label': label,
    'min': min,
    'max': max,
    if (minLabel != null) 'minLabel': minLabel,
    if (maxLabel != null) 'maxLabel': maxLabel,
    'items': items,
    if (options.isNotEmpty) 'options': options,
  };
}

enum FormTableAlignment { left, center, right }

class FormTableColumn {
  const FormTableColumn({
    required this.label,
    this.flex = 1,
    this.alignment = FormTableAlignment.left,
  });

  factory FormTableColumn.fromJson(Object? value) {
    if (value is String) return FormTableColumn(label: value);
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      return FormTableColumn(
        label: _optionalText(json['label']) ?? '',
        flex: _positiveInt(json['flex'] ?? json['width']),
        alignment: FormTableAlignment.values.firstWhere(
          (alignment) => alignment.name == json['alignment'],
          orElse: () => FormTableAlignment.left,
        ),
      );
    }
    return const FormTableColumn(label: '');
  }

  final String label;
  final int flex;
  final FormTableAlignment alignment;

  Map<String, dynamic> toJson() => {
    'label': label,
    'flex': flex,
    'alignment': alignment.name,
  };
}

class TableFormElement extends FormElement {
  const TableFormElement({
    this.label,
    required this.columns,
    required this.rows,
    this.header = true,
  });

  factory TableFormElement.fromJson(Map<String, dynamic> json) =>
      TableFormElement(
        label: _optionalText(json['label']),
        columns: _list(
          json['columns'],
        ).map(FormTableColumn.fromJson).toList(growable: false),
        rows: _list(json['rows'])
            .whereType<List>()
            .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
            .toList(growable: false),
        header: json['header'] != false,
      );

  final String? label;
  final List<FormTableColumn> columns;
  final List<List<String>> rows;
  final bool header;

  List<List<String>> get normalizedRows => [
    for (final row in rows)
      [
        for (var index = 0; index < columns.length; index++)
          index < row.length ? row[index] : '',
      ],
  ];

  @override
  String get type => 'table';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (label != null) 'label': label,
    'columns': columns.map((column) => column.toJson()).toList(),
    'rows': rows,
    'header': header,
  };
}

class RubricCriterion {
  const RubricCriterion({required this.label, required this.descriptors});

  factory RubricCriterion.fromJson(Map<String, dynamic> json) {
    final rawDescriptors = json['descriptors'];
    final descriptors = rawDescriptors is Map
        ? rawDescriptors.values
              .map((value) => value?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : _stringList(rawDescriptors);
    return RubricCriterion(
      label: _optionalText(json['label']) ?? '',
      descriptors: descriptors,
    );
  }

  final String label;
  final List<String> descriptors;

  List<String> normalizedDescriptors(int levelCount) => [
    for (var index = 0; index < levelCount; index++)
      index < descriptors.length ? descriptors[index] : '',
  ];

  Map<String, dynamic> toJson() => {'label': label, 'descriptors': descriptors};
}

class RubricFormElement extends FormElement {
  const RubricFormElement({
    this.label,
    required this.levels,
    required this.criteria,
  });

  factory RubricFormElement.fromJson(Map<String, dynamic> json) =>
      RubricFormElement(
        label: _optionalText(json['label']),
        levels: _stringList(json['levels']),
        criteria: _objectList(
          json['criteria'],
        ).map(RubricCriterion.fromJson).toList(growable: false),
      );

  final String? label;
  final List<String> levels;
  final List<RubricCriterion> criteria;

  List<List<String>> get normalizedRows => [
    for (final criterion in criteria)
      [criterion.label, ...criterion.normalizedDescriptors(levels.length)],
  ];

  @override
  String get type => 'rubric';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (label != null) 'label': label,
    'levels': levels,
    'criteria': criteria.map((criterion) => criterion.toJson()).toList(),
  };
}

class NoteFormElement extends FormElement {
  const NoteFormElement({required this.text});

  factory NoteFormElement.fromJson(Map<String, dynamic> json) =>
      NoteFormElement(text: _optionalText(json['text']) ?? '');

  final String text;

  @override
  String get type => 'note';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};
}

class SignatureFormElement extends FormElement {
  const SignatureFormElement({required this.fields});

  factory SignatureFormElement.fromJson(Map<String, dynamic> json) =>
      SignatureFormElement(fields: _stringList(json['fields']));

  final List<String> fields;

  @override
  String get type => 'signature';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'fields': fields};
}

class SpacerFormElement extends FormElement {
  const SpacerFormElement({this.height = 16});

  factory SpacerFormElement.fromJson(Map<String, dynamic> json) =>
      SpacerFormElement(height: _positiveInt(json['height'], fallback: 16));

  final int height;

  @override
  String get type => 'spacer';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'height': height};
}

class UnknownFormElement extends FormElement {
  const UnknownFormElement({required this.rawType, required this.raw});

  final String rawType;
  final Map<String, dynamic> raw;

  @override
  String get type => rawType;

  @override
  Map<String, dynamic> toJson() => Map.of(raw);
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = _optionalText(json[key]);
  if (value == null) {
    throw FormDefinitionException('Form alanı boş veya eksik: $key');
  }
  return value;
}

String? _optionalText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<Object?> _list(Object? value) => value is List ? value : const [];

List<Map<String, dynamic>> _objectList(Object? value) => _list(value)
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList(growable: false);

List<String> _stringList(Object? value) => _list(value)
    .map((item) => item?.toString().trim() ?? '')
    .where((item) => item.isNotEmpty)
    .toList(growable: false);

int _intValue(Object? value, {required int fallback}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;

int _positiveInt(Object? value, {int fallback = 1}) {
  final parsed = _intValue(value, fallback: fallback);
  return parsed > 0 ? parsed : fallback;
}
