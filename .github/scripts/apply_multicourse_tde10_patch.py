#!/usr/bin/env python3
from __future__ import annotations

import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TYMM_SHA = "a0389a83c62102fe9be082b887737638afe23b69"


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def replace(path: str, old: str, new: str, *, count: int = 1) -> None:
    text = read(path)
    actual = text.count(old)
    if actual != count:
        raise RuntimeError(f"{path}: expected {count} occurrences, got {actual}: {old[:80]!r}")
    write(path, text.replace(old, new, count))


# 1) Course registry.
write(
    "lib/domain/runtime/course_runtime_registry.dart",
    """class CourseRuntimeDescriptor {
  const CourseRuntimeDescriptor({
    required this.courseId,
    required this.grade,
    required this.label,
    required this.assetRoot,
  });

  final String courseId;
  final int grade;
  final String label;
  final String assetRoot;

  String get manifestAsset => '$assetRoot/runtime_manifest.json';
  String get databaseAsset => '$assetRoot/course_runtime.sqlite';
  String get validationReportAsset => '$assetRoot/runtime_validation_report.md';
}

const supportedCourseRuntimes = <CourseRuntimeDescriptor>[
  CourseRuntimeDescriptor(
    courseId: 'TDE_9',
    grade: 9,
    label: '9. Sınıf Türk Dili ve Edebiyatı',
    assetRoot: 'assets/courses/TDE_9',
  ),
  CourseRuntimeDescriptor(
    courseId: 'TDE_10',
    grade: 10,
    label: '10. Sınıf Türk Dili ve Edebiyatı',
    assetRoot: 'assets/courses/TDE_10',
  ),
];

bool isSupportedRuntimeCourse(String courseId) =>
    supportedCourseRuntimes.any((course) => course.courseId == courseId);

CourseRuntimeDescriptor runtimeForCourse(String courseId) =>
    supportedCourseRuntimes.firstWhere(
      (course) => course.courseId == courseId,
      orElse: () => throw StateError('Desteklenmeyen ders runtime kimliği: $courseId'),
    );
""",
)

# 2) Manifest policy: support every registered runtime.
replace(
    "lib/domain/runtime/runtime_manifest_policy.dart",
    "const supportedRuntimeCourseId = 'TDE_9';\n",
    "import 'course_runtime_registry.dart';\n\n",
)
replace(
    "lib/domain/runtime/runtime_manifest_policy.dart",
    """  if (manifest['course_id'] != supportedRuntimeCourseId) {
    throw StateError('Beklenmeyen course_id: ${manifest['course_id']}');
  }
""",
    """  final courseId = manifest['course_id']?.toString() ?? '';
  if (!isSupportedRuntimeCourse(courseId)) {
    throw StateError('Desteklenmeyen course_id: $courseId');
  }
""",
)

# 3) Runtime model capabilities + rubric payload models.
replace(
    "lib/domain/models/course_models.dart",
    "import 'dart:convert';\n",
    "import 'dart:convert';\n\nimport '../runtime/course_runtime_registry.dart';\n",
)
replace(
    "lib/domain/models/course_models.dart",
    """List<String> jsonStringList(String? value) {
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
""",
    """List<String> jsonStringList(String? value) {
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

Map<String, dynamic> jsonStringMap(String? value) {
  if (value == null || value.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    return const {};
  }
  return const {};
}

List<Map<String, dynamic>> jsonObjectList(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
  } on FormatException {
    return const [];
  }
  return const [];
}
""",
)
replace(
    "lib/domain/models/course_models.dart",
    """    required this.timelineResolution,
    required this.timelineUnresolvedFields,
  });
""",
    """    required this.timelineResolution,
    required this.timelineUnresolvedFields,
    required this.assessmentPayloadCapabilities,
  });
""",
)
replace(
    "lib/domain/models/course_models.dart",
    """    return RuntimeManifest(
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
""",
    """    final rawCapabilities = json['assessment_payload_capabilities'];
    final capabilities = <String, bool>{};
    if (rawCapabilities is Map) {
      for (final entry in rawCapabilities.entries) {
        capabilities[entry.key.toString()] = entry.value == true;
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
      assessmentPayloadCapabilities: capabilities,
    );
""",
)
replace(
    "lib/domain/models/course_models.dart",
    """  final String timelineResolution;
  final Map<String, Object?> timelineUnresolvedFields;

  bool get isCompatible =>
      courseId == 'TDE_9' &&
      schemaVersion.startsWith('1.') &&
      validationStatus == 'PASS';
""",
    """  final String timelineResolution;
  final Map<String, Object?> timelineUnresolvedFields;
  final Map<String, bool> assessmentPayloadCapabilities;

  bool get isCompatible =>
      isSupportedRuntimeCourse(courseId) &&
      schemaVersion.startsWith('1.') &&
      validationStatus == 'PASS';

  bool hasAssessmentCapability(String capability) =>
      assessmentPayloadCapabilities[capability] == true;
""",
)

models = read("lib/domain/models/course_models.dart")
start = models.index("class AssessmentArtifact {")
end = models.index("class AssessmentGapMapping {")
new_artifact = r'''class RubricLevel {
  const RubricLevel({
    required this.score,
    required this.label,
    required this.descriptor,
  });

  factory RubricLevel.fromJson(Map<String, dynamic> json) => RubricLevel(
    score: nullableInt(json['score']) ?? 0,
    label: json['label']?.toString() ?? '',
    descriptor: nullableString(json['descriptor']),
  );

  final int score;
  final String label;
  final String? descriptor;
}

class RubricCriterion {
  const RubricCriterion({
    required this.id,
    required this.name,
    required this.conditional,
    required this.descriptors,
  });

  factory RubricCriterion.fromJson(Map<String, dynamic> json) {
    final rawDescriptors = json['descriptors'];
    final descriptors = <int, String>{};
    if (rawDescriptors is Map) {
      for (final entry in rawDescriptors.entries) {
        final score = int.tryParse(entry.key.toString());
        if (score != null && entry.value != null) {
          descriptors[score] = entry.value.toString();
        }
      }
    }
    return RubricCriterion(
      id: json['criterion_id']?.toString() ?? '',
      name: json['criterion_name']?.toString() ?? '',
      conditional: json['conditional'] == true,
      descriptors: descriptors,
    );
  }

  final String id;
  final String name;
  final bool conditional;
  final Map<int, String> descriptors;
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
    required this.levels,
    required this.criteria,
    required this.provenance,
  });

  factory AssessmentArtifact.fromRow(Row row) {
    final levelModel = jsonStringMap(nullableString(row['level_model_json']));
    final rawLevels = levelModel['levels'];
    return AssessmentArtifact(
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
      levels: rawLevels is List
          ? rawLevels
              .whereType<Map>()
              .map((item) => RubricLevel.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const [],
      criteria: jsonObjectList(nullableString(row['criteria_json']))
          .map(RubricCriterion.fromJson)
          .toList(growable: false),
      provenance: jsonStringMap(nullableString(row['provenance_json'])),
    );
  }

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
  final List<RubricLevel> levels;
  final List<RubricCriterion> criteria;
  final Map<String, dynamic> provenance;
}

'''
write("lib/domain/models/course_models.dart", models[:start] + new_artifact + models[end:])

models = read("lib/domain/models/course_models.dart")
start = models.index("class AssessmentTaskBinding {")
end = models.index("class SourceReference {")
new_binding = r'''class AssessmentTaskBinding {
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
    required this.taskSpecificCriteria,
    required this.sourceEquivalenceStatus,
    required this.bindingKeySemantics,
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
    taskSpecificCriteria: jsonStringList(
      nullableString(row['task_specific_criteria_json']),
    ),
    sourceEquivalenceStatus: nullableString(row['source_equivalence_status']),
    bindingKeySemantics: nullableString(row['binding_key_semantics']),
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
  final List<String> taskSpecificCriteria;
  final String? sourceEquivalenceStatus;
  final String? bindingKeySemantics;
}

'''
write("lib/domain/models/course_models.dart", models[:start] + new_binding + models[end:])

# 4) Data source: capability/column-safe payload queries for TDE9 and TDE10.
replace(
    "lib/data/course/course_database_data_source.dart",
    """  Future<List<AssessmentArtifact>> getAssessmentArtifacts(
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
""",
    """  Future<List<AssessmentArtifact>> getAssessmentArtifacts(
    String themeId,
  ) async {
    final hasPayload = await _hasColumn('assessment_artifacts', 'criteria_json');
    final payloadColumns = hasPayload
        ? 'level_model_json, criteria_json, provenance_json'
        : \"'{}' AS level_model_json, '[]' AS criteria_json, '{}' AS provenance_json\";
    final rows = await _database.rawQuery('''
      SELECT artifact_id, title, skill_domain, scope, assessment_family,
             reuse_policy, generation_priority, generation_status,
             teacher_review_required, covered_themes_json,
             covered_gap_instances_json, $payloadColumns
      FROM assessment_artifacts
      ORDER BY artifact_id
    ''');
""",
)
replace(
    "lib/data/course/course_database_data_source.dart",
    """  Future<List<AssessmentTaskBinding>> getAssessmentTaskBindings({
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
""",
    """  Future<List<AssessmentTaskBinding>> getAssessmentTaskBindings({
    required String themeId,
    String? blockId,
  }) async {
    final where = blockId == null
        ? 'WHERE theme_id = ?'
        : 'WHERE theme_id = ? AND block_id = ?';
    final arguments = blockId == null ? [themeId] : [themeId, blockId];
    final hasPayload = await _hasColumn(
      'assessment_task_bindings',
      'task_specific_criteria_json',
    );
    final payloadColumns = hasPayload
        ? 'task_specific_criteria_json, source_equivalence_status, binding_key_semantics'
        : \"'[]' AS task_specific_criteria_json, NULL AS source_equivalence_status, NULL AS binding_key_semantics\";
    final rows = await _database.rawQuery('''
      SELECT artifact_id, gap_instance_id, theme_id, block_id, activity_id,
             targeted_outcomes_json, task_title, evidence, textbook_locator,
             curriculum_locator, $payloadColumns
      FROM assessment_task_bindings
      $where
      ORDER BY artifact_id, gap_instance_id
    ''', arguments);
""",
)
replace(
    "lib/data/course/course_database_data_source.dart",
    """  Row _first(List<Row> rows, String entity) {
    if (rows.isEmpty) throw StateError('$entity bulunamadı.');
    return rows.first;
  }
}
""",
    """  Future<bool> _hasColumn(String table, String column) async {
    final rows = await _database.rawQuery('PRAGMA table_info($table)');
    return rows.any((row) => row['name']?.toString() == column);
  }

  Row _first(List<Row> rows, String entity) {
    if (rows.isEmpty) throw StateError('$entity bulunamadı.');
    return rows.first;
  }
}
""",
)

# 5) Dynamic installer.
write(
    "lib/data/course/course_database_installer.dart",
    r'''import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'course_database_data_source.dart';
import '../../domain/models/course_models.dart';
import '../../domain/runtime/course_runtime_registry.dart';
import '../../domain/runtime/runtime_manifest_policy.dart';

class InstalledRuntime {
  const InstalledRuntime({required this.manifest, required this.databasePath});

  final RuntimeManifest manifest;
  final String databasePath;
}

class CourseDatabaseInstaller {
  const CourseDatabaseInstaller({this.courseId = 'TDE_9'});

  final String courseId;

  CourseRuntimeDescriptor get descriptor => runtimeForCourse(courseId);

  Future<InstalledRuntime> install() async {
    final manifest = await _readBundledManifest();
    if (!manifest.isCompatible || manifest.courseId != courseId) {
      throw StateError(
        'Desteklenmeyen veya doğrulanmamış runtime paketi: '
        '${manifest.courseId}/${manifest.schemaVersion}/${manifest.validationStatus}',
      );
    }

    final databasesDirectory = await getDatabasesPath();
    final runtimeDirectory = Directory(
      p.join(databasesDirectory, 'course_runtime', manifest.courseId),
    );
    await runtimeDirectory.create(recursive: true);

    final databaseFile = File(p.join(runtimeDirectory.path, 'course_runtime.sqlite'));
    final manifestFile = File(p.join(runtimeDirectory.path, 'runtime_manifest.json'));
    final shouldInstall = await _needsInstall(
      manifestFile,
      databaseFile,
      manifest,
    );
    if (shouldInstall) {
      final databaseBytes = (await rootBundle.load(
        descriptor.databaseAsset,
      )).buffer.asUint8List();
      final manifestBytes = (await rootBundle.load(
        descriptor.manifestAsset,
      )).buffer.asUint8List();
      await _replaceFile(databaseFile, databaseBytes);
      await _replaceFile(manifestFile, manifestBytes);
    }

    if (!databaseFile.existsSync() || await databaseFile.length() == 0) {
      throw StateError('Runtime SQLite yerel kopyası oluşturulamadı.');
    }
    return InstalledRuntime(manifest: manifest, databasePath: databaseFile.path);
  }

  Future<RuntimeManifest> _readBundledManifest() async {
    final manifestString = await rootBundle.loadString(descriptor.manifestAsset);
    final decoded = jsonDecode(manifestString);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Bundled runtime manifest geçersiz.');
    }
    validateRuntimeManifest(decoded);
    return RuntimeManifest.fromJson(decoded);
  }

  Future<bool> _needsInstall(
    File manifestFile,
    File databaseFile,
    RuntimeManifest expected,
  ) async {
    if (!manifestFile.existsSync() || !databaseFile.existsSync()) return true;
    if (await databaseFile.length() == 0) return true;
    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map<String, dynamic>) return true;
      validateRuntimeManifest(decoded);
      final local = RuntimeManifest.fromJson(decoded);
      return local.runtimePackageVersion != expected.runtimePackageVersion ||
          local.schemaVersion != expected.schemaVersion ||
          local.courseId != expected.courseId ||
          local.canonicalContentFingerprint != expected.canonicalContentFingerprint ||
          local.validationStatus != expected.validationStatus;
    } on Object {
      return true;
    }
  }

  Future<void> _replaceFile(File destination, List<int> bytes) async {
    final temporary = File('${destination.path}.tmp');
    if (temporary.existsSync()) await temporary.delete();
    await temporary.writeAsBytes(bytes, flush: true);
    if (destination.existsSync()) await destination.delete();
    await temporary.rename(destination.path);
  }
}

class CourseDatabase {
  CourseDatabase._({required this.manifest, required this.database})
    : dataSource = CourseDatabaseDataSource(database);

  static Future<CourseDatabase> open({
    String courseId = 'TDE_9',
    CourseDatabaseInstaller? installer,
  }) async {
    final selectedInstaller = installer ?? CourseDatabaseInstaller(courseId: courseId);
    final installed = await selectedInstaller.install();
    final database = await openDatabase(
      installed.databasePath,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final dataSource = CourseDatabaseDataSource(database);
      final course = await dataSource.getCourse();
      if (course.courseId != installed.manifest.courseId ||
          course.schemaVersion != installed.manifest.schemaVersion ||
          course.sourceManifestFingerprint != installed.manifest.canonicalContentFingerprint) {
        await database.close();
        throw StateError('Runtime DB manifest ile uyumlu değil.');
      }
      return CourseDatabase._(manifest: installed.manifest, database: database);
    } on Object {
      if (database.isOpen) await database.close();
      rethrow;
    }
  }

  final RuntimeManifest manifest;
  final Database database;
  final CourseDatabaseDataSource dataSource;

  Future<void> close() => database.close();
}
''',
)

# 6) Dependency loader per course.
replace(
    "lib/app/app_dependencies.dart",
    "Future<AppDependencies> loadProductionDependencies() async {\n  final database = await CourseDatabase.open();\n",
    """Future<AppDependencies> loadProductionDependencies() =>
    loadProductionDependenciesForCourse('TDE_9');

Future<AppDependencies> loadProductionDependenciesForCourse(String courseId) async {
  final database = await CourseDatabase.open(courseId: courseId);
""",
)

# 7) Course switcher in app shell.
replace(
    "lib/app/app.dart",
    "import '../domain/repositories/outcome_tracking_repository.dart';\n",
    "import '../domain/repositories/outcome_tracking_repository.dart';\nimport '../domain/runtime/course_runtime_registry.dart';\n",
)
replace(
    "lib/app/app.dart",
    """  const TeacherOsApp({
    super.key,
    this.dependencies,
    this.loader = loadProductionDependencies,
  });

  final AppDependencies? dependencies;
  final Future<AppDependencies> Function()? loader;
""",
    """  const TeacherOsApp({
    super.key,
    this.dependencies,
    this.courseLoader = loadProductionDependenciesForCourse,
    this.initialCourseId = 'TDE_9',
  });

  final AppDependencies? dependencies;
  final Future<AppDependencies> Function(String courseId)? courseLoader;
  final String initialCourseId;
""",
)
replace(
    "lib/app/app.dart",
    """class _TeacherOsAppState extends State<TeacherOsApp> {
  late final Future<AppDependencies> _dependenciesFuture;

  @override
  void initState() {
    super.initState();
    _dependenciesFuture = widget.dependencies != null
        ? Future.value(widget.dependencies)
        : widget.loader!();
  }

  @override
  void dispose() {
    if (widget.dependencies == null) {
      _dependenciesFuture.then((dependencies) => dependencies.dispose?.call());
    }
    super.dispose();
  }
""",
    """class _TeacherOsAppState extends State<TeacherOsApp> {
  late Future<AppDependencies> _dependenciesFuture;
  late String _activeCourseId;
  AppDependencies? _resolvedDependencies;

  @override
  void initState() {
    super.initState();
    _activeCourseId = widget.initialCourseId;
    _dependenciesFuture = widget.dependencies != null
        ? Future.value(widget.dependencies)
        : widget.courseLoader!(_activeCourseId);
  }

  Future<void> _switchCourse(String courseId) async {
    if (courseId == _activeCourseId || widget.dependencies != null) return;
    final previous = _resolvedDependencies;
    _resolvedDependencies = null;
    setState(() {
      _activeCourseId = courseId;
      _dependenciesFuture = widget.courseLoader!(courseId);
    });
    await previous?.dispose?.call();
  }

  @override
  void dispose() {
    if (widget.dependencies == null) {
      _resolvedDependencies?.dispose?.call();
    }
    super.dispose();
  }
""",
)
replace(
    "lib/app/app.dart",
    """        return _AppShell(dependencies: snapshot.data!);
""",
    """        _resolvedDependencies = snapshot.data!;
        return _AppShell(
          dependencies: snapshot.data!,
          activeCourseId: _activeCourseId,
          onCourseChanged: widget.dependencies == null ? _switchCourse : null,
        );
""",
)
replace(
    "lib/app/app.dart",
    """class _AppShell extends StatefulWidget {
  const _AppShell({required this.dependencies});

  final AppDependencies dependencies;
""",
    """class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.dependencies,
    required this.activeCourseId,
    required this.onCourseChanged,
  });

  final AppDependencies dependencies;
  final String activeCourseId;
  final ValueChanged<String>? onCourseChanged;
""",
)
replace(
    "lib/app/app.dart",
    """        return Scaffold(
          appBar: AppBar(title: Text(_titles[_selectedIndex])),
""",
    """        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_selectedIndex]),
            actions: [
              if (widget.onCourseChanged != null)
                PopupMenuButton<String>(
                  tooltip: 'Sınıf seç',
                  initialValue: widget.activeCourseId,
                  onSelected: widget.onCourseChanged,
                  itemBuilder: (context) => [
                    for (final course in supportedCourseRuntimes)
                      PopupMenuItem<String>(
                        value: course.courseId,
                        child: Row(
                          children: [
                            if (course.courseId == widget.activeCourseId)
                              const Icon(Icons.check, size: 18)
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            Text('${course.grade}. Sınıf'),
                          ],
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.school_outlined),
                ),
            ],
          ),
""",
)

# 8) Rubric scoring UI.
write(
    "lib/features/block/rubric_score_card.dart",
    r'''import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart';
import '../shared/feature_widgets.dart';

class RubricScoreCard extends StatefulWidget {
  const RubricScoreCard({
    super.key,
    required this.binding,
    required this.artifact,
  });

  final AssessmentTaskBinding binding;
  final AssessmentArtifact? artifact;

  @override
  State<RubricScoreCard> createState() => _RubricScoreCardState();
}

class _RubricScoreCardState extends State<RubricScoreCard> {
  final Map<int, int> _scores = {};

  List<RubricLevel> get _levels {
    final levels = widget.artifact?.levels ?? const <RubricLevel>[];
    if (levels.isNotEmpty) return levels;
    return const [
      RubricLevel(score: 3, label: 'Oldukça iyi', descriptor: null),
      RubricLevel(score: 2, label: 'Kabul edilebilir', descriptor: null),
      RubricLevel(score: 1, label: 'Geliştirilmeli', descriptor: null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final criteria = widget.binding.taskSpecificCriteria;
    if (criteria.isEmpty) return const SizedBox.shrink();
    final maxLevel = _levels.map((level) => level.score).reduce((a, b) => a > b ? a : b);
    final total = _scores.values.fold<int>(0, (sum, score) => sum + score);
    final maxScore = criteria.length * maxLevel;
    final complete = _scores.length == criteria.length;
    final percentage = maxScore == 0 ? 0 : (total / maxScore * 100).round();

    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dereceli puanlama formu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('${criteria.length} ölçüt · maksimum $maxScore puan'),
            const SizedBox(height: AppSpacing.lg),
            for (var index = 0; index < criteria.length; index++) ...[
              Text(
                '${index + 1}. ${criteria[index]}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final level in _levels)
                    ChoiceChip(
                      label: Text('${level.score} · ${level.label}'),
                      selected: _scores[index] == level.score,
                      onSelected: (_) => setState(() => _scores[index] = level.score),
                    ),
                ],
              ),
              if (index != criteria.length - 1) const Divider(height: AppSpacing.xl),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              complete
                  ? 'Toplam: $total / $maxScore · %$percentage'
                  : 'Puanlanan ölçüt: ${_scores.length}/${criteria.length}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (widget.binding.sourceEquivalenceStatus != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Bu form, kabul edilmiş güçlü kopya ve resmî program/kitap ölçütlerinden oluşturulmuş canonical değerlendirme formudur.',
                style: TextStyle(height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
''',
)
replace(
    "lib/features/block/block_detail_page.dart",
    "import '../shared/feature_widgets.dart';\n",
    "import '../shared/feature_widgets.dart';\nimport 'rubric_score_card.dart';\n",
)
replace(
    "lib/features/block/block_detail_page.dart",
    """                  _AssessmentTaskItem(
                    binding: detail.assessmentTaskBindings[index],
                  ),
""",
    """                  _AssessmentTaskItem(
                    binding: detail.assessmentTaskBindings[index],
                    artifacts: detail.assessmentArtifacts,
                  ),
""",
)
replace(
    "lib/features/block/block_detail_page.dart",
    """class _AssessmentTaskItem extends StatelessWidget {
  const _AssessmentTaskItem({required this.binding});

  final model.AssessmentTaskBinding binding;

  @override
  Widget build(BuildContext context) {
    final bookLocation = teacherLocatorLabel(binding.textbookLocator);
    return ExpansionTile(
""",
    """class _AssessmentTaskItem extends StatelessWidget {
  const _AssessmentTaskItem({required this.binding, required this.artifacts});

  final model.AssessmentTaskBinding binding;
  final List<model.AssessmentArtifact> artifacts;

  @override
  Widget build(BuildContext context) {
    final bookLocation = teacherLocatorLabel(binding.textbookLocator);
    model.AssessmentArtifact? artifact;
    for (final candidate in artifacts) {
      if (candidate.id == binding.artifactId) {
        artifact = candidate;
        break;
      }
    }
    return ExpansionTile(
""",
)
replace(
    "lib/features/block/block_detail_page.dart",
    """        if (bookLocation != null) ...[
          const SizedBox(height: AppSpacing.md),
          LabeledValue(
            label: 'Ders kitabı',
            value: bookLocation,
            icon: Icons.menu_book_outlined,
          ),
        ],
      ],
    );
""",
    """        if (bookLocation != null) ...[
          const SizedBox(height: AppSpacing.md),
          LabeledValue(
            label: 'Ders kitabı',
            value: bookLocation,
            icon: Icons.menu_book_outlined,
          ),
        ],
        if (binding.taskSpecificCriteria.isNotEmpty)
          RubricScoreCard(binding: binding, artifact: artifact),
      ],
    );
""",
    count=1,
)

# 9) Generic sync tool.
write(
    "tool/sync_course_runtime.dart",
    r'''import 'dart:convert';
import 'dart:io';

import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  try {
    final courseId = _valueFor(args, '--course') ?? 'TDE_9';
    runtimeForCourse(courseId);
    final sourceRoot = _valueFor(args, '--source-root') ??
        '/Users/kadir/Desktop/tymm/courses/$courseId/runtime';
    final targetRoot = _valueFor(args, '--target-root') ?? 'assets/courses/$courseId';

    final sourceManifest = File(p.join(sourceRoot, 'runtime_manifest.json'));
    final sourceDatabase = File(p.join(sourceRoot, 'course_runtime.sqlite'));
    final sourceValidationReport = File(p.join(sourceRoot, 'runtime_validation_report.md'));
    if (!sourceManifest.existsSync()) throw StateError('Runtime manifest bulunamadı: ${sourceManifest.path}');
    if (!sourceDatabase.existsSync()) throw StateError('Runtime SQLite bulunamadı: ${sourceDatabase.path}');

    final manifestJson = jsonDecode(await sourceManifest.readAsString());
    if (manifestJson is! Map<String, dynamic>) throw StateError('Runtime manifest JSON nesnesi olmalı.');
    if (manifestJson['course_id'] != courseId) {
      throw StateError('İstenen course_id ile runtime uyuşmuyor: $courseId/${manifestJson['course_id']}');
    }
    final validationReport = sourceValidationReport.existsSync() ? await sourceValidationReport.readAsString() : null;
    validateRuntimeFreshnessEvidence(manifestJson, validationReport: validationReport);

    final targetDirectory = Directory(targetRoot);
    await targetDirectory.create(recursive: true);
    final targetDatabase = File(p.join(targetRoot, 'course_runtime.sqlite'));
    final targetManifest = File(p.join(targetRoot, 'runtime_manifest.json'));
    final targetValidationReport = File(p.join(targetRoot, 'runtime_validation_report.md'));

    await sourceDatabase.copy(targetDatabase.path);
    await sourceManifest.copy(targetManifest.path);
    if (sourceValidationReport.existsSync()) await sourceValidationReport.copy(targetValidationReport.path);

    if (!await _filesEqual(sourceDatabase, targetDatabase)) throw StateError('Runtime SQLite hedef doğrulaması başarısız.');
    if (!await _filesEqual(sourceManifest, targetManifest)) throw StateError('Runtime manifest hedef doğrulaması başarısız.');

    stdout.writeln('RUNTIME_SYNC: PASS');
    stdout.writeln('COURSE_ID: $courseId');
    stdout.writeln('RUNTIME_PACKAGE_VERSION: ${manifestJson['runtime_package_version']}');
    stdout.writeln('SCHEMA_VERSION: ${manifestJson['schema_version']}');
    stdout.writeln('VALIDATION_STATUS: ${manifestJson['validation_status']}');
  } catch (error, stackTrace) {
    stderr.writeln('RUNTIME_SYNC: FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

String? _valueFor(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

Future<bool> _filesEqual(File source, File target) async {
  if (!source.existsSync() || !target.existsSync()) return false;
  if (await source.length() != await target.length()) return false;
  final sourceBytes = await source.readAsBytes();
  final targetBytes = await target.readAsBytes();
  for (var index = 0; index < sourceBytes.length; index++) {
    if (sourceBytes[index] != targetBytes[index]) return false;
  }
  return true;
}
''',
)

# 10) Runtime verifier parameterized by course.
verifier = read("tool/runtime_verifier/bin/verify_runtime.dart")
verifier = verifier.replace("Future<void> main() async {", "Future<void> main(List<String> args) async {\n  final courseId = _valueFor(args, '--course') ?? 'TDE_9';")
verifier = verifier.replace("    'TDE_9',\n", "    courseId,\n", 1)
verifier = verifier.replace("_check(manifestMap['course_id'] == 'TDE_9', 'course_id TDE_9 değil');", "_check(manifestMap['course_id'] == courseId, 'course_id $courseId değil');")
verifier += """

String? _valueFor(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
"""
write("tool/runtime_verifier/bin/verify_runtime.dart", verifier)

# 11) Package both course runtimes.
replace(
    "pubspec.yaml",
    'description: "Offline-first TYMM Teacher OS runtime for TDE_9."',
    'description: "Offline-first TYMM Teacher OS runtime for multiple TDE grades."',
)
replace(
    "pubspec.yaml",
    """    - assets/courses/TDE_9/course_runtime.sqlite
    - assets/courses/TDE_9/runtime_manifest.json
    - assets/calendars/
""",
    """    - assets/courses/TDE_9/
    - assets/courses/TDE_10/
    - assets/calendars/
""",
)

# 12) TDE10 scheduling profile.
calendar_path = ROOT / "assets/calendars/academic_calendar_2026_2027.json"
calendar = json.loads(calendar_path.read_text(encoding="utf-8"))
profile = dict(calendar["course_profiles"]["TDE_9"])
profile["block_hour_allocation_note"] = (
    "TDE_10 için resmî kaynak blok bazında ayrı saat vermediği için 43 yapılandırılmış saat "
    "sıralı dört bloğa planlama amacıyla 12+11+10+10 dağıtılır. Bu değerler resmî blok süresi değildir."
)
calendar["course_profiles"]["TDE_10"] = profile
calendar_path.write_text(json.dumps(calendar, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 13) CI verifies both runtime packages.
replace(
    ".github/workflows/flutter-ci.yml",
    """      - name: Verify versioned canonical runtime
        working-directory: tool/runtime_verifier
        run: dart run bin/verify_runtime.dart
""",
    """      - name: Verify TDE9 canonical runtime
        working-directory: tool/runtime_verifier
        run: dart run bin/verify_runtime.dart --course TDE_9

      - name: Verify TDE10 canonical runtime
        working-directory: tool/runtime_verifier
        run: dart run bin/verify_runtime.dart --course TDE_10
""",
)

# 14) Real TDE10 integration test including the recovered Fabl rubric.
write(
    "test/tde10_runtime_integration_test.dart",
    r'''import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late CourseDatabaseDataSource dataSource;
  late Map<String, dynamic> manifest;

  setUpAll(() async {
    final runtimeRoot = p.join(Directory.current.path, 'assets', 'courses', 'TDE_10');
    final manifestFile = File(p.join(runtimeRoot, 'runtime_manifest.json'));
    final databaseFile = File(p.join(runtimeRoot, 'course_runtime.sqlite'));
    expect(manifestFile.existsSync(), isTrue);
    expect(databaseFile.existsSync(), isTrue);
    manifest = Map<String, dynamic>.from(jsonDecode(await manifestFile.readAsString()) as Map);
    validateRuntimeManifest(manifest);
    database = await databaseFactoryFfi.openDatabase(
      databaseFile.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    dataSource = CourseDatabaseDataSource(database);
  });

  tearDownAll(() => database.close());

  test('TDE10 runtime temel ÖğretmenOS ilişki sözleşmesini karşılar', () async {
    final course = await dataSource.getCourse();
    expect(course.courseId, 'TDE_10');
    expect((await dataSource.getThemes()).length, 4);
    expect((await dataSource.getAnnualSequence()).length, 16);
    final package = await dataSource.getTeacherPackage('TEMA_03');
    expect(package.outcomes, isNotEmpty);
    expect(package.activities, isNotEmpty);
    expect(package.resourceDecisions, isNotEmpty);
    expect(package.sourceReferences, isNotEmpty);
    expect(package.assessmentTaskBindings, isNotEmpty);
  });

  test('Fabl Yazma rubriği 8 görev ölçütü ve 3 düzeyli modelle okunur', () async {
    final detail = await dataSource.getBlockDetail('BLOCK_T3_04_YAZMA');
    final binding = detail.assessmentTaskBindings.singleWhere(
      (item) => item.gapInstanceId == 'REQ_T10_T3_YAZMA_DPA',
    );
    final artifact = detail.assessmentArtifacts.singleWhere(
      (item) => item.id == 'TDE10_YAZMA_RUBRIC',
    );
    expect(binding.taskTitle, 'Fabl Yazma');
    expect(binding.taskSpecificCriteria, hasLength(8));
    expect(binding.taskSpecificCriteria, contains('Özgünlük'));
    expect(binding.taskSpecificCriteria, contains('Biçim/tür özellikleri'));
    expect(artifact.levels.map((level) => level.score), orderedEquals([3, 2, 1]));
    expect(artifact.criteria, isNotEmpty);
    expect(artifact.provenance, isNotEmpty);
  });
}
''',
)

# 15) Download pinned TDE10 runtime assets from the canonical TYMM producer.
asset_root = ROOT / "assets/courses/TDE_10"
asset_root.mkdir(parents=True, exist_ok=True)
for filename in ("course_runtime.sqlite", "runtime_manifest.json", "runtime_validation_report.md"):
    url = f"https://raw.githubusercontent.com/knigdelioglu/tymm/{TYMM_SHA}/courses/TDE_10/runtime/{filename}"
    urllib.request.urlretrieve(url, asset_root / filename)

print("MULTICOURSE_TDE10_PATCH: APPLIED")
