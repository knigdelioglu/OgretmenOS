import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/models/teacher_guide_models.dart';
import '../../domain/models/teacher_guide_note_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/teacher_guide_notes_repository.dart';
import '../shared/feature_widgets.dart';
import 'form_reference_tile.dart';

/// Native, structured view of the optional teacher-guide runtime capability.
///
/// The page receives canonical content through the repository only.  It never
/// reads source JSON or executes SQL, and the optional note editor writes only
/// to assignment-scoped teacher state.
class TeacherGuideViewerPage extends StatefulWidget {
  const TeacherGuideViewerPage({
    super.key,
    required this.repository,
    required this.scopeType,
    required this.scopeId,
    this.guideId,
    this.sectionId,
    this.unitId,
    this.itemId,
    this.guideItemIds = const [],
    this.assignmentId,
    this.notesRepository,
  });

  final CourseKnowledgeRepository repository;
  final String scopeType;
  final String scopeId;
  final String? guideId;
  final String? sectionId;
  final String? unitId;
  final String? itemId;
  final List<String> guideItemIds;
  final String? assignmentId;
  final TeacherGuideNotesRepository? notesRepository;

  @override
  State<TeacherGuideViewerPage> createState() => _TeacherGuideViewerPageState();
}

class _TeacherGuideViewerPageState extends State<TeacherGuideViewerPage> {
  late Future<_GuideViewData> _future;
  final _searchController = TextEditingController();
  Timer? _noteSaveTimer;
  TextEditingController? _noteController;
  TeacherGuideNote? _loadedNote;
  TeacherGuideItem? _noteItem;
  String? _selectedSectionId;
  String? _selectedUnitId;
  String? _selectedItemId;
  String _query = '';
  String? _noteError;
  bool _noteSaving = false;
  bool _noteDirty = false;
  int _noteRevision = 0;
  int _noteEditRevision = 0;

  @override
  void initState() {
    super.initState();
    _selectedSectionId = widget.sectionId;
    _selectedUnitId = widget.unitId;
    _selectedItemId = widget.itemId ?? widget.guideItemIds.firstOrNull;
    _searchController.addListener(_onSearchChanged);
    _future = _load();
  }

  @override
  void dispose() {
    _noteSaveTimer?.cancel();
    _flushPendingNoteOnDispose();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _noteController?.dispose();
    super.dispose();
  }

  Future<_GuideViewData> _load() async {
    final guide = widget.guideId == null
        ? await widget.repository.getTeacherGuideForScope(
            scopeType: widget.scopeType,
            scopeId: widget.scopeId,
          )
        : await _findGuideById(widget.guideId!);
    if (guide == null) {
      throw StateError('Öğretmen rehberi bu kapsamda kullanılamıyor.');
    }
    final sections = await widget.repository.getTeacherGuideSections(
      guide.guideId,
    );
    final sectionData = <_GuideSectionData>[];
    for (final section in sections) {
      final units = await widget.repository.getTeacherGuideUnits(
        section.sectionId,
      );
      final unitData = <_GuideUnitData>[];
      for (final unit in units) {
        unitData.add(
          _GuideUnitData(
            unit: unit,
            items: await widget.repository.getTeacherGuideItems(unit.unitId),
          ),
        );
      }
      sectionData.add(_GuideSectionData(section: section, units: unitData));
    }
    final data = _GuideViewData(guide: guide, sections: sectionData);
    _repairSelection(data);
    unawaited(_loadNoteForSelection(data.itemById(_selectedItemId)));
    return data;
  }

  Future<TeacherGuide?> _findGuideById(String guideId) async {
    final guide = await widget.repository.getTeacherGuideForScope(
      scopeType: widget.scopeType,
      scopeId: widget.scopeId,
    );
    return guide?.guideId == guideId ? guide : null;
  }

  void _repairSelection(_GuideViewData data) {
    final requestedItem = data.items.where((item) {
      if (_selectedItemId != null && item.itemId == _selectedItemId) {
        return true;
      }
      return widget.guideItemIds.contains(item.itemId);
    });
    final item = requestedItem.isNotEmpty
        ? requestedItem.first
        : data.items.firstOrNull;
    if (item == null) return;
    _selectedItemId = item.itemId;
    final unitData = data.unitFor(item.unitId);
    _selectedUnitId = unitData?.unit.unitId;
    _selectedSectionId = unitData == null
        ? _selectedSectionId
        : data.sectionFor(unitData.unit.sectionId)?.section.sectionId;
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text.trim());
  }

  List<TeacherGuideItem> _searchResults(_GuideViewData data) {
    final query = _query.toLowerCase();
    if (query.isEmpty) return const [];
    return data.items
        .where((item) {
          final unit = data.unitFor(item.unitId)?.unit;
          final section = unit == null ? null : data.sectionFor(unit.sectionId);
          final haystack = [
            item.title,
            item.label,
            item.itemType,
            item.pageLocator,
            _searchableJson(item.teacherGuidance),
            _searchableJson(item.expectedResponse),
            _searchableJson(item.acceptanceCriteria),
            _searchableJson(item.assessmentEvidence),
            item.relations.map((relation) => relation.targetId).join(' '),
            unit?.title,
            section?.section.title,
          ].whereType<String>().join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _selectSection(String sectionId, _GuideViewData data) async {
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

  Future<void> _selectItem(TeacherGuideItem item, _GuideViewData data) async {
    final unitData = data.unitFor(item.unitId);
    if (unitData == null) return;
    _noteSaveTimer?.cancel();
    if (_noteDirty && !await _saveNote()) return;
    if (!mounted) return;
    setState(() {
      _selectedItemId = item.itemId;
      _selectedUnitId = unitData.unit.unitId;
      _selectedSectionId = unitData.sectionId;
      _noteError = null;
    });
    unawaited(_loadNoteForSelection(item));
  }

  Future<void> _loadNoteForSelection(TeacherGuideItem? item) async {
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
  }

  void _onNoteChanged(String _) {
    _noteEditRevision++;
    _noteDirty = true;
    _noteError = null;
    _noteSaveTimer?.cancel();
    _noteSaveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveNote());
    });
    setState(() {});
  }

  Future<bool> _saveNote() async {
    _noteSaveTimer?.cancel();
    final assignmentId = widget.assignmentId;
    final notes = widget.notesRepository;
    final item = _noteItem ?? _currentItem;
    final controller = _noteController;
    if (!_noteDirty ||
        assignmentId == null ||
        notes == null ||
        item == null ||
        controller == null) {
      return true;
    }
    final hash = item.canonicalPayloadSha256;
    if (hash == null || hash.isEmpty) {
      setState(
        () =>
            _noteError = 'Bu rehber maddesi not için canonical hash taşımıyor.',
      );
      return false;
    }
    final editRevision = _noteEditRevision;
    final noteText = controller.text;
    final savedNote = TeacherGuideNote(
      assignmentId: assignmentId,
      guideItemId: item.itemId,
      note: noteText,
      canonicalPayloadSha256: hash,
      updatedAt: DateTime.now(),
    );
    setState(() {
      _noteSaving = true;
      _noteError = null;
    });
    try {
      await notes.save(savedNote);
      if (!mounted) return false;
      _noteSaving = false;
      if (_noteEditRevision != editRevision) {
        // A keystroke arrived while the write was in flight. Persist the
        // latest value before allowing navigation to complete.
        return await _saveNote();
      }
      _noteDirty = false;
      _loadedNote = savedNote;
      setState(() {});
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      setState(() {
        _noteSaving = false;
        _noteError = 'Not kaydedilemedi. Tekrar dene. ($error)';
      });
      return false;
    }
  }

  void _flushPendingNoteOnDispose() {
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
      notes.save(snapshot).onError((Object _, StackTrace _) {
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
  }

  TeacherGuideItem? get _currentItem {
    // The detail widgets receive the loaded data and set this through the
    // local selection, so the getter is only used by note actions below.
    return _lastLoadedItem;
  }

  TeacherGuideItem? _lastLoadedItem;

  @override
  Widget build(BuildContext context) => FutureBuilder<_GuideViewData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const Scaffold(
          body: LoadingView(label: 'Öğretmen rehberi hazırlanıyor…'),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: const Text('Öğretmen Rehberi')),
          body: FeatureErrorView(
            message: 'Öğretmen rehberi yüklenemedi.',
            onRetry: () => setState(() => _future = _load()),
          ),
        );
      }
      return PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_handleBack());
        },
        child: _buildLoaded(context, snapshot.data!),
      );
    },
  );

  Widget _buildLoaded(BuildContext context, _GuideViewData data) {
    _repairSelection(data);
    final item = data.itemById(_selectedItemId);
    _lastLoadedItem = item;
    final searchResults = _searchResults(data);
    return Scaffold(
      appBar: AppBar(
        title: Text(data.guide.title),
        actions: [
          if (data.guide.contentStatus.toUpperCase() == 'REVIEW_REQUIRED')
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Tooltip(
                  message: 'Öğretmen incelemesi gerekli',
                  child: Icon(Icons.rate_review_outlined),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final search = _searchField(context);
            if (!wide) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  search,
                  if (data.isBookFirstV23) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _bookFirstPageJump(data),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (searchResults.isNotEmpty)
                    _SearchResults(
                      results: searchResults,
                      data: data,
                      onSelect: (value) => _selectItem(value, data),
                    ),
                  _phoneSelectors(context, data),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.guideItemIds.length > 1)
                    _RelatedItems(
                      items: data.items
                          .where(
                            (item) => widget.guideItemIds.contains(item.itemId),
                          )
                          .toList(growable: false),
                      selectedItemId: item?.itemId,
                      onSelect: (value) => _selectItem(value, data),
                    ),
                  if (item != null) _ItemDetail(item: item, state: this),
                  const SizedBox(height: AppSpacing.md),
                  _ReviewSummary(data: data),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      if (data.isBookFirstV23) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _bookFirstPageJump(data),
                      ],
                    ],
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: _SearchResults(
                      results: searchResults,
                      data: data,
                      onSelect: (value) => _selectItem(value, data),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: _ReviewSummary(data: data),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth.clamp(260, 340),
                        child: _GuideOutline(
                          data: data,
                          selectedSectionId: _selectedSectionId,
                          selectedUnitId: _selectedUnitId,
                          selectedItemId: item?.itemId,
                          onSelectItem: (value) => _selectItem(value, data),
                          onSelectSection: (value) =>
                              unawaited(_selectSection(value, data)),
                          onSelectUnit: (value) =>
                              unawaited(_selectUnit(value, data)),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.lg,
                            AppSpacing.xl,
                            AppSpacing.xxl,
                          ),
                          child: widget.guideItemIds.length > 1
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _RelatedItems(
                                      items: data.items
                                          .where(
                                            (item) => widget.guideItemIds
                                                .contains(item.itemId),
                                          )
                                          .toList(growable: false),
                                      selectedItemId: item?.itemId,
                                      onSelect: (value) =>
                                          _selectItem(value, data),
                                    ),
                                    if (item != null)
                                      _ItemDetail(item: item, state: this),
                                  ],
                                )
                              : item == null
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpacing.xl),
                                  child: Text('Bir rehber maddesi seç.'),
                                )
                              : _ItemDetail(item: item, state: this),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) => TextField(
    controller: _searchController,
    decoration: InputDecoration(
      labelText: 'Rehberde ara',
      hintText: 'Başlık, yönlendirme, cevap veya sayfa',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Aramayı temizle',
              onPressed: _searchController.clear,
              icon: const Icon(Icons.clear),
            ),
    ),
  );

  Widget _bookFirstPageJump(_GuideViewData data) {
    final targets = data.pageTargets;
    final selectedLocator = data.itemById(_selectedItemId)?.pageLocator?.trim();
    final currentValue =
        targets.any((target) => target.locator == selectedLocator)
        ? selectedLocator
        : null;
    return DropdownButtonFormField<String>(
      key: const ValueKey('book-first-page-jump'),
      initialValue: currentValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kitap sayfasına git',
        prefixIcon: Icon(Icons.menu_book_outlined),
      ),
      items: [
        for (final target in targets)
          DropdownMenuItem(
            value: target.locator,
            child: Text(
              's. ${target.locator} — ${target.title}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (locator) {
        if (locator == null) return;
        final target = targets
            .where((candidate) => candidate.locator == locator)
            .firstOrNull;
        final item = target == null ? null : data.itemById(target.itemId);
        if (item != null) unawaited(_selectItem(item, data));
      },
    );
  }

  Widget _phoneSelectors(BuildContext context, _GuideViewData data) {
    final selectedSection =
        data.sections.any(
          (value) => value.section.sectionId == _selectedSectionId,
        )
        ? _selectedSectionId
        : data.sections.firstOrNull?.section.sectionId;
    final sectionData = data.sections
        .where((value) => value.section.sectionId == selectedSection)
        .firstOrNull;
    final selectedUnit =
        (sectionData?.units.any(
              (value) => value.unit.unitId == _selectedUnitId,
            ) ??
            false)
        ? _selectedUnitId
        : sectionData?.units.firstOrNull?.unit.unitId;
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedSection,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Bölüm'),
          items: [
            for (final value in data.sections)
              DropdownMenuItem(
                value: value.section.sectionId,
                child: Text(value.section.title),
              ),
          ],
          onChanged: (value) {
            if (value != null) unawaited(_selectSection(value, data));
          },
        ),
        if (sectionData != null) ...[
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: selectedUnit,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: data.isBookFirstV23 ? 'Sayfa / etkinlik' : 'Ünite',
            ),
            items: [
              for (final value in sectionData.units)
                DropdownMenuItem(
                  value: value.unit.unitId,
                  child: Text(value.unit.title),
                ),
            ],
            onChanged: (value) {
              if (value != null) unawaited(_selectUnit(value, data));
            },
          ),
        ],
      ],
    );
  }
}

class _GuideViewData {
  const _GuideViewData({required this.guide, required this.sections});

  final TeacherGuide guide;
  final List<_GuideSectionData> sections;

  List<TeacherGuideItem> get items => [
    for (final section in sections)
      for (final unit in section.units) ...unit.items,
  ];

  _GuideSectionData? sectionFor(String sectionId) => sections
      .where((value) => value.section.sectionId == sectionId)
      .firstOrNull;

  _GuideUnitData? unitFor(String unitId) =>
      [for (final section in sections) ...section.units]
          .where((value) => value.unit.unitId == unitId)
          .firstOrNull;

  TeacherGuideItem? itemById(String? itemId) => itemId == null
      ? null
      : items.where((value) => value.itemId == itemId).firstOrNull;

  List<_GuidePageTarget> get pageTargets {
    final byLocator = <String, _GuidePageTarget>{};
    for (final section in sections) {
      for (final unit in section.units) {
        for (final item in unit.items) {
          final locator = item.pageLocator?.trim();
          if (locator == null || locator.isEmpty) continue;
          byLocator.putIfAbsent(
            locator,
            () => _GuidePageTarget(
              locator: locator,
              itemId: item.itemId,
              title: unit.unit.title,
            ),
          );
        }
      }
    }
    final result = byLocator.values.toList(growable: false)
      ..sort((a, b) {
        final pageCompare = _pageSortKey(a.locator)
            .compareTo(_pageSortKey(b.locator));
        return pageCompare != 0 ? pageCompare : a.locator.compareTo(b.locator);
      });
    return result;
  }

  bool get isBookFirstV23 => items.any(_isBookFirstV23Item);
}

class _GuidePageTarget {
  const _GuidePageTarget({
    required this.locator,
    required this.itemId,
    required this.title,
  });

  final String locator;
  final String itemId;
  final String title;
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.data});

  final _GuideViewData data;

  @override
  Widget build(BuildContext context) {
    final sections = data.sections;
    final units = [for (final section in sections) ...section.units];
    final items = data.items;
    final reviewSections = sections
        .where((value) => _isReviewStatus(value.section.contentStatus))
        .length;
    final reviewUnits = units
        .where((value) => _isReviewStatus(value.unit.contentStatus))
        .length;
    final reviewItems = items
        .where((value) => _isReviewStatus(value.contentStatus))
        .length;
    final linkedForms = items.fold<int>(
      0,
      (count, item) =>
          count +
          item.relations
              .where((relation) => relation.targetType.toLowerCase() == 'form')
              .length,
    );
    final needsReview =
        _isReviewStatus(data.guide.contentStatus) ||
        reviewSections > 0 ||
        reviewUnits > 0 ||
        reviewItems > 0;
    final scheme = Theme.of(context).colorScheme;
    final bookFirst = data.isBookFirstV23;

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              bookFirst
                  ? Icons.fact_check_outlined
                  : needsReview
                  ? Icons.rate_review_outlined
                  : Icons.verified_outlined,
              color: bookFirst
                  ? scheme.tertiary
                  : needsReview
                  ? scheme.error
                  : scheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookFirst
                        ? needsReview
                              ? 'Kaynak denetimi sürüyor'
                              : 'Kitap odaklı rehber doğrulandı'
                        : needsReview
                        ? 'İnceleme durumu: Öğretmen incelemesi gerekli'
                        : 'İnceleme durumu: Doğrulandı',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: bookFirst
                          ? scheme.tertiary
                          : needsReview
                          ? scheme.error
                          : scheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text('madde inceleme: $reviewItems'),
                      Text('ünite inceleme: $reviewUnits'),
                      Text('bölüm inceleme: $reviewSections'),
                      Text('form bağlantısı: $linkedForms'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSectionData {
  const _GuideSectionData({required this.section, required this.units});

  final TeacherGuideSection section;
  final List<_GuideUnitData> units;
}

class _GuideUnitData {
  const _GuideUnitData({required this.unit, required this.items});

  final TeacherGuideUnit unit;
  final List<TeacherGuideItem> items;

  String get sectionId => unit.sectionId;
}

class _OutlineSubtitle extends StatelessWidget {
  const _OutlineSubtitle({required this.locator, required this.contentStatus});

  final String? locator;
  final String contentStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (_locator(locator).isNotEmpty) Text(_locator(locator)),
        if (_isReviewStatus(contentStatus))
          Text(
            'İnceleme gerekli',
            style: TextStyle(color: theme.colorScheme.error),
          ),
      ],
    );
  }
}

class _GuideOutline extends StatelessWidget {
  const _GuideOutline({
    required this.data,
    required this.selectedSectionId,
    required this.selectedUnitId,
    required this.selectedItemId,
    required this.onSelectSection,
    required this.onSelectUnit,
    required this.onSelectItem,
  });

  final _GuideViewData data;
  final String? selectedSectionId;
  final String? selectedUnitId;
  final String? selectedItemId;
  final ValueChanged<String> onSelectSection;
  final ValueChanged<String> onSelectUnit;
  final ValueChanged<TeacherGuideItem> onSelectItem;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final section in data.sections) ...[
          ListTile(
            selected: section.section.sectionId == selectedSectionId,
            leading: const Icon(Icons.view_agenda_outlined),
            title: Text(section.section.title),
            subtitle: _OutlineSubtitle(
              locator: section.section.pageLocator,
              contentStatus: section.section.contentStatus,
            ),
            onTap: () => onSelectSection(section.section.sectionId),
          ),
          for (final unit in section.units) ...[
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: ListTile(
                dense: true,
                selected: unit.unit.unitId == selectedUnitId,
                leading: const Icon(Icons.list_alt_outlined, size: 20),
                title: Text(unit.unit.title),
                subtitle: _OutlineSubtitle(
                  locator: unit.unit.pageLocator,
                  contentStatus: unit.unit.contentStatus,
                ),
                onTap: () => onSelectUnit(unit.unit.unitId),
              ),
            ),
            for (final item in unit.items)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: ListTile(
                  dense: true,
                  selected: item.itemId == selectedItemId,
                  title: Text(item.title ?? item.label),
                  subtitle: _OutlineSubtitle(
                    locator: item.pageLocator,
                    contentStatus: item.contentStatus,
                  ),
                  onTap: () => onSelectItem(item),
                ),
              ),
          ],
        ],
      ],
    ),
  );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.data,
    required this.onSelect,
  });

  final List<TeacherGuideItem> results;
  final _GuideViewData data;
  final ValueChanged<TeacherGuideItem> onSelect;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            '${results.length} sonuç',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final item in results.take(12))
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(item.title ?? item.label),
            subtitle: Text(_contextLabel(data, item)),
            onTap: () => onSelect(item),
          ),
      ],
    ),
  );
}

class _RelatedItems extends StatelessWidget {
  const _RelatedItems({
    required this.items,
    required this.selectedItemId,
    required this.onSelect,
  });

  final List<TeacherGuideItem> items;
  final String? selectedItemId;
  final ValueChanged<TeacherGuideItem> onSelect;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text('İlgili rehber maddeleri'),
        ),
        for (final item in items)
          ListTile(
            selected: item.itemId == selectedItemId,
            title: Text(item.title ?? item.label),
            subtitle: Text(_locator(item.pageLocator)),
            onTap: () => onSelect(item),
          ),
      ],
    ),
  );
}

class _ItemDetail extends StatelessWidget {
  const _ItemDetail({required this.item, required this.state});

  final TeacherGuideItem item;
  final _TeacherGuideViewerPageState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enrichment =
        item.provenance.contentClass?.toUpperCase() == 'PEDAGOGICAL_ENRICHMENT';
    final bookFirst = _isBookFirstV23Item(item);
    final formRelations = item.relations
        .where((relation) => relation.targetType.toLowerCase() == 'form')
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (item.pageLocator?.isNotEmpty == true)
              Chip(label: Text('s. ${item.pageLocator}')),
            Chip(label: Text(_itemTypeLabel(item.itemType))),
            if (item.contentStatus.toUpperCase() == 'REVIEW_REQUIRED')
              _ReviewBadge(bookFirst: bookFirst),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          item.title ?? item.label,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (item.title != null && item.title != item.label) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(item.label, style: theme.textTheme.titleMedium),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (_hasContent(item.expectedResponse))
          _ContentBlock(
            title: _expectedResponseTitle(item),
            icon: Icons.forum_outlined,
            value: item.expectedResponse,
          )
        else if (_isSourceBoundUnanswered(item))
          const _SourceBoundAnswerNotice(),
        if (_hasContent(item.teacherGuidance))
          _ContentBlock(
            title: bookFirst ? 'Öğretmen yönlendirmesi' : 'Öğretmene not',
            icon: Icons.lightbulb_outline,
            value: item.teacherGuidance,
          ),
        if (enrichment)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Pedagojik öneri; kitabın zorunlu yönergesi değildir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (state.widget.assignmentId != null &&
            state.widget.notesRepository != null &&
            item.canonicalPayloadSha256?.isNotEmpty == true)
          _TeacherGuideNoteEditor(item: item, state: state),
        if (formRelations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Bağlı formlar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final relation in formRelations)
            FormReferenceTile(
              formId: relation.targetId,
              repository: state.widget.repository,
              compact: true,
            ),
        ],
        Card.outlined(
          child: ExpansionTile(
            title: const Text('Ayrıntılar'),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              if (_hasContent(item.acceptanceCriteria))
                _ContentBlock(
                  title: 'Kabul ölçütleri',
                  value: item.acceptanceCriteria,
                ),
              if (_hasContent(item.commonMisconceptions))
                _ContentBlock(
                  title: 'Sık yapılan hata',
                  value: item.commonMisconceptions,
                ),
              if (_hasContent(item.assessmentEvidence))
                _ContentBlock(
                  title: 'Değerlendirme kanıtı',
                  value: item.assessmentEvidence,
                ),
              if (_hasContent(item.differentiation.support))
                _ContentBlock(
                  title: 'Destek',
                  value: item.differentiation.support,
                ),
              if (_hasContent(item.differentiation.enrichment))
                _ContentBlock(
                  title: 'Zenginleştirme',
                  value: item.differentiation.enrichment,
                ),
              _ProvenanceBlock(provenance: item.provenance),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeacherGuideNoteEditor extends StatefulWidget {
  const _TeacherGuideNoteEditor({required this.item, required this.state});

  final TeacherGuideItem item;
  final _TeacherGuideViewerPageState state;

  @override
  State<_TeacherGuideNoteEditor> createState() =>
      _TeacherGuideNoteEditorState();
}

class _TeacherGuideNoteEditorState extends State<_TeacherGuideNoteEditor> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    state._noteController ??= TextEditingController(
      text: state._loadedNote?.note ?? '',
    );
    final note = state._loadedNote;
    final stale =
        note?.isStaleFor(widget.item.canonicalPayloadSha256!) ?? false;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bu atama için not',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (state._noteSaving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (stale) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Rehber maddesi güncellendi · notunu gözden geçir',
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: state._noteController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Bu sınıf/atama için not ekle',
                alignLabelWithHint: true,
              ),
              onChanged: state._onNoteChanged,
            ),
            if (state._noteError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                state._noteError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => unawaited(state._saveNote()),
                  child: const Text('Tekrar kaydet'),
                ),
              ),
            ],
            if (!state._noteDirty &&
                !state._noteSaving &&
                state._noteError == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Kaydedildi',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContentBlock extends StatelessWidget {
  const _ContentBlock({required this.title, required this.value, this.icon});

  final String title;
  final Object? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _JsonValue(value: value),
      ],
    ),
  );
}

class _JsonValue extends StatelessWidget {
  const _JsonValue({required this.value, this.indent = 0});

  final Object? value;
  final int indent;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const Text('Belirtilmemiş');
    if (value is String || value is num || value is bool) {
      return Text(value.toString());
    }
    if (value is List) {
      final list = value as List;
      if (list.isEmpty) return const Text('Belirtilmemiş');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in list)
            Padding(
              padding: EdgeInsets.only(
                left: indent.toDouble(),
                bottom: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: _JsonValue(value: entry, indent: indent + 12),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (value is Map) {
      final map = Map<Object?, Object?>.from(value as Map);
      if (map.isEmpty) return const Text('Belirtilmemiş');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in map.entries)
            Padding(
              padding: EdgeInsets.only(
                left: indent.toDouble(),
                bottom: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _humanizeKey(entry.key.toString()),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _JsonValue(value: entry.value, indent: indent + 12),
                ],
              ),
            ),
        ],
      );
    }
    return Text(value.toString());
  }
}

class _ProvenanceBlock extends StatelessWidget {
  const _ProvenanceBlock({required this.provenance});

  final TeacherGuideProvenance provenance;

  @override
  Widget build(BuildContext context) => _ContentBlock(
    title: _provenanceLabel(provenance.contentClass),
    value: [
      if (provenance.sourceLocators.isNotEmpty)
        provenance.sourceLocators.join(' · '),
      if (provenance.note?.isNotEmpty == true) provenance.note!,
    ],
  );
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({this.bookFirst = false});

  final bool bookFirst;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      bookFirst ? Icons.fact_check_outlined : Icons.rate_review_outlined,
      size: 16,
    ),
    label: Text(bookFirst ? 'Kaynak kontrolü' : 'Öğretmen incelemesi gerekli'),
  );
}

class _SourceBoundAnswerNotice extends StatelessWidget {
  const _SourceBoundAnswerNotice();

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.image_search_outlined, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Cevap, ders kitabındaki görsel veya kaynak katmanına bağlı. '
              'Rehber doğrulanmamış bir cevap üretmez; kabul ölçütü ve kaynak '
              'bilgisi Ayrıntılar bölümünde gösterilir.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

String _searchableJson(Object? value) {
  try {
    return jsonEncode(value);
  } on Object {
    return value?.toString() ?? '';
  }
}

String _contextLabel(_GuideViewData data, TeacherGuideItem item) {
  final unit = data.unitFor(item.unitId);
  final section = unit == null ? null : data.sectionFor(unit.unit.sectionId);
  return [
    if (section != null) section.section.title,
    if (unit != null) unit.unit.title,
    _locator(item.pageLocator),
  ].where((value) => value.isNotEmpty).join(' · ');
}

String _locator(String? value) =>
    value?.trim().isNotEmpty == true ? 's. ${value!.trim()}' : '';

bool _isReviewStatus(String value) =>
    value.trim().toUpperCase() == 'REVIEW_REQUIRED';

bool _isBookFirstV23Item(TeacherGuideItem item) =>
    item.provenance.contentClass?.trim().toUpperCase() ==
    'BOOK_FIRST_V2_3_ITEM';

bool _hasContent(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

bool _isSourceBoundUnanswered(TeacherGuideItem item) =>
    _isBookFirstV23Item(item) &&
    item.itemType.trim().toUpperCase() == 'QUESTION' &&
    !_hasContent(item.expectedResponse) &&
    item.provenance.additional['rights_mode'] == 'PAGE_REFERENCE';

String _expectedResponseTitle(TeacherGuideItem item) {
  if (!_isBookFirstV23Item(item)) return 'Beklenen cevap / öğrenci tepkisi';
  return switch (item.itemType.trim().toUpperCase()) {
    'QUESTION' => 'Cevap / kabul edilebilir yaklaşım',
    'PROCESS' => 'Uygulama / beklenen süreç',
    'REFERENCE' => 'Başvuru bilgisi',
    'VOCABULARY' => 'Söz varlığı / açıklama',
    'TABLE' => 'Tablo / örnek çözüm',
    'COMPARISON' => 'Karşılaştırma',
    'ASSESSMENT' => 'Değerlendirme anahtarı',
    _ => 'Beklenen çıktı',
  };
}

String _humanizeKey(String value) {
  final known = switch (value) {
    'canonical_ref' => 'Kaynak maddesi',
    'label' => 'Başlık',
    'value' => 'İçerik',
    _ => null,
  };
  if (known != null) return known;
  final normalized = value.replaceAll('_', ' ').trim();
  return normalized.isEmpty ? value : normalized;
}

int _pageSortKey(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return int.tryParse(match?.group(0) ?? '') ?? (1 << 30);
}

String _itemTypeLabel(String value) => switch (value.trim().toUpperCase()) {
  'QUESTION' => 'Soru',
  'PROCESS' => 'Süreç',
  'REFERENCE' => 'Kaynak',
  'VOCABULARY' => 'Söz varlığı',
  'TABLE' => 'Tablo',
  'COMPARISON' => 'Karşılaştırma',
  'ASSESSMENT' => 'Değerlendirme',
  _ => () {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'İçerik';
    return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
  }(),
};

String _provenanceLabel(String? value) => switch (value?.toUpperCase()) {
  'OFFICIAL_TEXTBOOK' => 'Resmî ders kitabı',
  'OFFICIAL_NORMATIVE' => 'Program dayanağı',
  'LESSON_PLAN_IMPLEMENTATION' => 'Ders planı uygulaması',
  'PEDAGOGICAL_ENRICHMENT' => 'Pedagojik öneri',
  'REVIEW_REQUIRED' => 'Öğretmen incelemesi gerekli',
  'MIXED' => 'Kaynaklı içerik',
  _ => 'Kaynak bilgisi',
};

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
