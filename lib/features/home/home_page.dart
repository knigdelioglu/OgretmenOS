import 'package:flutter/material.dart';

import '../../data/preferences/user_preferences_repository.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../block/block_detail_page.dart';
import '../book_first/book_first_page.dart';
import '../shared/feature_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.preferences,
    required this.onOpenAnnualPlan,
    required this.onOpenTeacherPackage,
  });

  final CourseKnowledgeRepository repository;
  final UserPreferencesRepository preferences;
  final VoidCallback onOpenAnnualPlan;
  final VoidCallback onOpenTeacherPackage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final course = await widget.repository.getCourse();
    final themes = await widget.repository.getThemes();
    final sequence = await widget.repository.getAnnualSequence();
    final manualPosition = await widget.preferences.getManualPositionOverride();

    model.BlockDetail? selectedBlock;
    if (manualPosition != null &&
        sequence.any((entry) => entry.block.id == manualPosition)) {
      selectedBlock = await widget.repository.getBlock(manualPosition);
    }

    return _HomeData(
      course: course,
      themes: themes,
      sequence: sequence,
      manualPosition: manualPosition,
      selectedBlock: selectedBlock,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_HomeData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView(label: 'Ders planınız hazırlanıyor…');
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Ders planı yüklenemedi.',
          onRetry: _refresh,
        );
      }

      final data = snapshot.data!;
      return AppPage(
        onRefresh: _refresh,
        children: [
          PageHeader(
            eyebrow: '${data.course.grade}. sınıf',
            title: data.course.title,
            description:
                'Kaldığınız plan konumundan derse devam edin veya temaları inceleyin.',
          ),
          _SelectedBlockBrief(
            data: data,
            onOpenAnnualPlan: widget.onOpenAnnualPlan,
            onOpenBlock: data.selectedBlock == null
                ? null
                : () => _openBlock(data.selectedBlock!.block.id),
            onOpenBookFirst: data.selectedBlock == null
                ? null
                : () => _openBookFirst(data.selectedBlock!.theme.id),
          ),
          const SectionHeading(
            'Temalar',
            subtitle: 'Program sırasındaki temaları ve temel ders kitabı kapsamını görün.',
            icon: Icons.layers_outlined,
          ),
          if (data.themes.isEmpty)
            const StatusPanel(
              icon: Icons.info_outline,
              title: 'Tema bilgisi bulunamadı',
              message: 'Ders içeriği şu anda görüntülenemiyor.',
            )
          else
            for (final theme in data.themes) ...[
              _ThemeCard(
                theme: theme,
                blockCount: data.sequence
                    .where((entry) => entry.theme.id == theme.id)
                    .length,
                onTap: () => _openTheme(theme),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          const SectionHeading(
            'Hızlı erişim',
            subtitle: 'Planın tamamına, kaynak kararlarına veya tema paketlerine geçin.',
            icon: Icons.grid_view_outlined,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onOpenAnnualPlan,
                icon: const Icon(Icons.view_timeline_outlined),
                label: const Text('Yıllık plan'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openBookFirst(null),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Kitap ve materyal'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenTeacherPackage,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Öğretmen paketi'),
              ),
            ],
          ),
        ],
      );
    },
  );

  void _openTheme(model.Theme theme) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThemeBlocksPage(
          repository: widget.repository,
          theme: theme,
        ),
      ),
    );
  }

  void _openBlock(String blockId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlockDetailPage(
          repository: widget.repository,
          blockId: blockId,
        ),
      ),
    );
  }

  void _openBookFirst(String? themeId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookFirstPage(
          repository: widget.repository,
          initialThemeId: themeId,
        ),
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.course,
    required this.themes,
    required this.sequence,
    required this.manualPosition,
    required this.selectedBlock,
  });

  final model.Course course;
  final List<model.Theme> themes;
  final List<model.TimelineEntry> sequence;
  final String? manualPosition;
  final model.BlockDetail? selectedBlock;
}

class _SelectedBlockBrief extends StatelessWidget {
  const _SelectedBlockBrief({
    required this.data,
    required this.onOpenAnnualPlan,
    required this.onOpenBlock,
    required this.onOpenBookFirst,
  });

  final _HomeData data;
  final VoidCallback onOpenAnnualPlan;
  final VoidCallback? onOpenBlock;
  final VoidCallback? onOpenBookFirst;

  @override
  Widget build(BuildContext context) {
    final detail = data.selectedBlock;
    if (detail == null) {
      return StatusPanel(
        icon: Icons.bookmark_add_outlined,
        title: 'Kaldığınız yeri seçin',
        message: data.manualPosition == null
            ? 'Yıllık planda bulunduğunuz bloğu bir kez işaretleyin. Uygulama doğrulanmış takvim bilgisi olmadan sizin yerinize tarih tabanlı bir ders seçmez.'
            : 'Daha önce seçilen plan konumu güncel ders içeriğinde bulunamadı. Yıllık plandan yeni bir konum seçin.',
        action: FilledButton.icon(
          onPressed: onOpenAnnualPlan,
          icon: const Icon(Icons.view_timeline_outlined),
          label: const Text('Yıllık plandan seç'),
        ),
      );
    }

    final matchingEntries = data.sequence.where(
      (entry) => entry.block.id == detail.block.id,
    );
    final position = matchingEntries.isEmpty
        ? null
        : matchingEntries.first.sequencePosition;
    final bookReference = _bookReference(detail.textbookSections);
    final outcomeCodes = detail.outcomes
        .take(5)
        .map((outcome) => outcome.code)
        .join(' · ');
    final resourceCounts = _resourceCategoryCounts(detail.resourceDecisions);

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.theme.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        detail.block.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (position != null)
                  Chip(label: Text('$position / ${data.sequence.length}')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (bookReference != null) ...[
              LabeledValue(
                icon: Icons.menu_book_outlined,
                label: 'Ders kitabı',
                value: bookReference,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (outcomeCodes.isNotEmpty) ...[
              LabeledValue(
                icon: Icons.flag_outlined,
                label: 'Çıktılar',
                value: outcomeCodes,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MetricChip(
                  icon: Icons.flag_outlined,
                  value: '${detail.outcomes.length}',
                  label: 'çıktı',
                ),
                MetricChip(
                  icon: Icons.auto_stories_outlined,
                  value: '${detail.activities.length}',
                  label: 'etkinlik',
                ),
                MetricChip(
                  icon: Icons.assignment_outlined,
                  value: '${detail.forms.length}',
                  label: 'form',
                ),
                MetricChip(
                  icon: Icons.fact_check_outlined,
                  value: '${detail.assessmentArtifacts.length}',
                  label: 'değerlendirme aracı',
                ),
              ],
            ),
            if (resourceCounts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Materyal durumu',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final entry in resourceCounts.entries)
                    Chip(
                      avatar: const Icon(Icons.check_circle_outline, size: 17),
                      label: Text(
                        entry.value == 1
                            ? _resourceCategoryLabel(entry.key)
                            : '${_resourceCategoryLabel(entry.key)} · ${entry.value}',
                      ),
                    ),
                ],
              ),
            ],
            if (detail.nextBlock != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Divider(color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.25)),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.arrow_forward_outlined, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Sonraki: ${detail.nextBlock!.title}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: onOpenBlock,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Dersi aç'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenBookFirst,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Kitap ve materyal'),
                ),
                TextButton.icon(
                  onPressed: onOpenAnnualPlan,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Konumu değiştir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.blockCount,
    required this.onTap,
  });

  final model.Theme theme;
  final int blockCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${theme.order}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      MetricChip(
                        icon: Icons.segment_outlined,
                        value: '$blockCount',
                        label: 'blok',
                      ),
                      if (theme.plannedHours != null)
                        MetricChip(
                          icon: Icons.schedule_outlined,
                          value: '${theme.plannedHours}',
                          label: 'saat',
                        ),
                    ],
                  ),
                  if (theme.pageRange != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Ders kitabı: s. ${theme.pageRange}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class ThemeBlocksPage extends StatefulWidget {
  const ThemeBlocksPage({
    super.key,
    required this.repository,
    required this.theme,
  });

  final CourseKnowledgeRepository repository;
  final model.Theme theme;

  @override
  State<ThemeBlocksPage> createState() => _ThemeBlocksPageState();
}

class _ThemeBlocksPageState extends State<ThemeBlocksPage> {
  late Future<_ThemeDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ThemeDetailData> _load() async {
    final package = await widget.repository.getTeacherPackage(widget.theme.id);
    final sequence = await widget.repository.getAnnualSequence();
    final entries = sequence
        .where((entry) => entry.theme.id == widget.theme.id)
        .toList(growable: false);
    return _ThemeDetailData(
      package: package,
      entries: entries,
      totalSequenceLength: sequence.length,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tema')), 
    body: FutureBuilder<_ThemeDetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(label: 'Tema hazırlanıyor…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Tema içeriği yüklenemedi.',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        final package = data.package;
        final theme = package.theme;
        final firstTimeline = data.entries.isEmpty ? null : data.entries.first;
        final resourceCounts = _resourceCategoryCounts(package.resourceDecisions);
        final outcomeCodes = package.outcomes
            .take(8)
            .map((outcome) => outcome.code)
            .join(' · ');
        final textbookPages = package.textbookSections
            .map((section) => section.printedPageRange)
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .take(4)
            .join(' · ');

        return AppPage(
          onRefresh: _refresh,
          children: [
            PageHeader(
              eyebrow: '${theme.order}. tema',
              title: theme.title,
              description:
                  'Program, ders kitabı, değerlendirme araçları ve öğretim bloklarını tek görünümde inceleyin.',
            ),
            InfoCard(
              title: 'Tema özeti',
              icon: Icons.dashboard_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      MetricChip(
                        icon: Icons.segment_outlined,
                        value: '${package.blocks.length}',
                        label: 'blok',
                      ),
                      MetricChip(
                        icon: Icons.flag_outlined,
                        value: '${package.outcomes.length}',
                        label: 'çıktı',
                      ),
                      MetricChip(
                        icon: Icons.auto_stories_outlined,
                        value: '${package.activities.length}',
                        label: 'etkinlik',
                      ),
                      MetricChip(
                        icon: Icons.assignment_outlined,
                        value: '${package.forms.length}',
                        label: 'form',
                      ),
                    ],
                  ),
                  if (firstTimeline?.officialTotalHours != null ||
                      theme.plannedHours != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    LabeledValue(
                      icon: Icons.schedule_outlined,
                      label: 'Program zamanı',
                      value:
                          '${firstTimeline?.officialTotalHours ?? theme.plannedHours} saat',
                    ),
                  ],
                  if (firstTimeline?.coreInstructionHours != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    LabeledValue(
                      label: 'Çekirdek öğretim',
                      value: '${firstTimeline!.coreInstructionHours} saat',
                    ),
                  ],
                  if (firstTimeline?.schoolBasedHours != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    LabeledValue(
                      label: 'Okul temelli',
                      value: '${firstTimeline!.schoolBasedHours} saat',
                    ),
                  ],
                ],
              ),
            ),
            const SectionHeading(
              'Program',
              subtitle: 'Bu temada ele alınan öğrenme çıktıları.',
              icon: Icons.flag_outlined,
            ),
            InfoCard(
              title: '${package.outcomes.length} öğrenme çıktısı',
              child: outcomeCodes.isEmpty
                  ? const UnresolvedText(
                      label: 'Bu tema için öğrenme çıktısı bilgisi bulunmuyor.',
                    )
                  : Text(outcomeCodes, style: const TextStyle(height: 1.45)),
            ),
            const SectionHeading(
              'Ders kitabı',
              subtitle: 'Tema ile ilişkilendirilmiş bölüm, etkinlik ve formlar.',
              icon: Icons.menu_book_outlined,
            ),
            InfoCard(
              title: '${package.textbookSections.length} kitap bölümü',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (textbookPages.isNotEmpty)
                    LabeledValue(label: 'Basılı sayfalar', value: textbookPages),
                  if (textbookPages.isNotEmpty)
                    const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      MetricChip(
                        icon: Icons.auto_stories_outlined,
                        value: '${package.activities.length}',
                        label: 'etkinlik',
                      ),
                      MetricChip(
                        icon: Icons.assignment_outlined,
                        value: '${package.forms.length}',
                        label: 'form',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeading(
              'Değerlendirme',
              subtitle: 'Tema için ilişkilendirilmiş ölçme ve değerlendirme araçları.',
              icon: Icons.fact_check_outlined,
            ),
            if (package.assessmentArtifacts.isEmpty)
              const StatusPanel(
                icon: Icons.info_outline,
                title: 'Değerlendirme aracı bulunamadı',
                message: 'Bu tema için ilişkilendirilmiş bir araç görünmüyor.',
              )
            else
              InfoCard(
                title: '${package.assessmentArtifacts.length} değerlendirme aracı',
                child: Column(
                  children: [
                    for (final artifact in package.assessmentArtifacts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fact_check_outlined),
                        title: Text(artifact.title),
                        subtitle: artifact.skillDomain == null
                            ? null
                            : Text(artifact.skillDomain!),
                      ),
                  ],
                ),
              ),
            const SectionHeading(
              'Materyal durumu',
              subtitle: 'Kitap ve mevcut araçların nasıl kullanılacağına ilişkin kararların özeti.',
              icon: Icons.inventory_2_outlined,
            ),
            InfoCard(
              title: '${package.resourceDecisions.length} kaynak kararı',
              trailing: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookFirstPage(
                      repository: widget.repository,
                      initialThemeId: theme.id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ayrıntı'),
              ),
              child: resourceCounts.isEmpty
                  ? const UnresolvedText(
                      label: 'Bu tema için kaynak kararı bulunmuyor.',
                    )
                  : Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final entry in resourceCounts.entries)
                          Chip(
                            label: Text(
                              '${_resourceCategoryLabel(entry.key)} · ${entry.value}',
                            ),
                          ),
                      ],
                    ),
            ),
            const SectionHeading(
              'Öğretim blokları',
              subtitle: 'Programdaki sıraya göre bu temanın ders akışı.',
              icon: Icons.view_timeline_outlined,
            ),
            if (data.entries.isEmpty)
              const StatusPanel(
                icon: Icons.info_outline,
                title: 'Blok sırası bulunamadı',
                message: 'Bu tema için öğretim sırası görüntülenemiyor.',
              )
            else
              for (final entry in data.entries) ...[
                _ThemeBlockCard(
                  entry: entry,
                  totalSequenceLength: data.totalSequenceLength,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlockDetailPage(
                        repository: widget.repository,
                        blockId: entry.block.id,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        );
      },
    ),
  );
}

class _ThemeDetailData {
  const _ThemeDetailData({
    required this.package,
    required this.entries,
    required this.totalSequenceLength,
  });

  final model.TeacherPackage package;
  final List<model.TimelineEntry> entries;
  final int totalSequenceLength;
}

class _ThemeBlockCard extends StatelessWidget {
  const _ThemeBlockCard({
    required this.entry,
    required this.totalSequenceLength,
    required this.onTap,
  });

  final model.TimelineEntry entry;
  final int totalSequenceLength;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                '${entry.sequencePosition}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.block.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      'Plan sırası ${entry.sequencePosition} / $totalSequenceLength',
                      if (entry.block.skillDomain != null)
                        entry.block.skillDomain!,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

String? _bookReference(List<model.TextbookSection> sections) {
  final pages = sections
      .map((section) => section.printedPageRange)
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .toSet()
      .take(3)
      .toList(growable: false);
  if (pages.isEmpty) return null;
  return 's. ${pages.join(' · ')}';
}

Map<String?, int> _resourceCategoryCounts(
  List<model.ResourceDecision> decisions,
) {
  final counts = <String?, int>{};
  for (final decision in decisions) {
    counts.update(decision.appCategory, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

String _resourceCategoryLabel(String? category) => switch (category) {
  'BOOK_SUFFICIENT' => 'Kitap karşılığı mevcut',
  'USE_EXISTING_TEXTBOOK_ACTIVITY' => 'Kitap etkinliği kullanılır',
  'USE_EXISTING_FORM' => 'Mevcut form kullanılır',
  'USE_ANNUAL_ASSESSMENT_ARTIFACT' => 'Değerlendirme aracı kullanılır',
  'ADDITIONAL_SUPPORT_REQUIRED' => 'Ek destek gerekli',
  _ => 'Kaynak kararı',
};
