import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';
import '../shared/teacher_presentation.dart';

class TeacherPackagePage extends StatefulWidget {
  const TeacherPackagePage({super.key, required this.repository});

  final CourseKnowledgeRepository repository;

  @override
  State<TeacherPackagePage> createState() => _TeacherPackagePageState();
}

class _TeacherPackagePageState extends State<TeacherPackagePage> {
  String? _selectedThemeId;
  late Future<_PackageData> _future;

  final GlobalKey _bookKey = GlobalKey();
  final GlobalKey _activityKey = GlobalKey();
  final GlobalKey _assessmentKey = GlobalKey();
  final GlobalKey _materialsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PackageData> _load() async {
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) {
      return const _PackageData(themes: [], package: null);
    }

    final selectedThemeId =
        _selectedThemeId != null && themes.any((theme) => theme.id == _selectedThemeId)
        ? _selectedThemeId!
        : themes.first.id;
    final package = await widget.repository.getTeacherPackage(selectedThemeId);
    return _PackageData(themes: themes, package: package);
  }

  void _selectTheme(String themeId) {
    if (_selectedThemeId == themeId) return;
    setState(() {
      _selectedThemeId = themeId;
      _future = _load();
    });
  }

  void _reload() {
    setState(() => _future = _load());
  }

  void _jumpTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_PackageData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
        return const LoadingView(label: 'Öğretmen paketi hazırlanıyor…');
      }
      if (snapshot.hasError && !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Öğretmen paketi yüklenemedi.',
          onRetry: _reload,
        );
      }

      final data = snapshot.data;
      final package = data?.package;
      if (data == null || package == null) {
        return const Center(
          child: UnresolvedText(label: 'Gösterilebilir tema paketi bulunmuyor.'),
        );
      }

      final switchingTheme = snapshot.connectionState != ConnectionState.done;
      final selectedThemeId = _selectedThemeId ?? package.theme.id;

      return AppPage(
        children: [
          const PageHeader(
            eyebrow: 'HAZIRLIK DOSYASI',
            title: 'Öğretmen Paketi',
            description:
                'Seçili temanın kitap, etkinlik, değerlendirme, materyal ve program bağlamına hızlı erişin.',
          ),
          _ThemeSelector(
            themes: data.themes,
            selectedThemeId: selectedThemeId,
            onChanged: _selectTheme,
          ),
          if (switchingTheme) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: AppSpacing.md),
          _PackageHero(package: package),
          const SizedBox(height: AppSpacing.md),
          _QuickSectionNav(
            onBook: () => _jumpTo(_bookKey),
            onActivities: () => _jumpTo(_activityKey),
            onAssessment: () => _jumpTo(_assessmentKey),
            onMaterials: () => _jumpTo(_materialsKey),
          ),
          const SectionHeading(
            'Tema dosyası',
            subtitle: 'İhtiyacınız olan bölümü açın; diğer ayrıntılar kapalı kalır',
            icon: Icons.folder_open_outlined,
          ),
          _PackageSection(
            icon: Icons.view_timeline_outlined,
            title: 'Öğretim blokları',
            summary: '${package.blocks.length} blok',
            isEmpty: package.blocks.isEmpty,
            child: _BlocksContent(
              blocks: package.blocks,
              repository: widget.repository,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.flag_outlined,
            title: 'Program çıktıları',
            summary: '${package.outcomes.length} çıktı',
            isEmpty: package.outcomes.isEmpty,
            child: _OutcomesContent(outcomes: package.outcomes),
          ),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: _bookKey,
            child: _PackageSection(
              icon: Icons.menu_book_outlined,
              title: 'Ders kitabı',
              summary: '${package.textbookSections.length} bölüm',
              initiallyExpanded: package.textbookSections.isNotEmpty,
              isEmpty: package.textbookSections.isEmpty,
              child: _TextbookContent(sections: package.textbookSections),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: _activityKey,
            child: _PackageSection(
              icon: Icons.task_alt_outlined,
              title: 'Etkinlikler',
              summary: '${package.activities.length} etkinlik',
              isEmpty: package.activities.isEmpty,
              child: _ActivitiesContent(activities: package.activities),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.assignment_outlined,
            title: 'Formlar ve araçlar',
            summary: '${package.forms.length} form',
            isEmpty: package.forms.isEmpty,
            child: _FormsContent(forms: package.forms),
          ),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: _assessmentKey,
            child: _PackageSection(
              icon: Icons.fact_check_outlined,
              title: 'Değerlendirme',
              summary:
                  '${package.assessmentArtifacts.length} araç · ${package.assessmentTaskBindings.length} görev',
              isEmpty: package.assessmentArtifacts.isEmpty &&
                  package.assessmentTaskBindings.isEmpty,
              child: _AssessmentContent(package: package),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: _materialsKey,
            child: _PackageSection(
              icon: Icons.library_add_check_outlined,
              title: 'Materyal durumu',
              summary: '${package.resourceDecisions.length} karar',
              isEmpty: package.resourceDecisions.isEmpty,
              child: _MaterialsContent(decisions: package.resourceDecisions),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.source_outlined,
            title: 'Kaynaklar ve dayanaklar',
            summary: '${package.sourceReferences.length} dayanak · teknik referans',
            isEmpty: package.sourceReferences.isEmpty,
            subdued: true,
            child: _SourcesContent(sources: package.sourceReferences),
          ),
        ],
      );
    },
  );
}

class _PackageData {
  const _PackageData({required this.themes, required this.package});

  final List<model.Theme> themes;
  final model.TeacherPackage? package;
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.themes,
    required this.selectedThemeId,
    required this.onChanged,
  });

  final List<model.Theme> themes;
  final String selectedThemeId;
  final void Function(String themeId) onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: DropdownButtonFormField<String>(
        key: ValueKey(selectedThemeId),
        initialValue: selectedThemeId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tema',
          prefixIcon: Icon(Icons.layers_outlined),
        ),
        items: [
          for (final theme in themes)
            DropdownMenuItem<String>(
              value: theme.id,
              child: Text(
                theme.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    ),
  );
}

class _PackageHero extends StatelessWidget {
  const _PackageHero({required this.package});

  final model.TeacherPackage package;

  @override
  Widget build(BuildContext context) {
    final supportCount = package.resourceDecisions
        .where((decision) => decision.appCategory == 'ADDITIONAL_SUPPORT_REQUIRED')
        .length;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              package.theme.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (package.theme.pageRange != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ders kitabı: s. ${package.theme.pageRange}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MetricChip(
                  icon: Icons.view_timeline_outlined,
                  label: 'blok',
                  value: '${package.blocks.length}',
                ),
                MetricChip(
                  icon: Icons.menu_book_outlined,
                  label: 'kitap bölümü',
                  value: '${package.textbookSections.length}',
                ),
                MetricChip(
                  icon: Icons.task_alt_outlined,
                  label: 'etkinlik',
                  value: '${package.activities.length}',
                ),
              ],
            ),
            if (supportCount > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.add_task, color: scheme.onPrimaryContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$supportCount alanda ek destek gerekiyor.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickSectionNav extends StatelessWidget {
  const _QuickSectionNav({
    required this.onBook,
    required this.onActivities,
    required this.onAssessment,
    required this.onMaterials,
  });

  final VoidCallback onBook;
  final VoidCallback onActivities;
  final VoidCallback onAssessment;
  final VoidCallback onMaterials;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      ActionChip(
        avatar: const Icon(Icons.menu_book_outlined, size: 18),
        label: const Text('Kitap'),
        onPressed: onBook,
      ),
      ActionChip(
        avatar: const Icon(Icons.task_alt_outlined, size: 18),
        label: const Text('Etkinlik'),
        onPressed: onActivities,
      ),
      ActionChip(
        avatar: const Icon(Icons.fact_check_outlined, size: 18),
        label: const Text('Değerlendirme'),
        onPressed: onAssessment,
      ),
      ActionChip(
        avatar: const Icon(Icons.library_add_check_outlined, size: 18),
        label: const Text('Materyal'),
        onPressed: onMaterials,
      ),
    ],
  );
}

class _PackageSection extends StatelessWidget {
  const _PackageSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
    this.initiallyExpanded = false,
    this.isEmpty = false,
    this.subdued = false,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget child;
  final bool initiallyExpanded;
  final bool isEmpty;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = ExpansionTile(
      enabled: !isEmpty,
      initiallyExpanded: initiallyExpanded && !isEmpty,
      leading: Icon(
        icon,
        color: subdued || isEmpty ? scheme.onSurfaceVariant : scheme.primary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(isEmpty ? '$summary · içerik yok' : summary),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [child],
    );

    return Opacity(
      opacity: isEmpty ? 0.55 : subdued ? 0.82 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: tile,
      ),
    );
  }
}

class _BlocksContent extends StatelessWidget {
  const _BlocksContent({required this.blocks, required this.repository});

  final List<model.Block> blocks;
  final CourseKnowledgeRepository repository;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const UnresolvedText(label: 'Bu tema için blok bulunmuyor.');
    }

    return Column(
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${blocks[index].order}')),
            title: Text(blocks[index].title),
            subtitle: blocks[index].skillDomain == null
                ? null
                : Text(blocks[index].skillDomain!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlockDetailPage(
                  repository: repository,
                  blockId: blocks[index].id,
                ),
              ),
            ),
          ),
          if (index != blocks.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _OutcomesContent extends StatelessWidget {
  const _OutcomesContent({required this.outcomes});

  final List<model.Outcome> outcomes;

  @override
  Widget build(BuildContext context) {
    if (outcomes.isEmpty) {
      return const UnresolvedText(label: 'Program çıktısı bulunmuyor.');
    }

    return Column(
      children: [
        for (var index = 0; index < outcomes.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(outcomes[index].code),
            subtitle: Text(outcomes[index].officialText),
          ),
          if (index != outcomes.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _TextbookContent extends StatelessWidget {
  const _TextbookContent({required this.sections});

  final List<model.TextbookSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const UnresolvedText(label: 'Kitap bölümü bulunmuyor.');
    }

    return Column(
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.book_outlined),
            title: Text(sections[index].title),
            subtitle: Text(
              [
                if (sections[index].genre != null) sections[index].genre!,
                pageReference(
                  printed: sections[index].printedPageRange,
                  pdf: sections[index].pdfPageRange,
                ),
              ].where((value) => value.isNotEmpty).join(' · '),
            ),
          ),
          if (index != sections.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _ActivitiesContent extends StatelessWidget {
  const _ActivitiesContent({required this.activities});

  final List<model.Activity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const UnresolvedText(label: 'Etkinlik bulunmuyor.');
    }

    return Column(
      children: [
        for (var index = 0; index < activities.length; index++) ...[
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
            title: Text(activities[index].title),
            subtitle: Text(
              pageReference(
                printed: activities[index].printedPage,
                pdf: activities[index].pdfPage,
              ),
            ),
            children: [
              if (activities[index].studentAction != null)
                LabeledValue(
                  label: 'Öğrenci ne yapacak?',
                  value: activities[index].studentAction!,
                  icon: Icons.person_outline,
                ),
              if (activities[index].expectedEvidence != null) ...[
                const SizedBox(height: AppSpacing.md),
                LabeledValue(
                  label: 'Beklenen ürün',
                  value: activities[index].expectedEvidence!,
                  icon: Icons.check_circle_outline,
                ),
              ],
            ],
          ),
          if (index != activities.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _FormsContent extends StatelessWidget {
  const _FormsContent({required this.forms});

  final List<model.Form> forms;

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
      return const UnresolvedText(label: 'Form veya araç bulunmuyor.');
    }

    return Column(
      children: [
        for (var index = 0; index < forms.length; index++) ...[
          _FormItem(form: forms[index]),
          if (index != forms.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _FormItem extends StatelessWidget {
  const _FormItem({required this.form});

  final model.Form form;

  @override
  Widget build(BuildContext context) {
    final evaluator = teacherEvaluatorLabel(form.evaluator);
    final pages = pageReference(
      printed: form.printedPage?.toString(),
      pdf: form.pdfPage?.toString(),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(form.title),
      subtitle: evaluator == null && pages.isEmpty
          ? null
          : Text(
              [
                ?evaluator,
                if (pages.isNotEmpty) pages,
              ].join(' · '),
            ),
    );
  }
}

class _AssessmentContent extends StatelessWidget {
  const _AssessmentContent({required this.package});

  final model.TeacherPackage package;

  @override
  Widget build(BuildContext context) {
    if (package.assessmentArtifacts.isEmpty &&
        package.assessmentTaskBindings.isEmpty) {
      return const UnresolvedText(label: 'Değerlendirme aracı bulunmuyor.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < package.assessmentArtifacts.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined),
            title: Text(package.assessmentArtifacts[index].title),
            subtitle: Text(
              [
                if (package.assessmentArtifacts[index].skillDomain != null)
                  package.assessmentArtifacts[index].skillDomain!,
                if (package.assessmentArtifacts[index].teacherReviewRequired)
                  'Öğretmen incelemesi gerekli',
              ].join(' · '),
            ),
          ),
          if (index != package.assessmentArtifacts.length - 1) const Divider(),
        ],
        if (package.assessmentArtifacts.isNotEmpty &&
            package.assessmentTaskBindings.isNotEmpty)
          const Divider(),
        for (var index = 0; index < package.assessmentTaskBindings.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.checklist_outlined),
            title: Text(
              package.assessmentTaskBindings[index].taskTitle ??
                  'Değerlendirme görevi',
            ),
            subtitle: package.assessmentTaskBindings[index].evidence == null
                ? null
                : Text(package.assessmentTaskBindings[index].evidence!),
          ),
          if (index != package.assessmentTaskBindings.length - 1)
            const Divider(),
        ],
      ],
    );
  }
}

class _MaterialsContent extends StatelessWidget {
  const _MaterialsContent({required this.decisions});

  final List<model.ResourceDecision> decisions;

  @override
  Widget build(BuildContext context) {
    if (decisions.isEmpty) {
      return const UnresolvedText(label: 'Materyal bilgisi bulunmuyor.');
    }

    return Column(
      children: [
        for (var index = 0; index < decisions.length; index++) ...[
          TeacherResourceDecisionCard(decision: decisions[index]),
          if (index != decisions.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SourcesContent extends StatelessWidget {
  const _SourcesContent({required this.sources});

  final List<model.SourceReference> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const UnresolvedText(label: 'Kaynak bilgisi bulunmuyor.');
    }

    return Column(
      children: [
        for (var index = 0; index < sources.length; index++) ...[
          _SourceItem(source: sources[index]),
          if (index != sources.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _SourceItem extends StatelessWidget {
  const _SourceItem({required this.source});

  final model.SourceReference source;

  @override
  Widget build(BuildContext context) {
    final subtitle = teacherSourceSubtitle(source);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.article_outlined),
      title: Text(source.title),
      subtitle: subtitle == null ? null : Text(subtitle),
    );
  }
}
