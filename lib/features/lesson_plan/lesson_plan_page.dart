import 'package:flutter/material.dart';

import '../../domain/models/lesson_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

class LessonPlanPage extends StatefulWidget {
  const LessonPlanPage({
    super.key,
    required this.repository,
    required this.initialPackageId,
  });

  final CourseKnowledgeRepository repository;
  final String initialPackageId;

  @override
  State<LessonPlanPage> createState() => _LessonPlanPageState();
}

class _LessonPlanPageState extends State<LessonPlanPage> {
  late String _packageId;
  late Future<_LessonPlanViewData> _future;

  @override
  void initState() {
    super.initState();
    _packageId = widget.initialPackageId;
    _future = _load(_packageId);
  }

  Future<_LessonPlanViewData> _load(String packageId) async {
    final current = await widget.repository.getLessonPlan(packageId);
    if (current == null) {
      throw StateError('Ders planı paketi bulunamadı: $packageId');
    }
    final previous = await widget.repository.getPreviousLessonPlan(packageId);
    final next = await widget.repository.getNextLessonPlan(packageId);
    return _LessonPlanViewData(
      current: current,
      previous: previous,
      next: next,
    );
  }

  void _openPackage(String packageId) {
    setState(() {
      _packageId = packageId;
      _future = _load(packageId);
    });
  }

  void _reload() {
    setState(() => _future = _load(_packageId));
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
          onOpenPackage: _openPackage,
        );
      },
    ),
  );
}

class _LessonPlanContent extends StatelessWidget {
  const _LessonPlanContent({
    required this.data,
    required this.onOpenPackage,
  });

  final _LessonPlanViewData data;
  final ValueChanged<String> onOpenPackage;

  @override
  Widget build(BuildContext context) {
    final plan = data.current;
    final outcomeLabel = plan.outcomeCodes.isEmpty
        ? null
        : plan.outcomeCodes.join(' · ');

    return AppPage(
      children: [
        PageHeader(
          eyebrow:
              'P${plan.packageNo.toString().padLeft(2, '0')} · ${plan.lessonHours} ders saati',
          title: plan.title,
          description: plan.summary,
        ),
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
                            'Plan konumu',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            plan.remainingBlockHours == 0
                                ? 'Bu paket bloğu tamamlıyor.'
                                : 'Bu paketten sonra blokta ${plan.remainingBlockHours} saat kalıyor.',
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (outcomeLabel != null) ...[
                  const Divider(height: AppSpacing.xl),
                  Text(
                    'Kazanımlar',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(outcomeLabel),
                ],
                if (plan.continuation.nextStepHint?.trim().isNotEmpty == true) ...[
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
                    plan.continuation.nextStepHint!,
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
            message: 'Bu pakette yapılandırılmış ders adımı yer almıyor.',
          )
        else
          for (final lesson in plan.lessons) ...[
            _LessonStepCard(lesson: lesson),
            const SizedBox(height: AppSpacing.md),
          ],
        _PlanNavigation(
          previous: data.previous,
          next: data.next,
          onOpenPackage: onOpenPackage,
        ),
        const SizedBox(height: AppSpacing.md),
        _PlanProvenance(plan: plan),
      ],
    );
  }
}

class _LessonStepCard extends StatelessWidget {
  const _LessonStepCard({required this.lesson});

  final LessonPlanLesson lesson;

  @override
  Widget build(BuildContext context) {
    final opening = _humanLines(lesson.opening);
    final teacherActions = _humanLines(lesson.teacherActions);
    final studentActions = _humanLines(lesson.studentActions);
    final assessment = _humanLines(lesson.assessment);
    final closure = _humanLines(lesson.closure);
    final materials = _humanLines(lesson.materials);

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
              lesson.title.isEmpty ? 'Ders adımı' : lesson.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (lesson.objective.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(lesson.objective, style: const TextStyle(height: 1.45)),
            ],
            if (opening.isNotEmpty)
              _PlanSection(title: 'Başlangıç', lines: opening),
            if (teacherActions.isNotEmpty)
              _PlanSection(title: 'Öğretmen', lines: teacherActions),
            if (studentActions.isNotEmpty)
              _PlanSection(title: 'Öğrenci', lines: studentActions),
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
            'Plan sırası',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
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
                  label: Text(
                    previous == null
                        ? 'Önceki yok'
                        : 'P${previous!.packageNo.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: next == null
                      ? null
                      : () => onOpenPackage(next!.packageId),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    next == null
                        ? 'Son paket'
                        : 'P${next!.packageNo.toString().padLeft(2, '0')}',
                  ),
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
  const _PlanProvenance({required this.plan});

  final LessonPlanPackage plan;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const Icon(Icons.verified_outlined),
      title: const Text(
        'Plan doğrulaması',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('Kaynak ve runtime bilgileri'),
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
            'Durum: ${plan.validationStatus}\nŞema: ${plan.schemaVersion}\nKaynak: ${plan.sourcePath}',
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
  });

  final LessonPlanPackage current;
  final LessonPlanPackage? previous;
  final LessonPlanPackage? next;
}

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
