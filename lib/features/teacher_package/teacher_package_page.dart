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
        _selectedThemeId != null &&
            themes.any((theme) => theme.id == _selectedThemeId)
        ? _selectedThemeId!
        : themes.first.id;
    final package = await widget.repository.getTeacherPackage(selectedThemeId);
    return _PackageData(themes: themes, package: package);
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
  Widget build(BuildContext context) => FutureBuilder<_PackageData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView(label: 'Öğretmen paketi hazırlanıyor…');
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Öğretmen paketi yüklenemedi.',
          onRetry: _reload,
        );
      }

      final data = snapshot.data!;
      final package = data.package;
      if (package == null) {
        return const Center(
          child: UnresolvedText(label: 'Gösterilebilir tema paketi bulunmuyor.'),
        );
      }

      return AppPage(
        children: [
          const PageHeader(
            eyebrow: 'HAZIRLIK DOSYASI',
            title: 'Öğretmen Paketi',
            description:
                'Bir temanın program, kitap, etkinlik, değerlendirme ve materyal bilgilerini tek yerde inceleyin.',
          ),
          _ThemeSelector(
            themes: data.themes,
            selectedThemeId: package.theme.id,
            onChanged: _selectTheme,
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageHero(package: package),
          const SectionHeading(
            'Tema dosyası',
            subtitle: 'İhtiyacınız olan bölümü açın; diğer ayrıntılar kapalı kalır',
            icon: Icons.folder_open_outlined,
          ),
          _PackageSection(
            icon: Icons.view_timeline_outlined,
            title: 'Öğretim blokları',
            summary: '${package.blocks.length} blok',
            initiallyExpanded: true,
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
            child: _OutcomesContent(outcomes: package.outcomes),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.menu_book_outlined,
            title: 'Ders kitabı',
            summary: '${package.textbookSections.length} bölüm',
            child: _TextbookContent(sections: package.textbookSections),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.task_alt_outlined,
            title: 'Etkinlikler',
            summary: '${package.activities.length} etkinlik',
            child: _ActivitiesContent(activities: package.activities),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.assignment_outlined,
            title: 'Formlar ve araçlar',
            summary: '${package.forms.length} form',
            child: _FormsContent(forms: package.forms),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.fact_check_outlined,
            title: 'Değerlendirme',
            summary:
                '${package.assessmentArtifacts.length} araç · ${package.assessmentTaskBindings.length} görev',
            child: _AssessmentContent(package: package),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.library_add_check_outlined,
            title: 'Materyal durumu',
            summary: '${package.resourceDecisions.length} karar',
            child: _MaterialsContent(decisions: package.resourceDecisions),
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageSection(
            icon: Icons.source_outlined,
            title: 'Kaynaklar',
            summary: '${package.sourceReferences.length} dayanak',
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
  Widget build(BuildContext context) => InfoCard(
    title: 'Tema seçimi',
    subtitle: 'Hazırlık dosyasını tema bazında görüntüleyin',
    icon: Icons.layers_outlined,
    child: DropdownButtonFormField<String>(
      initialValue: selectedThemeId,
      decoration: const InputDecoration(labelText: 'Tema'),
      items: [
        for (final theme in themes)
          DropdownMenuItem<String>(
            value: theme.id,
            child: Text(theme.title),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
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

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              package.theme.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (package.theme.pageRange != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ders kitabı: s. ${package.theme.pageRange}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
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
                  icon: Icons.flag_outlined,
                  label: 'çıktı',
                  value: '${package.outcomes.length}',
                ),
                MetricChip(
                  icon: Icons.task_alt_outlined,
                  label: 'etkinlik',
                  value: '${package.activities.length}',
                ),
                MetricChip(
                  icon: Icons.assignment_outlined,
                  label: 'form',
                  value: '${package.forms.length}',
                ),
                MetricChip(
                  icon: Icons.fact_check_outlined,
                  label: 'değerlendirme',
                  value: '${package.assessmentArtifacts.length}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  supportCount == 0 ? Icons.check_circle_outline : Icons.add_task,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    supportCount == 0
                        ? 'Ek destek gerektiren materyal alanı görünmüyor.'
                        : '$supportCount alanda ek destek gerekiyor.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageSection extends StatelessWidget {
  const _PackageSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(summary),
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(forms[index].title),
            subtitle: Text(
              [
                if (forms[index].evaluator != null)
                  'Değerlendiren: ${forms[index].evaluator}',
                pageReference(
                  printed: forms[index].printedPage?.toString(),
                  pdf: forms[index].pdfPage?.toString(),
                ),
              ].where((value) => value.isNotEmpty).join(' · '),
            ),
          ),
          if (index != forms.length - 1) const Divider(),
        ],
      ],
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
        for (var index = 0;
            index < package.assessmentTaskBindings.length;
            index++) ...[
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: Text(sources[index].title),
            subtitle: teacherSourceSubtitle(sources[index]) == null
                ? null
                : Text(teacherSourceSubtitle(sources[index])!),
          ),
          if (index != sources.length - 1) const Divider(),
        ],
      ],
    );
  }
}
