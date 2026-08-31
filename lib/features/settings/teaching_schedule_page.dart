import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/preferences/legacy_migration_decision_repository.dart';
import '../../domain/models/instruction_context_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/instruction_context_repository.dart';
import '../../domain/runtime/course_runtime_registry.dart';
import '../../domain/services/assignment_lesson_timeline_service.dart';
import '../../domain/services/assignment_progress_cursor_service.dart';
import '../../domain/services/bell_schedule_builder.dart';
import '../../domain/services/legacy_teacher_state_migration_service.dart';
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
    this.legacyMigration,
    this.legacyMigrationDecision,
  });

  final InstructionContextRepository repository;
  final WeeklyPlanningService weeklyPlanning;
  final AssignmentLessonTimelineService timeline;
  final String courseId;
  final int grade;
  final LegacyTeacherStateMigrationService? legacyMigration;
  final LegacyMigrationDecisionRepository? legacyMigrationDecision;

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
      activeOnly: false,
    );
    final courseAssignments = assignments
        .where((item) => item.courseId == widget.courseId)
        .toList(growable: false);
    final periods = await widget.repository.getBellPeriods();
    final slots = await widget.repository.getScheduleSlotsForAssignments(
      assignments.map((item) => item.id),
    );
    final allowedOutcomeIds = plan.weeks
        .expand((week) => week.outcomes)
        .map((outcome) => outcome.id)
        .toSet();

    LegacyTeacherStateMigrationPreview? migrationPreview;
    LegacyMigrationDecision? migrationDecision;
    final migration = widget.legacyMigration;
    final decisionRepository = widget.legacyMigrationDecision;
    if (migration != null && decisionRepository != null) {
      try {
        migrationPreview = await migration.preview(
          courseId: widget.courseId,
          academicYear: plan.academicYear,
          allowedOutcomeIds: allowedOutcomeIds,
        );
        migrationDecision = await decisionRepository.get(
          courseId: widget.courseId,
          academicYear: plan.academicYear,
        );
        if (migrationDecision != null &&
            !courseAssignments.any(
              (item) => item.id == migrationDecision!.assignmentId,
            )) {
          await decisionRepository.clear(
            courseId: widget.courseId,
            academicYear: plan.academicYear,
          );
          migrationDecision = null;
        }
      } on Object {
        // Legacy import is optional. Schedule setup must stay usable if the
        // preview/decision preference cannot be read.
        migrationPreview = null;
        migrationDecision = null;
      }
    }

    return _SchedulePageData(
      academicYear: plan.academicYear,
      weeklyLessonHours: plan.weeklyLessonHours,
      classes: classes,
      assignments: assignments,
      periods: periods,
      slots: slots,
      allowedOutcomeIds: allowedOutcomeIds,
      migrationPreview: migrationPreview,
      migrationDecision: migrationDecision,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _addClass(_SchedulePageData data) async {
    final draft = await showModalBottomSheet<_ClassDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddClassSheet(initialGrade: widget.grade),
    );
    if (draft == null || draft.section.trim().isEmpty) return;
    final normalizedSection = draft.section.trim().toUpperCase();
    final targetCourse = supportedCourseRuntimes.firstWhere(
      (course) => course.grade == draft.grade,
    );
    final displayName = '${draft.grade}/$normalizedSection';
    if (data.classes.any(
      (item) =>
          item.academicYear == data.academicYear &&
          item.displayName.trim().toUpperCase() == displayName.toUpperCase(),
    )) {
      if (mounted) showTeacherFeedback(context, '$displayName zaten ekli.');
      return;
    }

    final now = DateTime.now();
    final suffix = _safeId('${draft.grade}_$normalizedSection');
    final classId = 'class_${_safeId(data.academicYear)}_$suffix';
    final assignmentId =
        'assignment_${_safeId(data.academicYear)}_${_safeId(targetCourse.courseId)}_$suffix';
    try {
      await widget.repository.saveClass(
        SchoolClass(
          id: classId,
          academicYear: data.academicYear,
          grade: draft.grade,
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
          courseId: targetCourse.courseId,
          classId: classId,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      _reload();
      final followUp = draft.grade == widget.grade
          ? ''
          : ' Programını görmek için ana ekrandan ${draft.grade}. sınıfı seçin.';
      showTeacherFeedback(
        context,
        '$displayName eklendi.$followUp',
        duration: const Duration(seconds: 4),
      );
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
        expectedWeeklyHours: data.weeklyLessonHours,
        initial: currentSlots
            .map((slot) => _ScheduleCell(slot.weekday, slot.periodNumber))
            .toSet(),
        occupied: occupied.keys.toSet(),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.isNotEmpty && selected.length != data.weeklyLessonHours) {
      showTeacherFeedback(
        context,
        'Bu ders haftada ${data.weeklyLessonHours} saat. '
        '${data.weeklyLessonHours} ders saati seçin veya programı tamamen temizleyin.',
        duration: const Duration(seconds: 5),
      );
      return;
    }

    try {
      final previousCursor = await widget.repository.getProgressCursor(
        assignment.id,
      );
      final hasManualCursor =
          previousCursor?.mode == AssignmentProgressMode.manualOffset;
      int? oldPlannedOrdinal;

      if (hasManualCursor) {
        if (currentSlots.isEmpty &&
            previousCursor!.plannedOrdinalAtAnchor == 0) {
          oldPlannedOrdinal = 0;
        } else {
          try {
            final before = await widget.timeline.resolve(
              academicYear: data.academicYear,
              courseId: widget.courseId,
            );
            oldPlannedOrdinal = before
                .positionFor(assignment.id)
                ?.plannedOrdinal;
          } on Object {
            oldPlannedOrdinal = null;
          }
        }
        if (oldPlannedOrdinal == null) {
          if (!mounted) return;
          showTeacherFeedback(
            context,
            'Gerçek ilerleme konumu doğrulanamadığı için program değiştirilmedi. Tekrar deneyin.',
            duration: const Duration(seconds: 5),
          );
          return;
        }
      }

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

      Future<bool> restorePreviousSchedule() async {
        try {
          await widget.repository.replaceScheduleSlotsForAssignment(
            assignmentId: assignment.id,
            slots: currentSlots,
          );
          return true;
        } on Object {
          return false;
        }
      }

      await widget.repository.replaceScheduleSlotsForAssignment(
        assignmentId: assignment.id,
        slots: slots,
      );

      if (hasManualCursor) {
        int? newPlannedOrdinal;
        if (selected.isEmpty) {
          newPlannedOrdinal = 0;
        } else {
          try {
            final after = await widget.timeline.resolve(
              academicYear: data.academicYear,
              courseId: widget.courseId,
            );
            newPlannedOrdinal = after
                .positionFor(assignment.id)
                ?.plannedOrdinal;
          } on Object {
            newPlannedOrdinal = null;
          }
        }

        if (newPlannedOrdinal == null) {
          final restored = await restorePreviousSchedule();
          if (!mounted) return;
          _reload();
          showTeacherFeedback(
            context,
            restored
                ? 'Yeni programda gerçek ilerleme doğrulanamadı; değişiklik uygulanmadı ve önceki program korundu.'
                : 'Program değişti ancak gerçek ilerleme doğrulanamadı. İlerlemeyi “Düzelt” ile kontrol edin.',
            duration: const Duration(seconds: 6),
          );
          return;
        }

        try {
          await AssignmentProgressCursorService(
            repository: widget.repository,
          ).reanchorForScheduleChange(
            assignmentId: assignment.id,
            oldPlannedOrdinal: oldPlannedOrdinal!,
            newPlannedOrdinal: newPlannedOrdinal,
          );
        } on Object {
          final restored = await restorePreviousSchedule();
          if (!mounted) return;
          _reload();
          showTeacherFeedback(
            context,
            restored
                ? 'Gerçek ilerleme korunamadığı için program değişikliği geri alındı.'
                : 'Program değişti ancak gerçek ilerleme kaydı korunamadı. İlerlemeyi “Düzelt” ile kontrol edin.',
            duration: const Duration(seconds: 6),
          );
          return;
        }
      }

      if (!mounted) return;
      _reload();
      showTeacherFeedback(
        context,
        selected.isEmpty
            ? 'Ders programı temizlendi.'
            : 'Ders programı kaydedildi.',
      );
    } on ScheduleSlotConflictException catch (error) {
      if (!mounted) return;
      final conflictingAssignment = data.assignment(
        error.conflictingAssignmentId,
      );
      final conflictingClass = conflictingAssignment == null
          ? null
          : data.classFor(conflictingAssignment.classId);
      final classLabel = conflictingClass?.displayName;
      showTeacherFeedback(
        context,
        '${_weekdayLong(error.weekday)} ${error.periodNumber}. ders'
        '${classLabel == null ? '' : ' $classLabel'} için zaten dolu.',
        duration: const Duration(seconds: 5),
      );
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Ders programı kaydedilemedi. Tekrar deneyin.',
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
      if (data.migrationDecision?.assignmentId == assignment.id) {
        try {
          await widget.legacyMigrationDecision?.clear(
            courseId: widget.courseId,
            academicYear: data.academicYear,
          );
        } on Object {
          // Optional duplicate-import guard; deletion itself remains authoritative.
        }
      }
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

  Future<void> _migrateLegacyState(_SchedulePageData data) async {
    final migration = widget.legacyMigration;
    final decisionRepository = widget.legacyMigrationDecision;
    final preview = data.migrationPreview;
    final assignments = data.courseAssignments(widget.courseId);
    if (migration == null ||
        decisionRepository == null ||
        preview == null ||
        !preview.hasMigratableData ||
        assignments.isEmpty) {
      return;
    }

    TeachingAssignment? selected;
    if (assignments.length == 1) {
      selected = assignments.first;
    } else {
      final assignmentId = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (_) => _LegacyAssignmentPicker(
          assignments: assignments,
          classes: data.classes,
        ),
      );
      if (assignmentId == null) return;
      selected = data.assignment(assignmentId);
    }
    if (selected == null || !mounted) return;
    final className =
        data.classFor(selected.classId)?.displayName ?? 'seçili şube';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eski takip $className şubesine aktarılsın mı?'),
        content: Text(
          '${preview.migratableRecordCount} eski kayıt bu şubeye kopyalanabilir. '
          'Uygulama bu eşleşmeyi tahmin etmez; yalnızca seçtiğiniz şubeye kopyalar. '
          'Eski kayıtlar silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aktar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    LegacyTeacherStateMigrationReport report;
    try {
      report = await migration.migrateToAssignment(
        assignmentId: selected.id,
        courseId: widget.courseId,
        academicYear: data.academicYear,
        allowedOutcomeIds: data.allowedOutcomeIds,
      );
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Eski takip verisi aktarılamadı. Hiçbir eski kayıt silinmedi.',
        duration: const Duration(seconds: 5),
      );
      return;
    }

    var decisionSaved = true;
    try {
      await decisionRepository.save(
        LegacyMigrationDecision(
          courseId: widget.courseId,
          academicYear: data.academicYear,
          assignmentId: selected.id,
          decidedAt: DateTime.now(),
        ),
      );
    } on Object {
      decisionSaved = false;
    }

    if (!mounted) return;
    _reload();
    final copiedMessage = report.copiedCount == 0
        ? 'Yeni kayıt yok; mevcut şube verileri korundu.'
        : '${report.copiedCount} eski kayıt $className şubesine aktarıldı.';
    showTeacherFeedback(
      context,
      decisionSaved
          ? copiedMessage
          : '$copiedMessage Aktarım tercihi kaydedilemediği için bu soru yeniden görünebilir.',
      duration: const Duration(seconds: 6),
    );
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
        final courseAssignments = data.courseAssignments(widget.courseId);
        final showLegacyMigration =
            data.migrationDecision == null &&
            data.migrationPreview?.hasMigratableData == true &&
            courseAssignments.isNotEmpty;
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
                  'Bu ders haftada ${data.weeklyLessonHours} saat. Her şube kendi programını ve gerçek ilerleme konumunu tutar.',
              icon: Icons.groups_2_outlined,
            ),
            if (courseAssignments.isEmpty)
              const FeatureEmptyView(
                icon: Icons.class_outlined,
                title: 'Henüz sınıf eklenmedi',
                message:
                    'Derse girdiğiniz şubeleri ekleyin; her şubenin programı ve ilerlemesi ayrı tutulacak.',
              )
            else
              for (final assignment in courseAssignments)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _AssignmentCard(
                    schoolClass: data.classFor(assignment.classId),
                    slots: data.slots
                        .where((slot) => slot.assignmentId == assignment.id)
                        .toList(growable: false),
                    periods: data.periods,
                    expectedWeeklyHours: data.weeklyLessonHours,
                    onEdit: () => _editAssignmentSchedule(data, assignment),
                    onDelete: () => _deleteAssignment(data, assignment),
                  ),
                ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () => _addClass(data),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Sınıf ekle'),
            ),
            if (showLegacyMigration) ...[
              const SizedBox(height: AppSpacing.lg),
              _LegacyMigrationCard(
                preview: data.migrationPreview!,
                onMigrate: () => _migrateLegacyState(data),
              ),
            ],
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
    required this.expectedWeeklyHours,
    required this.onEdit,
    required this.onDelete,
  });

  final SchoolClass? schoolClass;
  final List<LessonScheduleSlot> slots;
  final List<BellPeriod> periods;
  final int expectedWeeklyHours;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ordered = [...slots]
      ..sort((a, b) {
        final day = a.weekday.compareTo(b.weekday);
        return day != 0 ? day : a.periodNumber.compareTo(b.periodNumber);
      });
    final incomplete = ordered.length != expectedWeeklyHours;
    final byWeekday = <int, int>{};
    for (final slot in ordered) {
      byWeekday.update(slot.weekday, (count) => count + 1, ifAbsent: () => 1);
    }
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
            if (ordered.isNotEmpty) ...[
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
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Haftalık dağılım',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (byWeekday.isEmpty)
              Text(
                'Henüz ders saati eklenmedi.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final entry in byWeekday.entries)
                    Text(
                      '${_weekdayLong(entry.key)}: ${entry.value}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              incomplete
                  ? '${ordered.length} / $expectedWeeklyHours ders saati · program tamamlanmalı'
                  : '${ordered.length} / $expectedWeeklyHours ders saati ✓',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: incomplete
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
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

class _LegacyMigrationCard extends StatelessWidget {
  const _LegacyMigrationCard({required this.preview, required this.onMigrate});

  final LegacyTeacherStateMigrationPreview preview;
  final VoidCallback onMigrate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.move_down_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Eski takip verisi bulundu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bu kayıtların hangi şubeye ait olduğunu uygulama bilemez. '
            '${preview.migratableRecordCount} kayıt yalnızca sizin seçeceğiniz bir şubeye kopyalanabilir; eski kayıtlar korunur.',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: onMigrate,
            icon: const Icon(Icons.call_split_rounded),
            label: const Text('Şubeye aktar'),
          ),
        ],
      ),
    ),
  );
}

class _LegacyAssignmentPicker extends StatelessWidget {
  const _LegacyAssignmentPicker({
    required this.assignments,
    required this.classes,
  });

  final List<TeachingAssignment> assignments;
  final List<SchoolClass> classes;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            'Eski takip hangi şubeye ait?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        for (final assignment in assignments)
          ListTile(
            leading: const Icon(Icons.class_outlined),
            title: Text(_classLabel(classes, assignment.classId)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(assignment.id),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ),
  );

  String _classLabel(List<SchoolClass> classes, String classId) {
    for (final item in classes) {
      if (item.id == classId) return item.displayName;
    }
    return classId;
  }
}

class _ClassDraft {
  const _ClassDraft({required this.grade, required this.section});

  final int grade;
  final String section;
}

class _AddClassSheet extends StatefulWidget {
  const _AddClassSheet({required this.initialGrade});

  final int initialGrade;

  @override
  State<_AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<_AddClassSheet> {
  final _controller = TextEditingController();
  late int _grade;
  String? _sectionError;

  @override
  void initState() {
    super.initState();
    _grade = widget.initialGrade;
  }

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
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 520),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sınıf ekle',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sınıf düzeyini ve şubeyi seçin.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _grade,
              decoration: const InputDecoration(
                labelText: 'Sınıf düzeyi',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var grade = 9; grade <= 12; grade++)
                  DropdownMenuItem<int>(
                    value: grade,
                    child: Text('$grade. sınıf'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _grade = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Şube',
                hintText: 'A',
                border: const OutlineInputBorder(),
                errorText: _sectionError,
              ),
              onChanged: (_) {
                if (_sectionError != null) {
                  setState(() => _sectionError = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _submit, child: const Text('Ekle')),
          ],
        ),
      ),
    ),
  );

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _sectionError = 'Şube adını yazın.');
      return;
    }
    Navigator.of(context).pop(_ClassDraft(grade: _grade, section: value));
  }
}

class _BellPeriodsSheet extends StatefulWidget {
  const _BellPeriodsSheet({required this.initial});

  final List<BellPeriod> initial;

  @override
  State<_BellPeriodsSheet> createState() => _BellPeriodsSheetState();
}

class _BellPeriodsSheetState extends State<_BellPeriodsSheet> {
  static const _defaultLessonCount = 8;
  static const _defaultStartMinute = 8 * 60 + 30;
  static const _defaultLessonsBeforeLunch = 4;
  static const _defaultLunchBreakMinutes = 45;
  static const _defaultLessonDurationMinutes = 40;
  static const _defaultPassingBreakMinutes = 10;

  late int _startMinute;
  late int _lessonCount;
  late int _lessonsBeforeLunch;
  late int _passingBreakMinutes;
  late final TextEditingController _lunchController;
  late final TextEditingController _durationController;
  String? _lunchError;
  String? _durationError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final ordered = [...widget.initial]
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    _startMinute = ordered.isEmpty
        ? _defaultStartMinute
        : ordered.first.startMinute;
    final sourceCount = ordered.isEmpty ? _defaultLessonCount : ordered.length;
    _lessonCount = sourceCount < 2 ? 2 : sourceCount;
    _passingBreakMinutes = _inferPassingBreak(ordered);
    _lessonsBeforeLunch = _inferLessonsBeforeLunch(
      ordered,
      _passingBreakMinutes,
    );
    _lunchController = TextEditingController(
      text: _inferLunchBreak(ordered, _passingBreakMinutes).toString(),
    );
    _durationController = TextEditingController(
      text: _inferLessonDuration(ordered).toString(),
    );
  }

  @override
  void dispose() {
    _lunchController.dispose();
    _durationController.dispose();
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
      constraints: const BoxConstraints(maxHeight: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial.isEmpty
                ? 'Ders saatlerini tanımla'
                : 'Ders saatlerini düzenle',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Birkaç bilgiyi cevaplayın; saatleri sizin için oluşturalım.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _startTimeField(context),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  key: ValueKey('lesson-count-$_lessonCount'),
                  initialValue: _lessonCount,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Bir günde toplam ders',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final count in _lessonCountOptions)
                      DropdownMenuItem<int>(
                        value: count,
                        child: Text('$count ders'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _lessonCount = value;
                      if (_lessonsBeforeLunch >= value) {
                        _lessonsBeforeLunch = value - 1;
                      }
                      _formError = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  key: ValueKey(
                    'before-lunch-$_lessonCount-$_lessonsBeforeLunch',
                  ),
                  initialValue: _lessonsBeforeLunch,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Öğle arasından önce kaç ders saati var?',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var count = 1; count < _lessonCount; count++)
                      DropdownMenuItem<int>(
                        value: count,
                        child: Text('$count ders'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _lessonsBeforeLunch = value;
                        _formError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _lunchController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Öğle arası',
                    suffixText: 'dakika',
                    border: const OutlineInputBorder(),
                    errorText: _lunchError,
                  ),
                  onChanged: (_) => _clearFieldErrors(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Bir ders kaç dakika?',
                    suffixText: 'dakika',
                    helperText: 'Başlangıç değeri: 40 dakika',
                    border: const OutlineInputBorder(),
                    errorText: _durationError,
                  ),
                  onChanged: (_) => _clearFieldErrors(),
                ),
                const SizedBox(height: AppSpacing.md),
                _schedulePreview(context),
                if (_formError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _save,
            child: const Text('Saatleri oluştur ve kaydet'),
          ),
        ],
      ),
    ),
  );

  Widget _startTimeField(BuildContext context) => InputDecorator(
    decoration: const InputDecoration(
      labelText: 'İlk ders başlangıcı',
      border: OutlineInputBorder(),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _formatMinute(_startMinute),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton.icon(
          onPressed: _pickStartTime,
          icon: const Icon(Icons.schedule_rounded),
          label: const Text('Değiştir'),
        ),
      ],
    ),
  );

  Widget _schedulePreview(BuildContext context) {
    final periods = _tryBuildPeriods();
    if (periods == null || periods.isEmpty) return const SizedBox.shrink();
    final lunchAfter = periods[_lessonsBeforeLunch - 1];
    final firstAfterLunch = periods[_lessonsBeforeLunch];
    return Text(
      '${periods.length} ders oluşacak · ${_formatMinute(periods.first.startMinute)}–'
      '${_formatMinute(periods.last.endMinute)}\n'
      'Öğle arası ${_formatMinute(lunchAfter.endMinute)}–'
      '${_formatMinute(firstAfterLunch.startMinute)} · Ders araları $_passingBreakMinutes dakika',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startMinute ~/ 60,
        minute: _startMinute % 60,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _startMinute = picked.hour * 60 + picked.minute;
      _formError = null;
    });
  }

  void _save() {
    final lunch = int.tryParse(_lunchController.text.trim());
    final duration = int.tryParse(_durationController.text.trim());
    final lunchError = lunch == null || lunch < 1 || lunch > 180
        ? '1–180 dakika arasında yazın.'
        : null;
    final durationError = duration == null || duration < 1 || duration > 180
        ? '1–180 dakika arasında yazın.'
        : null;
    if (lunchError != null || durationError != null) {
      setState(() {
        _lunchError = lunchError;
        _durationError = durationError;
        _formError = null;
      });
      return;
    }

    try {
      final periods = buildBellPeriods(
        BellScheduleConfiguration(
          firstLessonStartMinute: _startMinute,
          lessonCount: _lessonCount,
          lessonsBeforeLunch: _lessonsBeforeLunch,
          lunchBreakMinutes: lunch!,
          lessonDurationMinutes: duration!,
          passingBreakMinutes: _passingBreakMinutes,
        ),
      );
      Navigator.of(context).pop(periods);
    } on ArgumentError {
      setState(() {
        _formError =
            'Bu ayarlarla son ders günün dışına taşıyor. Başlangıç veya süreyi azaltın.';
      });
    }
  }

  void _clearFieldErrors() {
    if (_lunchError == null && _durationError == null && _formError == null) {
      return;
    }
    setState(() {
      _lunchError = null;
      _durationError = null;
      _formError = null;
    });
  }

  List<BellPeriod>? _tryBuildPeriods() {
    final lunch = int.tryParse(_lunchController.text.trim());
    final duration = int.tryParse(_durationController.text.trim());
    if (lunch == null || duration == null) return null;
    try {
      return buildBellPeriods(
        BellScheduleConfiguration(
          firstLessonStartMinute: _startMinute,
          lessonCount: _lessonCount,
          lessonsBeforeLunch: _lessonsBeforeLunch,
          lunchBreakMinutes: lunch,
          lessonDurationMinutes: duration,
          passingBreakMinutes: _passingBreakMinutes,
        ),
      );
    } on ArgumentError {
      return null;
    }
  }

  int _inferPassingBreak(List<BellPeriod> periods) {
    if (periods.length < 2) return _defaultPassingBreakMinutes;
    for (var index = 1; index < periods.length; index++) {
      final gap = periods[index].startMinute - periods[index - 1].endMinute;
      if (gap >= 0 && gap <= 20) return gap;
    }
    return _defaultPassingBreakMinutes;
  }

  List<int> get _lessonCountOptions {
    final options = [for (var count = 2; count <= 12; count++) count];
    if (_lessonCount > 12) options.add(_lessonCount);
    return options;
  }

  int _inferLessonsBeforeLunch(List<BellPeriod> periods, int passingBreak) {
    final defaultBoundary = _defaultLessonsBeforeLunch >= _lessonCount
        ? _lessonCount - 1
        : _defaultLessonsBeforeLunch;
    if (periods.length < 2) return defaultBoundary;
    var largestGap = passingBreak;
    var boundary = defaultBoundary;
    for (var index = 1; index < periods.length; index++) {
      final gap = periods[index].startMinute - periods[index - 1].endMinute;
      if (gap > largestGap) {
        largestGap = gap;
        boundary = index;
      }
    }
    if (largestGap == passingBreak) {
      boundary = defaultBoundary;
    }
    if (boundary >= _lessonCount) boundary = _lessonCount - 1;
    return boundary < 1 ? 1 : boundary;
  }

  int _inferLunchBreak(List<BellPeriod> periods, int passingBreak) {
    var largestGap = 0;
    for (var index = 1; index < periods.length; index++) {
      final gap = periods[index].startMinute - periods[index - 1].endMinute;
      if (gap > largestGap) largestGap = gap;
    }
    return largestGap > passingBreak ? largestGap : _defaultLunchBreakMinutes;
  }

  int _inferLessonDuration(List<BellPeriod> periods) {
    if (periods.isEmpty) return _defaultLessonDurationMinutes;
    final duration = periods.first.endMinute - periods.first.startMinute;
    return duration > 0 ? duration : _defaultLessonDurationMinutes;
  }
}

class _AssignmentScheduleSheet extends StatefulWidget {
  const _AssignmentScheduleSheet({
    required this.periods,
    required this.expectedWeeklyHours,
    required this.initial,
    required this.occupied,
  });

  final List<BellPeriod> periods;
  final int expectedWeeklyHours;
  final Set<_ScheduleCell> initial;
  final Set<_ScheduleCell> occupied;

  @override
  State<_AssignmentScheduleSheet> createState() =>
      _AssignmentScheduleSheetState();
}

class _AssignmentScheduleSheetState extends State<_AssignmentScheduleSheet> {
  late final Set<_ScheduleCell> _selected = {...widget.initial};

  bool get _canSave =>
      _selected.isEmpty || _selected.length == widget.expectedWeeklyHours;

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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bu ders haftada ${widget.expectedWeeklyHours} saat. '
            'Tam program için ${widget.expectedWeeklyHours} saat seçin. '
            'Dolu görünen saat başka bir ders/sınıfa atanmıştır.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_selected.length}/${widget.expectedWeeklyHours} saat seçildi',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _canSave
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (
                  var weekday = DateTime.monday;
                  weekday <= DateTime.friday;
                  weekday++
                ) ...[
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
          if (_selected.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(_selected.clear),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Programı temizle'),
            ),
          FilledButton(
            onPressed: _canSave
                ? () => Navigator.of(context).pop(_selected)
                : null,
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
    required this.weeklyLessonHours,
    required this.classes,
    required this.assignments,
    required this.periods,
    required this.slots,
    required this.allowedOutcomeIds,
    required this.migrationPreview,
    required this.migrationDecision,
  });

  final String academicYear;
  final int weeklyLessonHours;
  final List<SchoolClass> classes;
  final List<TeachingAssignment> assignments;
  final List<BellPeriod> periods;
  final List<LessonScheduleSlot> slots;
  final Set<String> allowedOutcomeIds;
  final LegacyTeacherStateMigrationPreview? migrationPreview;
  final LegacyMigrationDecision? migrationDecision;

  SchoolClass? classFor(String classId) {
    for (final item in classes) {
      if (item.id == classId) return item;
    }
    return null;
  }

  TeachingAssignment? assignment(String? assignmentId) {
    if (assignmentId == null) return null;
    for (final item in assignments) {
      if (item.id == assignmentId) return item;
    }
    return null;
  }

  List<TeachingAssignment> courseAssignments(String courseId) => assignments
      .where((item) => item.courseId == courseId)
      .toList(growable: false);
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
