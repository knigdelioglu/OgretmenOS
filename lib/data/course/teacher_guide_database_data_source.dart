import 'package:sqflite/sqflite.dart';

import '../../domain/models/course_models.dart';
import '../../domain/models/teacher_guide_models.dart';

/// Read-only SQLite adapter for the optional teacher-guide projection.
///
/// This data source never falls back to labels or IDs from another runtime
/// table. Entity relationships are read only from
/// `teacher_guide_item_relations` and are integrity-checked by the runtime
/// verifier before a capable package is published.
class TeacherGuideDatabaseDataSource {
  const TeacherGuideDatabaseDataSource(this._database);

  final Database _database;

  Future<TeacherGuideCapability> getCapability(RuntimeManifest manifest) async {
    final tablePresence = <String, bool>{};
    for (final table in teacherGuideRuntimeTableNames) {
      tablePresence[table] = await _hasTable(table);
    }

    final tablesAvailable = teacherGuideRuntimeTableNames.every(
      (table) => tablePresence[table] == true,
    );
    final counts = <String, int>{};
    for (final table in teacherGuideRuntimeTableNames) {
      if (tablePresence[table] == true) {
        counts[table] = await _count(table);
      } else {
        counts[table] = 0;
      }
    }

    final manifestAdvertised = manifest.hasCapability('teacher_guide');
    final metadata = manifest.teacherGuideCapabilities;
    final metadataAvailable = metadata['available'] == true;
    final metadataSourceBound = metadata['source_bound'] == true;
    final metadataValidationStatus = metadata['validation_status']?.toString();
    final validation = manifest.teacherGuideValidation;
    final validationCanonicalFingerprint =
        validation['canonical_content_fingerprint']?.toString().trim();
    final validationEvidence =
        validation['status'] == 'PASS' &&
        validation['scope'] == 'COURSE' &&
        validation['source_bound'] == true &&
        (validation['content_fingerprint']?.toString().trim() ?? '')
            .isNotEmpty &&
        validationCanonicalFingerprint == manifest.canonicalContentFingerprint;
    final countsPresent = teacherGuideRuntimeTableNames.every(
      (table) => manifest.rowCounts.containsKey(table),
    );
    final rowCountsMatch =
        countsPresent &&
        teacherGuideRuntimeTableNames.every(
          (table) => manifest.rowCounts[table] == counts[table],
        );
    final hasContent =
        counts['canonical_entities']! > 0 &&
        counts['teacher_guides']! > 0 &&
        counts['teacher_guide_sections']! > 0 &&
        counts['teacher_guide_units']! > 0 &&
        counts['teacher_guide_items']! > 0;

    var reason = _capabilityReason(
      manifest: manifest,
      manifestAdvertised: manifestAdvertised,
      tablesAvailable: tablesAvailable,
      metadataAvailable: metadataAvailable,
      metadataSourceBound: metadataSourceBound,
      metadataValidationStatus: metadataValidationStatus,
      validationEvidence: validationEvidence,
      countsPresent: countsPresent,
      rowCountsMatch: rowCountsMatch,
      hasContent: hasContent,
    );
    final available = reason == null;
    if (available) reason = null;

    return TeacherGuideCapability(
      available: available,
      manifestAdvertised: manifestAdvertised,
      tablesAvailable: tablesAvailable,
      canonicalEntityCount: counts['canonical_entities']!,
      guideCount: counts['teacher_guides']!,
      sectionCount: counts['teacher_guide_sections']!,
      unitCount: counts['teacher_guide_units']!,
      itemCount: counts['teacher_guide_items']!,
      relationCount: counts['teacher_guide_item_relations']!,
      schemaVersion: metadata['schema_version']?.toString(),
      validationStatus: manifest.validationStatus,
      reason: reason,
    );
  }

  Future<TeacherGuide?> getTeacherGuideForScope({
    required String scopeType,
    required String scopeId,
  }) async {
    if (!await _hasTable('teacher_guides')) return null;
    final rows = await _database.rawQuery(
      '''
      SELECT guide_id, course_id, scope_type, scope_id, title,
             content_status, schema_version, provenance_json
      FROM teacher_guides
      WHERE scope_type = ? AND scope_id = ?
      ORDER BY guide_id
      LIMIT 1
      ''',
      [scopeType, scopeId],
    );
    return rows.isEmpty ? null : TeacherGuide.fromRow(rows.first);
  }

  Future<List<TeacherGuideSection>> getTeacherGuideSections(
    String guideId,
  ) async {
    if (!await _hasTable('teacher_guide_sections')) return const [];
    final rows = await _database.rawQuery(
      '''
      SELECT section_id, guide_id, section_order, title, section_type,
             page_locator, source_locator, content_status, provenance_json
      FROM teacher_guide_sections
      WHERE guide_id = ?
      ORDER BY section_order, section_id
      ''',
      [guideId],
    );
    return rows.map(TeacherGuideSection.fromRow).toList(growable: false);
  }

  Future<TeacherGuideSection?> getTeacherGuideSection(String sectionId) async {
    if (!await _hasTable('teacher_guide_sections')) return null;
    final rows = await _database.rawQuery(
      '''
      SELECT section_id, guide_id, section_order, title, section_type,
             page_locator, source_locator, content_status, provenance_json
      FROM teacher_guide_sections
      WHERE section_id = ?
      LIMIT 1
      ''',
      [sectionId],
    );
    return rows.isEmpty ? null : TeacherGuideSection.fromRow(rows.first);
  }

  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async {
    if (!await _hasTable('teacher_guide_units')) return const [];
    final rows = await _database.rawQuery(
      '''
      SELECT unit_id, section_id, unit_order, title, page_locator,
             source_locator, content_status, purpose_json, provenance_json
      FROM teacher_guide_units
      WHERE section_id = ?
      ORDER BY unit_order, unit_id
      ''',
      [sectionId],
    );
    return rows.map(TeacherGuideUnit.fromRow).toList(growable: false);
  }

  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId) async {
    if (!await _hasTable('teacher_guide_units')) return null;
    final rows = await _database.rawQuery(
      '''
      SELECT unit_id, section_id, unit_order, title, page_locator,
             source_locator, content_status, purpose_json, provenance_json
      FROM teacher_guide_units
      WHERE unit_id = ?
      LIMIT 1
      ''',
      [unitId],
    );
    return rows.isEmpty ? null : TeacherGuideUnit.fromRow(rows.first);
  }

  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async {
    if (!await _hasTable('teacher_guide_items')) return const [];
    final rows = await _database.rawQuery(
      '''
      SELECT item_id, unit_id, item_order, title, label, item_type,
             page_locator, source_locator, content_status,
             expected_response_json, acceptance_criteria_json,
             teacher_guidance_json, common_misconceptions_json,
             assessment_evidence_json, differentiation_json, provenance_json,
             canonical_payload_sha256
      FROM teacher_guide_items
      WHERE unit_id = ?
      ORDER BY item_order, item_id
      ''',
      [unitId],
    );
    return _hydrateItems(rows);
  }

  Future<TeacherGuideItem?> getTeacherGuideItem(String itemId) async {
    if (!await _hasTable('teacher_guide_items')) return null;
    final rows = await _database.rawQuery(
      '''
      SELECT item_id, unit_id, item_order, title, label, item_type,
             page_locator, source_locator, content_status,
             expected_response_json, acceptance_criteria_json,
             teacher_guidance_json, common_misconceptions_json,
             assessment_evidence_json, differentiation_json, provenance_json,
             canonical_payload_sha256
      FROM teacher_guide_items
      WHERE item_id = ?
      LIMIT 1
      ''',
      [itemId],
    );
    if (rows.isEmpty) return null;
    return (await _hydrateItems(rows)).single;
  }

  Future<List<TeacherGuideItem>> getTeacherGuideItemsForEntity({
    required String targetType,
    required String targetId,
    String? relationType,
  }) async {
    if (!await _hasTable('teacher_guide_item_relations')) return const [];
    final relationFilter = relationType == null
        ? ''
        : ' AND r.relation_type = ?';
    final arguments = <Object?>[targetType, targetId, ?relationType];
    final rows = await _database.rawQuery('''
      SELECT DISTINCT i.item_id, i.unit_id, i.item_order, i.title, i.label,
             i.item_type, i.page_locator, i.source_locator, i.content_status,
             i.expected_response_json, i.acceptance_criteria_json,
             i.teacher_guidance_json, i.common_misconceptions_json,
             i.assessment_evidence_json, i.differentiation_json,
             i.provenance_json, i.canonical_payload_sha256
      FROM teacher_guide_item_relations r
      INNER JOIN teacher_guide_items i ON i.item_id = r.item_id
      INNER JOIN teacher_guide_units u ON u.unit_id = i.unit_id
      INNER JOIN teacher_guide_sections s ON s.section_id = u.section_id
      INNER JOIN teacher_guides g ON g.guide_id = s.guide_id
      WHERE r.target_type = ? AND r.target_id = ?$relationFilter
      ORDER BY g.guide_id, s.section_order, s.section_id,
               u.unit_order, u.unit_id, i.item_order, i.item_id
      ''', arguments);
    return _hydrateItems(rows);
  }

  Future<List<TeacherGuideItem>> _hydrateItems(
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final items = rows.map(TeacherGuideItem.fromRow).toList(growable: false);
    return _attachRelationsAsync(items);
  }

  Future<List<TeacherGuideItem>> _attachRelationsAsync(
    List<TeacherGuideItem> items,
  ) async {
    if (!await _hasTable('teacher_guide_item_relations')) return items;
    final placeholders = List.filled(items.length, '?').join(', ');
    final rows = await _database.rawQuery('''
      SELECT item_id, target_type, target_id, relation_type, relation_order
      FROM teacher_guide_item_relations
      WHERE item_id IN ($placeholders)
      ORDER BY item_id, relation_order, target_type, target_id, relation_type
      ''', items.map((item) => item.itemId).toList(growable: false));
    final relationsByItem = <String, List<TeacherGuideRelation>>{};
    for (final row in rows) {
      final relation = TeacherGuideRelation.fromRow(row);
      relationsByItem.putIfAbsent(relation.itemId, () => []).add(relation);
    }
    return items
        .map(
          (item) =>
              item.withRelations(relationsByItem[item.itemId] ?? const []),
        )
        .toList(growable: false);
  }

  Future<bool> _hasTable(String table) async {
    final rows = await _database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<int> _count(String table) async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM $table',
    );
    return _int(rows.first['count']);
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _capabilityReason({
    required RuntimeManifest manifest,
    required bool manifestAdvertised,
    required bool tablesAvailable,
    required bool metadataAvailable,
    required bool metadataSourceBound,
    required String? metadataValidationStatus,
    required bool validationEvidence,
    required bool countsPresent,
    required bool rowCountsMatch,
    required bool hasContent,
  }) {
    if (!manifestAdvertised) return 'TEACHER_GUIDE_NOT_ADVERTISED';
    if (!tablesAvailable) return 'TEACHER_GUIDE_TABLE_MISSING';
    if (manifest.validationStatus != 'PASS') {
      return 'RUNTIME_VALIDATION_NOT_PASS';
    }
    if (!metadataAvailable) return 'TEACHER_GUIDE_METADATA_UNAVAILABLE';
    if (!metadataSourceBound) return 'TEACHER_GUIDE_SOURCE_UNBOUND';
    if (metadataValidationStatus != 'PASS') {
      return 'TEACHER_GUIDE_VALIDATION_NOT_PASS';
    }
    if (!validationEvidence) return 'TEACHER_GUIDE_VALIDATION_EVIDENCE_MISSING';
    if (!countsPresent) return 'TEACHER_GUIDE_ROW_COUNTS_MISSING';
    if (!rowCountsMatch) return 'TEACHER_GUIDE_ROW_COUNT_MISMATCH';
    if (!hasContent) return 'TEACHER_GUIDE_TABLE_EMPTY';
    return null;
  }
}
