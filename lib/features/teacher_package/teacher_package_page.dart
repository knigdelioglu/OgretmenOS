import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

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

  @override
  Widget build(BuildContext context) => FutureBuilder<_PackageData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView();
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Öğretmen paketi yüklenemedi.',
          onRetry: () {
            setState(() {
              _future = _load();
            });
          },
        );
      }
      final data = snapshot.data!;
      final package = data.package;
      if (package == null) {
        return const Center(
          child: UnresolvedText(label: 'Tema paketi bulunmuyor.'),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DropdownButtonFormField<String>(
            initialValue: package.theme.id,
            decoration: const InputDecoration(
              labelText: 'Tek bir tema seçin',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final theme in data.themes)
                DropdownMenuItem<String>(
                  value: theme.id,
                  child: Text(theme.title),
                ),
            ],
            onChanged: (value) {
              if (value != null) _selectTheme(value);
            },
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.theme.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Seçili temanın doğrulanmış öğretmen paketi'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CountChip('Blok', package.blocks.length),
                      _CountChip('Çıktı', package.outcomes.length),
                      _CountChip('Etkinlik', package.activities.length),
                      _CountChip('Form', package.forms.length),
                      _CountChip(
                        'Değerlendirme',
                        package.assessmentArtifacts.length,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionHeading('Bloklar'),
          for (final block in package.blocks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${block.order}')),
              title: Text(block.title),
              subtitle: Text(
                block.skillDomain ??
                    'Beceri alanı için doğrulanmış değer bulunmuyor.',
              ),
            ),
          SectionHeading('Program çıktıları'),
          for (final outcome in package.outcomes)
            Card(
              child: ListTile(
                title: Text(outcome.code),
                subtitle: Text(outcome.officialText),
              ),
            ),
          SectionHeading('Ders kitabı'),
          for (final section in package.textbookSections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(section.title),
              subtitle: Text(
                [
                  if (section.printedPageRange != null)
                    'Basılı s. ${section.printedPageRange}',
                  if (section.pdfPageRange != null)
                    'PDF s. ${section.pdfPageRange}',
                ].join(' · '),
              ),
            ),
          SectionHeading('Etkinlikler'),
          for (final activity in package.activities)
            Card(
              child: ListTile(
                title: Text(activity.title),
                subtitle: Text(
                  [
                    if (activity.activityType != null) activity.activityType!,
                    pageReference(
                      printed: activity.printedPage,
                      pdf: activity.pdfPage,
                    ),
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
              ),
            ),
          SectionHeading('Formlar'),
          for (final form in package.forms)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(form.title),
              subtitle: Text(
                pageReference(
                  printed: form.printedPage?.toString(),
                  pdf: form.pdfPage?.toString(),
                ),
              ),
            ),
          SectionHeading('Değerlendirme araçları'),
          for (final artifact in package.assessmentArtifacts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(artifact.title),
              subtitle: Text(artifact.skillDomain ?? 'Runtime kaydı'),
            ),
          SectionHeading('Materyal kararları'),
          for (final decision in package.resourceDecisions)
            ResourceDecisionCard(decision: decision),
          SectionHeading('Kaynak referansları'),
          for (final source in package.sourceReferences)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.source_outlined),
              title: Text(source.title),
              subtitle: Text(
                [
                  if (source.entityLocator != null) source.entityLocator!,
                  if (source.locator != null) source.locator!,
                ].join(' · '),
              ),
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

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.check, size: 16),
    label: Text('$label: $count'),
  );
}
