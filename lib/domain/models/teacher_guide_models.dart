import 'dart:convert';

import 'course_models.dart';

typedef TeacherGuideRow = Map<String, Object?>;
typedef TeacherGuideJsonValue = Object?;

/// Tables that make up the optional, canonical teacher-guide projection.
///
/// The table names are part of the runtime contract. The values stored in
/// them remain course-, subject-, and pedagogy-neutral.
const teacherGuideRuntimeTableNames = <String>[
  'canonical_entities',
  'teacher_guides',
  'teacher_guide_sections',
  'teacher_guide_units',
  'teacher_guide_items',
  'teacher_guide_item_relations',
];

const teacherGuideCoreRuntimeTableNames = <String>[
  'teacher_guides',
  'teacher_guide_sections',
  'teacher_guide_units',
  'teacher_guide_items',
  'teacher_guide_item_relations',
];

class TeacherGuideFormatException implements Exception {
  const TeacherGuideFormatException(this.message);

  final String message;

  @override
  String toString() => 'TeacherGuideFormatException: $message';
}

/// Availability evidence for the optional teacher-guide runtime capability.
class TeacherGuideCapability {
  const TeacherGuideCapability({
    required this.available,
    required this.manifestAdvertised,
    required this.tablesAvailable,
    required this.canonicalEntityCount,
    required this.guideCount,
    required this.sectionCount,
    required this.unitCount,
    required this.itemCount,
    required this.relationCount,
    required this.schemaVersion,
    required this.validationStatus,
    this.reason,
  });

  const TeacherGuideCapability.unavailable({this.reason})
    : available = false,
      manifestAdvertised = false,
      tablesAvailable = false,
      canonicalEntityCount = 0,
      guideCount = 0,
      sectionCount = 0,
      unitCount = 0,
      itemCount = 0,
      relationCount = 0,
      schemaVersion = null,
      validationStatus = null;

  final bool available;
  final bool manifestAdvertised;
  final bool tablesAvailable;
  final int canonicalEntityCount;
  final int guideCount;
  final int sectionCount;
  final int unitCount;
  final int itemCount;
  final int relationCount;
  final String? schemaVersion;
  final String? validationStatus;
  final String? reason;

  bool get usable => available && validationStatus == 'PASS';

  Map<String, int> get rowCounts => <String, int>{
    'canonical_entities': canonicalEntityCount,
    'teacher_guides': guideCount,
    'teacher_guide_sections': sectionCount,
    'teacher_guide_units': unitCount,
    'teacher_guide_items': itemCount,
    'teacher_guide_item_relations': relationCount,
  };
}

class TeacherGuide {
  const TeacherGuide({
    required this.guideId,
    required this.courseId,
    required this.scopeType,
    required this.scopeId,
    required this.title,
    required this.contentStatus,
    required this.schemaVersion,
    required this.provenance,
    this.sections = const [],
  });

  factory TeacherGuide.fromRow(TeacherGuideRow row) => TeacherGuide(
    guideId: _requiredString(row['guide_id'], 'guide_id'),
    courseId: _requiredString(row['course_id'], 'course_id'),
    scopeType: _requiredString(row['scope_type'], 'scope_type'),
    scopeId: _requiredString(row['scope_id'], 'scope_id'),
    title: _requiredString(row['title'], 'title'),
    contentStatus: _requiredString(row['content_status'], 'content_status'),
    schemaVersion: _requiredString(row['schema_version'], 'schema_version'),
    provenance: TeacherGuideProvenance.fromJson(
      _requiredJson(row['provenance_json'], 'provenance_json'),
    ),
  );

  final String guideId;
  final String courseId;
  final String scopeType;
  final String scopeId;
  final String title;
  final String contentStatus;
  final String schemaVersion;
  final TeacherGuideProvenance provenance;
  final List<TeacherGuideSection> sections;
}

class TeacherGuideSection {
  const TeacherGuideSection({
    required this.sectionId,
    required this.guideId,
    required this.order,
    required this.title,
    required this.sectionType,
    required this.pageLocator,
    required this.sourceLocator,
    required this.contentStatus,
    required this.provenance,
    this.units = const [],
  });

  factory TeacherGuideSection.fromRow(TeacherGuideRow row) =>
      TeacherGuideSection(
        sectionId: _requiredString(row['section_id'], 'section_id'),
        guideId: _requiredString(row['guide_id'], 'guide_id'),
        order: _requiredInt(row['section_order'], 'section_order'),
        title: _requiredString(row['title'], 'title'),
        sectionType: _requiredString(row['section_type'], 'section_type'),
        pageLocator: nullableString(row['page_locator']),
        sourceLocator: nullableString(row['source_locator']),
        contentStatus: _requiredString(row['content_status'], 'content_status'),
        provenance: TeacherGuideProvenance.fromJson(
          _requiredJson(row['provenance_json'], 'provenance_json'),
        ),
      );

  final String sectionId;
  final String guideId;
  final int order;
  final String title;
  final String sectionType;
  final String? pageLocator;
  final String? sourceLocator;
  final String contentStatus;
  final TeacherGuideProvenance provenance;
  final List<TeacherGuideUnit> units;
}

class TeacherGuideUnit {
  const TeacherGuideUnit({
    required this.unitId,
    required this.sectionId,
    required this.order,
    required this.title,
    required this.pageLocator,
    required this.sourceLocator,
    required this.contentStatus,
    required this.purpose,
    required this.provenance,
    this.items = const [],
  });

  factory TeacherGuideUnit.fromRow(TeacherGuideRow row) => TeacherGuideUnit(
    unitId: _requiredString(row['unit_id'], 'unit_id'),
    sectionId: _requiredString(row['section_id'], 'section_id'),
    order: _requiredInt(row['unit_order'], 'unit_order'),
    title: _requiredString(row['title'], 'title'),
    pageLocator: nullableString(row['page_locator']),
    sourceLocator: nullableString(row['source_locator']),
    contentStatus: _requiredString(row['content_status'], 'content_status'),
    purpose: _jsonValue(row['purpose_json'], 'purpose_json'),
    provenance: TeacherGuideProvenance.fromJson(
      _requiredJson(row['provenance_json'], 'provenance_json'),
    ),
  );

  final String unitId;
  final String sectionId;
  final int order;
  final String title;
  final String? pageLocator;
  final String? sourceLocator;
  final String contentStatus;
  final TeacherGuideJsonValue purpose;
  final TeacherGuideProvenance provenance;
  final List<TeacherGuideItem> items;
}

class TeacherGuideItem {
  const TeacherGuideItem({
    required this.itemId,
    required this.unitId,
    required this.order,
    required this.title,
    required this.label,
    required this.itemType,
    required this.pageLocator,
    required this.sourceLocator,
    required this.contentStatus,
    required this.expectedResponse,
    required this.acceptanceCriteria,
    required this.teacherGuidance,
    required this.commonMisconceptions,
    required this.assessmentEvidence,
    required this.differentiation,
    required this.provenance,
    this.canonicalPayloadSha256,
    this.relations = const [],
  });

  factory TeacherGuideItem.fromRow(TeacherGuideRow row) => TeacherGuideItem(
    itemId: _requiredString(row['item_id'], 'item_id'),
    unitId: _requiredString(row['unit_id'], 'unit_id'),
    order: _requiredInt(row['item_order'], 'item_order'),
    title: nullableString(row['title']),
    label: _requiredString(row['label'], 'label'),
    itemType: _requiredString(row['item_type'], 'item_type'),
    pageLocator: nullableString(row['page_locator']),
    sourceLocator: nullableString(row['source_locator']),
    contentStatus: _requiredString(row['content_status'], 'content_status'),
    expectedResponse: _jsonValue(
      row['expected_response_json'],
      'expected_response_json',
    ),
    acceptanceCriteria: _jsonValue(
      row['acceptance_criteria_json'],
      'acceptance_criteria_json',
    ),
    teacherGuidance: _jsonValue(
      row['teacher_guidance_json'],
      'teacher_guidance_json',
    ),
    commonMisconceptions: _jsonValue(
      row['common_misconceptions_json'],
      'common_misconceptions_json',
    ),
    assessmentEvidence: _jsonValue(
      row['assessment_evidence_json'],
      'assessment_evidence_json',
    ),
    differentiation: TeacherGuideDifferentiation.fromJson(
      _jsonValue(row['differentiation_json'], 'differentiation_json'),
    ),
    provenance: TeacherGuideProvenance.fromJson(
      _requiredJson(row['provenance_json'], 'provenance_json'),
    ),
    canonicalPayloadSha256: nullableString(row['canonical_payload_sha256']),
  );

  final String itemId;
  final String unitId;
  final int order;
  final String? title;
  final String label;
  final String itemType;
  final String? pageLocator;
  final String? sourceLocator;
  final String contentStatus;
  final TeacherGuideJsonValue expectedResponse;
  final TeacherGuideJsonValue acceptanceCriteria;
  final TeacherGuideJsonValue teacherGuidance;
  final TeacherGuideJsonValue commonMisconceptions;
  final TeacherGuideJsonValue assessmentEvidence;
  final TeacherGuideDifferentiation differentiation;
  final TeacherGuideProvenance provenance;
  final String? canonicalPayloadSha256;
  final List<TeacherGuideRelation> relations;

  TeacherGuideItem withRelations(List<TeacherGuideRelation> value) =>
      TeacherGuideItem(
        itemId: itemId,
        unitId: unitId,
        order: order,
        title: title,
        label: label,
        itemType: itemType,
        pageLocator: pageLocator,
        sourceLocator: sourceLocator,
        contentStatus: contentStatus,
        expectedResponse: expectedResponse,
        acceptanceCriteria: acceptanceCriteria,
        teacherGuidance: teacherGuidance,
        commonMisconceptions: commonMisconceptions,
        assessmentEvidence: assessmentEvidence,
        differentiation: differentiation,
        provenance: provenance,
        canonicalPayloadSha256: canonicalPayloadSha256,
        relations: List.unmodifiable(value),
      );
}

class TeacherGuideDifferentiation {
  const TeacherGuideDifferentiation({
    required this.support,
    required this.enrichment,
  });

  factory TeacherGuideDifferentiation.fromJson(Object? value) {
    final map = _requiredMap(value, 'differentiation');
    return TeacherGuideDifferentiation(
      support: _optionalJsonValue(map['support'], 'differentiation.support'),
      enrichment: _optionalJsonValue(
        map['enrichment'],
        'differentiation.enrichment',
      ),
    );
  }

  final TeacherGuideJsonValue support;
  final TeacherGuideJsonValue enrichment;

  Map<String, Object?> toJson() => <String, Object?>{
    'support': support,
    'enrichment': enrichment,
  };
}

class TeacherGuideProvenance {
  const TeacherGuideProvenance({
    required this.sourceIds,
    required this.sourceLocators,
    required this.contentClass,
    this.note,
    this.additional = const {},
  });

  factory TeacherGuideProvenance.fromJson(Object? value) {
    final map = _requiredMap(value, 'provenance');
    return TeacherGuideProvenance(
      sourceIds: _stringList(map['source_ids'], 'provenance.source_ids'),
      sourceLocators: _stringList(
        map['source_locators'],
        'provenance.source_locators',
      ),
      contentClass: nullableString(map['content_class']),
      note: nullableString(map['note']),
      additional: _additionalMap(map),
    );
  }

  final List<String> sourceIds;
  final List<String> sourceLocators;
  final String? contentClass;
  final String? note;
  final Map<String, dynamic> additional;

  Map<String, Object?> toJson() => <String, Object?>{
    'source_ids': sourceIds,
    'source_locators': sourceLocators,
    if (contentClass != null) 'content_class': contentClass,
    if (note != null) 'note': note,
    ...additional,
  };
}

/// A typed, explicit link from a guide item to any canonical runtime entity.
///
/// [targetType] is deliberately a string. The runtime registry is the
/// integrity boundary, so adding a future canonical entity does not require a
/// Flutter enum or a new hard-coded branch.
class TeacherGuideRelation {
  const TeacherGuideRelation({
    required this.itemId,
    required this.targetType,
    required this.targetId,
    required this.relationType,
    required this.order,
  });

  factory TeacherGuideRelation.fromRow(TeacherGuideRow row) =>
      TeacherGuideRelation(
        itemId: _requiredString(row['item_id'], 'item_id'),
        targetType: _requiredString(row['target_type'], 'target_type'),
        targetId: _requiredString(row['target_id'], 'target_id'),
        relationType: _requiredString(row['relation_type'], 'relation_type'),
        order: _requiredInt(row['relation_order'], 'relation_order'),
      );

  final String itemId;
  final String targetType;
  final String targetId;
  final String relationType;
  final int order;
}

Object? _jsonValue(Object? value, String field) {
  if (value is String) {
    if (value.trim().isEmpty) {
      throw TeacherGuideFormatException('$field boş JSON içeriyor.');
    }
    try {
      return _freezeJson(jsonDecode(value));
    } on FormatException catch (error) {
      throw TeacherGuideFormatException('$field geçersiz JSON: $error');
    }
  }
  if (value == null) {
    throw TeacherGuideFormatException('$field eksik.');
  }
  return _freezeJson(value);
}

Object? _optionalJsonValue(Object? value, String field) {
  if (value == null) return null;
  return _freezeJson(value);
}

Object? _requiredJson(Object? value, String field) => _jsonValue(value, field);

Map<String, dynamic> _requiredMap(Object? value, String field) {
  final frozen = _freezeJson(value);
  if (frozen is! Map) {
    throw TeacherGuideFormatException('$field nesne olmalı.');
  }
  return Map<String, dynamic>.from(frozen);
}

Map<String, dynamic> _additionalMap(Map<String, dynamic> map) {
  final additional = <String, dynamic>{...map};
  for (final key in const [
    'source_ids',
    'source_locators',
    'content_class',
    'note',
  ]) {
    additional.remove(key);
  }
  return Map<String, dynamic>.unmodifiable(additional);
}

List<String> _stringList(Object? value, String field) {
  if (value is! List) {
    throw TeacherGuideFormatException('$field liste olmalı.');
  }
  final result = <String>[];
  for (final entry in value) {
    if (entry is! String || entry.trim().isEmpty) {
      throw TeacherGuideFormatException('$field yalnızca dolu metin içermeli.');
    }
    result.add(entry);
  }
  return List.unmodifiable(result);
}

String _requiredString(Object? value, String field) {
  final result = value?.toString().trim() ?? '';
  if (result.isEmpty) {
    throw TeacherGuideFormatException('$field eksik veya boş.');
  }
  return value.toString();
}

int _requiredInt(Object? value, String field) {
  final result = nullableInt(value);
  if (result == null) {
    throw TeacherGuideFormatException('$field integer olmalı.');
  }
  return result;
}

Object? _freezeJson(Object? value) {
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const TeacherGuideFormatException(
          'JSON nesne anahtarları metin olmalı.',
        );
      }
      result[entry.key as String] = _freezeJson(entry.value);
    }
    return Map<String, dynamic>.unmodifiable(result);
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeJson));
  }
  if (value is String || value is num || value is bool || value == null) {
    return value;
  }
  throw TeacherGuideFormatException(
    'Desteklenmeyen JSON değeri: ${value.runtimeType}.',
  );
}
