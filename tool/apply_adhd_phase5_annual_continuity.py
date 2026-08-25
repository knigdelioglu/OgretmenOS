from pathlib import Path

PREFS = Path('lib/data/preferences/user_preferences_repository.dart')
ANNUAL = Path('lib/features/annual_plan/annual_plan_page.dart')
PREF_TEST = Path('test/user_preferences_test.dart')
PHASE_TEST = Path('test/adhd_phase5_annual_continuity_test.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


PREFS.write_text("""import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ManualPositionOverrideState {
  const ManualPositionOverrideState({
    required this.courseId,
    required this.blockId,
    required this.updatedAt,
  });

  final String courseId;
  final String blockId;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'course_id': courseId,
    'block_id': blockId,
    'updated_at': updatedAt.toIso8601String(),
  };

  static ManualPositionOverrideState? fromJson(Map<String, Object?> json) {
    final courseId = json['course_id'];
    final blockId = json['block_id'];
    final updatedAt = json['updated_at'];
    if (courseId is! String || blockId is! String || updatedAt is! String) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;
    return ManualPositionOverrideState(
      courseId: courseId,
      blockId: blockId,
      updatedAt: parsedUpdatedAt,
    );
  }
}

abstract interface class UserPreferencesRepository {
  Future<String?> getManualPositionOverride();

  Future<void> setManualPositionOverride(String blockId);

  Future<void> clearManualPositionOverride();
}

/// Optional richer contract used by the production annual-plan experience.
///
/// Keeping this separate preserves lightweight test/fake implementations of
/// [UserPreferencesRepository] while letting production scope a manual marker
/// per course and compare it with continuity timestamps.
abstract interface class ScopedManualPositionPreferences {
  Future<ManualPositionOverrideState?> getManualPositionOverrideForCourse(
    String courseId,
  );

  Future<void> setManualPositionOverrideForCourse(
    String courseId,
    String blockId,
  );

  Future<void> clearManualPositionOverrideForCourse(String courseId);
}

class SharedPreferencesUserPreferences
    implements UserPreferencesRepository, ScopedManualPositionPreferences {
  const SharedPreferencesUserPreferences(this._preferences);

  static const manualPositionKey = 'manual_position_override';
  static const _scopedManualPositionPrefix = 'manual_position_override_v2_';

  final SharedPreferences _preferences;

  String _scopedKey(String courseId) => '$_scopedManualPositionPrefix$courseId';

  @override
  Future<String?> getManualPositionOverride() async =>
      _preferences.getString(manualPositionKey);

  @override
  Future<void> setManualPositionOverride(String blockId) async {
    await _preferences.setString(manualPositionKey, blockId);
  }

  @override
  Future<void> clearManualPositionOverride() async {
    await _preferences.remove(manualPositionKey);
  }

  @override
  Future<ManualPositionOverrideState?> getManualPositionOverrideForCourse(
    String courseId,
  ) async {
    final key = _scopedKey(courseId);
    final raw = _preferences.getString(key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final state = ManualPositionOverrideState.fromJson(decoded);
          if (state != null && state.courseId == courseId) return state;
        }
      } on FormatException {
        // Malformed preference is non-authoritative convenience state.
      }
      await _preferences.remove(key);
    }

    // Backward-compatible fallback for the pre-Faz-5 global string. It gets
    // the oldest possible timestamp so any real viewed-lesson continuity wins.
    final legacy = _preferences.getString(manualPositionKey);
    if (legacy == null) return null;
    return ManualPositionOverrideState(
      courseId: courseId,
      blockId: legacy,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  Future<void> setManualPositionOverrideForCourse(
    String courseId,
    String blockId,
  ) async {
    final state = ManualPositionOverrideState(
      courseId: courseId,
      blockId: blockId,
      updatedAt: DateTime.now(),
    );
    await _preferences.setString(_scopedKey(courseId), jsonEncode(state.toJson()));
    await _preferences.remove(manualPositionKey);
  }

  @override
  Future<void> clearManualPositionOverrideForCourse(String courseId) async {
    await _preferences.remove(_scopedKey(courseId));
    await _preferences.remove(manualPositionKey);
  }
}
""")

text = ANNUAL.read_text()
text = replace_once(
    text,
    """  Future<_PlanData> _load() async {\n    final sequence = await widget.repository.getAnnualSequence();\n    final manual = await widget.preferences.getManualPositionOverride();\n    final lastFocus = await widget.continuity.getLastFocus(widget.courseId);\n    final manualBlockId = sequence.any((entry) => entry.block.id == manual)\n        ? manual\n        : null;\n    final automaticBlockId = sequence.any(\n      (entry) => entry.block.id == lastFocus?.blockId,\n    )\n        ? lastFocus?.blockId\n        : null;\n    return _PlanData(\n      sequence: sequence,\n      manualBlockId: manualBlockId,\n      automaticBlockId: automaticBlockId,\n    );\n  }\n\n  void _reload() => setState(() => _future = _load());\n\n  Future<void> _setPosition(String blockId) async {\n    await widget.preferences.setManualPositionOverride(blockId);\n    if (mounted) _reload();\n  }\n\n  Future<void> _clearPosition() async {\n    await widget.preferences.clearManualPositionOverride();\n    if (mounted) _reload();\n  }\n""",
    """  Future<_PlanData> _load() async {\n    final sequence = await widget.repository.getAnnualSequence();\n    final manual = await _getManualPosition();\n    final lastFocus = await widget.continuity.getLastFocus(widget.courseId);\n    var manualBlockId = sequence.any((entry) => entry.block.id == manual?.blockId)\n        ? manual?.blockId\n        : null;\n    final automaticBlockId = sequence.any(\n      (entry) => entry.block.id == lastFocus?.blockId,\n    )\n        ? lastFocus?.blockId\n        : null;\n\n    final manualIsStale =\n        manualBlockId != null &&\n        automaticBlockId != null &&\n        lastFocus != null &&\n        lastFocus.updatedAt.isAfter(manual!.updatedAt);\n    if ((manual != null && manualBlockId == null) || manualIsStale) {\n      manualBlockId = null;\n      await _clearPositionPreferenceBestEffort();\n    }\n\n    return _PlanData(\n      sequence: sequence,\n      manualBlockId: manualBlockId,\n      automaticBlockId: automaticBlockId,\n    );\n  }\n\n  Future<ManualPositionOverrideState?> _getManualPosition() async {\n    final preferences = widget.preferences;\n    if (preferences is ScopedManualPositionPreferences) {\n      return preferences.getManualPositionOverrideForCourse(widget.courseId);\n    }\n    final blockId = await preferences.getManualPositionOverride();\n    if (blockId == null) return null;\n    return ManualPositionOverrideState(\n      courseId: widget.courseId,\n      blockId: blockId,\n      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),\n    );\n  }\n\n  Future<void> _setPositionPreference(String blockId) async {\n    final preferences = widget.preferences;\n    if (preferences is ScopedManualPositionPreferences) {\n      await preferences.setManualPositionOverrideForCourse(\n        widget.courseId,\n        blockId,\n      );\n      return;\n    }\n    await preferences.setManualPositionOverride(blockId);\n  }\n\n  Future<void> _clearPositionPreference() async {\n    final preferences = widget.preferences;\n    if (preferences is ScopedManualPositionPreferences) {\n      await preferences.clearManualPositionOverrideForCourse(widget.courseId);\n      return;\n    }\n    await preferences.clearManualPositionOverride();\n  }\n\n  Future<void> _clearPositionPreferenceBestEffort() async {\n    try {\n      await _clearPositionPreference();\n    } on Object {\n      // Position preference is convenience state and must not block the plan.\n    }\n  }\n\n  void _reload() => setState(() => _future = _load());\n\n  Future<void> _setPosition(String blockId) async {\n    await _setPositionPreference(blockId);\n    if (mounted) _reload();\n  }\n\n  Future<void> _clearPosition() async {\n    await _clearPositionPreference();\n    if (mounted) _reload();\n  }\n""",
    'annual position resolution',
)
text = replace_once(
    text,
    """                  tooltip: 'İşaretli konumu temizle',\n""",
    """                  tooltip: 'Geçici konum işaretini temizle',\n""",
    'summary clear tooltip',
)
text = replace_once(
    text,
    """                    isManualPosition\n                        ? 'İşaretlediğin konum'\n                        : 'Son ders odağı',\n""",
    """                    isManualPosition\n                        ? 'Elle işaretlendi · yeni bir ders açtığında otomatik güncellenir'\n                        : 'Son görüntülenen ders odağı',\n""",
    'summary position explanation',
)
text = replace_once(
    text,
    """                tooltip: entries[i].block.id == manualBlockId\n                    ? 'İşaretli konum'\n                    : 'Burada kaldım',\n""",
    """                tooltip: entries[i].block.id == manualBlockId\n                    ? 'Geçici konum işareti'\n                    : 'Burayı geçici olarak işaretle',\n""",
    'bookmark tooltip semantics',
)
ANNUAL.write_text(text)

PREF_TEST.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy manual position override ayrı yerel tercihte tutulur', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesUserPreferences(preferences);

    expect(await repository.getManualPositionOverride(), isNull);
    await repository.setManualPositionOverride('BLOCK_TEST');
    expect(await repository.getManualPositionOverride(), 'BLOCK_TEST');
    await repository.clearManualPositionOverride();
    expect(await repository.getManualPositionOverride(), isNull);
  });

  test('manuel yıllık konum ders bazında ayrılır ve zaman damgası taşır', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesUserPreferences(preferences);

    await repository.setManualPositionOverrideForCourse('TDE_9', 'B9');
    await repository.setManualPositionOverrideForCourse('TDE_10', 'B10');

    final grade9 = await repository.getManualPositionOverrideForCourse('TDE_9');
    final grade10 = await repository.getManualPositionOverrideForCourse('TDE_10');
    expect(grade9?.courseId, 'TDE_9');
    expect(grade9?.blockId, 'B9');
    expect(grade9?.updatedAt, isNotNull);
    expect(grade10?.courseId, 'TDE_10');
    expect(grade10?.blockId, 'B10');

    await repository.clearManualPositionOverrideForCourse('TDE_9');
    expect(await repository.getManualPositionOverrideForCourse('TDE_9'), isNull);
    expect(
      (await repository.getManualPositionOverrideForCourse('TDE_10'))?.blockId,
      'B10',
    );
  });

  test('eski global işaret en eski zaman damgasıyla okunur', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesUserPreferences.manualPositionKey: 'LEGACY_BLOCK',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesUserPreferences(preferences);

    final state = await repository.getManualPositionOverrideForCourse('TDE_9');
    expect(state?.blockId, 'LEGACY_BLOCK');
    expect(state?.updatedAt.millisecondsSinceEpoch, 0);
  });
}
""")

PHASE_TEST.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/preferences/continuity_repository.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/annual_plan/annual_plan_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('yeni ders odağı eski manuel yıllık işareti otomatik geçersiz kılar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final raw = await SharedPreferences.getInstance();
    final preferences = SharedPreferencesUserPreferences(raw);
    await preferences.setManualPositionOverrideForCourse('TDE_9', 'B1');
    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 1,
        trackingKey: 'TDE_9|O2',
        outcomeCode: 'TEST.2',
        themeTitle: 'Test Tema',
        blockId: 'B2',
        blockTitle: 'İkinci Blok',
        updatedAt: DateTime.now().add(const Duration(minutes: 1)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnualPlanPage(
            repository: const _Repository(),
            preferences: preferences,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Test Tema · İkinci Blok'), findsOneWidget);
    expect(find.text('Son görüntülenen ders odağı'), findsOneWidget);
    expect(find.textContaining('Elle işaretlendi'), findsNothing);
    expect(
      await preferences.getManualPositionOverrideForCourse('TDE_9'),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('daha yeni manuel işaret geçici istisna olarak korunur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final raw = await SharedPreferences.getInstance();
    final preferences = SharedPreferencesUserPreferences(raw);
    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      const LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 1,
        trackingKey: 'TDE_9|O2',
        outcomeCode: 'TEST.2',
        themeTitle: 'Test Tema',
        blockId: 'B2',
        blockTitle: 'İkinci Blok',
        updatedAt: _oldFocusTime,
      ),
    );
    await preferences.setManualPositionOverrideForCourse('TDE_9', 'B1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnualPlanPage(
            repository: const _Repository(),
            preferences: preferences,
            continuity: continuity,
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Test Tema · Birinci Blok'), findsOneWidget);
    expect(find.textContaining('Elle işaretlendi'), findsOneWidget);
    expect(
      (await preferences.getManualPositionOverrideForCourse('TDE_9'))?.blockId,
      'B1',
    );
    expect(tester.takeException(), isNull);
  });
}

const _oldFocusTime = DateTime.utc(2020, 1, 1);

class _Repository implements CourseKnowledgeRepository {
  const _Repository();

  static const theme = model.Theme(
    id: 'T1',
    order: 1,
    title: 'Test Tema',
    pageRange: null,
    plannedHours: 45,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  );

  static const block1 = model.Block(
    id: 'B1',
    themeId: 'T1',
    order: 1,
    title: 'Birinci Blok',
    skillDomain: 'Okuma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  static const block2 = model.Block(
    id: 'B2',
    themeId: 'T1',
    order: 2,
    title: 'İkinci Blok',
    skillDomain: 'Yazma',
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: [],
  );

  @override
  Future<model.Course> getCourse() async => const model.Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'test',
  );

  @override
  Future<model.RuntimeManifest> getManifest() async =>
      const model.RuntimeManifest(
        runtimePackageVersion: '1.0.0',
        schemaVersion: '1.0.0',
        courseId: 'TDE_9',
        validationStatus: 'PASS',
        canonicalContentFingerprint: 'test',
        rowCounts: {},
        timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
        timelineUnresolvedFields: {},
      );

  @override
  Future<List<model.Theme>> getThemes() async => const [theme];

  @override
  Future<model.Theme> getTheme(String themeId) async => theme;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => const [
    block1,
    block2,
  ];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async => model.BlockDetail(
    theme: theme,
    block: blockId == 'B1' ? block1 : block2,
    outcomes: const [],
    textbookSections: const [],
    activities: const [],
    forms: const [],
    assessmentArtifacts: const [],
    assessmentGaps: const [],
    assessmentTaskBindings: const [],
    resourceDecisions: const [],
    sourceReferences: const [],
    previousBlock: null,
    nextBlock: null,
  );

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async => const [
    model.TimelineEntry(
      sequencePosition: 1,
      theme: theme,
      block: block1,
      officialTotalHours: 45,
      coreInstructionHours: 43,
      schoolBasedHours: 2,
      schoolBasedHoursStatus: 'CONFIRMED',
    ),
    model.TimelineEntry(
      sequencePosition: 2,
      theme: theme,
      block: block2,
      officialTotalHours: 45,
      coreInstructionHours: 43,
      schoolBasedHours: 2,
      schoolBasedHoursStatus: 'CONFIRMED',
    ),
  ];

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(String themeId) async =>
      const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async =>
      const model.TeacherPackage(
        theme: theme,
        blocks: [block1, block2],
        outcomes: [],
        textbookSections: [],
        activities: [],
        forms: [],
        assessmentArtifacts: [],
        assessmentGaps: [],
        assessmentTaskBindings: [],
        resourceDecisions: [],
        sourceReferences: [],
      );
}
""")
