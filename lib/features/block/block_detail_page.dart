import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';
import '../shared/teacher_presentation.dart';

class BlockDetailPage extends StatefulWidget {
  const BlockDetailPage({
    super.key,
    required this.repository,
    required this.blockId,
  });

  final CourseKnowledgeRepository repository;
  final String blockId;

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
    setState(() => _future = widget.repository.getBlock(widget.blockId));
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
        );
      },
    ),
  );
}

class _BlockDetailContent extends StatelessWidget {
  const _BlockDetailContent({required this.detail, required this.repository});

  final model.BlockDetail detail;
  final CourseKnowledgeRepository repository;

  @override
  Widget build(BuildContext context) => AppPage(
    maxWidth: AppLayoutTokens.detailMaxWidth,
    children: [
      PageHeader(
        eyebrow: detail.theme.title,
        title: detail.block.title,
        description:
            'Program çıktıları, kitap, etkinlik, değerlendirme ve materyal bağlamını ders sırasında gerektiği kadar açın.',
      ),
      _BlockSummary(detail: detail),
      const SizedBox(height: AppSpacing.md),
      _SequenceNavigation(detail: detail, repository: repository),
      const SectionHeading(
        'Ders yürütme dosyası',
        subtitle: 'Sınıfta kullanacağınız bölümü açın; teknik dayanaklar kapalı kalır.',
        icon: Icons.folder_open_outlined,
      ),
      _BlockSection(
        icon: Icons.track_changes_outlined,
        title: 'Program çıktıları',
        summary: '${detail.outcomes.length} çıktı',
        initiallyExpanded: true,
        child: _OutcomesSection(outcomes: detail.outcomes),
      ),
      const SizedBox(height: AppSpacing.md),
      _BlockSection(
        icon: Icons.menu_book_outlined,
        title: 'Kitap ve sınıf etkinlikleri',
        summary:
            '${detail.textbookSections.length} kitap bölümü · ${detail.activities.length} etkinlik · ${detail.forms.length} form',
        initiallyExpanded: true,
        child: Column(
          children: [
            _TextbookSection(sections: detail.textbookSections),
            if (detail.activities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _ActivitiesSection(activities: detail.activities),
            ],
            if (detail.forms.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _FormsSection(forms: detail.forms),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _BlockSection(
        icon: Icons.fact_check_outlined,
        title: 'Değerlendirme',
        summary:
            '${detail.assessmentArtifacts.length} araç · ${detail.assessmentTaskBindings.length} görev',
        child: _AssessmentSection(detail: detail),
      ),
      const SizedBox(height: AppSpacing.md),
      _BlockSection(
        icon: Icons.library_add_check_outlined,
        title: 'Materyal durumu',
        summary: '${detail.resourceDecisions.length} karar',
        child: _MaterialSection(decisions: detail.resourceDecisions),
      ),
      const SizedBox(height: AppSpacing.md),
      _BlockSection(
        icon: Icons.source_outlined,
        title: 'Kaynaklar ve dayanaklar',
        summary: '${detail.sourceReferences.length} kaynak · teknik referans',
        subdued: true,
        child: _SourcesSection(sources: detail.sourceReferences),
      ),
    ],
  );
}

class _BlockSection extends StatelessWidget {
  const _BlockSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
    this.initiallyExpanded = false,
    this.subdued = false,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget child;
  final bool initiallyExpanded;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: subdued ? 0.82 : 1,
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadiusTokens.card),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(summary),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _BlockSummary extends StatelessWidget {
  const _BlockSummary({required this.detail});

  final model.BlockDetail detail;

  @override
  Widget build(BuildContext context) {
    final skill = detail.block.skillDomain ?? detail.block.learningArea;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadiusTokens.control),
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
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      if (skill != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          skill,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MetricChip(
                  icon: Icons.flag_outlined,
                  label: 'çıktı',
                  value: '${detail.outcomes.length}',
                ),
                MetricChip(
                  icon: Icons.task_alt_outlined,
                  label: 'etkinlik',
                  value: '${detail.activities.length}',
                ),
                MetricChip(
                  icon: Icons.fact_check_outlined,
                  label: 'değerlendirme',
                  value: '${detail.assessmentArtifacts.length}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              teacherBlockTimeLabel(detail.block.timeStatus),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
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
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outcomes[index].code,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  outcomes[index].officialText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                ),
                if (outcomes[index].processComponents != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  LabeledValue(
                    label: 'Süreç bileşenleri',
                    value: outcomes[index].processComponents!,
                    icon: Icons.account_tree_outlined,
                  ),
                ],
              ],
            ),
          ),
          if (index != outcomes.length - 1) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

class _TextbookSection extends StatelessWidget {
  const _TextbookSection({required this.sections});

  final List<model.TextbookSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const StatusPanel(
        icon: Icons.menu_book_outlined,
        title: 'Kitap bölümü bulunmuyor',
        message: 'Bu blokla eşleştirilmiş kitap bölümü bulunmuyor.',
      );
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

class _ActivitiesSection extends StatelessWidget {
  const _ActivitiesSection({required this.activities});

  final List<model.Activity> activities;

  @override
  Widget build(BuildContext context) => Column(
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

class _FormsSection extends StatelessWidget {
  const _FormsSection({required this.forms});

  final List<model.Form> forms;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < forms.length; index++) ...[
        _FormItem(form: forms[index]),
        if (index != forms.length - 1) const Divider(),
      ],
    ],
  );
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.assessmentArtifacts.isNotEmpty) ...[
          Text(
            'Değerlendirme araçları',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < detail.assessmentArtifacts.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.checklist_outlined),
              title: Text(detail.assessmentArtifacts[index].title),
              subtitle: Text(
                [
                  if (detail.assessmentArtifacts[index].skillDomain != null)
                    detail.assessmentArtifacts[index].skillDomain!,
                  if (detail.assessmentArtifacts[index].teacherReviewRequired)
                    'Öğretmen incelemesi gerekli',
                ].join(' · '),
              ),
            ),
            if (index != detail.assessmentArtifacts.length - 1) const Divider(),
          ],
        ],
        if (detail.assessmentTaskBindings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Değerlendirme görevleri',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          for (var index = 0; index < detail.assessmentTaskBindings.length; index++) ...[
            _AssessmentTaskItem(binding: detail.assessmentTaskBindings[index]),
            if (index != detail.assessmentTaskBindings.length - 1) const Divider(),
          ],
        ],
        if (detail.assessmentGaps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Değerlendirme ihtiyaçları',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          for (var index = 0; index < detail.assessmentGaps.length; index++) ...[
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
              title: Text(
                detail.assessmentGaps[index].officialRequirement ??
                    'Değerlendirme ihtiyacı',
              ),
              children: [
                if (detail.assessmentGaps[index].exactRemainingGap != null)
                  Text(
                    detail.assessmentGaps[index].exactRemainingGap!,
                    style: const TextStyle(height: 1.45),
                  ),
              ],
            ),
            if (index != detail.assessmentGaps.length - 1) const Divider(),
          ],
        ],
      ],
    );
  }
}

class _AssessmentTaskItem extends StatelessWidget {
  const _AssessmentTaskItem({required this.binding});

  final model.AssessmentTaskBinding binding;

  @override
  Widget build(BuildContext context) {
    final bookLocation = teacherLocatorLabel(binding.textbookLocator);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
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
      ],
    );
  }
}

class _MaterialSection extends StatelessWidget {
  const _MaterialSection({required this.decisions});

  final List<model.ResourceDecision> decisions;

  @override
  Widget build(BuildContext context) {
    if (decisions.isEmpty) {
      return const StatusPanel(
        icon: Icons.info_outline,
        title: 'Materyal bilgisi bulunmuyor',
        message: 'Bu blok için gösterilebilir materyal bilgisi bulunmuyor.',
      );
    }

    final additional = decisions
        .where((decision) => decision.appCategory == 'ADDITIONAL_SUPPORT_REQUIRED')
        .length;

    return Column(
      children: [
        StatusPanel(
          icon: additional == 0 ? Icons.check_circle_outline : Icons.add_task,
          title: additional == 0
              ? 'Ek destek gereken alan görünmüyor'
              : '$additional alanda ek destek gerekiyor',
          message: additional == 0
              ? 'Mevcut kitap ve araçlar bu blok bağlamında kullanılabilir.'
              : 'Ek destek alanlarını ders hazırlığında ayrıca gözden geçirin.',
          tone: additional == 0 ? StatusTone.positive : StatusTone.attention,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < decisions.length; index++) ...[
          TeacherResourceDecisionCard(decision: decisions[index]),
          if (index != decisions.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.sources});

  final List<model.SourceReference> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const UnresolvedText(label: 'Bu blok için kaynak bilgisi bulunmuyor.');
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

class _SequenceNavigation extends StatelessWidget {
  const _SequenceNavigation({required this.detail, required this.repository});

  final model.BlockDetail detail;
  final CourseKnowledgeRepository repository;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          final previous = OutlinedButton.icon(
            onPressed: detail.previousBlock == null
                ? null
                : () => _open(context, detail.previousBlock!.id),
            icon: const Icon(Icons.arrow_back),
            label: Text(
              detail.previousBlock == null
                  ? 'Önceki blok'
                  : detail.previousBlock!.title,
              maxLines: 2,
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
              maxLines: 2,
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
      ),
    ),
  );

  void _open(BuildContext context, String blockId) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BlockDetailPage(repository: repository, blockId: blockId),
      ),
    );
  }
}
