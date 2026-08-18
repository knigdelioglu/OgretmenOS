import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_tokens.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';
import 'outcome_presentation.dart';

enum _SavingAction { status, note, carry }

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
  bool _noteDirty = false;
  _SavingAction? _savingAction;

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
          title: const Text('Kazanım'),
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: AppPage(
          maxWidth: AppLayoutTokens.detailMaxWidth,
          children: [
            PageHeader(
              eyebrow: 'Kazanım Ayrıntısı',
              title: outcome.code,
              description: outcome.officialText,
              trailing: OutcomeStatusChip(status: _item.presentationStatus),
            ),
            if (_item.isCarriedIn)
              StatusPanel(
                icon: Icons.redo_outlined,
                title: 'Geçen haftadan taşındı',
                message:
                    'Planlanan konum ${_item.plannedWeekNumber}. haftadır; sınıf takibi ${_item.displayWeekNumber}. haftada devam ediyor.',
                tone: StatusTone.attention,
              )
            else if (_item.carriedToWeekNumber != null)
              StatusPanel(
                icon: Icons.redo_outlined,
                title: 'Sonraki haftaya taşındı',
                message:
                    'Planlanan hafta korunuyor; gerçekleşen takip ${_item.carriedToWeekNumber}. haftaya taşındı.',
                tone: StatusTone.attention,
              ),
            const SectionHeading(
              'Takip durumu',
              subtitle:
                  'Bu alan yalnız öğretmenin sınıf yürütme takibidir; resmî programı değiştirmez.',
              icon: Icons.fact_check_outlined,
            ),
            _TrackingControls(
              item: _item,
              savingAction: _savingAction,
              onStatusChanged: _setStatus,
              onComplete: () => _setStatus(OutcomeTrackingStatus.completed),
              onCarry: _carry,
            ),
            const SectionHeading(
              'Öğretmen notu',
              subtitle: 'Bu haftalık kazanım takibine bağlı kısa yerel not',
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
                    scrollPadding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 120,
                    ),
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      final dirty = _noteController.text != (_item.teacherNote ?? '');
                      if (dirty != _noteDirty) setState(() => _noteDirty = dirty);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Örn. son etkinlik gelecek derste tamamlanacak',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: !_noteDirty || _savingAction == _SavingAction.note
                          ? null
                          : _saveNote,
                      icon: _savingAction == _SavingAction.note
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_noteDirty ? 'Notu kaydet' : 'Not güncel'),
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeading(
              'Deftere Bakış',
              subtitle: 'Yalnız doğrulanmış program ifadelerini kopyalar.',
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  if (outcome.processComponents?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.md),
                    LabeledValue(
                      label: 'Süreç bileşenleri',
                      value: outcome.processComponents!,
                    ),
                  ],
                ],
              ),
            ),
            const SectionHeading(
              'Blok bağlamı',
              subtitle:
                  'Aşağıdaki ilişkiler kazanımın yer aldığı doğrulanmış bloklardan gelir.',
              icon: Icons.account_tree_outlined,
            ),
            if (_item.contexts.isEmpty)
              const StatusPanel(
                icon: Icons.info_outline,
                title: 'Blok bağlamı bulunamadı',
                message: 'Bu haftalık görünüm için doğrulanmış blok bağlamı yok.',
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
            const SectionHeading(
              'Ders yürütme kaynakları',
              subtitle:
                  'Kitap, etkinlik, değerlendirme ve materyal ayrıntılarını gerektiğinde açın.',
              icon: Icons.folder_open_outlined,
            ),
            _DetailSection(
              icon: Icons.menu_book_outlined,
              title: 'Kitap',
              countLabel: '${textbook.length} bölüm',
              isEmpty: textbook.isEmpty,
              child: _TextbookContent(items: textbook),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              icon: Icons.task_alt_outlined,
              title: 'Etkinlikler',
              countLabel: '${activities.length} etkinlik',
              isEmpty: activities.isEmpty,
              child: _ActivitiesContent(items: activities),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              icon: Icons.description_outlined,
              title: 'Formlar',
              countLabel: '${forms.length} form',
              isEmpty: forms.isEmpty,
              child: _FormsContent(items: forms),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              icon: Icons.fact_check_outlined,
              title: targetedBindings.isNotEmpty
                  ? 'Doğrudan hedeflenen değerlendirme'
                  : 'Değerlendirme — blok bağlamı',
              countLabel: targetedBindings.isNotEmpty
                  ? '${targetedBindings.length} doğrudan görev'
                  : '${artifacts.length} blok aracı',
              isEmpty: targetedBindings.isEmpty && artifacts.isEmpty,
              child: _AssessmentContent(
                targetedBindings: targetedBindings,
                artifacts: artifacts,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              icon: Icons.inventory_2_outlined,
              title: 'Materyal kararları — blok bağlamı',
              countLabel: '${decisions.length} karar',
              isEmpty: decisions.isEmpty,
              child: _MaterialsContent(items: decisions),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailSection(
              icon: Icons.source_outlined,
              title: 'Kaynaklar ve dayanaklar',
              countLabel: '${sources.length} kaynak',
              isEmpty: sources.isEmpty,
              subdued: true,
              child: _SourcesContent(items: sources),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(OutcomeTrackingStatus status) async {
    if (status == OutcomeTrackingStatus.carriedOver || status == _item.status) return;
    await _mutate(
      action: () => widget.service.setStatus(_item, status),
      savingAction: _SavingAction.status,
      successMessage: 'Takip durumu güncellendi.',
      haptic: status == OutcomeTrackingStatus.completed,
    );
  }

  Future<void> _saveNote() async {
    if (!_noteDirty) return;
    await _mutate(
      action: () => widget.service.saveTeacherNote(_item, _noteController.text),
      savingAction: _SavingAction.note,
      successMessage: 'Öğretmen notu kaydedildi.',
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
          scrollable: true,
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
      action: () => widget.service.carryToWeek(
        item: _item,
        targetWeekNumber: target,
        plan: _plan,
      ),
      savingAction: _SavingAction.carry,
      successMessage: 'Kazanım $target. haftaya taşındı.',
      haptic: true,
    );
  }

  Future<void> _mutate({
    required Future<void> Function() action,
    required _SavingAction savingAction,
    String? successMessage,
    bool haptic = false,
  }) async {
    if (_savingAction != null) return;
    setState(() => _savingAction = savingAction);
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
        if (next != null) _item = next;
        _noteController.text = _item.teacherNote ?? '';
        _noteDirty = false;
        _changed = true;
        _savingAction = null;
      });
      if (haptic) unawaited(HapticFeedback.mediumImpact());
      if (successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _savingAction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Değişiklik kaydedilemedi: $error')),
      );
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

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({
    required this.item,
    required this.savingAction,
    required this.onStatusChanged,
    required this.onComplete,
    required this.onCarry,
  });

  final TrackedOutcome item;
  final _SavingAction? savingAction;
  final ValueChanged<OutcomeTrackingStatus> onStatusChanged;
  final VoidCallback onComplete;
  final VoidCallback onCarry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<OutcomeTrackingStatus>(
            key: ValueKey(item.status),
            initialValue: item.status,
            decoration: const InputDecoration(
              labelText: 'Sınıftaki gerçekleşen durum',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
            items: OutcomeTrackingStatus.values
                .map(
                  (status) => DropdownMenuItem<OutcomeTrackingStatus>(
                    value: status,
                    enabled: status != OutcomeTrackingStatus.carriedOver,
                    child: Text(outcomeStatusLabel(status)),
                  ),
                )
                .toList(growable: false),
            onChanged: savingAction == _SavingAction.status
                ? null
                : (value) {
                    if (value != null &&
                        value != OutcomeTrackingStatus.carriedOver) {
                      onStatusChanged(value);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (item.presentationStatus != OutcomeTrackingStatus.completed)
                FilledButton.icon(
                  onPressed: savingAction == _SavingAction.status
                      ? null
                      : onComplete,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('İşlendi'),
                ),
              OutlinedButton.icon(
                onPressed: savingAction == _SavingAction.carry ? null : onCarry,
                icon: const Icon(Icons.redo_outlined),
                label: Text(
                  savingAction == _SavingAction.carry
                      ? 'Taşınıyor…'
                      : 'Sonraki haftaya taşı',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BlockContextCard extends StatelessWidget {
  const _BlockContextCard({required this.contextItem, required this.onOpen});

  final OutcomeBlockContext contextItem;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.view_agenda_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contextItem.block.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    contextItem.theme.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (contextItem.block.skillDomain != null ||
                      contextItem.block.learningArea != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      [
                        contextItem.block.skillDomain,
                        contextItem.block.learningArea,
                      ].whereType<String>().join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.countLabel,
    required this.isEmpty,
    required this.child,
    this.subdued = false,
  });

  final IconData icon;
  final String title;
  final String countLabel;
  final bool isEmpty;
  final Widget child;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: isEmpty ? 0.55 : subdued ? 0.82 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadiusTokens.card),
        ),
        child: ExpansionTile(
          enabled: !isEmpty,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(isEmpty ? '$countLabel · içerik yok' : countLabel),
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

class _TextbookContent extends StatelessWidget {
  const _TextbookContent({required this.items});

  final List<model.TextbookSection> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.book_outlined),
          title: Text(items[index].title),
          subtitle: Text(
            [
              if (items[index].genre != null) items[index].genre!,
              pageReference(
                printed: items[index].printedPageRange,
                pdf: items[index].pdfPageRange,
              ),
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
        ),
        if (index != items.length - 1) const Divider(),
      ],
    ],
  );
}

class _ActivitiesContent extends StatelessWidget {
  const _ActivitiesContent({required this.items});

  final List<model.Activity> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
          title: Text(items[index].title),
          subtitle: Text(
            [
              if (items[index].activityType != null) items[index].activityType!,
              pageReference(
                printed: items[index].printedPage,
                pdf: items[index].pdfPage,
              ),
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
          children: [
            if (items[index].studentAction != null)
              LabeledValue(
                label: 'Öğrenci ne yapacak?',
                value: items[index].studentAction!,
                icon: Icons.person_outline,
              ),
            if (items[index].expectedEvidence != null) ...[
              const SizedBox(height: AppSpacing.md),
              LabeledValue(
                label: 'Beklenen ürün',
                value: items[index].expectedEvidence!,
                icon: Icons.check_circle_outline,
              ),
            ],
          ],
        ),
        if (index != items.length - 1) const Divider(),
      ],
    ],
  );
}

class _FormsContent extends StatelessWidget {
  const _FormsContent({required this.items});

  final List<model.Form> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(items[index].title),
          subtitle: Text(
            [
              if (items[index].assessmentType != null) items[index].assessmentType!,
              if (items[index].structuralType != null) items[index].structuralType!,
              if (items[index].printedPage != null)
                'Basılı s. ${items[index].printedPage}',
            ].join(' · '),
          ),
        ),
        if (index != items.length - 1) const Divider(),
      ],
    ],
  );
}

class _AssessmentContent extends StatelessWidget {
  const _AssessmentContent({
    required this.targetedBindings,
    required this.artifacts,
  });

  final List<model.AssessmentTaskBinding> targetedBindings;
  final List<model.AssessmentArtifact> artifacts;

  @override
  Widget build(BuildContext context) {
    if (targetedBindings.isNotEmpty) {
      return Column(
        children: [
          const StatusPanel(
            icon: Icons.verified_outlined,
            title: 'Doğrudan kazanım hedeflemesi',
            message:
                'Runtime targeted_outcomes verisi bu kazanımı açıkça hedefliyor.',
            tone: StatusTone.positive,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < targetedBindings.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(
                targetedBindings[index].taskTitle ?? 'Değerlendirme görevi',
              ),
              subtitle: targetedBindings[index].evidence == null
                  ? null
                  : Text(targetedBindings[index].evidence!),
            ),
            if (index != targetedBindings.length - 1) const Divider(),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bu araçlar yalnız blok bağlamında erişilebilir; doğrudan bu kazanıma atanmış gibi gösterilmez.',
        ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < artifacts.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.assignment_outlined),
            title: Text(artifacts[index].title),
            subtitle: Text(
              [
                if (artifacts[index].assessmentFamily != null)
                  artifacts[index].assessmentFamily!,
                if (artifacts[index].generationStatus != null)
                  'Durum: ${artifacts[index].generationStatus}',
              ].join(' · '),
            ),
          ),
          if (index != artifacts.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _MaterialsContent extends StatelessWidget {
  const _MaterialsContent({required this.items});

  final List<model.ResourceDecision> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        ResourceDecisionCard(decision: items[index]),
        if (index != items.length - 1) const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}

class _SourcesContent extends StatelessWidget {
  const _SourcesContent({required this.items});

  final List<model.SourceReference> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.article_outlined),
          title: Text(items[index].title),
          subtitle: Text(
            [
              if (items[index].sourceType != null) items[index].sourceType!,
              if (items[index].locator != null) items[index].locator!,
            ].join(' · '),
          ),
        ),
        if (index != items.length - 1) const Divider(),
      ],
    ],
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
