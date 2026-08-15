import 'package:sqflite/sqflite.dart';

import '../../domain/models/course_models.dart';
import '../../domain/services/sequence_navigation.dart';

class CourseDatabaseDataSource {
  const CourseDatabaseDataSource(this._database);

  final Database _database;

  Future<Course> getCourse() async {
    final rows = await _database.rawQuery('''
      SELECT course_id, grade, title, schema_version, source_manifest_fingerprint
      FROM courses
      LIMIT 1
    ''');
    return Course.fromRow(_first(rows, 'courses'));
  }

  Future<List<Theme>> getThemes() async {
    final rows = await _database.rawQuery('''
      SELECT theme_id, theme_order, title, page_range, planned_hours,
             anlama_hours, anlatma_hours, source_locator
      FROM themes
      ORDER BY theme_order
    ''');
    return rows.map(Theme.fromRow).toList(growable: false);
  }

  Future<Theme> getTheme(String themeId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT theme_id, theme_order, title, page_range, planned_hours,
             anlama_hours, anlatma_hours, source_locator
      FROM themes
      WHERE theme_id = ?
    ''',
      [themeId],
    );
    return Theme.fromRow(_first(rows, 'theme $themeId'));
  }

  Future<List<Block>> getBlocks(String themeId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT block_id, theme_id, block_order, title, skill_domain,
             learning_area, planned_hours, time_status, source_locators_json
      FROM blocks
      WHERE theme_id = ?
      ORDER BY block_order
    ''',
      [themeId],
    );
    return rows.map(Block.fromRow).toList(growable: false);
  }

  Future<Block> getBlock(String blockId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT block_id, theme_id, block_order, title, skill_domain,
             learning_area, planned_hours, time_status, source_locators_json
      FROM blocks
      WHERE block_id = ?
    ''',
      [blockId],
    );
    return Block.fromRow(_first(rows, 'block $blockId'));
  }

  Future<List<Outcome>> getOutcomesForBlock(String blockId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT o.outcome_id, o.theme_id, o.outcome_code, o.official_text,
             o.process_components, o.source_locator, o.verification_status
      FROM outcomes o
      INNER JOIN block_outcomes bo ON bo.outcome_id = o.outcome_id
      WHERE bo.block_id = ?
      ORDER BY o.outcome_code
    ''',
      [blockId],
    );
    return rows.map(Outcome.fromRow).toList(growable: false);
  }

  Future<List<Outcome>> getOutcomesForTheme(String themeId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT outcome_id, theme_id, outcome_code, official_text,
             process_components, source_locator, verification_status
      FROM outcomes
      WHERE theme_id = ?
      ORDER BY outcome_code
    ''',
      [themeId],
    );
    return rows.map(Outcome.fromRow).toList(growable: false);
  }

  Future<List<TextbookSection>> getTextbookSections(String themeId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT section_id, theme_id, title, genre, printed_page_range,
             pdf_page_range, source_id
      FROM textbook_sections
      WHERE theme_id = ?
      ORDER BY section_id
    ''',
      [themeId],
    );
    return rows.map(TextbookSection.fromRow).toList(growable: false);
  }

  Future<List<Activity>> getActivitiesForBlock(String blockId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT a.activity_id, a.section_id, a.theme_id, a.title,
             a.activity_type, a.student_action, a.expected_evidence,
             a.printed_page, a.pdf_page, a.verification_status
      FROM activities a
      INNER JOIN block_activities ba ON ba.activity_id = a.activity_id
      WHERE ba.block_id = ?
      ORDER BY a.activity_id
    ''',
      [blockId],
    );
    return rows.map(Activity.fromRow).toList(growable: false);
  }

  Future<List<Activity>> getActivitiesForTheme(String themeId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT activity_id, section_id, theme_id, title, activity_type,
             student_action, expected_evidence, printed_page, pdf_page,
             verification_status
      FROM activities
      WHERE theme_id = ?
      ORDER BY activity_id
    ''',
      [themeId],
    );
    return rows.map(Activity.fromRow).toList(growable: false);
  }

  Future<List<Form>> getFormsForActivities(List<String> activityIds) async {
    if (activityIds.isEmpty) return const [];
    final placeholders = List.filled(activityIds.length, '?').join(', ');
    final rows = await _database.rawQuery('''
      SELECT DISTINCT f.form_id, f.title, f.structural_type,
             f.assessment_type, f.printed_page, f.pdf_page, f.evaluator,
             f.source_id, f.verification_status
      FROM forms f
      INNER JOIN activity_forms af ON af.form_id = f.form_id
      WHERE af.activity_id IN ($placeholders)
      ORDER BY f.form_id
    ''', activityIds);
    return rows.map(Form.fromRow).toList(growable: false);
  }

  Future<List<ResourceDecision>> getResourceDecisions(String themeId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT resource_plan_id, theme_id, need_id, resource_type,
             decision_code, app_category, priority, purpose,
             expected_evidence, textbook_coverage, locator,
             teacher_review_required
      FROM resource_decisions
      WHERE theme_id = ?
      ORDER BY resource_plan_id
    ''',
      [themeId],
    );
    return rows.map(ResourceDecision.fromRow).toList(growable: false);
  }

  Future<List<AssessmentArtifact>> getAssessmentArtifacts(
    String themeId,
  ) async {
    final rows = await _database.rawQuery('''
      SELECT artifact_id, title, skill_domain, scope, assessment_family,
             reuse_policy, generation_priority, generation_status,
             teacher_review_required, covered_themes_json,
             covered_gap_instances_json
      FROM assessment_artifacts
      ORDER BY artifact_id
    ''');
    return rows
        .map(AssessmentArtifact.fromRow)
        .where((artifact) => artifact.coveredThemes.contains(themeId))
        .toList(growable: false);
  }

  Future<List<AssessmentGapMapping>> getAssessmentGaps(String themeId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT gap_instance_id, artifact_id, theme_id, resource_plan_id,
             official_requirement, exact_remaining_gap, source_locators_json
      FROM assessment_gap_mappings
      WHERE theme_id = ?
      ORDER BY gap_instance_id
    ''',
      [themeId],
    );
    return rows.map(AssessmentGapMapping.fromRow).toList(growable: false);
  }

  Future<List<AssessmentTaskBinding>> getAssessmentTaskBindings({
    required String themeId,
    String? blockId,
  }) async {
    final where = blockId == null
        ? 'WHERE theme_id = ?'
        : 'WHERE theme_id = ? AND block_id = ?';
    final arguments = blockId == null ? [themeId] : [themeId, blockId];
    final rows = await _database.rawQuery('''
      SELECT artifact_id, gap_instance_id, theme_id, block_id, activity_id,
             targeted_outcomes_json, task_title, evidence, textbook_locator,
             curriculum_locator
      FROM assessment_task_bindings
      $where
      ORDER BY artifact_id, gap_instance_id
    ''', arguments);
    return rows.map(AssessmentTaskBinding.fromRow).toList(growable: false);
  }

  Future<List<SourceReference>> getSourceReferencesForTheme(
    String themeId,
  ) async {
    final rows = await _database.rawQuery(
      '''
      SELECT sr.source_id, sr.source_type, sr.source_title,
             sr.locator AS source_locator, sr.provenance_category,
             sr.authority_rank, sr.verification_status,
             esr.locator AS entity_locator
      FROM entity_source_references esr
      INNER JOIN source_references sr ON sr.source_id = esr.source_id
      WHERE esr.entity_type = 'theme' AND esr.entity_id = ?
      ORDER BY sr.authority_rank, sr.source_id
    ''',
      [themeId],
    );
    return rows.map(SourceReference.fromRow).toList(growable: false);
  }

  Future<List<TimelineEntry>> getAnnualSequence() async {
    final rows = await _database.rawQuery('''
      SELECT t.theme_id, t.theme_order, t.title AS theme_title,
             t.page_range AS theme_page_range,
             t.planned_hours AS theme_planned_hours,
             t.anlama_hours AS theme_anlama_hours,
             t.anlatma_hours AS theme_anlatma_hours,
             t.source_locator AS theme_source_locator,
             b.block_id, b.theme_id AS block_theme_id,
             tb.block_order, b.title AS block_title,
             b.skill_domain, b.learning_area,
             tb.planned_hours, tb.time_status, tb.source_locators_json,
             tt.official_total_hours, tt.core_instruction_hours,
             tt.school_based_hours, tt.school_based_hours_status
      FROM timeline_blocks tb
      INNER JOIN blocks b ON b.block_id = tb.block_id
      INNER JOIN themes t ON t.theme_id = tb.theme_id
      LEFT JOIN timeline_themes tt ON tt.theme_id = tb.theme_id
      ORDER BY t.theme_order, tb.block_order
    ''');
    return [
      for (var index = 0; index < rows.length; index++)
        TimelineEntry(
          sequencePosition: index + 1,
          theme: Theme(
            id: rows[index]['theme_id']! as String,
            order: nullableInt(rows[index]['theme_order']) ?? 0,
            title: rows[index]['theme_title']! as String,
            pageRange: nullableString(rows[index]['theme_page_range']),
            plannedHours: nullableInt(rows[index]['theme_planned_hours']),
            anlamaHours: nullableInt(rows[index]['theme_anlama_hours']),
            anlatmaHours: nullableInt(rows[index]['theme_anlatma_hours']),
            sourceLocator: nullableString(rows[index]['theme_source_locator']),
          ),
          block: Block(
            id: rows[index]['block_id']! as String,
            themeId: rows[index]['block_theme_id']! as String,
            order: nullableInt(rows[index]['block_order']) ?? 0,
            title: rows[index]['block_title']! as String,
            skillDomain: nullableString(rows[index]['skill_domain']),
            learningArea: nullableString(rows[index]['learning_area']),
            plannedHours: nullableInt(rows[index]['planned_hours']),
            timeStatus: nullableString(rows[index]['time_status']),
            sourceLocators: jsonStringList(
              nullableString(rows[index]['source_locators_json']),
            ),
          ),
          officialTotalHours: nullableInt(rows[index]['official_total_hours']),
          coreInstructionHours: nullableInt(
            rows[index]['core_instruction_hours'],
          ),
          schoolBasedHours: nullableInt(rows[index]['school_based_hours']),
          schoolBasedHoursStatus: nullableString(
            rows[index]['school_based_hours_status'],
          ),
        ),
    ];
  }

  Future<Block?> getPreviousBlock(Block current) async =>
      previousBlockInSequence(await getAnnualSequence(), current.id);

  Future<Block?> getNextBlock(Block current) async =>
      nextBlockInSequence(await getAnnualSequence(), current.id);

  Future<BlockDetail> getBlockDetail(String blockId) async {
    final block = await getBlock(blockId);
    final theme = await getTheme(block.themeId);
    final outcomes = await getOutcomesForBlock(blockId);
    final activities = await getActivitiesForBlock(blockId);
    final themeSections = await getTextbookSections(theme.id);
    final sectionIds = activities
        .map((activity) => activity.sectionId)
        .whereType<String>()
        .toSet();
    final textbookSections = themeSections
        .where((section) => sectionIds.contains(section.id))
        .toList(growable: false);
    final forms = await getFormsForActivities(
      activities.map((activity) => activity.id).toList(growable: false),
    );
    return BlockDetail(
      theme: theme,
      block: block,
      outcomes: outcomes,
      textbookSections: textbookSections,
      activities: activities,
      forms: forms,
      assessmentArtifacts: await getAssessmentArtifacts(theme.id),
      assessmentGaps: await getAssessmentGaps(theme.id),
      assessmentTaskBindings: await getAssessmentTaskBindings(
        themeId: theme.id,
        blockId: block.id,
      ),
      resourceDecisions: await getResourceDecisions(theme.id),
      sourceReferences: await getSourceReferencesForTheme(theme.id),
      previousBlock: await getPreviousBlock(block),
      nextBlock: await getNextBlock(block),
    );
  }

  Future<TeacherPackage> getTeacherPackage(String themeId) async {
    final theme = await getTheme(themeId);
    final blocks = await getBlocks(themeId);
    final activities = await getActivitiesForTheme(themeId);
    return TeacherPackage(
      theme: theme,
      blocks: blocks,
      outcomes: await getOutcomesForTheme(themeId),
      textbookSections: await getTextbookSections(themeId),
      activities: activities,
      forms: await getFormsForActivities(
        activities.map((activity) => activity.id).toList(growable: false),
      ),
      assessmentArtifacts: await getAssessmentArtifacts(themeId),
      assessmentGaps: await getAssessmentGaps(themeId),
      assessmentTaskBindings: await getAssessmentTaskBindings(themeId: themeId),
      resourceDecisions: await getResourceDecisions(themeId),
      sourceReferences: await getSourceReferencesForTheme(themeId),
    );
  }

  Row _first(List<Row> rows, String entity) {
    if (rows.isEmpty) throw StateError('$entity bulunamadı.');
    return rows.first;
  }
}
