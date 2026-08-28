import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/models/lesson_plan_models.dart';
import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../shared/feature_widgets.dart';
import '../shared/interaction_polish.dart';
import 'lesson_plan_teacher_presentation.dart';

class SingleLessonPlanPage extends StatefulWidget {
  const SingleLessonPlanPage({
    super.key,
    required this.repository,
    required this.initialPackageId,
    required this.initialPackageHour,
    this.progressRepository,
    this.academicYear,
  });

  final CourseKnowledgeRepository repository;
  final String initialPackageId;
  final int initialPackageHour;
  final LessonPlanProgressRepository? progressRepository;
  final String? academicYear;

  @override
  State<SingleLessonPlanPage> createState() => _SingleLessonPlanPageState();
}

class _SingleLessonPlanPageState extends State<SingleLessonPlanPage> {
  late String _packageId;
  late int _packageHour;
  late Future<_SingleLessonViewData> _future;
  LessonPlanProgressResolution? _localProgress;

  bool get _progressEnabled =>
      widget.progressRepository != null &&
      widget.academicYear != null &&
      widget.academicYear!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _packageId = widget.initialPackageId;
    _packageHour = widget.initialPackageHour < 1
        ? 1
        : widget.initialPackageHour;
    _future = _load(_packageId, _packageHour);
  }

  Future<_SingleLessonViewData> _load(String packageId, int packageHour) async {
    final current = await widget.repository.getLessonPlan(packageId);
    if (current == null) {
      throw StateError('Ders planı bulunamadı: $packageId');
    }
    if (current.lessonHours <= 0 || current.lessons.isEmpty) {
      throw StateError('Bu ders planında tekil ders verisi bulunamadı.');
    }

    final effectiveHour = packageHour < 1
        ? 1
        : packageHour > current.lessonHours
        ? current.lessonHours
        : packageHour;
    final lesson = _lessonForPackageHour(current, effectiveHour);
    if (lesson == null) {
      throw StateError('Ders saati plan verisiyle eşleştirilemedi.');
    }

    final previousPackage = await widget.repository.getPreviousLessonPlan(
      packageId,
    );
    final nextPackage = await widget.repository.getNextLessonPlan(packageId);
    final blockPlans = await widget.repository.getLessonPlansForBlock(
      current.blockId,
    );

    model.BlockDetail? blockDetail;
    try {
      blockDetail = await widget.repository.getBlock(current.blockId);
    } on Object {
      blockDetail = null;
    }

    final plansForPresentation = blockPlans.isEmpty ? [current] : blockPlans;
    final presentation = LessonPlanTeacherPresentation(
      blockPlans: plansForPresentation,
      blockDetail: blockDetail,
    );
    final blockHour = _blockHourFor(
      plansForPresentation,
      current,
      effectiveHour,
    );

    final previous = effectiveHour > 1
        ? _LessonTarget(packageId: packageId, packageHour: effectiveHour - 1)
        : previousPackage == null
        ? null
        : _LessonTarget(
            packageId: previousPackage.packageId,
            packageHour: previousPackage.lessonHours,
          );
    final next = effectiveHour < current.lessonHours
        ? _LessonTarget(packageId: packageId, packageHour: effectiveHour + 1)
        : nextPackage == null
        ? null
        : _LessonTarget(packageId: nextPackage.packageId, packageHour: 1);

    LessonPlanProgressResolution? progress;
    if (_progressEnabled) {
      final record = await widget.progressRepository!.get(
        courseId: current.courseId,
        academicYear: widget.academicYear!,
        packageId: _hourProgressId(current.packageId, effectiveHour),
      );
      progress = _resolveProgress(current, record);
    }

    return _SingleLessonViewData(
      package: current,
      lesson: lesson,
      packageHour: effectiveHour,
      blockHour: blockHour,
      previous: previous,
      next: next,
      progress: progress,
      presentation: presentation,
    );
  }

  void _openLesson(_LessonTarget target) {
    setState(() {
      _packageId = target.packageId;
      _packageHour = target.packageHour;
      _localProgress = null;
      _future = _load(_packageId, _packageHour);
    });
  }

  void _reload() => setState(() => _future = _load(_packageId, _packageHour));

  Future<void> _setProgress(
    LessonPlanPackage package,
    int packageHour,
    LessonPlanProgressStatus status,
  ) async {
    final repository = widget.progressRepository;
    final academicYear = widget.academicYear;
    if (repository == null || academicYear == null || academicYear.isEmpty) {
      return;
    }

    final progressId = _hourProgressId(package.packageId, packageHour);
    try {
      final previous = await repository.get(
        courseId: package.courseId,
        academicYear: academicYear,
        packageId: progressId,
      );
      LessonPlanProgressRecord? saved;
      if (status == LessonPlanProgressStatus.notStarted) {
        await repository.delete(
          courseId: package.courseId,
          academicYear: academicYear,
          packageId: progressId,
        );
      } else {
        final hash = package.payloadSha256.trim();
        if (hash.isEmpty) {
          throw StateError('Ders planı özeti doğrulanamadı.');
        }
        final now = DateTime.now();
        final previousCurrent =
            _resolveProgress(package, previous).isCurrent ? previous : null;
        saved = LessonPlanProgressRecord(
          courseId: package.courseId,
          academicYear: academicYear,
          packageId: progressId,
          payloadSha256: hash,
          status: status,
          startedAt: previousCurrent?.startedAt ?? now,
          completedAt: status == LessonPlanProgressStatus.completed ? now : null,
          updatedAt: now,
        );
        await repository.save(saved);
      }

      if (!mounted) return;
      if (status == LessonPlanProgressStatus.completed) {
        HapticFeedback.mediumImpact();
      }
      setState(() => _localProgress = _resolveProgress(package, saved));
      showTeacherUndoFeedback(
        context,
        '${status.teacherLabel} olarak kaydedildi.',
        onUndo: () async {
          try {
            if (previous == null) {
              await repository.delete(
                courseId: package.courseId,
                academicYear: academicYear,
                packageId: progressId,
              );
            } else {
              await repository.save(previous);
            }
            if (!mounted) return;
            if (_packageId == package.packageId && _packageHour == packageHour) {
              setState(
                () => _localProgress = _resolveProgress(package, previous),
              );
            }
            showTeacherFeedback(context, 'Ders durumu geri alındı.');
          } on Object {
            if (!mounted) return;
            showTeacherFeedback(
              context,
              'Ders durumu geri alınamadı. Tekrar deneyin.',
              duration: const Duration(seconds: 4),
            );
          }
        },
      );
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Ders durumu kaydedilemedi. Tekrar deneyin.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ders Planı')),
    body: FutureBuilder<_SingleLessonViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const LoadingView(label: 'Ders planı hazırlanıyor…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Ders planı yüklenemedi.',
            onRetry: _reload,
          );
        }
        return _SingleLessonContent(
          data: snapshot.data!,
          progressEnabled: _progressEnabled,
          progressOverride: _localProgress,
          onSetProgress: _setProgress,
          onOpenLesson: _openLesson,
        );
      },
    ),
  );
}

class _SingleLessonContent extends StatelessWidget {
  const _SingleLessonContent({
    required this.data,
    required this.progressEnabled,
    required this.progressOverride,
    required this.onSetProgress,
    required this.onOpenLesson,
  });

  final _SingleLessonViewData data;
  final bool progressEnabled;
  final LessonPlanProgressResolution? progressOverride;
  final Future<void> Function(
    LessonPlanPackage package,
    int packageHour,
    LessonPlanProgressStatus status,
  ) onSetProgress;
  final ValueChanged<_LessonTarget> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final plan = data.package;
    final lesson = data.lesson;
    final presentation = data.presentation;
    final summary = presentation.humanize(lesson.objective).trim();
    final title = lesson.title.trim().isEmpty
        ? presentation.humanize(plan.title)
        : presentation.humanize(lesson.title);
    final outcomeLabels = presentation.outcomeLabels(lesson.outcomeCodes);
    final remainingHours =
        plan.remainingBlockHours + (plan.lessonHours - data.packageHour);
    final progress =
        progressOverride ??
        data.progress ??
        const LessonPlanProgressResolution.none();

    return AppPage(
      children: [
        _CollapsibleLessonHeader(
          eyebrow: '${data.blockHour}. DERS SAATİ',
          title: title,
          summary: summary,
        ),
        if (progressEnabled) ...[
          _HourProgressCard(
            plan: plan,
            packageHour: data.packageHour,
            progress: progress,
            next: data.next,
            onSetProgress: onSetProgress,
            onOpenLesson: onOpenLesson,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.route_outlined),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ders konumu',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (presentation.locationLabel case final location?) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              location,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            remainingHours == 0
                                ? 'Bu ders, bu çalışma alanını tamamlıyor.'
                                : 'Bu dersten sonra aynı çalışma alanında $remainingHours ders saati kalıyor.',
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (outcomeLabels.isNotEmpty) ...[
                  const Divider(height: AppSpacing.xl),
                  Text(
                    'Öğrenme çıktıları',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final label in outcomeLabels)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(label, style: const TextStyle(height: 1.4)),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SectionHeading(
          'Ders akışı',
          subtitle: 'Bu ders saatinde uygulanacak adımlar',
          icon: Icons.play_lesson_outlined,
        ),
        _SingleLessonStepCard(
          lesson: lesson,
          displayHour: data.blockHour,
          presentation: presentation,
        ),
        const SizedBox(height: AppSpacing.md),
        _LessonNavigation(
          previous: data.previous,
          next: data.next,
          onOpenLesson: onOpenLesson,
        ),
        const SizedBox(height: AppSpacing.md),
        _PlanProvenance(plan: plan, presentation: presentation),
      ],
    );
  }
}

class _CollapsibleLessonHeader extends StatefulWidget {
  const _CollapsibleLessonHeader({
    required this.eyebrow,
    required this.title,
    required this.summary,
  });

  final String eyebrow;
  final String title;
  final String summary;

  @override
  State<_CollapsibleLessonHeader> createState() =>
      _CollapsibleLessonHeaderState();
}

class _CollapsibleLessonHeaderState extends State<_CollapsibleLessonHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.eyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            button: true,
            label: _expanded ? 'Ders özetini gizle' : 'Ders özetini göster',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.summary.isEmpty
                  ? null
                  : () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900, height: 1.08),
                      ),
                    ),
                    if (widget.summary.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: !_expanded || widget.summary.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      widget.summary,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HourProgressCard extends StatelessWidget {
  const _HourProgressCard({
    required this.plan,
    required this.packageHour,
    required this.progress,
    required this.next,
    required this.onSetProgress,
    required this.onOpenLesson,
  });

  final LessonPlanPackage plan;
  final int packageHour;
  final LessonPlanProgressResolution progress;
  final _LessonTarget? next;
  final Future<void> Function(
    LessonPlanPackage package,
    int packageHour,
    LessonPlanProgressStatus status,
  ) onSetProgress;
  final ValueChanged<_LessonTarget> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = progress.effectiveStatus;
    final stale = progress.isStale;
    final completed = !stale && status == LessonPlanProgressStatus.completed;
    return Card(
      color: stale
          ? scheme.errorContainer
          : completed
          ? scheme.secondaryContainer
          : scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DERS DURUMU',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              stale ? 'Plan güncellendi' : status.teacherLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (stale) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Bu ders saati için önceki durum kaydı güncel planla eşleşmiyor. Dersi gördükten sonra durumu yeniden seçin.',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final candidate in LessonPlanProgressStatus.values)
                  ChoiceChip(
                    selected: !stale && status == candidate,
                    label: Text(candidate.teacherLabel),
                    onSelected: !stale && status == candidate
                        ? null
                        : (_) => onSetProgress(plan, packageHour, candidate),
                  ),
              ],
            ),
            if (completed && next != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => onOpenLesson(next!),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Sonraki derse geç'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SingleLessonStepCard extends StatelessWidget {
  const _SingleLessonStepCard({
    required this.lesson,
    required this.displayHour,
    required this.presentation,
  });

  final LessonPlanLesson lesson;
  final int displayHour;
  final LessonPlanTeacherPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final opening = _presentedLines(lesson.opening, presentation);
    final teacherActions = _presentedLines(lesson.teacherActions, presentation);
    final studentActions = _presentedLines(lesson.studentActions, presentation);
    final assessment = _presentedLines(lesson.assessment, presentation);
    final closure = _presentedLines(lesson.closure, presentation);
    final materials = _presentedLines(lesson.materials, presentation);
    final activities = presentation.activityLabels(lesson.activityIds);
    final forms = presentation.formLabels(lesson.formIds);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$displayHour. ders',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (opening.isNotEmpty)
              _PlanSection(title: 'Başlangıç', lines: opening),
            if (teacherActions.isNotEmpty)
              _PlanSection(title: 'Öğretmen', lines: teacherActions),
            if (studentActions.isNotEmpty)
              _PlanSection(title: 'Öğrenci', lines: studentActions),
            if (activities.isNotEmpty)
              _PlanSection(title: 'Ders kitabı etkinlikleri', lines: activities),
            if (forms.isNotEmpty)
              _PlanSection(title: 'Değerlendirme formları', lines: forms),
            if (materials.isNotEmpty)
              _PlanSection(title: 'Materyaller', lines: materials),
            if (assessment.isNotEmpty)
              _PlanSection(title: 'Kontrol / değerlendirme', lines: assessment),
            if (closure.isNotEmpty)
              _PlanSection(title: 'Kapanış', lines: closure),
          ],
        ),
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final line in lines) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.circle, size: 6),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(line, style: const TextStyle(height: 1.4))),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    ),
  );
}

class _LessonNavigation extends StatelessWidget {
  const _LessonNavigation({
    required this.previous,
    required this.next,
    required this.onOpenLesson,
  });

  final _LessonTarget? previous;
  final _LessonTarget? next;
  final ValueChanged<_LessonTarget> onOpenLesson;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: previous == null ? null : () => onOpenLesson(previous!),
              icon: const Icon(Icons.arrow_back),
              label: Text(previous == null ? 'Önceki ders yok' : 'Önceki ders'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: next == null ? null : () => onOpenLesson(next!),
              icon: const Icon(Icons.arrow_forward),
              label: Text(next == null ? 'Son ders' : 'Sonraki ders'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlanProvenance extends StatelessWidget {
  const _PlanProvenance({required this.plan, required this.presentation});

  final LessonPlanPackage plan;
  final LessonPlanTeacherPresentation presentation;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const Icon(Icons.verified_outlined),
      title: const Text(
        'Plan doğrulaması',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('Kaynağı doğrulanmış ders planı'),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Durum: ${presentation.validationLabel(plan.validationStatus)}\nKaynak: TYMM ders planı veritabanı',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _SingleLessonViewData {
  const _SingleLessonViewData({
    required this.package,
    required this.lesson,
    required this.packageHour,
    required this.blockHour,
    required this.previous,
    required this.next,
    required this.progress,
    required this.presentation,
  });

  final LessonPlanPackage package;
  final LessonPlanLesson lesson;
  final int packageHour;
  final int blockHour;
  final _LessonTarget? previous;
  final _LessonTarget? next;
  final LessonPlanProgressResolution? progress;
  final LessonPlanTeacherPresentation presentation;
}

class _LessonTarget {
  const _LessonTarget({required this.packageId, required this.packageHour});

  final String packageId;
  final int packageHour;
}

LessonPlanLesson? _lessonForPackageHour(
  LessonPlanPackage package,
  int packageHour,
) {
  var consumed = 0;
  for (final lesson in package.lessons) {
    final duration = lesson.durationLessonHours > 0
        ? lesson.durationLessonHours
        : 1;
    final end = consumed + duration;
    if (packageHour > consumed && packageHour <= end) return lesson;
    consumed = end;
  }
  return null;
}

int _blockHourFor(
  List<LessonPlanPackage> blockPlans,
  LessonPlanPackage current,
  int packageHour,
) {
  var start = 1;
  final ordered = [...blockPlans]
    ..sort((a, b) => a.packageNo.compareTo(b.packageNo));
  for (final plan in ordered) {
    if (plan.packageId == current.packageId) return start + packageHour - 1;
    start += plan.lessonHours;
  }
  return ((current.packageNo - 1) * current.lessonHours) + packageHour;
}

String _hourProgressId(String packageId, int packageHour) =>
    '$packageId::lesson-hour:$packageHour';

LessonPlanProgressResolution _resolveProgress(
  LessonPlanPackage package,
  LessonPlanProgressRecord? record,
) {
  if (record == null) return const LessonPlanProgressResolution.none();
  final packageHash = package.payloadSha256.trim();
  final recordHash = record.payloadSha256?.trim() ?? '';
  if (packageHash.isEmpty || recordHash.isEmpty || packageHash != recordHash) {
    return LessonPlanProgressResolution(
      record: record,
      bindingState: LessonPlanProgressBindingState.stale,
    );
  }
  return LessonPlanProgressResolution(
    record: record,
    bindingState: LessonPlanProgressBindingState.current,
  );
}

List<String> _presentedLines(
  Object? value,
  LessonPlanTeacherPresentation presentation,
) => _humanLines(value).map(presentation.humanize).toList(growable: false);

List<String> _humanLines(Object? value) {
  final result = <String>[];

  void collect(Object? item) {
    if (item == null) return;
    if (item is String) {
      final text = item.trim();
      if (text.isNotEmpty && !result.contains(text)) result.add(text);
      return;
    }
    if (item is num) {
      final text = item.toString();
      if (!result.contains(text)) result.add(text);
      return;
    }
    if (item is Iterable) {
      for (final child in item) {
        collect(child);
      }
      return;
    }
    if (item is Map) {
      for (final child in item.values) {
        collect(child);
      }
    }
  }

  collect(value);
  return List<String>.unmodifiable(result);
}
