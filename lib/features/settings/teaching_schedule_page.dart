import 'package:flutter/material.dart';

import '../../domain/models/instruction_context_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/instruction_context_repository.dart';
import '../../domain/services/assignment_lesson_timeline_service.dart';
import '../../domain/services/assignment_progress_cursor_service.dart';
import '../shared/feature_widgets.dart';
import '../shared/interaction_polish.dart';

class TeachingSchedulePage extends StatefulWidget {
  const TeachingSchedulePage({
    super.key,
    required this.repository,
    required this.weeklyPlanning,
    required this.timeline,
    required this.courseId,
    required this.grade,
  });

  final InstructionContextRepository repository;
  final WeeklyPlanningService weeklyPlanning;
  final AssignmentLessonTimelineService timeline;
  final String courseId;
  final int grade;

  @override
  State<TeachingSchedulePage> createState() => _TeachingSchedulePageState();
}

class _TeachingSchedulePageState extends State<TeachingSchedulePage> {
  late Future<_SchedulePageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SchedulePageData> _load() async {
    final plan = await widget.weeklyPlanning.buildPlan();
    final classes = await widget.repository.getClasses(plan.academicYear);
    final assignments = await widget.repository.getAssignments(
      academicYear: plan.academicYear,
      courseId: widget.courseId,
      activeOnly: false,
    );
    final periods = await widget.repository.getBellPeriods();
    final slots = await widget.repository.getScheduleSlotsForAssignments(
      assignments.map((item) => item.id),
    );
    return _SchedulePageData(
      academicYear: plan.academicYear,
      classes: classes,
      assignments: assignments,
      periods: periods,
      slots: slots,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _addClass(_SchedulePageData data) async {
    final section = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddClassSheet(grade: widget.grade),
    );
    if (section == null || section.trim().isEmpty) return;
    final normalizedSection = section.trim().toUpperCase();
    final displayName = '${widget.grade}/$normalizedSection';
    if (data.classes.any(
      (item) =>
          item.academicYear == data.academicYear &&
          item.displayName.toUpperCase() == displayName.toUpperCase(),
    )) {
      if (mounted) showTeacherFeedback(context, '$displayName zaten ekli.');
      return;
    }

    final now = DateTime.now();
    final suffix = _safeId('${widget.grade}_$normalizedSection');
    final classId = 'class_${_safeId(data.academicYear)}_$suffix';
    final assignmentId =
        'assignment_${_safeId(data.academicYear)}_${_safeId(widget.courseId)}_$suffix';
    try {
      await widget.repository.saveClass(
        SchoolClass(
          id: classId,
          academicYear: data.academicYear,
          grade: widget.grade,
          section: normalizedSection,
          displayName: displayName,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await widget.repository.saveAssignment(
        TeachingAssignment(
          id: assignmentId,
          academicYear: data.academicYear,
          courseId: widget.courseId,
          classId: classId,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      _reload();
      showTeacherFeedback(context, '$displayName eklendi.');
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Sınıf eklenemedi. Tekrar deneyin.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _editBellPeriods(_SchedulePageData data) async {
    final periods = await showModalBottomSheet<List<BellPeriod>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BellPeriodsSheet(initial: data.periods),
    );
    if (periods == null) return;
    try {
      await widget.repository.replaceBellPeriods(periods);
      if (!mounted) return;
      _reload();
      showTeacherFeedback(context, 'Ders saatleri kaydedildi.');
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Ders saatleri kaydedilemedi. Programda kullanılan bir saati silmiş olabilirsiniz.',
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _editAssignmentSchedule(
    _SchedulePageData data,
    TeachingAssignment assignment,
  ) async {
    if (data.periods.isEmpty) {
      showTeacherFeedback(context, 'Önce ders saatlerini tanımlayın.');
      return;
    }
    final currentSlots = data.slots
        .where((slot) => slot.assignmentId == assignment.id)
        .toList(growable: false);
    final occupied = <_ScheduleCell, String>{};
    for (final slot in data.slots) {
      if (slot.assignmentId == assignment.id) continue;
      occupied[_ScheduleCell(slot.weekday, slot.periodNumber)] =
          slot.assignmentId;
    }
    final selected = await showModalBottomSheet<Set<_ScheduleCell>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AssignmentScheduleSheet(
        periods: data.periods,
        initial: currentSlots
            .map((slot) => _ScheduleCell(slot.weekday, slot.periodNumber))
            .toSet(),
        occupied: occupied.keys.toSet(),
      ),
    );
    if (selected == null) return;

    try {
      final before = await widget.timeline.resolve(
        academicYear: data.academicYear,
        courseId: widget.courseId,
      );
      final oldPlanned = before.positionFor(assignment.id)?.plannedOrdinal ?? 0;
      final now = DateTime.now();
      final slots = selected
          .map(
            (cell) => LessonScheduleSlot(
              id: 'slot_${_safeId(assignment.id)}_${cell.weekday}_${cell.period}',
              assignmentId: assignment.id,
              weekday: cell.weekday,
              periodNumber: cell.period,
              createdAt: now,
              updatedAt: now,
            ),
          )
          .toList(growable: false);
      await widget.repository.replaceScheduleSlotsForAssignment(
        assignmentId: assignment.id,
        slots: slots,
      );
      final after = await widget.timeline.resolve(
        academicYear: data.academicYear,
        courseId: widget.courseId,
      );
      final newPlanned = after.positionFor(assignment.id)?.plannedOrdinal ?? 0;
      await AssignmentProgressCursorService(
        repository: widget.repository,
      ).reanchorForScheduleChange(
        assignmentId: assignment.id,
        oldPlannedOrdinal: oldPlanned,
        newPlannedOrdinal: newPlanned,
      );
      if (!mounted) return;
      _reload();
      showTeacherFeedback(context, 'Ders programı kaydedildi.');
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Ders programı kaydedilemedi. Aynı saatte başka bir sınıf olabilir.',
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _deleteAssignment(
    _SchedulePageData data,
    TeachingAssignment assignment,
  ) async {
    final schoolClass = data.classFor(assignment.classId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${schoolClass?.displayName ?? 'Sınıf'} kaldırılsın mı?'),
        content: const Text(
          'Bu sınıfın ders programı ve sınıfa bağlı yeni ilerleme kayıtları kaldırılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteAssignment(assignment.id);
      final classStillUsed = (await widget.repository.getAssignments(
        academicYear: data.academicYear,
        activeOnly: false,
      )).any((item) => item.classId == assignment.classId);
      if (!classStillUsed) {
        await widget.repository.deleteClass(assignment.classId);
      }
      if (!mounted) return;
      _reload();
      showTeacherFeedback(context, 'Sınıf kaldırıldı.');
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(context, 'Sınıf kaldırılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sınıflar ve ders programı')),
    body: FutureBuilder<_SchedulePageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const LoadingView(label: 'Ders programı hazırlanıyor…');
        }
        if (!snapshot.hasData) {
          return FeatureErrorView(
            message: 'Ders programı yüklenemedi.',
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        return AppPage(
          children: [
            SectionHeading(
              'Ders saatleri',
              subtitle: data.periods.isEmpty
                  ? 'ŞU AN dersini bulmak için okulunuzun zil saatlerini bir kez tanımlayın.'
                  : '${data.periods.length} ders saati tanımlı',
              icon: Icons.access_time_rounded,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.periods.isNotEmpty)
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final period in data.periods)
                            Chip(
                              label: Text(
                                '${period.periodNumber}. ders · ${_formatMinute(period.startMinute)}–${_formatMinute(period.endMinute)}',
                              ),
                            ),
                        ],
                      ),
                    if (data.periods.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    FilledButton.tonalIcon(
                      onPressed: () => _editBellPeriods(data),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        data.periods.isEmpty
                            ? 'Ders saatlerini tanımla'
                            : 'Ders saatlerini düzenle',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionHeading(
              '${widget.grade}. sınıf şubeleri',
              subtitle:
                  'Aynı dersin her şubesi kendi gerçek ilerleme konumunu tutar.',
              icon: Icons.groups_2_outlined,
            ),
            if (data.courseAssignments(widget.courseId).isEmpty)
              const FeatureEmptyView(
                icon: Icons.class_outlined,
                title: 'Henüz sınıf eklenmedi',
                message:
                    'Derse girdiğiniz şubeleri ekleyin; her şubenin programı ve ilerlemesi ayrı tutulacak.',
              )
            else
              for (final assignment in data.courseAssignments(widget.courseId))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _AssignmentCard(
                    schoolClass: data.classFor(assignment.classId),
                    slots: data.slots
                        .where((slot) => slot.assignmentId == assignment.id)
                        .toList(growable: false),
                    periods: data.periods,
                    onEdit: () =>
                        _editAssignmentSchedule(data, assignment),
                    onDelete: () => _deleteAssignment(data, assignment),
                  ),
                ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () => _addClass(data),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Sınıf ekle'),
            ),
          ],
        );
      },
    ),
  );
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.schoolClass,
    required this.slots,
    required this.periods,
    required this.onEdit,
    required this.onDelete,
  });

  final SchoolClass? schoolClass;
  final List<LessonScheduleSlot> slots;
  final List<BellPeriod> periods;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ordered = [...slots]
      ..sort((a, b) {
        final day = a.weekday.compareTo(b.weekday);
        return day != 0 ? day : a.periodNumber.compareTo(b.periodNumber);
      });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schoolClass?.displayName ?? 'Sınıf',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sınıfı kaldır',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (ordered.isEmpty)
              Text(
                'Ders programı henüz girilmedi.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final slot in ordered)
                    Chip(
                      label: Text(
                        '${_weekdayShort(slot.weekday)} · ${slot.periodNumber}. ders',
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Programı düzenle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddClassSheet extends StatefulWidget {
  const _AddClassSheet({required this.grade});

  final int grade;

  @override
  State<_AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<_AddClassSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.grade}. sınıf şubesi ekle',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Şube',
            hintText: 'A',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _submit,
          child: const Text('Ekle'),
        ),
      ],
    ),
  );

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }
}

class _BellPeriodsSheet extends StatefulWidget {
  const _BellPeriodsSheet({required this.initial});

  final List<BellPeriod> initial;

  @override
  State<_BellPeriodsSheet> createState() => _BellPeriodsSheetState();
}

class _BellPeriodsSheetState extends State<_BellPeriodsSheet> {
  late final List<_PeriodDraft> _drafts;

  @override
  void initState() {
    super.initState();
    final source = widget.initial.isEmpty ? _defaultPeriods() : widget.initial;
    _drafts = [
      for (final item in source)
        _PeriodDraft(
          start: TextEditingController(text: _formatMinute(item.startMinute)),
          end: TextEditingController(text: _formatMinute(item.endMinute)),
        ),
    ];
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.start.dispose();
      draft.end.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 640),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ders saatleri',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Başlangıç değerleri örnektir; okulunuzun zil saatlerine göre düzenleyin.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final draft = _drafts[index];
                return Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${index + 1}. ders',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: draft.start,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Başlangıç',
                          hintText: '08:30',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: draft.end,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Bitiş',
                          hintText: '09:10',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (_drafts.length > 1) ...[
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        tooltip: 'Ders saatini kaldır',
                        onPressed: () => setState(() {
                          final removed = _drafts.removeAt(index);
                          removed.start.dispose();
                          removed.end.dispose();
                        }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              final previous = _drafts.last;
              final previousEnd = _parseMinute(previous.end.text) ?? 8 * 60 + 30;
              final start = previousEnd + 10;
              _drafts.add(
                _PeriodDraft(
                  start: TextEditingController(text: _formatMinute(start)),
                  end: TextEditingController(text: _formatMinute(start + 40)),
                ),
              );
            }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ders saati ekle'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );

  void _save() {
    final periods = <BellPeriod>[];
    for (var index = 0; index < _drafts.length; index++) {
      final start = _parseMinute(_drafts[index].start.text);
      final end = _parseMinute(_drafts[index].end.text);
      if (start == null || end == null || end <= start) {
        showTeacherFeedback(context, '${index + 1}. ders saati geçersiz.');
        return;
      }
      periods.add(
        BellPeriod(
          periodNumber: index + 1,
          startMinute: start,
          endMinute: end,
        ),
      );
    }
    Navigator.of(context).pop(periods);
  }

  List<BellPeriod> _defaultPeriods() {
    const start = 8 * 60 + 30;
    return List.generate(8, (index) {
      final periodStart = start + index * 50;
      return BellPeriod(
        periodNumber: index + 1,
        startMinute: periodStart,
        endMinute: periodStart + 40,
      );
    });
  }
}

class _AssignmentScheduleSheet extends StatefulWidget {
  const _AssignmentScheduleSheet({
    required this.periods,
    required this.initial,
    required this.occupied,
  });

  final List<BellPeriod> periods;
  final Set<_ScheduleCell> initial;
  final Set<_ScheduleCell> occupied;

  @override
  State<_AssignmentScheduleSheet> createState() =>
      _AssignmentScheduleSheetState();
}

class _AssignmentScheduleSheetState extends State<_AssignmentScheduleSheet> {
  late final Set<_ScheduleCell> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 680),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Haftalık ders programı',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bu sınıfa girdiğiniz ders saatlerini seçin. Dolu görünen saat başka bir sınıfa atanmıştır.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var weekday = DateTime.monday;
                    weekday <= DateTime.friday;
                    weekday++) ...[
                  Text(
                    _weekdayLong(weekday),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final period in widget.periods)
                        Builder(
                          builder: (context) {
                            final cell = _ScheduleCell(
                              weekday,
                              period.periodNumber,
                            );
                            final occupied = widget.occupied.contains(cell);
                            return FilterChip(
                              selected: _selected.contains(cell),
                              onSelected: occupied
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected) {
                                        _selected.add(cell);
                                      } else {
                                        _selected.remove(cell);
                                      }
                                    }),
                              label: Text(
                                occupied
                                    ? '${period.periodNumber}. ders · dolu'
                                    : '${period.periodNumber}. ders',
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
}

class _SchedulePageData {
  const _SchedulePageData({
    required this.academicYear,
    required this.classes,
    required this.assignments,
    required this.periods,
    required this.slots,
  });

  final String academicYear;
  final List<SchoolClass> classes;
  final List<TeachingAssignment> assignments;
  final List<BellPeriod> periods;
  final List<LessonScheduleSlot> slots;

  SchoolClass? classFor(String classId) {
    for (final item in classes) {
      if (item.id == classId) return item;
    }
    return null;
  }

  List<TeachingAssignment> courseAssignments(String courseId) => assignments
      .where((item) => item.courseId == courseId)
      .toList(growable: false);
}

class _PeriodDraft {
  const _PeriodDraft({required this.start, required this.end});

  final TextEditingController start;
  final TextEditingController end;
}

class _ScheduleCell {
  const _ScheduleCell(this.weekday, this.period);

  final int weekday;
  final int period;

  @override
  bool operator ==(Object other) =>
      other is _ScheduleCell &&
      other.weekday == weekday &&
      other.period == period;

  @override
  int get hashCode => Object.hash(weekday, period);
}

String _safeId(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _formatMinute(int minute) {
  final hour = (minute ~/ 60).toString().padLeft(2, '0');
  final mins = (minute % 60).toString().padLeft(2, '0');
  return '$hour:$mins';
}

int? _parseMinute(String text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String _weekdayShort(int weekday) => switch (weekday) {
  DateTime.monday => 'Pzt',
  DateTime.tuesday => 'Sal',
  DateTime.wednesday => 'Çar',
  DateTime.thursday => 'Per',
  DateTime.friday => 'Cum',
  DateTime.saturday => 'Cmt',
  _ => 'Paz',
};

String _weekdayLong(int weekday) => switch (weekday) {
  DateTime.monday => 'Pazartesi',
  DateTime.tuesday => 'Salı',
  DateTime.wednesday => 'Çarşamba',
  DateTime.thursday => 'Perşembe',
  DateTime.friday => 'Cuma',
  DateTime.saturday => 'Cumartesi',
  _ => 'Pazar',
};
