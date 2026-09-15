from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{path}: expected exactly one match, got {count}: {old[:80]!r}"
        )
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_all(path: str, old: str, new: str, expected_min: int = 1) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count < expected_min:
        raise SystemExit(
            f"{path}: expected at least {expected_min} matches, got {count}: {old!r}"
        )
    p.write_text(text.replace(old, new), encoding="utf-8")


viewer = "lib/features/resources/teacher_guide_viewer_page.dart"
replace_once(
    viewer,
    "  TeacherGuideNote? _loadedNote;\n  String? _selectedSectionId;",
    "  TeacherGuideNote? _loadedNote;\n  TeacherGuideItem? _noteItem;\n  String? _selectedSectionId;",
)
replace_once(
    viewer,
    "  void dispose() {\n    _noteSaveTimer?.cancel();\n    _searchController",
    "  void dispose() {\n    _noteSaveTimer?.cancel();\n    _flushPendingNoteOnDispose();\n    _searchController",
)
replace_once(
    viewer,
    "        .toList(growable: false);\n  }\n\n  Future<void> _selectItem(TeacherGuideItem item, _GuideViewData data) async {",
    """        .toList(growable: false);
  }

  Future<void> _selectSection(
    String sectionId,
    _GuideViewData data,
  ) async {
    final section = data.sectionFor(sectionId);
    final item = section?.units.expand((unit) => unit.items).firstOrNull;
    if (item == null) return;
    await _selectItem(item, data);
  }

  Future<void> _selectUnit(String unitId, _GuideViewData data) async {
    final item = data.unitFor(unitId)?.items.firstOrNull;
    if (item == null) return;
    await _selectItem(item, data);
  }

  Future<void> _selectItem(TeacherGuideItem item, _GuideViewData data) async {""",
)
replace_once(
    viewer,
    "    final unitData = data.unitFor(item.unitId);\n    if (unitData == null) return;\n    if (_noteDirty && !await _saveNote()) return;",
    "    final unitData = data.unitFor(item.unitId);\n    if (unitData == null) return;\n    _noteSaveTimer?.cancel();\n    if (_noteDirty && !await _saveNote()) return;",
)
old_load = """  Future<void> _loadNoteForSelection(TeacherGuideItem? item) async {
    final assignmentId = widget.assignmentId;
    final notes = widget.notesRepository;
    final controller = _noteController;
    if (assignmentId == null || notes == null || item == null) return;
    final revision = ++_noteRevision;
    try {
      final loaded = await notes.get(
        assignmentId: assignmentId,
        guideItemId: item.itemId,
      );
      if (!mounted || revision != _noteRevision) return;
      _noteSaving = false;
      _noteDirty = false;
      _loadedNote = loaded;
      controller?.text = loaded?.note ?? '';
      setState(() {});
    } on Object catch (error) {
      if (!mounted || revision != _noteRevision) return;
      _noteError = 'Not yüklenemedi: $error';
      setState(() {});
    }
  }"""
new_load = """  Future<void> _loadNoteForSelection(TeacherGuideItem? item) async {
    final assignmentId = widget.assignmentId;
    final notes = widget.notesRepository;
    if (assignmentId == null || notes == null || item == null) return;
    final revision = ++_noteRevision;
    _noteItem = item;
    _loadedNote = null;
    _noteSaving = false;
    _noteDirty = false;
    _noteError = null;
    _noteController?.text = '';
    try {
      final loaded = await notes.get(
        assignmentId: assignmentId,
        guideItemId: item.itemId,
      );
      if (!mounted || revision != _noteRevision) return;
      _loadedNote = loaded;
      _noteController?.text = loaded?.note ?? '';
      setState(() {});
    } on Object catch (error) {
      if (!mounted || revision != _noteRevision) return;
      _noteError = 'Not yüklenemedi: $error';
      setState(() {});
    }
  }"""
replace_once(viewer, old_load, new_load)
replace_once(
    viewer,
    "  Future<bool> _saveNote() async {\n    final assignmentId = widget.assignmentId;",
    "  Future<bool> _saveNote() async {\n    _noteSaveTimer?.cancel();\n    final assignmentId = widget.assignmentId;",
)
replace_once(viewer, "    final item = _currentItem;", "    final item = _noteItem ?? _currentItem;")
replace_once(
    viewer,
    """  Future<void> _handleBack() async {
    if (_noteSaving) return;
    if (await _saveNote() && mounted) Navigator.of(context).pop();
  }""",
    """  void _flushPendingNoteOnDispose() {
    final assignmentId = widget.assignmentId;
    final notes = widget.notesRepository;
    final item = _noteItem;
    final controller = _noteController;
    final hash = item?.canonicalPayloadSha256;
    if (!_noteDirty ||
        assignmentId == null ||
        notes == null ||
        item == null ||
        controller == null ||
        hash == null ||
        hash.isEmpty) {
      return;
    }
    final snapshot = TeacherGuideNote(
      assignmentId: assignmentId,
      guideItemId: item.itemId,
      note: controller.text,
      canonicalPayloadSha256: hash,
      updatedAt: DateTime.now(),
    );
    unawaited(
      notes.save(snapshot).onError((Object _, StackTrace __) {
        // Route teardown cannot surface an error. Normal back navigation
        // remains fail-visible through _saveNote(); this is a final best-effort
        // flush for parent/lifecycle-driven disposal.
      }),
    );
  }

  Future<void> _handleBack() async {
    _noteSaveTimer?.cancel();
    if (_noteSaving) return;
    if (await _saveNote() && mounted) Navigator.of(context).pop();
  }""",
)
replace_once(
    viewer,
    """                          onSelectSection: (value) => setState(() {
                            _selectedSectionId = value;
                            _selectedUnitId = data.sections
                                .firstWhere((s) => s.section.sectionId == value)
                                .units
                                .firstOrNull
                                ?.unit
                                .unitId;
                          }),
                          onSelectUnit: (value) => setState(() {
                            _selectedUnitId = value;
                            _selectedItemId = data
                                .unitFor(value)
                                ?.items
                                .firstOrNull
                                ?.itemId;
                          }),""",
    """                          onSelectSection: (value) =>
                              unawaited(_selectSection(value, data)),
                          onSelectUnit: (value) =>
                              unawaited(_selectUnit(value, data)),""",
)
replace_once(
    viewer,
    """          onChanged: (value) {
            if (value == null) return;
            final next = data.sections.firstWhere(
              (section) => section.section.sectionId == value,
            );
            setState(() {
              _selectedSectionId = value;
              _selectedUnitId = next.units.firstOrNull?.unit.unitId;
              _selectedItemId =
                  next.units.firstOrNull?.items.firstOrNull?.itemId;
            });
          },""",
    """          onChanged: (value) {
            if (value != null) unawaited(_selectSection(value, data));
          },""",
)
replace_once(
    viewer,
    """            onChanged: (value) {
              if (value == null) return;
              final next = data.unitFor(value);
              setState(() {
                _selectedUnitId = value;
                _selectedItemId = next?.items.firstOrNull?.itemId;
              });
            },""",
    """            onChanged: (value) {
              if (value != null) unawaited(_selectUnit(value, data));
            },""",
)

test = "test/teacher_guide_viewer_test.dart"
insert_tests = """

  testWidgets(
    'unit switch saves dirty note against the previous guide item',
    (tester) async {
      _useSize(tester, const Size(412, 915));
      final notes = _MemoryNotes();

      await tester.pumpWidget(
        _viewerApp(assignmentId: 'assignment-A', notes: notes),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Gözlem notu');
      await tester.pump(const Duration(milliseconds: 100));

      final unitDropdown = find.byType(DropdownButtonFormField<String>).at(1);
      await tester.tap(unitDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modelleme').last);
      await tester.pumpAndSettle();

      expect(notes.saved, isNotEmpty);
      expect(notes.saved.first.guideItemId, 'ITEM_OBSERVATION');
      expect(notes.saved.first.note, 'Gözlem notu');
      expect(find.text('Modeli değiştir'), findsWidgets);
      final noteField = tester.widget<TextField>(find.byType(TextField).last);
      expect(noteField.controller?.text ?? '', isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dispose flushes a pending note before debounce fires', (
    tester,
  ) async {
    _useSize(tester, const Size(412, 915));
    final notes = _MemoryNotes();

    await tester.pumpWidget(
      _viewerApp(assignmentId: 'assignment-A', notes: notes),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Kapanış notu');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(notes.saved, isNotEmpty);
    expect(notes.saved.last.guideItemId, 'ITEM_OBSERVATION');
    expect(notes.saved.last.note, 'Kapanış notu');
    expect(tester.takeException(), isNull);
  });
"""
replace_once(
    test,
    "\n  testWidgets('failed note save is visible instead of silent loss', (",
    insert_tests + "\n  testWidgets('failed note save is visible instead of silent loss', (",
)
model_unit = """

  static const modelUnit = TeacherGuideUnit(
    unitId: 'UNIT_MODEL',
    sectionId: 'SECTION_EXPERIMENT',
    order: 2,
    title: 'Modelleme',
    pageLocator: '43',
    sourceLocator: 'physics_textbook#43',
    contentStatus: 'VERIFIED',
    purpose: ['Modelle', 'Karşılaştır'],
    provenance: TeacherGuideProvenance(
      sourceIds: ['physics_textbook'],
      sourceLocators: ['printed p. 43'],
      contentClass: 'PEDAGOGICAL_ENRICHMENT',
    ),
  );
"""
replace_once(
    test,
    "\n  static const observation = TeacherGuideItem(",
    model_unit + "\n  static const observation = TeacherGuideItem(",
)
replace_once(
    test,
    "    unitId: 'UNIT_OBSERVATION',\n    order: 2,\n    title: 'Modeli değiştir',",
    "    unitId: 'UNIT_MODEL',\n    order: 2,\n    title: 'Modeli değiştir',",
)
replace_once(test, "          unitCount: 1,", "          unitCount: 2,")
replace_once(
    test,
    """  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async =>
      sectionId == section.sectionId && guideAvailable ? const [unit] : [];

  @override
  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId) async =>
      unitId == unit.unitId && guideAvailable ? unit : null;

  @override
  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async =>
      unitId == unit.unitId && guideAvailable
      ? const [observation, modelItem]
      : [];""",
    """  Future<List<TeacherGuideUnit>> getTeacherGuideUnits(String sectionId) async =>
      sectionId == section.sectionId && guideAvailable
      ? const [unit, modelUnit]
      : [];

  @override
  Future<TeacherGuideUnit?> getTeacherGuideUnit(String unitId) async {
    if (!guideAvailable) return null;
    if (unitId == unit.unitId) return unit;
    if (unitId == modelUnit.unitId) return modelUnit;
    return null;
  }

  @override
  Future<List<TeacherGuideItem>> getTeacherGuideItems(String unitId) async {
    if (!guideAvailable) return const [];
    if (unitId == unit.unitId) return const [observation];
    if (unitId == modelUnit.unitId) return const [modelItem];
    return const [];
  }""",
)

replace_once(
    "tool/rebuild_curriculum_only_runtimes.py",
    'COURSES = ("TDE_11", "TDE_12")',
    'COURSES = ("TDE_12",)',
)

ci = ".github/workflows/flutter-ci.yml"
replace_all(
    ci,
    "Rebuild TDE11/TDE12 curriculum-only runtimes",
    "Rebuild TDE12 curriculum-only runtime",
    expected_min=4,
)
replace_once(ci, "Verify TDE11 curriculum-only runtime", "Verify TDE11 full runtime")

replace_once(
    "tymm-verileri/turk-dili-ve-edebiyati/TDE_11/package_manifest.json",
    "296a1b41de17a4f0c2ae78a27e3a5cd3b6d6b482",
    "6785d28bd5c22bfad7c8a73d8162fa81cae62d6b",
)
