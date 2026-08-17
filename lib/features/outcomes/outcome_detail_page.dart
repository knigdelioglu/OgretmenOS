import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';
import 'outcome_presentation.dart';

class OutcomeDetailPage extends StatefulWidget {
  const OutcomeDetailPage({
    super.key,
    required this.repository,
    required this.service,
    required this.initialPlan,
    required this.initialItem,
  });

  final CourseKnowledgeRepository repository;
  final OutcomePlanningService service;
  final AnnualOutcomePlan initialPlan;
  final TrackedOutcome initialItem;

  @override
  State<OutcomeDetailPage> createState() => _OutcomeDetailPageState();
}

class _OutcomeDetailPageState extends State<OutcomeDetailPage> {
  late AnnualOutcomePlan _plan;
  late TrackedOutcome _item;
  late final TextEditingController _noteController;
  bool _changed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _item = widget.initialItem;
    _noteController = TextEditingController(text: _item.teacherNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _item.outcome;
    final details = _item.contexts.map((item) => item.detail).toList();
    final textbook = _uniqueBy<model.TextbookSection>(
      details.expand((item) => item.textbookSections),
      (item) => item.id,
    );
    final activities = _uniqueBy<model.Activity>(
      details.expand((item) => item.activities),
      (item) => item.id,
    );
    final forms = _uniqueBy<model.Form>(
      details.expand((item) => item.forms),
      (item) => item.id,
    );
    final artifacts = _uniqueBy<model.AssessmentArtifact>(
      details.expand((item) => item.assessmentArtifacts),
      (item) => item.id,
    );
    final decisions = _uniqueBy<model.ResourceDecision>(
      details.expand((item) => item.resourceDecisions),
      (item) => item.id,
    );
    final sources = _uniqueBy<model.SourceReference>(
      details.expand((item) => item.sourceReferences),
      (item) => item.id,
    );
    final targetedBindings = _uniqueBy<model.AssessmentTaskBinding>(
      details
          .expand((item) => item.assessmentTaskBindings)
          .where(
            (binding) => binding.targetedOutcomes.any(
              (target) => target == outcome.code || target == outcome.id,
            ),
          ),
      (item) => '${item.artifactId}:${item.gapInstanceId}:${item.taskTitle}',
    );
    final sourceWeek = _plan.week(_item.plannedWeekNumber)?.week;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(outcome.code),
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: AppPage(
          maxWidth: 900,
          children: [
            PageHeader(
              eyebrow: 'Kazanım Ayrıntısı',
              title: outcome.code,
              description: outcome.officialText,
              trailing: OutcomeStatusChip(status: _item.status),
            ),
            if (_item.isCarriedIn)
              StatusPanel(
                icon: Icons.redo_outlined,
                title: 'Geçen haftadan taşındı',
                message:
                    'Bu kazanımın planlanan haftası ${_item.plannedWeekNumber}. haftadır; şu anda ${_item.displayWeekNumber}. hafta görünümünde takip ediliyor.',
                tone: StatusTone.attention,
              )
            else if (_item.carriedToWeekNumber != null)
              StatusPanel(
                icon: Icons.redo_outlined,
                title: 'Sonraki haftaya taşındı',
                message:
                    'Planlanan konum korunuyor; gerçekleşen takip ${_item.carriedToWeekNumber}. haftada devam ediyor.',
                tone: StatusTone.attention,
              ),
            const SectionHeading(
              'Takip durumu',
              subtitle:
                  'Bu seçim yalnız yerel öğretmen takibidir; resmî programı değiştirmez.',
              icon: Icons.fact_check_outlined,
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatusButton(
                  label: 'Planlı',
                  icon: Icons.schedule_outlined,
                  selected: _item.status == OutcomeTrackingStatus.planned,
                  onPressed: () => _setStatus(OutcomeTrackingStatus.planned),
                ),
                _StatusButton(
                  label: 'Devam ediyor',
                  icon: Icons.play_circle_outline,
                  selected: _item.status == OutcomeTrackingStatus.inProgress,
                  onPressed: () => _setStatus(OutcomeTrackingStatus.inProgress),
                ),
                _StatusButton(
                  label: 'Kısmen işlendi',
                  icon: Icons.timelapse_outlined,
                  selected:
                      _item.status == OutcomeTrackingStatus.partiallyCompleted,
                  onPressed: () =>
                      _setStatus(OutcomeTrackingStatus.partiallyCompleted),
                ),
                _StatusButton(
                  label: 'İşlendi',
                  icon: Icons.check_circle_outline,
                  selected: _item.status == OutcomeTrackingStatus.completed,
                  onPressed: () => _setStatus(OutcomeTrackingStatus.completed),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _carry,
                  icon: const Icon(Icons.redo_outlined),
                  label: const Text('Sonraki haftaya taşı'),
                ),
              ],
            ),
            const SectionHeading(
              'Öğretmen notu',
              subtitle: 'Yalnız bu haftalık kazanım takibine bağlı yerel not',
              icon: Icons.sticky_note_2_outlined,
            ),
            InfoCard(
              title: 'Kısa not',
              icon: Icons.edit_note_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Örn. son etkinlik gelecek derste tamamlanacak',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _saving ? null : _saveNote,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Notu kaydet'),
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeading(
              'Deftere Bakış',
              subtitle:
                  'Kopyalanan metin yalnız doğrulanmış program ifadelerini kullanır.',
              icon: Icons.menu_book_outlined,
            ),
            InfoCard(
              title: 'Kazanım ve plan bağlamı',
              icon: Icons.content_paste_outlined,
              trailing: IconButton(
                tooltip: 'Panoya kopyala',
                onPressed: _copyDiaryText,
                icon: const Icon(Icons.copy_outlined),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sourceWeek != null)
                    LabeledValue(
                      label: 'Planlanan hafta',
                      value:
                          '${sourceWeek.weekNumber}. Hafta · ${outcomeDateRange(sourceWeek.start, sourceWeek.end)}',
                    ),
                  if (_item.primaryTheme != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    LabeledValue(label: 'Tema', value: _item.primaryTheme!.title),
                  ],
                  if (_item.primaryBlock != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    LabeledValue(label: 'Blok', value: _item.primaryBlock!.title),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(
                    '${outcome.code} — ${outcome.officialText}',
                    style: const TextStyle(height: 1.5),
                  ),
                  if (outcome.processComponents?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Süreç bileşenleri',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SelectableText(outcome.processComponents!),
                  ],
                ],
              ),
            ),
            const SectionHeading(
              'Plan ve blok bağlamı',
              subtitle:
                  'Aşağıdaki kaynaklar kazanımın yer aldığı doğrulanmış bloklardan gelir.',
              icon: Icons.account_tree_outlined,
            ),
            if (_item.contexts.isEmpty)
              const StatusPanel(
                icon: Icons.info_outline,
                title: 'Blok bağlamı bulunamadı',
                message: 'Bu haftalık projection için doğrulanmış blok bağlamı yok.',
              )
            else
              for (var index = 0; index < _item.contexts.length; index++) ...[
                _BlockContextCard(
                  contextItem: _item.contexts[index],
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlockDetailPage(
                        repository: widget.repository,
                        blockId: _item.contexts[index].block.id,
                      ),
                    ),
                  ),
                ),
                if (index != _item.contexts.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            if (textbook.isNotEmpty) ...[
              const SectionHeading(
                'Kitap',
                subtitle:
                    'Kazanımın bulunduğu blokta erişilebilen ders kitabı bölümleri',
                icon: Icons.menu_book_outlined,
              ),
              for (var index = 0; index < textbook.length; index++) ...[
                InfoCard(
                  title: textbook[index].title,
                  subtitle: textbook[index].genre,
                  icon: Icons.book_outlined,
                  child: Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (textbook[index].printedPageRange != null)
                        Text('Basılı: s. ${textbook[index].printedPageRange}'),
                      if (textbook[index].pdfPageRange != null)
                        Text('PDF: ${textbook[index].pdfPageRange}'),
                    ],
                  ),
                ),
                if (index != textbook.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
            if (activities.isNotEmpty) ...[
              const SectionHeading(
                'Etkinlikler',
                subtitle: 'Kazanımın bulunduğu blokta erişilebilen etkinlikler',
                icon: Icons.task_alt_outlined,
              ),
              for (final activity in activities)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InfoCard(
                    title: activity.title,
                    subtitle: activity.activityType,
                    icon: Icons.edit_calendar_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activity.studentAction != null)
                          Text(
                            activity.studentAction!,
                            style: const TextStyle(height: 1.4),
                          ),
                        if (activity.printedPage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text('Kitap: s. ${activity.printedPage}'),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
            if (forms.isNotEmpty) ...[
              const SectionHeading(
                'Formlar',
                subtitle: 'Blok bağlamında erişilebilen değerlendirme/form öğeleri',
                icon: Icons.description_outlined,
              ),
              for (final form in forms)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InfoCard(
                    title: form.title,
                    subtitle: form.assessmentType ?? form.structuralType,
                    icon: Icons.description_outlined,
                    child: Text(
                      form.printedPage == null
                          ? 'Sayfa bilgisi doğrulanmış runtime verisinde belirtilmemiş.'
                          : 'Basılı kitap: s. ${form.printedPage}',
                    ),
                  ),
                ),
            ],
            if (targetedBindings.isNotEmpty) ...[
              const SectionHeading(
                'Doğrudan hedeflenen değerlendirme görevleri',
                subtitle:
                    'Runtime targeted_outcomes verisi bu kazanımı açıkça hedefliyor.',
                icon: Icons.fact_check_outlined,
              ),
              for (final binding in targetedBindings)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InfoCard(
                    title: binding.taskTitle ?? 'Değerlendirme görevi',
                    subtitle: 'Doğrudan kazanım hedeflemesi',
                    icon: Icons.fact_check_outlined,
                    child: Text(
                      binding.evidence ??
                          'Ek kanıt açıklaması runtime verisinde belirtilmemiş.',
                    ),
                  ),
                ),
            ] else if (artifacts.isNotEmpty) ...[
              const SectionHeading(
                'Değerlendirme araçları',
                subtitle:
                    'Bunlar blok bağlamında erişilebilir; doğrudan kazanım hedeflemesi olarak sunulmaz.',
                icon: Icons.assignment_outlined,
              ),
              for (final artifact in artifacts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InfoCard(
                    title: artifact.title,
                    subtitle: artifact.assessmentFamily,
                    icon: Icons.assignment_outlined,
                    child: Text(
                      artifact.generationStatus == null
                          ? 'Blok değerlendirme bağlamı'
                          : 'Durum: ${artifact.generationStatus}',
                    ),
                  ),
                ),
            ],
            if (decisions.isNotEmpty) ...[
              const SectionHeading(
                'Materyal / kaynak kararları',
                subtitle:
                    'Kazanımın bulunduğu blokların doğrulanmış resource decision verisi',
                icon: Icons.inventory_2_outlined,
              ),
              for (var index = 0; index < decisions.length; index++) ...[
                ResourceDecisionCard(decision: decisions[index]),
                if (index != decisions.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
            if (sources.isNotEmpty) ...[
              const SectionHeading(
                'Kaynak referansları',
                subtitle: 'Blok bağlamında runtime tarafından taşınan kaynak izleri',
                icon: Icons.link_outlined,
              ),
              for (final source in sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InfoCard(
                    title: source.title,
                    subtitle: source.sourceType,
                    icon: Icons.link_outlined,
                    child: SelectableText(source.locator ?? 'Konum bilgisi yok'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(OutcomeTrackingStatus status) async {
    await _mutate(() => widget.service.setStatus(_item, status));
  }

  Future<void> _saveNote() async {
    await _mutate(
      () => widget.service.saveTeacherNote(_item, _noteController.text),
    );
  }

  Future<void> _carry() async {
    final targets = _plan.weeks
        .where(
          (summary) =>
              !summary.week.isEventWeek &&
              summary.week.weekNumber > _item.plannedWeekNumber,
        )
        .toList(growable: false);
    if (targets.isEmpty) return;
    var selected = targets.first.week.weekNumber;
    final target = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sonraki haftaya taşı'),
          content: DropdownButtonFormField<int>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Hedef öğretim haftası'),
            items: [
              for (final summary in targets)
                DropdownMenuItem<int>(
                  value: summary.week.weekNumber,
                  child: Text(
                    '${summary.week.weekNumber}. Hafta · ${outcomeDateRange(summary.week.start, summary.week.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Taşı'),
            ),
          ],
        ),
      ),
    );
    if (target == null) return;
    await _mutate(
      () => widget.service.carryToWeek(
        item: _item,
        targetWeekNumber: target,
        plan: _plan,
      ),
    );
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      final refreshed = await widget.service.buildPlan();
      final summary = refreshed.week(_item.displayWeekNumber) ??
          refreshed.week(_item.plannedWeekNumber);
      TrackedOutcome? next;
      if (summary != null) {
        for (final candidate in summary.outcomes) {
          if (candidate.trackingKey == _item.trackingKey &&
              candidate.isCarriedIn == _item.isCarriedIn) {
            next = candidate;
            break;
          }
        }
        next ??= summary.findByKey(_item.trackingKey);
      }
      if (!mounted) return;
      setState(() {
        _plan = refreshed;
        if (next != null) _item = next!;
        _noteController.text = _item.teacherNote ?? '';
        _changed = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Değişiklik kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyDiaryText() async {
    final week = _plan.week(_item.plannedWeekNumber)?.week;
    final buffer = StringBuffer();
    if (week != null) {
      buffer.writeln(
        '${week.weekNumber}. Hafta · ${outcomeDateRange(week.start, week.end)}',
      );
    }
    if (_item.primaryTheme != null) {
      buffer.writeln('Tema: ${_item.primaryTheme!.title}');
    }
    if (_item.primaryBlock != null) {
      buffer.writeln('Blok: ${_item.primaryBlock!.title}');
    }
    buffer.write('${_item.outcome.code} — ${_item.outcome.officialText}');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kazanım özeti panoya kopyalandı.')),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        )
      : OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );
}

class _BlockContextCard extends StatelessWidget {
  const _BlockContextCard({required this.contextItem, required this.onOpen});

  final OutcomeBlockContext contextItem;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InfoCard(
    title: contextItem.block.title,
    subtitle: contextItem.theme.title,
    icon: Icons.view_agenda_outlined,
    trailing: IconButton(
      tooltip: 'Blok ayrıntısını aç',
      onPressed: onOpen,
      icon: const Icon(Icons.chevron_right),
    ),
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (contextItem.block.skillDomain != null)
          Chip(label: Text(contextItem.block.skillDomain!)),
        if (contextItem.block.learningArea != null)
          Chip(label: Text(contextItem.block.learningArea!)),
      ],
    ),
  );
}

List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) idOf) {
  final seen = <String>{};
  final result = <T>[];
  for (final item in items) {
    if (seen.add(idOf(item))) result.add(item);
  }
  return result;
}
