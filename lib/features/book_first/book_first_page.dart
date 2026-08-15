import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

class BookFirstPage extends StatefulWidget {
  const BookFirstPage({
    super.key,
    required this.repository,
    this.initialThemeId,
  });

  final CourseKnowledgeRepository repository;
  final String? initialThemeId;

  @override
  State<BookFirstPage> createState() => _BookFirstPageState();
}

class _BookFirstPageState extends State<BookFirstPage> {
  String? _selectedThemeId;
  late Future<_BookFirstData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BookFirstData> _load() async {
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) {
      return const _BookFirstData(
        themes: [],
        package: null,
        selectedThemeId: null,
      );
    }

    final requestedId = _selectedThemeId ?? widget.initialThemeId;
    final selectedThemeId = themes.any((theme) => theme.id == requestedId)
        ? requestedId!
        : themes.first.id;
    final package = await widget.repository.getTeacherPackage(selectedThemeId);

    return _BookFirstData(
      themes: themes,
      package: package,
      selectedThemeId: selectedThemeId,
    );
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kitap ve Materyal')),
    body: FutureBuilder<_BookFirstData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(label: 'Kitap ve materyal bilgileri hazırlanıyor…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Kitap ve materyal bilgileri yüklenemedi.',
            onRetry: _reload,
          );
        }

        final data = snapshot.data!;
        final package = data.package;
        if (data.themes.isEmpty || package == null || data.selectedThemeId == null) {
          return const Center(
            child: UnresolvedText(label: 'Gösterilebilir tema verisi bulunmuyor.'),
          );
        }

        return AppPage(
          children: [
            const PageHeader(
              eyebrow: 'KİTAP-ÖNCE',
              title: 'Bu tema için ne kullanacağım?',
              description:
                  'Önce ders kitabındaki karşılıkları görün; yalnız doğrulanmış ihtiyaç varsa ek destek kararlarını inceleyin.',
            ),
            _ThemeSelector(
              themes: data.themes,
              selectedThemeId: data.selectedThemeId!,
              onChanged: _selectTheme,
            ),
            const SizedBox(height: AppSpacing.md),
            _DecisionOverview(package: package),
            SectionHeading(
              'Ders kitabındaki karşılıklar',
              subtitle: package.textbookSections.isEmpty
                  ? 'Bu tema için kitap bölümü gösterilemiyor'
                  : '${package.textbookSections.length} kitap bölümü',
              icon: Icons.menu_book_outlined,
            ),
            _TextbookCoverage(package: package),
            SectionHeading(
              'Mevcut kitap ve araçlarla karşılananlar',
              subtitle: 'Doğrudan kullanılabilecek veya yeniden kullanılabilecek kayıtlar',
              icon: Icons.library_add_check_outlined,
            ),
            _ExistingResourceDecisions(decisions: package.resourceDecisions),
            SectionHeading(
              'Ek destek gereken alanlar',
              subtitle: 'Yalnız ek destek kararı bulunan kayıtlar',
              icon: Icons.add_task,
            ),
            _AdditionalSupportDecisions(decisions: package.resourceDecisions),
          ],
        );
      },
    ),
  );
}

class _BookFirstData {
  const _BookFirstData({
    required this.themes,
    required this.package,
    required this.selectedThemeId,
  });

  final List<model.Theme> themes;
  final model.TeacherPackage? package;
  final String? selectedThemeId;
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
    subtitle: 'Kitap ve materyal kararlarını tema bazında inceleyin',
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

class _DecisionOverview extends StatelessWidget {
  const _DecisionOverview({required this.package});

  final model.TeacherPackage package;

  @override
  Widget build(BuildContext context) {
    final decisions = package.resourceDecisions;
    final supportCount = decisions
        .where((decision) => decision.appCategory == 'ADDITIONAL_SUPPORT_REQUIRED')
        .length;
    final reviewCount = decisions
        .where((decision) => decision.teacherReviewRequired)
        .length;
    final knownExistingCount = decisions.where(_isExistingResourceDecision).length;

    return Column(
      children: [
        StatusPanel(
          icon: supportCount == 0 ? Icons.check_circle_outline : Icons.add_task,
          title: decisions.isEmpty
              ? 'Materyal kararı bulunmuyor'
              : supportCount == 0
                  ? 'Ek destek gerektiren karar görünmüyor'
                  : '$supportCount alanda ek destek gerekiyor',
          message: decisions.isEmpty
              ? 'Bu tema için gösterilebilir kitap veya ek materyal kararı bulunmuyor.'
              : supportCount == 0
                  ? 'Kayıtlı kararlar kitapta veya mevcut araçlarda karşılığı bulunan kullanımlara yönlendiriyor.'
                  : 'Önce mevcut kitap ve araçları kullanın; ek destek işaretli alanları ayrıca inceleyin.',
          tone: supportCount == 0 && decisions.isNotEmpty
              ? StatusTone.positive
              : supportCount > 0
                  ? StatusTone.attention
                  : StatusTone.neutral,
        ),
        if (decisions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  MetricChip(
                    icon: Icons.menu_book_outlined,
                    label: 'mevcut kaynak kararı',
                    value: '$knownExistingCount',
                  ),
                  MetricChip(
                    icon: Icons.add_task,
                    label: 'ek destek',
                    value: '$supportCount',
                  ),
                  if (reviewCount > 0)
                    MetricChip(
                      icon: Icons.visibility_outlined,
                      label: 'inceleme',
                      value: '$reviewCount',
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TextbookCoverage extends StatelessWidget {
  const _TextbookCoverage({required this.package});

  final model.TeacherPackage package;

  @override
  Widget build(BuildContext context) {
    if (package.textbookSections.isEmpty) {
      return const StatusPanel(
        icon: Icons.menu_book_outlined,
        title: 'Kitap bölümü bulunmuyor',
        message: 'Seçili tema için gösterilebilir kitap bölümü bulunmuyor.',
      );
    }

    return InfoCard(
      title: package.theme.title,
      subtitle: package.theme.pageRange == null
          ? 'Ders kitabı eşleştirmeleri'
          : 'Tema sayfaları: ${package.theme.pageRange}',
      icon: Icons.auto_stories_outlined,
      child: Column(
        children: [
          for (var index = 0; index < package.textbookSections.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.book_outlined),
              title: Text(package.textbookSections[index].title),
              subtitle: Text(
                [
                  if (package.textbookSections[index].genre != null)
                    package.textbookSections[index].genre!,
                  pageReference(
                    printed: package.textbookSections[index].printedPageRange,
                    pdf: package.textbookSections[index].pdfPageRange,
                  ),
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
            ),
            if (index != package.textbookSections.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _ExistingResourceDecisions extends StatelessWidget {
  const _ExistingResourceDecisions({required this.decisions});

  final List<model.ResourceDecision> decisions;

  @override
  Widget build(BuildContext context) {
    final visible = decisions.where(_isExistingResourceDecision).toList();
    if (visible.isEmpty) {
      return const StatusPanel(
        icon: Icons.info_outline,
        title: 'Mevcut kaynak kararı bulunmuyor',
        message: 'Bu tema için bu grupta gösterilecek karar bulunmuyor.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          ResourceDecisionCard(decision: visible[index]),
          if (index != visible.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _AdditionalSupportDecisions extends StatelessWidget {
  const _AdditionalSupportDecisions({required this.decisions});

  final List<model.ResourceDecision> decisions;

  @override
  Widget build(BuildContext context) {
    final visible = decisions
        .where((decision) => decision.appCategory == 'ADDITIONAL_SUPPORT_REQUIRED')
        .toList();
    if (visible.isEmpty) {
      return const StatusPanel(
        icon: Icons.check_circle_outline,
        title: 'Ek destek gerektiren karar yok',
        message: 'Bu tema için ek materyal desteği gerektiren bir karar görünmüyor.',
        tone: StatusTone.positive,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          ResourceDecisionCard(decision: visible[index]),
          if (index != visible.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

bool _isExistingResourceDecision(model.ResourceDecision decision) => switch (
      decision.appCategory,
    ) {
      'BOOK_SUFFICIENT' ||
      'USE_EXISTING_TEXTBOOK_ACTIVITY' ||
      'USE_EXISTING_FORM' ||
      'USE_ANNUAL_ASSESSMENT_ARTIFACT' => true,
      _ => false,
    };
