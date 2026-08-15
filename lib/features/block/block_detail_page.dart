import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blok Özeti')),
    body: FutureBuilder<model.BlockDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Blok detayları yüklenemedi.',
            onRetry: () => setState(
              () => _future = widget.repository.getBlock(widget.blockId),
            ),
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      _HeaderCard(detail: detail),
      SectionHeading('Program'),
      _OutcomesCard(outcomes: detail.outcomes),
      SectionHeading('Ders kitabı'),
      _TextbookCard(sections: detail.textbookSections),
      SectionHeading('Etkinlikler'),
      _ActivitiesCard(activities: detail.activities),
      SectionHeading('Formlar'),
      _FormsCard(forms: detail.forms),
      SectionHeading('Değerlendirme'),
      const Text(
        'Gösterilen araç ve eşleştirmeler runtime paketindeki tema/blok ilişkilerinden gelir.',
      ),
      _AssessmentCard(detail: detail),
      SectionHeading('Materyal durumu'),
      const Text(
        'Kaynak kararları runtime şemasında tema düzeyinde tutulur; burada seçili temanın doğrulanmış kararları gösterilir.',
      ),
      if (detail.resourceDecisions.isEmpty)
        const InfoCard(
          title: 'Runtime kararı',
          child: UnresolvedText(
            label: 'Bu blok için doğrulanmış kaynak kararı bulunmuyor.',
          ),
        )
      else
        for (final decision in detail.resourceDecisions)
          ResourceDecisionCard(decision: decision),
      SectionHeading('Kaynak'),
      _SourcesCard(sources: detail.sourceReferences),
      SectionHeading('Sıra'),
      _SequenceNavigation(detail: detail, repository: repository),
    ],
  );
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final model.BlockDetail detail;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.theme.title),
          const SizedBox(height: 8),
          Text(
            detail.block.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('Blok sırası: ${detail.block.order}'),
          if (detail.block.skillDomain != null)
            Text('Beceri alanı: ${detail.block.skillDomain}'),
          if (detail.block.learningArea != null)
            Text('Öğrenme alanı: ${detail.block.learningArea}'),
          if (detail.block.timeStatus != null) ...[
            const SizedBox(height: 8),
            Text(blockTimeStatusLabel(detail.block.timeStatus!)),
          ] else ...[
            const SizedBox(height: 8),
            const UnresolvedText(
              label: 'Programda doğrulanmış ayrı blok süresi bulunmuyor.',
            ),
          ],
        ],
      ),
    ),
  );
}

class _OutcomesCard extends StatelessWidget {
  const _OutcomesCard({required this.outcomes});

  final List<model.Outcome> outcomes;

  @override
  Widget build(BuildContext context) {
    if (outcomes.isEmpty) {
      return const InfoCard(
        title: 'Program çıktıları',
        child: UnresolvedText(
          label: 'Bu blok için doğrulanmış çıktı ilişkisi bulunmuyor.',
        ),
      );
    }
    return Column(
      children: [
        for (final outcome in outcomes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outcome.code,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(outcome.officialText),
                  if (outcome.processComponents != null) ...[
                    const SizedBox(height: 8),
                    Text('Süreç bileşenleri: ${outcome.processComponents}'),
                  ],
                  if (outcome.sourceLocator != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Kaynak: ${outcome.sourceLocator}'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TextbookCard extends StatelessWidget {
  const _TextbookCard({required this.sections});

  final List<model.TextbookSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const InfoCard(
        title: 'Kitap karşılığı',
        child: UnresolvedText(
          label:
              'Bu blok etkinlikleri için doğrulanmış kitap bölümü bulunmuyor.',
        ),
      );
    }
    return InfoCard(
      title: 'Kitap bölümleri',
      icon: Icons.menu_book_outlined,
      child: Column(
        children: [
          for (final section in sections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(section.title),
              subtitle: Text(
                [
                  if (section.genre != null) section.genre!,
                  if (section.printedPageRange != null)
                    'Basılı s. ${section.printedPageRange}',
                  if (section.pdfPageRange != null)
                    'PDF s. ${section.pdfPageRange}',
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivitiesCard extends StatelessWidget {
  const _ActivitiesCard({required this.activities});

  final List<model.Activity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const InfoCard(
        title: 'Etkinlikler',
        child: UnresolvedText(
          label: 'Bu blok için doğrulanmış etkinlik bulunmuyor.',
        ),
      );
    }
    return Column(
      children: [
        for (final activity in activities)
          Card(
            child: ExpansionTile(
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
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (activity.studentAction != null)
                  _LabeledText(
                    label: 'Öğrenci eylemi',
                    value: activity.studentAction!,
                  ),
                if (activity.expectedEvidence != null)
                  _LabeledText(
                    label: 'Beklenen kanıt',
                    value: activity.expectedEvidence!,
                  ),
                if (activity.verificationStatus != null)
                  _LabeledText(
                    label: 'Doğrulama',
                    value: activity.verificationStatus!,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FormsCard extends StatelessWidget {
  const _FormsCard({required this.forms});

  final List<model.Form> forms;

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
      return const InfoCard(
        title: 'Formlar',
        child: UnresolvedText(
          label: 'Bu blok etkinlikleriyle ilişkilendirilmiş form bulunmuyor.',
        ),
      );
    }
    return InfoCard(
      title: 'İlişkili formlar',
      icon: Icons.assignment_outlined,
      child: Column(
        children: [
          for (final form in forms)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(form.title),
              subtitle: Text(
                [
                  if (form.assessmentType != null) form.assessmentType!,
                  if (form.evaluator != null)
                    'Değerlendirici: ${form.evaluator}',
                  pageReference(
                    printed: form.printedPage?.toString(),
                    pdf: form.pdfPage?.toString(),
                  ),
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.detail});

  final model.BlockDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.assessmentArtifacts.isEmpty &&
        detail.assessmentTaskBindings.isEmpty) {
      return const InfoCard(
        title: 'Değerlendirme araçları',
        child: UnresolvedText(
          label:
              'Bu tema/blok için doğrulanmış değerlendirme eşlemesi bulunmuyor.',
        ),
      );
    }
    return Column(
      children: [
        for (final artifact in detail.assessmentArtifacts)
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(artifact.title),
              subtitle: Text(
                [
                  if (artifact.skillDomain != null) artifact.skillDomain!,
                  if (artifact.generationStatus != null)
                    artifact.generationStatus!,
                  if (artifact.teacherReviewRequired) 'Öğretmen incelemesi',
                ].join(' · '),
              ),
            ),
          ),
        for (final binding in detail.assessmentTaskBindings)
          InfoCard(
            title: binding.taskTitle ?? 'Değerlendirme eşlemesi',
            icon: Icons.link,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (binding.evidence != null) Text(binding.evidence!),
                if (binding.textbookLocator != null)
                  _LabeledText(
                    label: 'Kitap kaynağı',
                    value: binding.textbookLocator!,
                  ),
                if (binding.curriculumLocator != null)
                  _LabeledText(
                    label: 'Program kaynağı',
                    value: binding.curriculumLocator!,
                  ),
              ],
            ),
          ),
        for (final gap in detail.assessmentGaps)
          Card(
            child: ExpansionTile(
              title: const Text('Doğrulanmış değerlendirme açığı'),
              subtitle: Text(gap.artifactId),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (gap.officialRequirement != null)
                  _LabeledText(
                    label: 'Resmî gereklilik',
                    value: gap.officialRequirement!,
                  ),
                if (gap.exactRemainingGap != null)
                  _LabeledText(
                    label: 'Kalan açık',
                    value: gap.exactRemainingGap!,
                  ),
                if (gap.sourceLocators.isNotEmpty)
                  _LabeledText(
                    label: 'Kaynaklar',
                    value: gap.sourceLocators.join(' · '),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.sources});

  final List<model.SourceReference> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const InfoCard(
        title: 'Kaynak referansı',
        child: UnresolvedText(label: 'Kaynak referansı bulunmuyor.'),
      );
    }
    return InfoCard(
      title: 'Kaynak referansları',
      icon: Icons.source_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                [
                  source.title,
                  if (source.entityLocator != null) source.entityLocator!,
                  if (source.locator != null) source.locator!,
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}

class _SequenceNavigation extends StatelessWidget {
  const _SequenceNavigation({required this.detail, required this.repository});

  final model.BlockDetail detail;
  final CourseKnowledgeRepository repository;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: detail.previousBlock == null
              ? null
              : () => _open(context, detail.previousBlock!.id),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Önceki blok'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.tonalIcon(
          onPressed: detail.nextBlock == null
              ? null
              : () => _open(context, detail.nextBlock!.id),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Sonraki blok'),
        ),
      ),
    ],
  );

  void _open(BuildContext context, String blockId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlockDetailPage(repository: repository, blockId: blockId),
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
