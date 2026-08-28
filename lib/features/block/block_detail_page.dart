import 'package:flutter/material.dart';

import '../../app/resource_navigation.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../lesson_plan/lesson_plan_panels.dart';
import '../resources/resource_library_page.dart';
import '../shared/feature_widgets.dart';
import '../shared/teacher_presentation.dart';
import 'rubric_score_card.dart';

class BlockDetailPage extends StatefulWidget {
  const BlockDetailPage({
    super.key,
    required this.repository,
    required this.blockId,
    this.onOpenResources,
  });

  final CourseKnowledgeRepository repository;
  final String blockId;
  final ResourceNavigationCallback? onOpenResources;

  @override
  State<BlockDetailPage> createState() => _BlockDetailPageState();
}

class _BlockDetailPageState extends State<BlockDetailPage> {
  late Future<model.BlockDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getBlock(widget.blockId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.getBlock(widget.blockId);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ders Bloğu')),
    body: FutureBuilder<model.BlockDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(label: 'Ders bloğu hazırlanıyor…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Blok detayları yüklenemedi.',
            onRetry: _reload,
          );
        }
        return _BlockDetailContent(
          detail: snapshot.data!,
          repository: widget.repository,
          onOpenResources: widget.onOpenResources,
        );
      },
    ),
  );
}

class _BlockDetailContent extends StatelessWidget {
  const _BlockDetailContent({
    required this.detail,
    required this.repository,
    this.onOpenResources,
  });

  final model.BlockDetail detail;
  final CourseKnowledgeRepository repository;
  final ResourceNavigationCallback? onOpenResources;

  @override
  Widget build(BuildContext context) => AppPage(
    children: [
      _BlockSummary(detail: detail),
      const SectionHeading(
        'Derste lazım',
        subtitle: 'İlk bakışta hedef, kitap ve etkinlik bağlamı',
        icon: Icons.play_lesson_outlined,
      ),
      _LessonReadyBlockCard(detail: detail),
      _BlockResourcesPanel(
        detail: detail,
        repository: repository,
        onOpenResources: onOpenResources,
      ),
      BlockLessonPlanPanel(
        repository: repository,
        blockId: detail.block.id,
        onOpenResources: onOpenResources,
      ),
      const SectionHeading(
        'Öğretim sırası',
        subtitle: 'Önceki veya sonraki öğretim bloğuna geçin',
        icon: Icons.swap_horiz,
      ),
      _SequenceNavigation(detail: detail, repository: repository),
      const SizedBox(height: AppSpacing.lg),
      _MoreBlockInformationPanel(detail: detail),
    ],
  );
}

class _BlockResourcesPanel extends StatelessWidget {
  const _BlockResourcesPanel({
    required this.detail,
    required this.repository,
    this.onOpenResources,
  });

  final model.BlockDetail detail;
  final CourseKnowledgeRepository repository;
  final ResourceNavigationCallback? onOpenResources;

  void _openAll(BuildContext context) {
    final request = ResourceNavigationContext(
      themeId: detail.theme.id,
      blockId: detail.block.id,
    );
    final callback = onOpenResources;
    if (callback != null) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      callback(request);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResourceLibraryPage(
          repository: repository,
          awaitingTextbook: false,
          navigationContext: request,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resourceCount =
        detail.textbookSections.length +
        detail.activities.length +
        detail.forms.length +
        detail.assessmentTaskBindings.length +
        detail.assessmentArtifacts.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text(
          'Bu blokta kullanılan kaynaklar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$resourceCount ilgili kaynak'),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        children: [
          if (detail.textbookSections.isNotEmpty)
            _BlockResourceSummary(
              icon: Icons.menu_book_outlined,
              label: 'Ders kitabı',
              value: detail.textbookSections
                  .map((section) => section.title)
                  .join(' · '),
            ),
          if (detail.activities.isNotEmpty)
            _BlockResourceSummary(
              icon: Icons.task_alt_outlined,
              label: 'Etkinlikler',
              value: detail.activities
                  .map((activity) => activity.title)
                  .join(' · '),
            ),
          if (detail.forms.isNotEmpty)
            _BlockResourceSummary(
              icon: Icons.assignment_outlined,
              label: 'Formlar',
              value: detail.forms.map((form) => form.title).join(' · '),
            ),
          if (detail.assessmentTaskBindings.isNotEmpty ||
              detail.assessmentArtifacts.isNotEmpty)
            _BlockResourceSummary(
              icon: Icons.fact_check_outlined,
              label: 'Değerlendirme',
              value:
                  '${detail.assessmentArtifacts.length + detail.assessmentTaskBindings.length} araç/görev',
            ),
          if (resourceCount == 0)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Text('Bu blok için ilişkilendirilmiş kaynak bulunmuyor.'),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openAll(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Temanın tüm kaynaklarını aç'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockResourceSummary extends StatelessWidget {
  const _BlockResourceSummary({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LessonReadyBlockCard extends StatelessWidget {
  const _LessonReadyBlockCard({required this.detail});

  final model.BlockDetail detail;

  @override
  Widget build(BuildContext context) {
    final firstOutcome = detail.outcomes.isEmpty ? null : detail.outcomes.first;
    final firstBook = detail.textbookSections.isEmpty
        ? null
        : detail.textbookSections.first;
    final firstActivity = detail.activities.isEmpty
        ? null
        : detail.activities.first;
    final assessmentCount =
        detail.assessmentArtifacts.length +
        detail.assessmentTaskBindings.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firstOutcome != null)
              _LessonReadyItem(
                icon: Icons.flag_outlined,
                label: 'İlk hedef',
                title: firstOutcome.code,
                detail: firstOutcome.officialText,
                trailing: detail.outcomes.length > 1
                    ? '+${detail.outcomes.length - 1} çıktı'
                    : null,
              )
            else
              const _LessonReadyItem(
                icon: Icons.info_outline,
                label: 'Hedef',
                title: 'Program çıktısı bulunmuyor',
              ),
            if (firstBook != null) ...[
              const Divider(height: AppSpacing.xl),
              _LessonReadyItem(
                icon: Icons.menu_book_outlined,
                label: 'Kitap',
                title: firstBook.title,
                detail: pageReference(
                  printed: firstBook.printedPageRange,
                  pdf: firstBook.pdfPageRange,
                ),
                trailing: detail.textbookSections.length > 1
                    ? '+${detail.textbookSections.length - 1} bölüm'
                    : null,
              ),
            ],
            if (firstActivity != null) ...[
              const Divider(height: AppSpacing.xl),
              _LessonReadyItem(
                icon: Icons.task_alt_outlined,
                label: 'Etkinlik',
                title: firstActivity.title,
                detail: pageReference(
                  printed: firstActivity.printedPage,
                  pdf: firstActivity.pdfPage,
                ),
                trailing: detail.activities.length > 1
                    ? '+${detail.activities.length - 1} etkinlik'
                    : null,
              ),
            ],
            if (assessmentCount > 0) ...[
              const Divider(height: AppSpacing.xl),
              _LessonReadyItem(
                icon: Icons.fact_check_outlined,
                label: 'Değerlendirme',
                title: '$assessmentCount araç/görev',
                detail: 'Ayrıntılar Daha fazla bilgi altında.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonReadyItem extends StatelessWidget {
  const _LessonReadyItem({
    required this.icon,
    required this.label,
    required this.title,
    this.detail,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String title;
  final String? detail;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (detail?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(detail!, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: AppSpacing.sm),
        Text(
          trailing!,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ],
  );
}

class _MoreBlockInformationPanel extends StatelessWidget {
  const _MoreBlockInformationPanel({required this.detail});

  final model.BlockDetail detail;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const Icon(Icons.unfold_more),
      title: const Text(
        'Daha fazla bilgi',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Program çıktıları ve bu bloğa bağlı değerlendirme ayrıntıları',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        _DisclosureSection(
          icon: Icons.track_changes_outlined,
          title: 'Program çıktıları',
          subtitle: '${detail.outcomes.length} çıktı · süreç bileşenleri dahil',
          child: _OutcomesSection(outcomes: detail.outcomes),
        ),
        _DisclosureSection(
          icon: Icons.fact_check_outlined,
          title: 'Değerlendirme',
          subtitle:
              '${detail.assessmentArtifacts.length + detail.assessmentTaskBindings.length} araç/görev',
          child: _AssessmentSection(detail: detail),
        ),
      ],
    ),
  );
}

class _DisclosureSection extends StatelessWidget {
  const _DisclosureSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: Icon(icon),
    tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    childrenPadding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      0,
      AppSpacing.sm,
      AppSpacing.lg,
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    children: [child],
  );
}

class _BlockSummary extends StatelessWidget {
  const _BlockSummary({required this.detail});

  final model.BlockDetail detail;

  @override
  Widget build(BuildContext context) {
    final skill = detail.block.skillDomain ?? detail.block.learningArea;
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
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${detail.block.order}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                        'Tema içindeki ${detail.block.order}. blok',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (skill != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          skill,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              teacherBlockTimeLabel(detail.block.timeStatus),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomesSection extends StatelessWidget {
  const _OutcomesSection({required this.outcomes});

  final List<model.Outcome> outcomes;

  @override
  Widget build(BuildContext context) {
    if (outcomes.isEmpty) {
      return const StatusPanel(
        icon: Icons.info_outline,
        title: 'Program çıktısı bulunmuyor',
        message: 'Bu blok için ilişkilendirilmiş program çıktısı bulunmuyor.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < outcomes.length; index++) ...[
          InfoCard(
            title: outcomes[index].code,
            subtitle: 'Program çıktısı',
            icon: Icons.flag_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outcomes[index].officialText,
                  style: const TextStyle(height: 1.45),
                ),
                if (outcomes[index].processComponents?.trim().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: AppSpacing.md),
                  LabeledValue(
                    label: 'Süreç bileşenleri',
                    value: _formatProcessComponents(
                      outcomes[index].processComponents!,
                    ),
                    icon: Icons.account_tree_outlined,
                  ),
                ],
              ],
            ),
          ),
          if (index != outcomes.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

String _formatProcessComponents(String raw) {
  final components = model.jsonObjectList(raw);
  if (components.isEmpty) return raw;

  final lines = components
      .map((component) {
        final code = _firstNonEmptyProcessComponent(component, const [
          'component_code',
          'component_code_normalized',
        ]);
        final text = _firstNonEmptyProcessComponent(component, const [
          'component_verbatim',
          'component_title',
          'component_title_verbatim',
        ]);
        return [?code, ?text].join(' — ');
      })
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  return lines.isEmpty ? raw : lines.join('\n\n');
}

String? _firstNonEmptyProcessComponent(
  Map<String, dynamic> component,
  List<String> keys,
) {
  for (final key in keys) {
    final value = component[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

class _AssessmentSection extends StatelessWidget {
  const _AssessmentSection({required this.detail});

  final model.BlockDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.assessmentArtifacts.isEmpty &&
        detail.assessmentTaskBindings.isEmpty &&
        detail.assessmentGaps.isEmpty) {
      return const StatusPanel(
        icon: Icons.fact_check_outlined,
        title: 'Değerlendirme aracı bulunmuyor',
        message: 'Bu blokla ilişkilendirilmiş değerlendirme aracı bulunmuyor.',
      );
    }

    return Column(
      children: [
        if (detail.assessmentArtifacts.isNotEmpty)
          InfoCard(
            title: 'Değerlendirme araçları',
            subtitle: '${detail.assessmentArtifacts.length} araç',
            icon: Icons.fact_check_outlined,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < detail.assessmentArtifacts.length;
                  index++
                ) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.checklist_outlined),
                    title: Text(detail.assessmentArtifacts[index].title),
                    subtitle: Text(
                      [
                        if (detail.assessmentArtifacts[index].skillDomain !=
                            null)
                          detail.assessmentArtifacts[index].skillDomain!,
                        if (detail
                            .assessmentArtifacts[index]
                            .teacherReviewRequired)
                          'Kullanmadan önce öğretmen incelemesi gerekli',
                      ].join(' · '),
                    ),
                  ),
                  if (index != detail.assessmentArtifacts.length - 1)
                    const Divider(),
                ],
              ],
            ),
          ),
        if (detail.assessmentArtifacts.isNotEmpty &&
            detail.assessmentTaskBindings.isNotEmpty)
          const SizedBox(height: AppSpacing.md),
        if (detail.assessmentTaskBindings.isNotEmpty)
          InfoCard(
            title: 'Değerlendirme görevleri',
            subtitle: '${detail.assessmentTaskBindings.length} görev',
            icon: Icons.checklist_outlined,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < detail.assessmentTaskBindings.length;
                  index++
                ) ...[
                  _AssessmentTaskItem(
                    binding: detail.assessmentTaskBindings[index],
                    artifacts: detail.assessmentArtifacts,
                  ),
                  if (index != detail.assessmentTaskBindings.length - 1)
                    const Divider(),
                ],
              ],
            ),
          ),
        if (detail.assessmentGaps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          InfoCard(
            title: 'Dikkat edilmesi gereken değerlendirme ihtiyaçları',
            subtitle: '${detail.assessmentGaps.length} ihtiyaç',
            icon: Icons.info_outline,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < detail.assessmentGaps.length;
                  index++
                ) ...[
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(
                      bottom: AppSpacing.lg,
                    ),
                    title: Text(
                      detail.assessmentGaps[index].officialRequirement ??
                          'Değerlendirme ihtiyacı',
                    ),
                    children: [
                      if (detail.assessmentGaps[index].exactRemainingGap !=
                          null)
                        Text(
                          detail.assessmentGaps[index].exactRemainingGap!,
                          style: const TextStyle(height: 1.45),
                        ),
                    ],
                  ),
                  if (index != detail.assessmentGaps.length - 1)
                    const Divider(),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AssessmentTaskItem extends StatelessWidget {
  const _AssessmentTaskItem({required this.binding, required this.artifacts});

  final model.AssessmentTaskBinding binding;
  final List<model.AssessmentArtifact> artifacts;

  @override
  Widget build(BuildContext context) {
    final bookLocation = teacherLocatorLabel(binding.textbookLocator);
    model.AssessmentArtifact? artifact;
    for (final candidate in artifacts) {
      if (candidate.id == binding.artifactId) {
        artifact = candidate;
        break;
      }
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.lg),
      title: Text(binding.taskTitle ?? 'Değerlendirme görevi'),
      subtitle: binding.evidence == null ? null : Text(binding.evidence!),
      children: [
        if (binding.targetedOutcomes.isNotEmpty)
          LabeledValue(
            label: 'Hedef çıktılar',
            value: binding.targetedOutcomes.join(', '),
            icon: Icons.flag_outlined,
          ),
        if (bookLocation != null) ...[
          const SizedBox(height: AppSpacing.md),
          LabeledValue(
            label: 'Ders kitabı',
            value: bookLocation,
            icon: Icons.menu_book_outlined,
          ),
        ],
        if (binding.taskSpecificCriteria.isNotEmpty)
          RubricScoreCard(binding: binding, artifact: artifact),
      ],
    );
  }
}

class _SequenceNavigation extends StatelessWidget {
  const _SequenceNavigation({required this.detail, required this.repository});

  final model.BlockDetail detail;
  final CourseKnowledgeRepository repository;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 560;
      final previous = OutlinedButton.icon(
        onPressed: detail.previousBlock == null
            ? null
            : () => _open(context, detail.previousBlock!.id),
        icon: const Icon(Icons.arrow_back),
        label: Text(
          detail.previousBlock == null
              ? 'Önceki blok'
              : detail.previousBlock!.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      final next = FilledButton.icon(
        onPressed: detail.nextBlock == null
            ? null
            : () => _open(context, detail.nextBlock!.id),
        icon: const Icon(Icons.arrow_forward),
        label: Text(
          detail.nextBlock == null ? 'Sonraki blok' : detail.nextBlock!.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            previous,
            const SizedBox(height: AppSpacing.sm),
            next,
          ],
        );
      }

      return Row(
        children: [
          Expanded(child: previous),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: next),
        ],
      );
    },
  );

  void _open(BuildContext context, String blockId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlockDetailPage(repository: repository, blockId: blockId),
      ),
    );
  }
}
