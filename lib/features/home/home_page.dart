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

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_HomeData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView();
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return FeatureErrorView(
          message: 'Ana sayfa verileri yüklenemedi.',
          onRetry: _refresh,
        );
      }
      final data = snapshot.data!;
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              data.course.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${data.course.courseId} · ${data.course.grade}. sınıf',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Doğrulanmış runtime paketi ${data.course.schemaVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _SelectedPositionCard(
              data: data,
              onOpenAnnualPlan: widget.onOpenAnnualPlan,
              onOpenBlock: data.selectedBlock == null
                  ? null
                  : () => _openBlock(data.selectedBlock!.block.id),
              onOpenBookFirst: data.selectedBlock == null
                  ? null
                  : () => _openBookFirst(data.selectedBlock!.theme.id),
            ),
            const SectionHeading('Ders Yürütme'),
            const Text(
              'Temayı seçin; doğrulanmış blok, kitap ve etkinlik ilişkilerini inceleyin.',
            ),
            const SizedBox(height: 8),
            if (data.themes.isEmpty)
              const InfoCard(
                title: 'Tema verisi',
                child: UnresolvedText(
                  label: 'Runtime paketinde doğrulanmış tema bulunmuyor.',
                ),
              )
            else
              for (final theme in data.themes)
                _ThemeCard(
                  theme: theme,
                  blockCount: data.sequence
                      .where((entry) => entry.theme.id == theme.id)
                      .length,
                  onTap: () => _openTheme(theme),
                ),
            const SectionHeading('Hızlı erişim'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onOpenAnnualPlan,
                  icon: const Icon(Icons.view_timeline_outlined),
                  label: const Text('Yıllık plan'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenTeacherPackage,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Öğretmen paketi'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openBookFirst(null),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Kitap-Önce'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  void _openTheme(model.Theme theme) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ThemeBlocksPage(repository: widget.repository, theme: theme),
      ),
    );
  }

  void _openBlock(String blockId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlockDetailPage(repository: widget.repository, blockId: blockId),
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

class _SelectedPositionCard extends StatelessWidget {
  const _SelectedPositionCard({
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
    final selectedBlock = data.selectedBlock;
    final sequenceEntry = selectedBlock == null
        ? null
        : data.sequence.where(
            (entry) => entry.block.id == selectedBlock.block.id,
          );
    final position = sequenceEntry == null || sequenceEntry.isEmpty
        ? null
        : sequenceEntry.first.sequencePosition;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seçili Plan Konumu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (selectedBlock == null) ...[
              Text(
                data.manualPosition == null
                    ? 'Henüz öğretmen tarafından bir plan konumu seçilmedi. Tarih tabanlı güncel blok gösterilmiyor.'
                    : 'Kaydedilmiş plan konumu bu runtime paketinde bulunamadı. Yıllık plandan yeni bir konum seçin.',
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onOpenAnnualPlan,
                child: const Text('Yıllık plandan konum seç'),
              ),
            ] else ...[
              Text(selectedBlock.theme.title),
              const SizedBox(height: 4),
              Text(
                selectedBlock.block.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (position != null) ...[
                const SizedBox(height: 4),
                Text('Plan sırası: $position / ${data.sequence.length}'),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: onOpenBlock,
                    child: const Text('Blok özetini aç'),
                  ),
                  OutlinedButton(
                    onPressed: onOpenBookFirst,
                    child: const Text('Kitap-Önce'),
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
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text('${theme.order}')),
      title: Text(theme.title),
      subtitle: Text(
        [
          '$blockCount blok',
          if (theme.pageRange != null) 'Kitap s. ${theme.pageRange}',
          if (theme.plannedHours != null)
            'Tema planı: ${theme.plannedHours} saat',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
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
  late Future<List<model.Block>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getBlocks(widget.theme.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.theme.title)),
    body: FutureBuilder<List<model.Block>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Tema blokları yüklenemedi.',
            onRetry: () => setState(
              () => _future = widget.repository.getBlocks(widget.theme.id),
            ),
          );
        }
        final blocks = snapshot.data!;
        if (blocks.isEmpty) {
          return const Center(
            child: UnresolvedText(
              label: 'Bu tema için blok verisi bulunmuyor.',
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: blocks.length,
          itemBuilder: (context, index) {
            final block = blocks[index];
            return Card(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlockDetailPage(
                      repository: widget.repository,
                      blockId: block.id,
                    ),
                  ),
                ),
                leading: CircleAvatar(child: Text('${block.order}')),
                title: Text(block.title),
                subtitle: Text(
                  block.skillDomain ??
                      'Beceri alanı için doğrulanmış değer bulunmuyor.',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    ),
  );
}
