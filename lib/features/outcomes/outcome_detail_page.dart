import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/models/outcome_tracking_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/services/outcome_planning_service.dart';
import '../block/block_detail_page.dart';
import '../shared/feature_widgets.dart';
import '../shared/interaction_polish.dart';
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

class _OutcomeDetailPageState extends State<OutcomeDetailPage>
    with WidgetsBindingObserver {
  late AnnualOutcomePlan _plan;
  late TrackedOutcome _item;
  late final TextEditingController _noteController;
  late String _lastSavedNote;
  Timer? _noteSaveDebounce;
  Future<bool>? _noteSaveInFlight;
  bool _changed = false;
  bool _saving = false;
  bool _noteDirty = false;
  bool _noteSaving = false;
  bool _noteSaveFailed = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _plan = widget.initialPlan;
    _item = widget.initialItem;
    _lastSavedNote = _item.teacherNote ?? '';
    _noteController = TextEditingController(text: _lastSavedNote);
    _noteController.addListener(_handleNoteChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _noteSaveDebounce?.cancel();
      unawaited(_persistNote());
    }
  }

  void _handleNoteChanged() {
    final dirty = _noteController.text != _lastSavedNote;
    _noteSaveDebounce?.cancel();
    if (dirty) _scheduleNoteSave();
    if (!mounted) return;
    if (dirty != _noteDirty || _noteSaveFailed) {
      setState(() {
        _noteDirty = dirty;
        _noteSaveFailed = false;
      });
    }
  }

  void _scheduleNoteSave() {
    _noteSaveDebounce?.cancel();
    _noteSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persistNote());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteSaveDebounce?.cancel();
    _noteController.removeListener(_handleNoteChanged);
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

    VoidCallback? primaryAction;
    String? primaryActionLabel;
    IconData? primaryActionIcon;
    if (_item.presentationStatus == OutcomeTrackingStatus.planned) {
      primaryAction = () => _setStatus(OutcomeTrackingStatus.inProgress);
      primaryActionLabel = 'Başla';
      primaryActionIcon = Icons.play_arrow_rounded;
    } else if (_item.presentationStatus != OutcomeTrackingStatus.completed) {
      primaryAction = () => _setStatus(OutcomeTrackingStatus.completed);
      primaryActionLabel = 'İşlendi';
      primaryActionIcon = Icons.check_rounded;
    }

    final moreSections = <Widget>[
      _DisclosureSection(
        title: 'Takip seçenekleri',
        subtitle: 'Yalnızca ikincil durumlar ve başka haftaya taşıma',
        icon: Icons.fact_check_outlined,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (_item.status == OutcomeTrackingStatus.partiallyCompleted)
              _StatusButton(
                label: 'Devam ediyor',
                icon: Icons.play_circle_outline,
                selected: false,
                onPressed: () => _setStatus(OutcomeTrackingStatus.inProgress),
              )
            else if (_item.status != OutcomeTrackingStatus.completed)
              _StatusButton(
                label: 'Kısmen işlendi',
                icon: Icons.timelapse_outlined,
                selected: false,
                onPressed: () =>
                    _setStatus(OutcomeTrackingStatus.partiallyCompleted),
              ),
            if (_item.status != OutcomeTrackingStatus.planned)
              _StatusButton(
                label: 'Planlıya döndür',
                icon: Icons.restart_alt,
                selected: false,
                onPressed: () => _setStatus(OutcomeTrackingStatus.planned),
              ),
            OutlinedButton.icon(
              onPressed: _saving ? null : _carry,
              icon: const Icon(Icons.redo_outlined),
              label: const Text('Başka haftaya taşı'),
            ),
          ],
        ),
      ),
      _DisclosureSection(
        title: 'Öğretmen notu',
        subtitle: _noteDirty || _lastSavedNote.trim().isNotEmpty
            ? 'Bu kazanıma bağlı bir not var'
            : 'Kısa yerel not ekle',
        icon: Icons.sticky_note_2_outlined,
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
            const SizedBox(height: AppSpacing.sm),
            _buildNoteSaveStatus(),
          ],
        ),
      ),
      if (outcome.processComponents?.isNotEmpty == true)
        _DisclosureSection(
          title: 'Süreç bileşenleri',
          subtitle: _processComponentSubtitle(outcome.processComponentOrigin),
          icon: Icons.account_tree_outlined,
          child: _ProcessComponentsView(raw: outcome.processComponents!),
        ),
      _DisclosureSection(
        title: 'Plan ve blok bağlamı',
        subtitle: _item.contexts.isEmpty
            ? 'Doğrulanmış blok bağlamı yok'
            : '${_item.contexts.length} doğrulanmış blok bağlamı',
        icon: Icons.view_agenda_outlined,
        child: _item.contexts.isEmpty
            ? const StatusPanel(
                icon: Icons.info_outline,
                title: 'Blok bağlamı bulunamadı',
                message:
                    'Bu haftalık projection için doğrulanmış blok bağlamı yok.',
              )
            : Column(
                children: [
                  for (var index = 0;
                      index < _item.contexts.length;
                      index++) ...[
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
                ],
              ),
      ),
      if (textbook.isNotEmpty || activities.isNotEmpty)
        _DisclosureSection(
          title: 'Kitap ve etkinlik ayrıntıları',
          subtitle:
              '${textbook.length} kitap bölümü · ${activities.length} etkinlik',
          icon: Icons.menu_book_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                const SizedBox(height: AppSpacing.md),
              ],
              for (var index = 0; index < activities.length; index++) ...[
                InfoCard(
                  title: activities[index].title,
                  subtitle: activities[index].activityType,
                  icon: Icons.task_alt_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activities[index].studentAction != null)
                        Text(
                          activities[index].studentAction!,
                          style: const TextStyle(height: 1.4),
                        ),
                      if (activities[index].printedPage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Kitap: s. ${activities[index].printedPage}'),
                      ],
                    ],
                  ),
                ),
                if (index != activities.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      if (forms.isNotEmpty)
        _DisclosureSection(
          title: 'Formlar',
          subtitle: '${forms.length} değerlendirme/form öğesi',
          icon: Icons.description_outlined,
          child: Column(
            children: [
              for (var index = 0; index < forms.length; index++) ...[
                InfoCard(
                  title: forms[index].title,
                  subtitle:
                      forms[index].assessmentType ?? forms[index].structuralType,
                  icon: Icons.description_outlined,
                  child: Text(
                    forms[index].printedPage == null
                        ? 'Sayfa bilgisi doğrulanmış runtime verisinde belirtilmemiş.'
                        : 'Basılı kitap: s. ${forms[index].printedPage}',
                  ),
                ),
                if (index != forms.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      if (targetedBindings.isNotEmpty || artifacts.isNotEmpty)
        _DisclosureSection(
          title: 'Değerlendirme',
          subtitle: targetedBindings.isNotEmpty
              ? '${targetedBindings.length} doğrudan hedeflenen görev'
              : '${artifacts.length} blok değerlendirme aracı',
          icon: Icons.assignment_outlined,
          child: Column(
            children: [
              if (targetedBindings.isNotEmpty)
                for (var index = 0;
                    index < targetedBindings.length;
                    index++) ...[
                  InfoCard(
                    title: targetedBindings[index].taskTitle ??
                        'Değerlendirme görevi',
                    subtitle: 'Doğrudan kazanım hedeflemesi',
                    icon: Icons.fact_check_outlined,
                    child: Text(
                      targetedBindings[index].evidence ??
                          'Ek kanıt açıklaması runtime verisinde belirtilmemiş.',
                    ),
                  ),
                  if (index != targetedBindings.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ]
              else
                for (var index = 0; index < artifacts.length; index++) ...[
                  InfoCard(
                    title: artifacts[index].title,
                    subtitle: artifacts[index].assessmentFamily,
                    icon: Icons.assignment_outlined,
                    child: Text(
                      artifacts[index].generationStatus == null
                          ? 'Blok değerlendirme bağlamı'
                          : 'Durum: ${artifacts[index].generationStatus}',
                    ),
                  ),
                  if (index != artifacts.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
            ],
          ),
        ),
      if (decisions.isNotEmpty)
        _DisclosureSection(
          title: 'Materyal / kaynak kararları',
          subtitle: '${decisions.length} doğrulanmış kaynak kararı',
          icon: Icons.inventory_2_outlined,
          child: Column(
            children: [
              for (var index = 0; index < decisions.length; index++) ...[
                ResourceDecisionCard(decision: decisions[index]),
                if (index != decisions.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      if (sources.isNotEmpty)
        _DisclosureSection(
          title: 'Kaynak referansları',
          subtitle: '${sources.length} runtime kaynak izi',
          icon: Icons.link_outlined,
          child: Column(
            children: [
              for (var index = 0; index < sources.length; index++) ...[
                InfoCard(
                  title: sources[index].title,
                  subtitle: sources[index].sourceType,
                  icon: Icons.link_outlined,
                  child: SelectableText(
                    sources[index].locator ?? 'Konum bilgisi yok',
                  ),
                ),
                if (index != sources.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_closePage());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(outcome.code),
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: _closing ? null : () => unawaited(_closePage()),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: AppPage(
          maxWidth: 900,
          children: [
            PageHeader(
              eyebrow: 'Kazanım',
              title: outcome.code,
              description: outcome.officialText,
              trailing: OutcomeStatusChip(status: _item.presentationStatus),
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
              'Derste lazım',
              subtitle: 'Derse girerken ihtiyaç duyulan kısa görünüm',
              icon: Icons.bolt_outlined,
            ),
            _LessonReadyCard(
              item: _item,
              sourceWeek: sourceWeek,
              textbook: textbook,
              activities: activities,
              primaryAction: _saving ? null : primaryAction,
              primaryActionLabel: primaryActionLabel,
              primaryActionIcon: primaryActionIcon,
              onCopyDiary: _copyDiaryText,
            ),
            const SizedBox(height: AppSpacing.md),
            _MoreInformationPanel(sections: moreSections),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSaveStatus() {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (_noteSaving) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Kaydediliyor…', style: style),
        ],
      );
    }
    if (_noteSaveFailed) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => unawaited(_persistNote()),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Not kaydedilemedi · tekrar dene'),
        ),
      );
    }
    return Row(
      children: [
        Icon(
          _noteDirty ? Icons.schedule_outlined : Icons.check_circle_outline,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _noteDirty ? 'Otomatik kaydedilecek' : 'Kaydedildi',
          style: style,
        ),
      ],
    );
  }

  Future<void> _setStatus(OutcomeTrackingStatus status) async {
    if (!await _persistNote() || !mounted) return;
    final itemBefore = _item;
    LearningOutcomeTrackingRecord? before;
    try {
      before = await widget.service.captureTracking(itemBefore);
    } on Object {
      _showMutationError();
      return;
    }
    final saved = await _mutate(
      () => widget.service.setStatus(itemBefore, status),
    );
    if (!saved || !mounted) return;
    if (status == OutcomeTrackingStatus.completed) {
      HapticFeedback.mediumImpact();
    }
    showTeacherUndoFeedback(
      context,
      _statusChangeMessage(status),
      onUndo: () async {
        if (!await _persistNote() || !mounted) return;
        final restored = await _mutate(
          () => widget.service.restoreTrackingStatus(
            itemBefore,
            before,
            displayWeekNumber: itemBefore.displayWeekNumber,
          ),
        );
        if (restored && mounted) {
          showTeacherFeedback(context, 'Değişiklik geri alındı.');
        }
      },
    );
  }

  Future<bool> _persistNote() async {
    _noteSaveDebounce?.cancel();
    final inFlight = _noteSaveInFlight;
    if (inFlight != null) {
      await inFlight;
    }
    if (!_noteDirty) return true;

    final text = _noteController.text;
    late final Future<bool> future;
    future = _writeNote(text);
    _noteSaveInFlight = future;
    final saved = await future;
    if (identical(_noteSaveInFlight, future)) {
      _noteSaveInFlight = null;
    }
    return saved;
  }

  Future<bool> _writeNote(String text) async {
    if (mounted) {
      setState(() {
        _noteSaving = true;
        _noteSaveFailed = false;
      });
    }
    try {
      await widget.service.saveTeacherNote(_item, text);
      if (!mounted) return true;
      _lastSavedNote = text;
      final stillDirty = _noteController.text != _lastSavedNote;
      setState(() {
        _noteSaving = false;
        _noteDirty = stillDirty;
        _noteSaveFailed = false;
        _changed = true;
      });
      if (stillDirty) _scheduleNoteSave();
      return true;
    } on Object {
      if (mounted) {
        setState(() {
          _noteSaving = false;
          _noteDirty = _noteController.text != _lastSavedNote;
          _noteSaveFailed = true;
        });
      }
      return false;
    }
  }

  Future<void> _closePage() async {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    final noteSaved = await _persistNote();
    if (!mounted) return;
    _closing = false;
    if (!noteSaved) {
      showTeacherFeedback(
        context,
        'Not henüz kaydedilemedi. Bağlantıyı veya depolamayı kontrol edip tekrar deneyin.',
        duration: const Duration(seconds: 4),
      );
      return;
    }
    Navigator.pop(context, _changed);
  }

  Future<void> _carry() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await _persistNote() || !mounted) return;
    final targets = _plan.weeks
        .where(
          (summary) =>
              !summary.week.isEventWeek &&
              summary.week.weekNumber > _item.plannedWeekNumber,
        )
        .toList(growable: false);
    if (targets.isEmpty) {
      showTeacherFeedback(context, 'Taşınabilecek sonraki öğretim haftası yok.');
      return;
    }
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
    if (target == null || !mounted) return;

    final itemBefore = _item;
    LearningOutcomeTrackingRecord? before;
    try {
      before = await widget.service.captureTracking(itemBefore);
    } on Object {
      _showMutationError();
      return;
    }
    final saved = await _mutate(
      () => widget.service.carryToWeek(
        item: itemBefore,
        targetWeekNumber: target,
        plan: _plan,
      ),
    );
    if (!saved || !mounted) return;
    HapticFeedback.mediumImpact();
    showTeacherUndoFeedback(
      context,
      '$target. haftaya taşındı.',
      onUndo: () async {
        if (!await _persistNote() || !mounted) return;
        final restored = await _mutate(
          () => widget.service.restoreTrackingStatus(
            itemBefore,
            before,
            displayWeekNumber: itemBefore.displayWeekNumber,
          ),
        );
        if (restored && mounted) {
          showTeacherFeedback(context, 'Taşıma geri alındı.');
        }
      },
    );
  }

  Future<bool> _mutate(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_saving) return false;
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
      if (!mounted) return false;
      setState(() {
        _plan = refreshed;
        if (next != null) _item = next;
        _lastSavedNote = _item.teacherNote ?? '';
        _noteDirty = _noteController.text != _lastSavedNote;
        _noteSaveFailed = false;
        _changed = true;
      });
      if (successMessage != null && mounted) {
        showTeacherFeedback(context, successMessage);
      }
      return true;
    } on Object {
      if (!mounted) return false;
      _showMutationError();
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMutationError() {
    if (!mounted) return;
    showTeacherFeedback(
      context,
      'Değişiklik kaydedilemedi. Tekrar deneyin.',
      duration: const Duration(seconds: 4),
    );
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
    showTeacherFeedback(context, 'Kazanım özeti kopyalandı.');
  }
}

class _LessonReadyCard extends StatelessWidget {
  const _LessonReadyCard({
    required this.item,
    required this.sourceWeek,
    required this.textbook,
    required this.activities,
    required this.primaryAction,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onCopyDiary,
  });

  final TrackedOutcome item;
  final AcademicWeekPlan? sourceWeek;
  final List<model.TextbookSection> textbook;
  final List<model.Activity> activities;
  final VoidCallback? primaryAction;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback onCopyDiary;

  @override
  Widget build(BuildContext context) {
    final firstBook = textbook.isEmpty ? null : textbook.first;
    final firstActivity = activities.isEmpty ? null : activities.first;
    final completed =
        item.presentationStatus == OutcomeTrackingStatus.completed;

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sourceWeek != null)
              _LessonCue(
                icon: Icons.calendar_today_outlined,
                label: 'Planlanan hafta',
                value:
                    '${sourceWeek!.weekNumber}. Hafta · ${outcomeDateRange(sourceWeek!.start, sourceWeek!.end)}',
              ),
            if (item.primaryTheme != null) ...[
              const SizedBox(height: AppSpacing.md),
              _LessonCue(
                icon: Icons.auto_stories_outlined,
                label: 'Tema',
                value: item.primaryTheme!.title,
              ),
            ],
            if (item.primaryBlock != null) ...[
              const SizedBox(height: AppSpacing.md),
              _LessonCue(
                icon: Icons.view_agenda_outlined,
                label: 'Blok',
                value: item.primaryBlock!.title,
              ),
            ],
            if (firstBook != null) ...[
              const SizedBox(height: AppSpacing.md),
              _LessonCue(
                icon: Icons.book_outlined,
                label: 'Kitap',
                value: _bookCue(firstBook, textbook.length),
              ),
            ],
            if (firstActivity != null) ...[
              const SizedBox(height: AppSpacing.md),
              _LessonCue(
                icon: Icons.task_alt_outlined,
                label: 'Etkinlik',
                value: _activityCue(firstActivity, activities.length),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (completed)
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Bu kazanım işlendi.',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            if (completed) const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (primaryActionLabel != null && primaryActionIcon != null)
                  FilledButton.icon(
                    onPressed: primaryAction,
                    icon: Icon(primaryActionIcon),
                    label: Text(primaryActionLabel!),
                  ),
                OutlinedButton.icon(
                  onPressed: onCopyDiary,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Deftere kopyala'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonCue extends StatelessWidget {
  const _LessonCue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.sm),
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
            Text(value, style: const TextStyle(height: 1.35)),
          ],
        ),
      ),
    ],
  );
}

class _ProcessComponentsView extends StatelessWidget {
  const _ProcessComponentsView({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final components = model.jsonObjectList(raw);
    if (components.isEmpty) {
      return SelectableText(raw, style: const TextStyle(height: 1.5));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < components.length; index++) ...[
          _ProcessComponentRow(component: components[index]),
          if (index != components.length - 1)
            const Divider(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _ProcessComponentRow extends StatelessWidget {
  const _ProcessComponentRow({required this.component});

  final Map<String, dynamic> component;

  @override
  Widget build(BuildContext context) {
    final code = _firstNonEmpty(component, const [
      'component_code',
      'component_code_normalized',
    ]);
    final text = _firstNonEmpty(component, const [
      'component_verbatim',
      'component_title',
      'component_title_verbatim',
    ]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.subdirectory_arrow_right, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SelectableText(
            [?code, ?text].join(' — '),
            style: const TextStyle(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _MoreInformationPanel extends StatelessWidget {
  const _MoreInformationPanel({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const Icon(Icons.unfold_more_outlined),
      title: const Text(
        'Daha fazla bilgi',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Takip, notlar, plan bağlamı, değerlendirme ve kaynaklar',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          sections[index],
          if (index != sections.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _DisclosureSection extends StatelessWidget {
  const _DisclosureSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    childrenPadding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    children: [Align(alignment: Alignment.centerLeft, child: child)],
  );
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
      ? FilledButton.tonalIcon(
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

String _statusChangeMessage(OutcomeTrackingStatus status) => switch (status) {
  OutcomeTrackingStatus.planned => 'Planlı durumuna döndürüldü.',
  OutcomeTrackingStatus.inProgress => 'Devam ediyor olarak işaretlendi.',
  OutcomeTrackingStatus.completed => 'İşlendi olarak işaretlendi.',
  OutcomeTrackingStatus.partiallyCompleted => 'Kısmen işlendi olarak işaretlendi.',
  OutcomeTrackingStatus.carriedOver => 'Taşındı olarak işaretlendi.',
};

String _processComponentSubtitle(String? origin) {
  switch (origin) {
    case 'ROOF_INHERITED':
      return 'Resmî programın ortak çatı tanımından devralındı';
    case 'THEME_EXPLICIT':
      return 'Bu tema için resmî programda açıkça tanımlandı';
    case 'SOURCE_VERIFIED_NONE':
      return 'Resmî kaynakta süreç bileşeni olmadığı doğrulandı';
    case null:
      return 'Resmî programdaki ayrıntılı süreç ifadesi';
    default:
      return 'Resmî süreç kaynağı: $origin';
  }
}

String? _firstNonEmpty(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String _bookCue(model.TextbookSection section, int count) {
  final parts = <String>[section.title];
  if (section.printedPageRange != null) {
    parts.add('s. ${section.printedPageRange}');
  } else if (section.pdfPageRange != null) {
    parts.add('PDF ${section.pdfPageRange}');
  }
  if (count > 1) parts.add('+${count - 1} bölüm');
  return parts.join(' · ');
}

String _activityCue(model.Activity activity, int count) {
  final parts = <String>[activity.title];
  if (activity.printedPage != null) parts.add('s. ${activity.printedPage}');
  if (count > 1) parts.add('+${count - 1} etkinlik');
  return parts.join(' · ');
}

List<T> _uniqueBy<T>(Iterable<T> items, String Function(T item) idOf) {
  final seen = <String>{};
  final result = <T>[];
  for (final item in items) {
    if (seen.add(idOf(item))) result.add(item);
  }
  return result;
}
