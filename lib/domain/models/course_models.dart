import 'dart:convert';

typedef Row = Map<String, Object?>;

String? nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

int? nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool nullableBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString() == '1' || value?.toString().toLowerCase() == 'true';
}

List<String> jsonStringList(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return decoded.whereType<String>().toList(growable: false);
    }
  } on FormatException {
    return const [];
  }
  return const [];
}

class RuntimeManifest {
  const RuntimeManifest({
    required this.runtimePackageVersion,
    required this.schemaVersion,
    required this.courseId,
    required this.validationStatus,
    required this.canonicalContentFingerprint,
    required this.rowCounts,
    required this.timelineResolution,
    required this.timelineUnresolvedFields,
  });

  factory RuntimeManifest.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['row_counts'];
    final rowCounts = <String, int>{};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final value = nullableInt(entry.value);
        if (value != null) rowCounts[entry.key.toString()] = value;
      }
    }
    final rawUnresolved = json['timeline_unresolved_fields'];
    final unresolved = <String, Object?>{};
    if (rawUnresolved is Map) {
      for (final entry in rawUnresolved.entries) {
        unresolved[entry.key.toString()] = entry.value;
      }
    }
    return RuntimeManifest(
      runtimePackageVersion: json['runtime_package_version']?.toString() ?? '',
      schemaVersion: json['schema_version']?.toString() ?? '',
      courseId: json['course_id']?.toString() ?? '',
      validationStatus: json['validation_status']?.toString() ?? '',
      canonicalContentFingerprint:
          json['canonical_content_fingerprint']?.toString() ?? '',
      rowCounts: rowCounts,
      timelineResolution: json['timeline_resolution']?.toString() ?? '',
      timelineUnresolvedFields: unresolved,
    );
  }

  final String runtimePackageVersion;
  final String schemaVersion;
  final String courseId;
  final String validationStatus;
  final String canonicalContentFingerprint;
  final Map<String, int> rowCounts;
  final String timelineResolution;
  final Map<String, Object?> timelineUnresolvedFields;

  bool get isCompatible =>
      courseId == 'TDE_9' &&
      schemaVersion.startsWith('1.') &&
      validationStatus == 'PASS';

  String? get weeklyLessonHours =>
      timelineUnresolvedFields['weekly_lesson_hours']?.toString();

  String? get calendarBinding =>
      timelineUnresolvedFields['calendar_binding']?.toString();

  String? get blockHours => timelineUnresolvedFields['block_hours']?.toString();
}

class Course {
  const Course({
    required this.courseId,
    required this.grade,
    required this.title,
    required this.schemaVersion,
    required this.sourceManifestFingerprint,
  });

  factory Course.fromRow(Row row) => Course(
    courseId: row['course_id']! as String,
    grade: nullableInt(row['grade']) ?? 0,
    title: row['title']! as String,
    schemaVersion: row['schema_version']! as String,
    sourceManifestFingerprint: row['source_manifest_fingerprint']! as String,
  );

  final String courseId;
  final int grade;
  final String title;
  final String schemaVersion;
  final String sourceManifestFingerprint;
}

class Theme {
  const Theme({
    required this.id,
    required this.order,
    required this.title,
    required this.pageRange,
    required this.plannedHours,
    required this.anlamaHours,
    required this.anlatmaHours,
    required this.sourceLocator,
  });

  factory Theme.fromRow(Row row) => Theme(
    id: row['theme_id']! as String,
    order: nullableInt(row['theme_order']) ?? 0,
    title: row['title']! as String,
    pageRange: nullableString(row['page_range']),
    plannedHours: nullableInt(row['planned_hours']),
    anlamaHours: nullableInt(row['anlama_hours']),
    anlatmaHours: nullableInt(row['anlatma_hours']),
    sourceLocator: nullableString(row['source_locator']),
  );

  final String id;
  final int order;
  final String title;
  final String? pageRange;
  final int? plannedHours;
  final int? anlamaHours;
  final int? anlatmaHours;
  final String? sourceLocator;
}

class Block {
  const Block({
    required this.id,
    required this.themeId,
    required this.order,
    required this.title,
    required this.skillDomain,
    required this.learningArea,
    required this.plannedHours,
    required this.timeStatus,
    required this.sourceLocators,
  });

  factory Block.fromRow(Row row) => Block(
    id: row['block_id']! as String,
    themeId: row['theme_id']! as String,
    order: nullableInt(row['block_order']) ?? 0,
    title: row['title']! as String,
    skillDomain: nullableString(row['skill_domain']),
    learningArea: nullableString(row['learning_area']),
    plannedHours: nullableInt(row['planned_hours']),
    timeStatus: nullableString(row['time_status']),
    sourceLocators: jsonStringList(nullableString(row['source_locators_json'])),
  );

  final String id;
  final String themeId;
  final int order;
  final String title;
  final String? skillDomain;
  final String? learningArea;
  final int? plannedHours;
  final String? timeStatus;
  final List<String> sourceLocators;
}

class Outcome {
  const Outcome({
    required this.id,
    required this.themeId,
    required this.code,
    required this.officialText,
    required this.processComponents,
    required this.sourceLocator,
    required this.verificationStatus,
  });

  factory Outcome.fromRow(Row row) => Outcome(
    id: row['outcome_id']! as String,
    themeId: row['theme_id']! as String,
    code: row['outcome_code']! as String,
    officialText: row['official_text']! as String,
    processComponents: nullableString(row['process_components']),
    sourceLocator: nullableString(row['source_locator']),
    verificationStatus: nullableString(row['verification_status']),
  );

  final String id;
  final String themeId;
  final String code;
  final String officialText;
  final String? processComponents;
  final String? sourceLocator;
  final String? verificationStatus;
}

class TextbookSection {
  const TextbookSection({
    required this.id,
    required this.themeId,
    required this.title,
    required this.genre,
    required this.printedPageRange,
    required this.pdfPageRange,
    required this.sourceId,
  });

  factory TextbookSection.fromRow(Row row) => TextbookSection(
    id: row['section_id']! as String,
    themeId: row['theme_id']! as String,
    title: row['title']! as String,
    genre: nullableString(row['genre']),
    printedPageRange: nullableString(row['printed_page_range']),
    pdfPageRange: nullableString(row['pdf_page_range']),
    sourceId: nullableString(row['source_id']),
  );

  final String id;
  final String themeId;
  final String title;
  final String? genre;
  final String? printedPageRange;
  final String? pdfPageRange;
  final String? sourceId;
}

class Activity {
  const Activity({
    required this.id,
    required this.sectionId,
    required this.themeId,
    required this.title,
    required this.activityType,
    required this.studentAction,
    required this.expectedEvidence,
    required this.printedPage,
    required this.pdfPage,
    required this.verificationStatus,
  });

  factory Activity.fromRow(Row row) => Activity(
    id: row['activity_id']! as String,
    sectionId: nullableString(row['section_id']),
    themeId: row['theme_id']! as String,
    title: row['title']! as String,
    activityType: nullableString(row['activity_type']),
    studentAction: nullableString(row['student_action']),
    expectedEvidence: nullableString(row['expected_evidence']),
    printedPage: nullableString(row['printed_page']),
    pdfPage: nullableString(row['pdf_page']),
    verificationStatus: nullableString(row['verification_status']),
  );

  final String id;
  final String? sectionId;
  final String themeId;
  final String title;
  final String? activityType;
  final String? studentAction;
  final String? expectedEvidence;
  final String? printedPage;
  final String? pdfPage;
  final String? verificationStatus;
}

class Form {
  const Form({
    required this.id,
    required this.title,
    required this.structuralType,
    required this.assessmentType,
    required this.printedPage,
    required this.pdfPage,
    required this.evaluator,
    required this.sourceId,
    required this.verificationStatus,
  });

  factory Form.fromRow(Row row) => Form(
    id: row['form_id']! as String,
    title: row['title']! as String,
    structuralType: nullableString(row['structural_type']),
    assessmentType: nullableString(row['assessment_type']),
    printedPage: nullableInt(row['printed_page']),
    pdfPage: nullableInt(row['pdf_page']),
    evaluator: nullableString(row['evaluator']),
    sourceId: nullableString(row['source_id']),
    verificationStatus: nullableString(row['verification_status']),
  );

  final String id;
  final String title;
  final String? structuralType;
  final String? assessmentType;
  final int? printedPage;
  final int? pdfPage;
  final String? evaluator;
  final String? sourceId;
  final String? verificationStatus;
}

class ResourceDecision {
  const ResourceDecision({
    required this.id,
    required this.themeId,
    required this.needId,
    required this.resourceType,
    required this.decisionCode,
    required this.appCategory,
    required this.priority,
    required this.purpose,
    required this.expectedEvidence,
    required this.textbookCoverage,
    required this.locator,
    required this.teacherReviewRequired,
  });

  factory ResourceDecision.fromRow(Row row) => ResourceDecision(
    id: row['resource_plan_id']! as String,
    themeId: row['theme_id']! as String,
    needId: nullableString(row['need_id']),
    resourceType: nullableString(row['resource_type']),
    decisionCode: row['decision_code']! as String,
    appCategory: nullableString(row['app_category']),
    priority: nullableString(row['priority']),
    purpose: nullableString(row['purpose']),
    expectedEvidence: nullableString(row['expected_evidence']),
    textbookCoverage: nullableString(row['textbook_coverage']),
    locator: nullableString(row['locator']),
    teacherReviewRequired: nullableBool(row['teacher_review_required']),
  );

  final String id;
  final String themeId;
  final String? needId;
  final String? resourceType;
  final String decisionCode;
  final String? appCategory;
  final String? priority;
  final String? purpose;
  final String? expectedEvidence;
  final String? textbookCoverage;
  final String? locator;
  final bool teacherReviewRequired;
}

class AssessmentArtifact {
  const AssessmentArtifact({
    required this.id,
    required this.title,
    required this.skillDomain,
    required this.scope,
    required this.assessmentFamily,
    required this.reusePolicy,
    required this.generationPriority,
    required this.generationStatus,
    required this.teacherReviewRequired,
    required this.coveredThemes,
    required this.coveredGapInstances,
  });

  factory AssessmentArtifact.fromRow(Row row) => AssessmentArtifact(
    id: row['artifact_id']! as String,
    title: row['title']! as String,
    skillDomain: nullableString(row['skill_domain']),
    scope: nullableString(row['scope']),
    assessmentFamily: nullableString(row['assessment_family']),
    reusePolicy: nullableString(row['reuse_policy']),
    generationPriority: nullableString(row['generation_priority']),
    generationStatus: nullableString(row['generation_status']),
    teacherReviewRequired: nullableBool(row['teacher_review_required']),
    coveredThemes: jsonStringList(nullableString(row['covered_themes_json'])),
    coveredGapInstances: jsonStringList(
      nullableString(row['covered_gap_instances_json']),
    ),
  );

  final String id;
  final String title;
  final String? skillDomain;
  final String? scope;
  final String? assessmentFamily;
  final String? reusePolicy;
  final String? generationPriority;
  final String? generationStatus;
  final bool teacherReviewRequired;
  final List<String> coveredThemes;
  final List<String> coveredGapInstances;
}

class AssessmentGapMapping {
  const AssessmentGapMapping({
    required this.id,
    required this.artifactId,
    required this.themeId,
    required this.resourcePlanId,
    required this.officialRequirement,
    required this.exactRemainingGap,
    required this.sourceLocators,
  });

  factory AssessmentGapMapping.fromRow(Row row) => AssessmentGapMapping(
    id: row['gap_instance_id']! as String,
    artifactId: row['artifact_id']! as String,
    themeId: row['theme_id']! as String,
    resourcePlanId: nullableString(row['resource_plan_id']),
    officialRequirement: nullableString(row['official_requirement']),
    exactRemainingGap: nullableString(row['exact_remaining_gap']),
    sourceLocators: jsonStringList(nullableString(row['source_locators_json'])),
  );

  final String id;
  final String artifactId;
  final String themeId;
  final String? resourcePlanId;
  final String? officialRequirement;
  final String? exactRemainingGap;
  final List<String> sourceLocators;
}

class AssessmentTaskBinding {
  const AssessmentTaskBinding({
    required this.artifactId,
    required this.gapInstanceId,
    required this.themeId,
    required this.blockId,
    required this.activityId,
    required this.targetedOutcomes,
    required this.taskTitle,
    required this.evidence,
    required this.textbookLocator,
    required this.curriculumLocator,
  });

  factory AssessmentTaskBinding.fromRow(Row row) => AssessmentTaskBinding(
    artifactId: row['artifact_id']! as String,
    gapInstanceId: row['gap_instance_id']! as String,
    themeId: row['theme_id']! as String,
    blockId: nullableString(row['block_id']),
    activityId: nullableString(row['activity_id']),
    targetedOutcomes: jsonStringList(
      nullableString(row['targeted_outcomes_json']),
    ),
    taskTitle: nullableString(row['task_title']),
    evidence: nullableString(row['evidence']),
    textbookLocator: nullableString(row['textbook_locator']),
    curriculumLocator: nullableString(row['curriculum_locator']),
  );

  final String artifactId;
  final String gapInstanceId;
  final String themeId;
  final String? blockId;
  final String? activityId;
  final List<String> targetedOutcomes;
  final String? taskTitle;
  final String? evidence;
  final String? textbookLocator;
  final String? curriculumLocator;
}

class SourceReference {
  const SourceReference({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.locator,
    required this.provenanceCategory,
    required this.authorityRank,
    required this.verificationStatus,
    required this.entityLocator,
  });

  factory SourceReference.fromRow(Row row) => SourceReference(
    id: row['source_id']! as String,
    sourceType: nullableString(row['source_type']),
    title: row['source_title']! as String,
    locator: nullableString(row['source_locator']),
    provenanceCategory: nullableString(row['provenance_category']),
    authorityRank: nullableInt(row['authority_rank']),
    verificationStatus: nullableString(row['verification_status']),
    entityLocator: nullableString(row['entity_locator']),
  );

  final String id;
  final String? sourceType;
  final String title;
  final String? locator;
  final String? provenanceCategory;
  final int? authorityRank;
  final String? verificationStatus;
  final String? entityLocator;
}

class TimelineEntry {
  const TimelineEntry({
    required this.sequencePosition,
    required this.theme,
    required this.block,
    required this.officialTotalHours,
    required this.coreInstructionHours,
    required this.schoolBasedHours,
    required this.schoolBasedHoursStatus,
  });

  final int sequencePosition;
  final Theme theme;
  final Block block;
  final int? officialTotalHours;
  final int? coreInstructionHours;
  final int? schoolBasedHours;
  final String? schoolBasedHoursStatus;
}

class BlockDetail {
  const BlockDetail({
    required this.theme,
    required this.block,
    required this.outcomes,
    required this.textbookSections,
    required this.activities,
    required this.forms,
    required this.assessmentArtifacts,
    required this.assessmentGaps,
    required this.assessmentTaskBindings,
    required this.resourceDecisions,
    required this.sourceReferences,
    required this.previousBlock,
    required this.nextBlock,
  });

  final Theme theme;
  final Block block;
  final List<Outcome> outcomes;
  final List<TextbookSection> textbookSections;
  final List<Activity> activities;
  final List<Form> forms;
  final List<AssessmentArtifact> assessmentArtifacts;
  final List<AssessmentGapMapping> assessmentGaps;
  final List<AssessmentTaskBinding> assessmentTaskBindings;
  final List<ResourceDecision> resourceDecisions;
  final List<SourceReference> sourceReferences;
  final Block? previousBlock;
  final Block? nextBlock;
}

class TeacherPackage {
  const TeacherPackage({
    required this.theme,
    required this.blocks,
    required this.outcomes,
    required this.textbookSections,
    required this.activities,
    required this.forms,
    required this.assessmentArtifacts,
    required this.assessmentGaps,
    required this.assessmentTaskBindings,
    required this.resourceDecisions,
    required this.sourceReferences,
  });

  final Theme theme;
  final List<Block> blocks;
  final List<Outcome> outcomes;
  final List<TextbookSection> textbookSections;
  final List<Activity> activities;
  final List<Form> forms;
  final List<AssessmentArtifact> assessmentArtifacts;
  final List<AssessmentGapMapping> assessmentGaps;
  final List<AssessmentTaskBinding> assessmentTaskBindings;
  final List<ResourceDecision> resourceDecisions;
  final List<SourceReference> sourceReferences;
}
