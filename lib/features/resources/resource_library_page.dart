import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

class ResourceLibraryPage extends StatefulWidget {
  const ResourceLibraryPage({
    super.key,
    required this.repository,
    required this.grade,
    required this.awaitingTextbook,
  });

  final CourseKnowledgeRepository repository;
  final int grade;
  final bool awaitingTextbook;

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

  Future<_ResourceData> _load() async {
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) return const _ResourceData(themes: [], package: null);
    final selected = _selectedThemeId != null &&
            themes.any((theme) => theme.id == _selectedThemeId)
        ? _selectedThemeId!
        : themes.first.id;
    return _ResourceData(
      themes: themes,
      package: await widget.repository.getTeacherPackage(selected),
    );
  }

  void _selectTheme(String themeId) {
    setState(() {
      _selectedThemeId = themeId;
      _future = _load();
    });
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_ResourceData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
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
            PageHeader(
              eyebrow: '${widget.grade}. sınıf',
              title: 'Kaynaklar',
              description:
                  'Öğretim programı hazır. Ders kitabı yayımlandığında kitap, etkinlik ve değerlendirme araçları burada açılacak.',
            ),
            const StatusPanel(
              icon: Icons.menu_book_outlined,
              title: 'Ders kitabı bekleniyor',
              message:
                  'Bu durum bir eksik veri hatası değil. Haftalık plan, yıllık plan ve kazanımlar kullanılabilir durumda.',
            ),
            if (package.sourceReferences.isNotEmpty) ...[
              const SectionHeading(
                'Program dayanakları',
                icon: Icons.verified_outlined,
              ),
              _Sources(sources: package.sourceReferences),
            ],
          ],
        );
      }

      final hasBook = package.textbookSections.isNotEmpty;
      final hasActivities = package.activities.isNotEmpty;
      final hasForms = package.forms.isNotEmpty;
      final hasAssessment = package.assessmentArtifacts.isNotEmpty ||
          package.assessmentTaskBindings.isNotEmpty;
      final hasSources = package.sourceReferences.isNotEmpty;

      return AppPage(
        children: [
          PageHeader(
            eyebrow: '${widget.grade}. sınıf',
            title: 'Kaynaklar',
            description:
                'Kitap, etkinlik, form ve değerlendirme araçlarını tema bazında açın.',
          ),
          DropdownButtonFormField<String>(
            initialValue: package.theme.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tema',
              prefixIcon: Icon(Icons.layers_outlined),
            ),
            items: [
              for (final theme in data.themes)
                DropdownMenuItem(
                  value: theme.id,
                  child: Text(theme.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value != null) _selectTheme(value);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasBook)
            _ResourceSection(
              icon: Icons.menu_book_outlined,
              title: 'Ders kitabı',
              countLabel: '${package.textbookSections.length} bölüm',
              child: _Textbook(sections: package.textbookSections),
            ),
          if (hasBook && (hasActivities || hasForms || hasAssessment || hasSources))
            const SizedBox(height: AppSpacing.sm),
          if (hasActivities)
            _ResourceSection(
              icon: Icons.task_alt_outlined,
              title: 'Etkinlikler',
              countLabel: '${package.activities.length} etkinlik',
              child: _Activities(activities: package.activities),
            ),
          if (hasActivities && (hasForms || hasAssessment || hasSources))
            const SizedBox(height: AppSpacing.sm),
          if (hasForms)
            _ResourceSection(
              icon: Icons.assignment_outlined,
              title: 'Formlar',
              countLabel: '${package.forms.length} form',
              child: _Forms(forms: package.forms),
            ),
          if (hasForms && (hasAssessment || hasSources))
            const SizedBox(height: AppSpacing.sm),
          if (hasAssessment)
            _ResourceSection(
              icon: Icons.fact_check_outlined,
              title: 'Değerlendirme',
              countLabel:
                  '${package.assessmentArtifacts.length + package.assessmentTaskBindings.length} araç/görev',
              child: _Assessments(package: package),
            ),
          if (hasAssessment && hasSources) const SizedBox(height: AppSpacing.sm),
          if (hasSources)
            _ResourceSection(
              icon: Icons.source_outlined,
              title: 'Kaynak dayanakları',
              countLabel: '${package.sourceReferences.length} kaynak',
              child: _Sources(sources: package.sourceReferences),
            ),
        ],
      );
    },
  );
}

class _ResourceData {
  const _ResourceData({required this.themes, required this.package});

  final List<model.Theme> themes;
  final model.TeacherPackage? package;
}

class _ResourceSection extends StatelessWidget {
  const _ResourceSection({
    required this.icon,
    required this.title,
    required this.countLabel,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String countLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
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
          leading: const Icon(Icons.rubric_outlined),
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
