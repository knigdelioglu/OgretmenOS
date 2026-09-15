import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/resource_navigation.dart';
import '../../domain/models/course_models.dart' as model;
import '../../domain/models/lesson_plan_models.dart';
import '../../domain/models/lesson_plan_progress_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../../domain/repositories/lesson_plan_progress_repository.dart';
import '../../domain/services/lesson_plan_progress_service.dart';
import '../shared/feature_widgets.dart';
import '../shared/interaction_polish.dart';
import '../resources/teacher_guide_relation_action.dart';
import 'lesson_plan_teacher_presentation.dart';

class LessonPlanPage extends StatefulWidget {
  const LessonPlanPage({
    super.key,
    required this.repository,
    required this.initialPackageId,
    this.progressRepository,
    this.academicYear,
    this.onOpenResources,
  });

  final CourseKnowledgeRepository repository;
  final String initialPackageId;
  final LessonPlanProgressRepository? progressRepository;
  final String? academicYear;
  final ResourceNavigationCallback? onOpenResources;

  @override
  State<LessonPlanPage> createState() => _LessonPlanPageState();
}

class _LessonPlanPageState extends State<LessonPlanPage> {
  late String _packageId;
  late Future<_LessonPlanViewData> _future;
  LessonPlanProgressResolution? _localProgressResolution;

  LessonPlanProgressService? get _progressService {
    final repository = widget.progressRepository;
    final academicYear = widget.academicYear;
    if (repository == null || academicYear == null || academicYear.isEmpty) {
      return null;
    }
    return LessonPlanProgressService(repository: repository);
  }

  @override
  void initState() {
    super.initState();
    _packageId = widget.initialPackageId;
    _future = _load(_packageId);
  }

  Future<_LessonPlanViewData> _load(String packageId) async {
    final current = await widget.repository.getLessonPlan(packageId);
    if (current == null) {
      throw StateError('Ders planı bulunamadı: $packageId');
    }
    final previous = await widget.repository.getPreviousLessonPlan(packageId);
    final next = await widget.repository.getNextLessonPlan(packageId);
    final blockPlans = await widget.repository.getLessonPlansForBlock(
      current.blockId,
    );

    model.BlockDetail? blockDetail;
    try {
      blockDetail = await widget.repository.getBlock(current.blockId);
    } on Object {
      blockDetail = null;
    }

    final presentation = LessonPlanTeacherPresentation(
      blockPlans: blockPlans.isEmpty ? [current] : blockPlans,
      blockDetail: blockDetail,
    );
    final progressService = _progressService;
    final progress = progressService == null
        ? null
        : await progressService.resolve(
            package: current,
            academicYear: widget.academicYear!,
          );
    return _LessonPlanViewData(
      current: current,
      previous: previous,
      next: next,
      progress: progress,
      presentation: presentation,
    );
  }

  void _openPackage(String packageId) {
    setState(() {
      _packageId = packageId;
      _localProgressResolution = null;
      _future = _load(packageId);
    });
  }

  void _reload() {
    setState(() => _future = _load(_packageId));
  }

  Future<void> _setProgress(
    LessonPlanPackage package,
    LessonPlanProgressStatus status,
  ) async {
    final service = _progressService;
    final progressRepository = widget.progressRepository;
    final academicYear = widget.academicYear;
    if (service == null ||
        progressRepository == null ||
        academicYear == null ||
        academicYear.isEmpty) {
      return;
    }

    try {
      final previous = await service.get(
        package: package,
        academicYear: academicYear,
      );
      final saved = await service.setStatus(
        package: package,
        academicYear: academicYear,
        status: status,
      );
      if (!mounted) return;
      if (status == LessonPlanProgressStatus.completed) {
        HapticFeedback.mediumImpact();
      }
      setState(
        () => _localProgressResolution = service.resolveRecord(
          package: package,
          record: saved,
        ),
      );
      showTeacherUndoFeedback(
        context,
        '${status.teacherLabel} olarak kaydedildi.',
        onUndo: () async {
          try {
            if (previous == null) {
              await progressRepository.delete(
                courseId: package.courseId,
                academicYear: academicYear,
                packageId: package.packageId,
              );
            } else {
              await progressRepository.save(previous);
            }
            if (!mounted) return;
            if (_packageId == package.packageId) {
              setState(
                () => _localProgressResolution = service.resolveRecord(
                  package: package,
                  record: previous,
                ),
              );
            }
            showTeacherFeedback(context, 'Ders planı değişikliği geri alındı.');
          } on Object {
            if (!mounted) return;
            showTeacherFeedback(
              context,
              'Ders planı değişikliği geri alınamadı. Tekrar deneyin.',
              duration: const Duration(seconds: 4),
            );
          }
        },
      );
    } on Object {
      if (!mounted) return;
      showTeacherFeedback(
        context,
        'Ders planı ilerlemesi kaydedilemedi. Tekrar deneyin.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ders Planı')),
    body: FutureBuilder<_LessonPlanViewData>(
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
        return _LessonPlanContent(
          data: snapshot.data!,
          repository: widget.repository,
          progressEnabled: _progressService != null,
          progressOverride: _localProgressResolution,
          onSetProgress: _setProgress,
          onOpenPackage: _openPackage,
          onOpenResources: widget.onOpenResources == null
              ? null
              : (request) {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  widget.onOpenResources!(request);
                },
        );
      },
    ),
  );
}

class _LessonPlanContent extends StatelessWidget {
  const _LessonPlanContent({
    required this.data,
    required this.repository,
    required this.progressEnabled,
    required this.progressOverride,
    required this.onSetProgress,
    required this.onOpenPackage,
    this.onOpenResources,
  });

  final _LessonPlanViewData data;
  final CourseKnowledgeRepository repository;
  final bool progressEnabled;
  final LessonPlanProgressResolution? progressOverride;
  final Future<void> Function(
    LessonPlanPackage package,
    LessonPlanProgressStatus status,
  )
  onSetProgress;
  final ValueChanged<String> onOpenPackage;
  final ResourceNavigationCallback? onOpenResources;

  @override
  Widget build(BuildContext context) {
    final plan = data.current;
    final presentation = data.presentation;
    final outcomeLabels = presentation.outcomeLabels(plan.outcomeCodes);
    final progress =
        progressOverride ??
        data.progress ??
        const LessonPlanProgressResolution.none();

    return AppPage(
      children: [
        if (progressEnabled) ...[
          _PlanProgressCard(
            plan: plan,
            progress: progress,
            onSetProgress: onSetProgress,
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
                            'Ders planı konumu',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (presentation.locationLabel
                              case final location?) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              location,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            plan.remainingBlockHours == 0
                                ? 'Bu ders planı bölümü, bu çalışma alanını tamamlıyor.'
                                : 'Bu bölümden sonra aynı çalışma alanında ${plan.remainingBlockHours} ders saati kalıyor.',
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
                if (plan.continuation.nextStepHint?.trim().isNotEmpty ==
                    true) ...[
                  const Divider(height: AppSpacing.xl),
                  Text(
                    'Sonraki adım',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    presentation.humanize(plan.continuation.nextStepHint!),
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SectionHeading(
          'Ders akışı',
          subtitle: 'Sınıfta uygulanacak adımlar',
          icon: Icons.play_lesson_outlined,
        ),
        if (plan.lessons.isEmpty)
          const StatusPanel(
            icon: Icons.info_outline,
            title: 'Ders adımı bulunmuyor',
            message:
                'Bu ders planı bölümünde yapılandırılmış ders adımı yer almıyor.',
          )
        else
          for (final lesson in plan.lessons) ...[
            _LessonStepCard(
              lesson: lesson,
              presentation: presentation,
              themeId: plan.themeId,
              packageId: plan.packageId,
              blockId: plan.blockId,
              repository: repository,
              onOpenResources: onOpenResources,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        _PlanNavigation(
          previous: data.previous,
          next: data.next,
          onOpenPackage: onOpenPackage,
        ),
        const SizedBox(height: AppSpacing.md),
        _PlanProvenance(plan: plan, presentation: presentation),
      ],
    );
  }
}

class _PlanProgressCard extends StatelessWidget {
  const _PlanProgressCard({
    required this.plan,
    required this.progress,
    required this.onSetProgress,
  });

  final LessonPlanPackage plan;
  final LessonPlanProgressResolution progress;
  final Future<void> Function(
    LessonPlanPackage package,
    LessonPlanProgressStatus status,
  )
  onSetProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = progress.effectiveStatus;
    final stale = progress.isStale;
    final subtitle = stale
        ? 'Plan güncellendi · takip yeniden seçilmeli'
        : status == LessonPlanProgressStatus.notStarted
        ? 'Takip yok · ders planı sırası bundan bağımsız ilerler'
        : 'Takip: ${status.teacherLabel} · plan sırası bundan bağımsız';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: stale,
        leading: Icon(
          stale ? Icons.warning_amber_rounded : Icons.fact_check_outlined,
          color: stale ? scheme.error : scheme.onSurfaceVariant,
        ),
        title: const Text(
          'İsteğe bağlı takip',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bu alan yalnız kişisel ders kaydı içindir. Önceki/sonraki ders planına geçiş bu seçimden bağımsızdır.',
              style: TextStyle(height: 1.4),
            ),
          ),
          if (stale) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Önceki “${progress.record?.status.teacherLabel ?? 'durum'}” kaydı güncel plan içeriği için geçerli sayılmadı. Planı gördükten sonra takip durumunu yeniden seçin.',
                style: TextStyle(color: scheme.error, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final candidate in LessonPlanProgressStatus.values)
                  ChoiceChip(
                    selected: !stale && status == candidate,
                    label: Text(candidate.teacherLabel),
                    onSelected: !stale && status == candidate
                        ? null
                        : (_) => onSetProgress(plan, candidate),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonStepCard extends StatelessWidget {
  const _LessonStepCard({
    required this.lesson,
    required this.presentation,
    required this.themeId,
    required this.packageId,
    required this.blockId,
    required this.repository,
    this.onOpenResources,
  });

  final LessonPlanLesson lesson;
  final LessonPlanTeacherPresentation presentation;
  final String themeId;
  final String packageId;
  final String blockId;
  final CourseKnowledgeRepository repository;
  final ResourceNavigationCallback? onOpenResources;

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
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${lesson.lessonNo}. ders',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${lesson.durationLessonHours} ders saati',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lesson.title.isEmpty
                  ? 'Ders adımı'
                  : presentation.humanize(lesson.title),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (lesson.objective.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                presentation.humanize(lesson.objective),
                style: const TextStyle(height: 1.45),
              ),
            ],
            if (opening.isNotEmpty)
              _PlanSection(title: 'Başlangıç', lines: opening),
            if (teacherActions.isNotEmpty)
              _PlanSection(title: 'Öğretmen', lines: teacherActions),
            if (studentActions.isNotEmpty)
              _PlanSection(title: 'Öğrenci', lines: studentActions),
            if (onOpenResources != null)
              TeacherGuideLessonContextActions(
                repository: repository,
                themeId: themeId,
                packageId: packageId,
                blockId: blockId,
                outcomeCodes: lesson.outcomeCodes,
                onOpenResources: onOpenResources!,
              ),
            if (activities.isNotEmpty)
              _PlanResourceSection(
                title: 'Ders kitabı etkinlikleri',
                lines: activities,
                themeId: themeId,
                resourceIds: lesson.activityIds,
                category: ResourceCategory.activities,
                repository: repository,
                onOpenResources: onOpenResources,
              ),
            if (forms.isNotEmpty)
              _PlanResourceSection(
                title: 'Değerlendirme formları',
                lines: forms,
                themeId: themeId,
                resourceIds: lesson.formIds,
                category: ResourceCategory.forms,
                repository: repository,
                onOpenResources: onOpenResources,
              ),
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

class _PlanResourceSection extends StatelessWidget {
  const _PlanResourceSection({
    required this.title,
    required this.lines,
    required this.themeId,
    required this.resourceIds,
    required this.category,
    required this.repository,
    this.onOpenResources,
  });

  final String title;
  final List<String> lines;
  final String themeId;
  final List<String> resourceIds;
  final ResourceCategory category;
  final CourseKnowledgeRepository repository;
  final ResourceNavigationCallback? onOpenResources;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 0; index < lines.length; index++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.link_outlined, size: 18),
                title: Text(lines[index]),
                trailing: onOpenResources == null
                    ? null
                    : TextButton(
                        onPressed: () => onOpenResources!(
                          ResourceNavigationContext(
                            themeId: themeId,
                            resourceId: index < resourceIds.length
                                ? resourceIds[index]
                                : null,
                            formId:
                                category == ResourceCategory.forms &&
                                    index < resourceIds.length
                                ? resourceIds[index]
                                : null,
                            category: category,
                          ),
                        ),
                        child: const Text('Kaynaklarda aç'),
                      ),
              ),
              if (onOpenResources != null && index < resourceIds.length)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xl),
                  child: TeacherGuideRelationAction(
                    repository: repository,
                    themeId: themeId,
                    targetType: category == ResourceCategory.activities
                        ? 'activity'
                        : 'form',
                    targetId: resourceIds[index],
                    onOpenResources: onOpenResources!,
                  ),
                ),
            ],
          ),
      ],
    ),
  );
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
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
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

class _PlanNavigation extends StatelessWidget {
  const _PlanNavigation({
    required this.previous,
    required this.next,
    required this.onOpenPackage,
  });

  final LessonPlanPackage? previous;
  final LessonPlanPackage? next;
  final ValueChanged<String> onOpenPackage;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ders planı sırası',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: previous == null
                      ? null
                      : () => onOpenPackage(previous!.packageId),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(previous == null ? 'Önceki yok' : 'Önceki plan'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: next == null
                      ? null
                      : () => onOpenPackage(next!.packageId),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(next == null ? 'Son plan' : 'Sonraki plan'),
                ),
              ),
            ],
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

class _LessonPlanViewData {
  const _LessonPlanViewData({
    required this.current,
    required this.previous,
    required this.next,
    required this.progress,
    required this.presentation,
  });

  final LessonPlanPackage current;
  final LessonPlanPackage? previous;
  final LessonPlanPackage? next;
  final LessonPlanProgressResolution? progress;
  final LessonPlanTeacherPresentation presentation;
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
