import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/resource_navigation.dart';
import '../../data/preferences/continuity_repository.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/performance_instrumentation.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';
import 'form_viewer_page.dart';

class ResourceLibraryPage extends StatefulWidget {
  const ResourceLibraryPage({
    super.key,
    required this.repository,
    required this.awaitingTextbook,
    this.isActive = true,
    this.topTrailing,
    this.continuity,
    this.weeklyPlanning,
    this.courseId,
    this.navigationContext,
  });

  final CourseKnowledgeRepository repository;
  final bool awaitingTextbook;
  final bool isActive;
  final Widget? topTrailing;
  final ContinuityRepository? continuity;
  final WeeklyPlanningService? weeklyPlanning;
  final String? courseId;
  final ResourceNavigationContext? navigationContext;

  @override
  State<ResourceLibraryPage> createState() => _ResourceLibraryPageState();
}

class _ResourceLibraryPageState extends State<ResourceLibraryPage> {
  late Future<_ResourceData> _future;
  _ResourceData? _resourceData;
  String? _selectedThemeId;
  ResourceCategory? _selectedCategory;
  int _sectionRevision = 0;
  int _focusRevision = 0;
  bool _initialUsefulContentReported = false;
  String? _openedNavigationFormId;
  ContinuityRepository? _observedContinuity;
  ContinuityChangeListener? _continuityChangeListener;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.navigationContext?.themeId;
    _selectedCategory = widget.navigationContext?.category;
    _subscribeToContinuityChanges();
    _future = _mainLoad();
  }

  @override
  void didUpdateWidget(covariant ResourceLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.continuity != widget.continuity) {
      _unsubscribeFromContinuityChanges();
      _subscribeToContinuityChanges();
    }
    if (oldWidget.repository != widget.repository ||
        oldWidget.awaitingTextbook != widget.awaitingTextbook ||
        oldWidget.continuity != widget.continuity ||
        oldWidget.weeklyPlanning != widget.weeklyPlanning ||
        oldWidget.courseId != widget.courseId ||
        oldWidget.navigationContext != widget.navigationContext) {
      _selectedThemeId = widget.navigationContext?.themeId;
      _selectedCategory = widget.navigationContext?.category;
      _sectionRevision++;
      if (widget.navigationContext != null ||
          oldWidget.repository != widget.repository ||
          oldWidget.awaitingTextbook != widget.awaitingTextbook ||
          oldWidget.continuity != widget.continuity ||
          oldWidget.weeklyPlanning != widget.weeklyPlanning ||
          oldWidget.courseId != widget.courseId) {
        _resourceData = null;
        _initialUsefulContentReported = false;
        _future = _mainLoad();
      }
    }
    if (!oldWidget.isActive &&
        widget.isActive &&
        widget.navigationContext == null) {
      _sectionRevision++;
      unawaited(_refreshOnActivation());
    }
  }

  @override
  void dispose() {
    _unsubscribeFromContinuityChanges();
    super.dispose();
  }

  void _subscribeToContinuityChanges() {
    final continuity = widget.continuity;
    if (continuity == null) return;
    final listener = _handleContinuityChanged;
    _observedContinuity = continuity;
    _continuityChangeListener = listener;
    continuity.addChangeListener(listener);
  }

  void _unsubscribeFromContinuityChanges() {
    final continuity = _observedContinuity;
    final listener = _continuityChangeListener;
    if (continuity != null && listener != null) {
      continuity.removeChangeListener(listener);
    }
    _observedContinuity = null;
    _continuityChangeListener = null;
  }

  void _handleContinuityChanged(String courseId) {
    if (courseId != widget.courseId || !mounted) return;
    final revision = ++_focusRevision;
    unawaited(_refreshFocusTheme(revision));
  }

  Future<void> _clearStaleFocusBestEffort() async {
    final continuity = widget.continuity;
    final courseId = widget.courseId;
    if (continuity != null && courseId != null) {
      try {
        await continuity.clearLastFocus(courseId);
      } on Object {
        // Stale continuity cleanup must never block the library view.
      }
    }
  }

  Future<void> _refreshFocusTheme(int revision) async {
    if (!mounted || revision != _focusRevision) return;
    final current = _resourceData;
    if (current == null || current.themes.isEmpty) return;
    final continuity = widget.continuity;
    final courseId = widget.courseId;
    if (continuity == null || courseId == null) return;

    String? currentAcademicYear;
    if (widget.weeklyPlanning != null) {
      try {
        final plan = await widget.weeklyPlanning!.buildPlan();
        if (!mounted || revision != _focusRevision) return;
        currentAcademicYear = plan.academicYear;
      } on Object {
        // Weekly planning context is optional.
      }
    }
    if (!mounted || revision != _focusRevision) return;

    String? targetThemeId;
    try {
      final stored = await continuity.getLastFocus(courseId);
      if (!mounted || revision != _focusRevision) return;
      if (stored != null) {
        if (currentAcademicYear != null &&
            stored.academicYear != currentAcademicYear) {
          await _clearStaleFocusBestEffort();
          return;
        }
        final storedThemeId = stored.themeId;
        if (storedThemeId != null &&
            current.themes.any((theme) => theme.id == storedThemeId)) {
          targetThemeId = storedThemeId;
        } else if (stored.blockId != null) {
          final blockThemeId = await widget.repository
              .getThemeIdForBlockIfAvailable(stored.blockId!);
          if (!mounted || revision != _focusRevision) return;
          if (blockThemeId != null &&
              current.themes.any((theme) => theme.id == blockThemeId)) {
            targetThemeId = blockThemeId;
          }
        }
      }
    } on Object {
      return;
    }

    if (targetThemeId == null || targetThemeId == current.package?.theme.id) {
      return;
    }

    try {
      final package = await widget.repository.getTeacherPackage(targetThemeId);
      if (!mounted || revision != _focusRevision) return;
      setState(() {
        _selectedThemeId = targetThemeId;
        _resourceData = _ResourceData(themes: current.themes, package: package);
      });
    } on Object {
      // Focus update is best-effort.
    }
  }

  Future<_ResourceData> _load() async {
    final focusRevision = _focusRevision;
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) {
      final data = const _ResourceData(themes: [], package: null);
      _resourceData = data;
      return data;
    }

    final explicitThemeId =
        _selectedThemeId ?? widget.navigationContext?.themeId;
    if (explicitThemeId != null &&
        themes.any((theme) => theme.id == explicitThemeId)) {
      final package = await widget.repository.getTeacherPackage(
        explicitThemeId,
      );
      final data = _ResourceData(themes: themes, package: package);
      _resourceData = data;
      return data;
    }

    final resolvedThemeId = await _resolveThemeId(themes);
    final selectedThemeId = resolvedThemeId ?? themes.first.id;
    final package = await widget.repository.getTeacherPackage(selectedThemeId);
    final data = _ResourceData(themes: themes, package: package);
    _resourceData = data;
    if (_focusRevision != focusRevision) {
      unawaited(_refreshFocusTheme(_focusRevision));
    }
    return data;
  }

  Future<_ResourceData> _mainLoad() =>
      RuntimePerformanceTrace.measure('ResourceLibraryPage.mainLoad', _load);

  Future<void> _refreshOnActivation() async {
    final revision = ++_focusRevision;
    final current = _resourceData;
    if (!mounted || current == null || current.themes.isEmpty) return;

    String? resolvedThemeId;
    try {
      resolvedThemeId = await _resolveThemeId(current.themes);
    } on Object {
      return;
    }
    if (!mounted || revision != _focusRevision) return;

    final targetThemeId = resolvedThemeId ?? current.themes.first.id;
    if (targetThemeId == current.package?.theme.id) {
      setState(() => _selectedCategory = null);
      return;
    }

    try {
      final package = await widget.repository.getTeacherPackage(targetThemeId);
      if (!mounted || revision != _focusRevision) return;
      setState(() {
        _selectedThemeId = targetThemeId;
        _selectedCategory = null;
        _resourceData = _ResourceData(themes: current.themes, package: package);
      });
    } on Object {
      // The current package remains usable when a lightweight refresh fails.
    }
  }

  Future<String?> _resolveThemeId(List<model.Theme> themes) async {
    AnnualWeeklyPlan? weeklyPlan;
    final weeklyPlanning = widget.weeklyPlanning;
    if (weeklyPlanning != null) {
      try {
        weeklyPlan = await weeklyPlanning.buildPlan();
      } on Object {
        // Current-week context is optional; the selected theme remains usable.
      }
    }

    final continuity = widget.continuity;
    final courseId = widget.courseId;
    if (continuity != null && courseId != null) {
      try {
        final stored = await continuity.getLastFocus(courseId);
        if (stored != null) {
          if (weeklyPlan != null &&
              stored.academicYear != weeklyPlan.academicYear) {
            unawaited(_clearStaleFocusBestEffort());
          } else {
            final storedThemeId = stored.themeId;
            if (storedThemeId != null &&
                themes.any((theme) => theme.id == storedThemeId)) {
              return storedThemeId;
            }

            final blockId = stored.blockId;
            if (blockId != null) {
              final blockThemeId = await widget.repository
                  .getThemeIdForBlockIfAvailable(blockId);
              if (blockThemeId != null &&
                  themes.any((theme) => theme.id == blockThemeId)) {
                return blockThemeId;
              }
            }
          }
        }
      } on Object {
        // Focus is a convenience hint; package access still falls back to the
        // first valid theme when it is unavailable.
      }
    }

    if (weeklyPlan != null) {
      final currentWeek = weeklyPlan.currentWeek;
      if (currentWeek != null) {
        for (final segment in currentWeek.segments) {
          final themeId = segment.theme.id;
          if (themes.any((theme) => theme.id == themeId)) {
            return themeId;
          }
        }
      }
    }
    return null;
  }

  Future<void> _selectTheme(String themeId) async {
    final current = _resourceData;
    if (current != null && current.package?.theme.id == themeId) return;
    _selectedThemeId = themeId;
    _selectedCategory = null;
    if (current != null && current.themes.any((t) => t.id == themeId)) {
      try {
        final package = await widget.repository.getTeacherPackage(themeId);
        if (!mounted) return;
        setState(() {
          _resourceData = _ResourceData(
            themes: current.themes,
            package: package,
          );
        });
        return;
      } on Object {
        // Fall back to full reload if needed.
      }
    }
    setState(() {
      _resourceData = null;
      _future = _mainLoad();
    });
  }

  void _reload() {
    setState(() {
      _resourceData = null;
      _future = _mainLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _resourceData;
    if (currentData != null) {
      return _buildContent(context, currentData, loading: false);
    }
    return FutureBuilder<_ResourceData>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        if (loading && !snapshot.hasData) {
          return const LoadingView(label: 'Kaynaklar hazırlanıyor…');
        }
        if (!snapshot.hasData) {
          return FeatureErrorView(
            message: 'Kaynaklar yüklenemedi.',
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        _resourceData = data;
        return _buildContent(context, data, loading: loading);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    _ResourceData data, {
    required bool loading,
  }) {
    if (!_initialUsefulContentReported) {
      _initialUsefulContentReported = true;
      RuntimePerformanceTrace.instant(
        'ResourceLibraryPage.initialUsefulContent',
      );
    }
    final package = data.package;
    if (package == null) {
      return const Center(child: Text('Gösterilebilir kaynak bulunmuyor.'));
    }

    if (widget.awaitingTextbook) {
      return AppPage(
        topTrailing: _topActions(data, loading),
        children: [
          if (loading) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpacing.lg),
          StatusPanel(
            icon: Icons.menu_book_outlined,
            title: 'Ders kitabı bekleniyor',
            message:
                '${package.theme.title} için öğretim programı hazır. Kitap yayımlandığında kitap, etkinlik, form ve değerlendirme araçları burada açılacak.',
          ),
          if (package.sourceReferences.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeading(
              'Şimdilik kullanabileceğin kaynak',
              subtitle: 'Seçili temanın program dayanakları',
              icon: Icons.verified_outlined,
            ),
            _ResourceSection(
              key: ValueKey('${package.theme.id}:sources'),
              icon: Icons.source_outlined,
              title: 'Program dayanakları',
              countLabel: '${package.sourceReferences.length} kaynak',
              initiallyExpanded: true,
              child: _Sources(sources: package.sourceReferences),
            ),
          ],
        ],
      );
    }

    final hasBook = package.textbookSections.isNotEmpty;
    _openNavigationFormIfNeeded(package.forms);
    final hasActivities = package.activities.isNotEmpty;
    final hasForms = package.forms.isNotEmpty;
    final hasAssessment =
        package.assessmentArtifacts.isNotEmpty ||
        package.assessmentTaskBindings.isNotEmpty;
    final hasSources = package.sourceReferences.isNotEmpty;
    final primary = _primaryResource(
      hasBook: hasBook,
      hasActivities: hasActivities,
      hasForms: hasForms,
      hasAssessment: hasAssessment,
      hasSources: hasSources,
    );

    return AppPage(
      topTrailing: _topActions(data, loading),
      children: [
        if (loading) ...[
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: AppSpacing.lg),
        const SectionHeading(
          'Kaynaklar',
          subtitle: 'Seçili temanın kaynakları',
          icon: Icons.folder_open_outlined,
        ),
        if (hasBook)
          _ResourceSection(
            key: ValueKey('${package.theme.id}:book:$_sectionRevision'),
            icon: Icons.menu_book_outlined,
            title: 'Ders kitabı',
            countLabel: '${package.textbookSections.length} bölüm',
            initiallyExpanded:
                primary == _ResourceKind.book ||
                _selectedCategory == ResourceCategory.textbook,
            child: _Textbook(sections: package.textbookSections),
          ),
        if (hasBook &&
            (hasActivities || hasForms || hasAssessment || hasSources))
          const SizedBox(height: AppSpacing.sm),
        if (hasActivities)
          _ResourceSection(
            key: ValueKey('${package.theme.id}:activities:$_sectionRevision'),
            icon: Icons.task_alt_outlined,
            title: 'Etkinlikler',
            countLabel: '${package.activities.length} etkinlik',
            initiallyExpanded:
                primary == _ResourceKind.activities ||
                _selectedCategory == ResourceCategory.activities,
            child: _Activities(activities: package.activities),
          ),
        if (hasActivities && (hasForms || hasAssessment || hasSources))
          const SizedBox(height: AppSpacing.sm),
        if (hasForms)
          _ResourceSection(
            key: ValueKey('${package.theme.id}:forms:$_sectionRevision'),
            icon: Icons.assignment_outlined,
            title: 'Formlar',
            countLabel: '${package.forms.length} form',
            initiallyExpanded:
                primary == _ResourceKind.forms ||
                _selectedCategory == ResourceCategory.forms,
            child: _Forms(forms: package.forms, repository: widget.repository),
          ),
        if (hasForms && (hasAssessment || hasSources))
          const SizedBox(height: AppSpacing.sm),
        if (hasAssessment)
          _ResourceSection(
            key: ValueKey('${package.theme.id}:assessment:$_sectionRevision'),
            icon: Icons.fact_check_outlined,
            title: 'Değerlendirme',
            countLabel:
                '${package.assessmentArtifacts.length + package.assessmentTaskBindings.length} araç/görev',
            initiallyExpanded:
                primary == _ResourceKind.assessment ||
                _selectedCategory == ResourceCategory.assessment,
            child: _Assessments(package: package),
          ),
        if (hasAssessment && hasSources) const SizedBox(height: AppSpacing.sm),
        if (hasSources)
          _ResourceSection(
            key: ValueKey('${package.theme.id}:sources:$_sectionRevision'),
            icon: Icons.source_outlined,
            title: 'Kaynak dayanakları',
            countLabel: '${package.sourceReferences.length} kaynak',
            initiallyExpanded:
                primary == _ResourceKind.sources ||
                _selectedCategory == ResourceCategory.sources,
            child: _Sources(sources: package.sourceReferences),
          ),
      ],
    );
  }

  void _openNavigationFormIfNeeded(List<model.Form> forms) {
    final navigation = widget.navigationContext;
    final requestedId =
        navigation?.formId ??
        (navigation?.category == ResourceCategory.forms
            ? navigation?.resourceId
            : null);
    if (requestedId == null || requestedId == _openedNavigationFormId) return;
    final matching = forms.where((form) => form.id == requestedId);
    if (matching.isEmpty) return;
    _openedNavigationFormId = requestedId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => FormViewerPage(
            form: matching.first,
            repository: widget.repository,
          ),
        ),
      );
    });
  }

  Widget _topActions(_ResourceData data, bool loading) => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    children: [
      if (widget.topTrailing != null) widget.topTrailing!,
      SizedBox(
        width: 220,
        child: _ThemeSelector(
          themes: data.themes,
          selectedThemeId: data.package!.theme.id,
          enabled: !loading,
          onChanged: _selectTheme,
        ),
      ),
    ],
  );
}

enum _ResourceKind { book, activities, forms, assessment, sources }

_ResourceKind? _primaryResource({
  required bool hasBook,
  required bool hasActivities,
  required bool hasForms,
  required bool hasAssessment,
  required bool hasSources,
}) {
  if (hasBook) return _ResourceKind.book;
  if (hasActivities) return _ResourceKind.activities;
  if (hasForms) return _ResourceKind.forms;
  if (hasAssessment) return _ResourceKind.assessment;
  if (hasSources) return _ResourceKind.sources;
  return null;
}

class _ResourceData {
  const _ResourceData({required this.themes, required this.package});

  final List<model.Theme> themes;
  final model.TeacherPackage? package;
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.themes,
    required this.selectedThemeId,
    required this.enabled,
    required this.onChanged,
  });

  final List<model.Theme> themes;
  final String selectedThemeId;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: selectedThemeId,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Tema değiştir',
      prefixIcon: Icon(Icons.layers_outlined),
    ),
    items: [
      for (final theme in themes)
        DropdownMenuItem(
          value: theme.id,
          child: Text(theme.title, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: !enabled
        ? null
        : (value) {
            if (value != null && value != selectedThemeId) onChanged(value);
          },
  );
}

class _ResourceSection extends StatelessWidget {
  const _ResourceSection({
    super.key,
    required this.icon,
    required this.title,
    required this.countLabel,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String countLabel;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(countLabel),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [child],
    ),
  );
}

class _Textbook extends StatelessWidget {
  const _Textbook({required this.sections});

  final List<model.TextbookSection> sections;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < sections.length; i++) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(sections[i].title),
          subtitle: Text(
            [
              if (sections[i].genre?.isNotEmpty == true) sections[i].genre!,
              if (sections[i].printedPageRange?.isNotEmpty == true)
                's. ${sections[i].printedPageRange}',
            ].join(' · '),
          ),
        ),
        if (i != sections.length - 1) const Divider(height: 1),
      ],
    ],
  );
}

class _Activities extends StatelessWidget {
  const _Activities({required this.activities});

  final List<model.Activity> activities;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < activities.length; i++) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(activities[i].title),
          subtitle: activities[i].printedPage?.isNotEmpty == true
              ? Text('s. ${activities[i].printedPage}')
              : null,
        ),
        if (i != activities.length - 1) const Divider(height: 1),
      ],
    ],
  );
}

class _Forms extends StatelessWidget {
  const _Forms({required this.forms, required this.repository});

  final List<model.Form> forms;
  final CourseKnowledgeRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < forms.length; i++) ...[
        Card.outlined(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forms[i].title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_friendlyFormType(forms[i])),
                  ],
                );
                final action = FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => FormViewerPage(
                        form: forms[i],
                        repository: repository,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Formu aç'),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: action),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 16),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ],
  );
}

String _friendlyFormType(model.Form form) {
  final type = form.assessmentType ?? form.structuralType ?? '';
  return switch (type) {
    'self_assessment_form' => 'Öz değerlendirme',
    'peer_assessment_form' => 'Akran değerlendirmesi',
    'teacher_evaluation_form' => 'Öğretmen değerlendirmesi',
    'checklist' => 'Kontrol listesi',
    'observation_form' => 'Gözlem formu',
    'learning_journal' => 'Öğrenme günlüğü',
    'assessment_criteria_table' => 'Değerlendirme ölçütleri',
    'test_question_set' => 'Ölçme ve değerlendirme',
    'exit_ticket' => 'Çıkış kartı',
    'reflection_prompt' => 'Yansıtma formu',
    'dereceli_puanlama_anahtari_link' => 'Dereceli puanlama anahtarı',
    _ => 'Değerlendirme formu',
  };
}

class _Assessments extends StatelessWidget {
  const _Assessments({required this.package});

  final model.TeacherPackage package;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final artifact in package.assessmentArtifacts)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(artifact.title),
          subtitle: artifact.skillDomain?.isNotEmpty == true
              ? Text(artifact.skillDomain!)
              : null,
        ),
      for (final binding in package.assessmentTaskBindings)
        if (binding.taskTitle?.isNotEmpty == true)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.checklist_outlined),
            title: Text(binding.taskTitle!),
            subtitle: binding.targetedOutcomes.isEmpty
                ? null
                : Text(binding.targetedOutcomes.join(', ')),
          ),
    ],
  );
}

class _Sources extends StatelessWidget {
  const _Sources({required this.sources});

  final List<model.SourceReference> sources;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < sources.length; i++) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_outlined),
          title: Text(sources[i].title),
          subtitle: sources[i].locator?.isNotEmpty == true
              ? Text(sources[i].locator!)
              : null,
        ),
        if (i != sources.length - 1) const Divider(height: 1),
      ],
    ],
  );
}
