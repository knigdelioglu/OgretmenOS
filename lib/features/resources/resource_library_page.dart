import 'package:flutter/material.dart';

import '../../data/preferences/continuity_repository.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../shared/feature_widgets.dart';

class ResourceLibraryPage extends StatefulWidget {
  const ResourceLibraryPage({
    super.key,
    required this.repository,
    required this.awaitingTextbook,
    this.continuity,
    this.outcomePlanning,
    this.courseId,
    this.active = true,
  });

  final CourseKnowledgeRepository repository;
  final bool awaitingTextbook;
  final ContinuityRepository? continuity;
  final OutcomePlanningService? outcomePlanning;
  final String? courseId;
  final bool active;

  @override
  State<ResourceLibraryPage> createState() => _ResourceLibraryPageState();
}

class _ResourceLibraryPageState extends State<ResourceLibraryPage> {
  late Future<_ResourceData> _future;
  String? _selectedThemeId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ResourceLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _selectedThemeId = null;
      _future = _load();
    }
  }

  Future<_ResourceData> _load() async {
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) return const _ResourceData(themes: [], package: null);

    final explicitThemeId = _selectedThemeId;
    if (explicitThemeId != null &&
        themes.any((theme) => theme.id == explicitThemeId)) {
      final package = await widget.repository.getTeacherPackage(
        explicitThemeId,
      );
      return _ResourceData(themes: themes, package: package);
    }

    final resolvedContext = await _resolveLessonContext(themes);
    final selectedThemeId = resolvedContext?.themeId ?? themes.first.id;
    final package = await widget.repository.getTeacherPackage(selectedThemeId);
    return _ResourceData(themes: themes, package: package);
  }

  Future<_LessonResourceContext?> _resolveLessonContext(
    List<model.Theme> themes,
  ) async {
    final continuity = widget.continuity;
    final outcomePlanning = widget.outcomePlanning;
    final courseId = widget.courseId;
    if (continuity == null || outcomePlanning == null || courseId == null) {
      return null;
    }

    try {
      final plan = await outcomePlanning.buildPlan();
      LastFocusState? stored;
      try {
        stored = await continuity.getLastFocus(courseId);
      } on Object {
        stored = null;
      }

      if (stored != null && stored.academicYear == plan.academicYear) {
        final item = _findTrackedOutcome(plan, stored.trackingKey);
        final theme = item?.primaryTheme;
        if (item != null &&
            theme != null &&
            themes.any((candidate) => candidate.id == theme.id)) {
          return _LessonResourceContext(themeId: theme.id);
        }
      }

      final currentWeek = plan.currentWeek;
      if (currentWeek == null) return null;

      for (final item in currentWeek.outcomes) {
        final theme = item.primaryTheme;
        if (theme != null &&
            themes.any((candidate) => candidate.id == theme.id)) {
          return _LessonResourceContext(themeId: theme.id);
        }
      }

      for (final segment in currentWeek.week.segments) {
        if (themes.any((candidate) => candidate.id == segment.theme.id)) {
          return _LessonResourceContext(themeId: segment.theme.id);
        }
      }
    } on Object {
      // Context is a convenience layer; resource access must still work.
    }
    return null;
  }

  TrackedOutcome? _findTrackedOutcome(AnnualOutcomePlan plan, String key) {
    for (final summary in plan.weeks) {
      for (final item in summary.outcomes) {
        if (item.trackingKey == key) return item;
      }
    }
    return null;
  }

  void _selectTheme(String themeId) {
    setState(() {
      _selectedThemeId = themeId;
      _future = _load();
    });
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ResourceData>(
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
      final package = data.package;
      if (package == null) {
        return const Center(child: Text('Gösterilebilir kaynak bulunmuyor.'));
      }

      if (widget.awaitingTextbook) {
        return AppPage(
          children: [
            _ThemeSelector(
              themes: data.themes,
              selectedThemeId: package.theme.id,
              enabled: !loading,
              onChanged: _selectTheme,
            ),
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
        children: [
          _ThemeSelector(
            themes: data.themes,
            selectedThemeId: package.theme.id,
            enabled: !loading,
            onChanged: _selectTheme,
          ),
          if (loading) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpacing.lg),
          const SectionHeading(
            'Kaynaklar',
            subtitle: 'İlk yararlı bölüm açık; diğerlerini gerektiğinde aç',
            icon: Icons.folder_open_outlined,
          ),
          if (hasBook)
            _ResourceSection(
              key: ValueKey('${package.theme.id}:book'),
              icon: Icons.menu_book_outlined,
              title: 'Ders kitabı',
              countLabel: '${package.textbookSections.length} bölüm',
              initiallyExpanded: primary == _ResourceKind.book,
              child: _Textbook(sections: package.textbookSections),
            ),
          if (hasBook &&
              (hasActivities || hasForms || hasAssessment || hasSources))
            const SizedBox(height: AppSpacing.sm),
          if (hasActivities)
            _ResourceSection(
              key: ValueKey('${package.theme.id}:activities'),
              icon: Icons.task_alt_outlined,
              title: 'Etkinlikler',
              countLabel: '${package.activities.length} etkinlik',
              initiallyExpanded: primary == _ResourceKind.activities,
              child: _Activities(activities: package.activities),
            ),
          if (hasActivities && (hasForms || hasAssessment || hasSources))
            const SizedBox(height: AppSpacing.sm),
          if (hasForms)
            _ResourceSection(
              key: ValueKey('${package.theme.id}:forms'),
              icon: Icons.assignment_outlined,
              title: 'Formlar',
              countLabel: '${package.forms.length} form',
              initiallyExpanded: primary == _ResourceKind.forms,
              child: _Forms(forms: package.forms),
            ),
          if (hasForms && (hasAssessment || hasSources))
            const SizedBox(height: AppSpacing.sm),
          if (hasAssessment)
            _ResourceSection(
              key: ValueKey('${package.theme.id}:assessment'),
              icon: Icons.fact_check_outlined,
              title: 'Değerlendirme',
              countLabel:
                  '${package.assessmentArtifacts.length + package.assessmentTaskBindings.length} araç/görev',
              initiallyExpanded: primary == _ResourceKind.assessment,
              child: _Assessments(package: package),
            ),
          if (hasAssessment && hasSources)
            const SizedBox(height: AppSpacing.sm),
          if (hasSources)
            _ResourceSection(
              key: ValueKey('${package.theme.id}:sources'),
              icon: Icons.source_outlined,
              title: 'Kaynak dayanakları',
              countLabel: '${package.sourceReferences.length} kaynak',
              initiallyExpanded: primary == _ResourceKind.sources,
              child: _Sources(sources: package.sourceReferences),
            ),
        ],
      );
    },
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

class _LessonResourceContext {
  const _LessonResourceContext({required this.themeId});

  final String themeId;
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
  const _Forms({required this.forms});

  final List<model.Form> forms;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < forms.length; i++) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(forms[i].title),
          subtitle: forms[i].assessmentType?.isNotEmpty == true
              ? Text(forms[i].assessmentType!)
              : null,
        ),
        if (i != forms.length - 1) const Divider(height: 1),
      ],
    ],
  );
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
