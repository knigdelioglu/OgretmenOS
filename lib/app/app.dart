import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/preferences/continuity_repository.dart';
import '../domain/repositories/assignment_lesson_progress_repository.dart';
import '../domain/repositories/assignment_outcome_tracking_repository.dart';
import '../domain/repositories/instruction_context_repository.dart';
import '../domain/repositories/lesson_plan_progress_repository.dart';
import '../domain/repositories/outcome_tracking_repository.dart';
import '../domain/runtime/course_runtime_registry.dart';
import '../domain/services/assignment_lesson_timeline_service.dart';
import '../domain/services/outcome_planning_service.dart';
import '../features/annual_plan/annual_plan_page.dart';
import '../features/resources/resource_library_page.dart';
import '../features/settings/teaching_schedule_page.dart';
import '../features/shared/interaction_polish.dart';
import '../features/this_week/continuity_this_week_page.dart';
import 'app_dependencies.dart';
import 'resource_navigation.dart';
import 'theme/app_theme.dart';

class TeacherOsApp extends StatefulWidget {
  const TeacherOsApp({
    super.key,
    this.dependencies,
    this.courseLoader = loadProductionDependenciesForCourse,
    this.initialCourseId = 'TDE_9',
  });

  final AppDependencies? dependencies;
  final Future<AppDependencies> Function(String courseId)? courseLoader;
  final String initialCourseId;

  @override
  State<TeacherOsApp> createState() => _TeacherOsAppState();
}

class _TeacherOsAppState extends State<TeacherOsApp> {
  late Future<AppDependencies> _dependenciesFuture;
  late String _activeCourseId;
  AppDependencies? _resolvedDependencies;
  int _selectedDestinationIndex = 0;
  ResourceNavigationContext? _resourceNavigationContext;

  @override
  void initState() {
    super.initState();
    _activeCourseId = widget.initialCourseId;
    _dependenciesFuture = widget.dependencies != null
        ? Future.value(widget.dependencies)
        : widget.courseLoader!(_activeCourseId);
  }

  Future<void> _switchCourse(String courseId) async {
    if (courseId == _activeCourseId || widget.dependencies != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final previous = _resolvedDependencies;
    _resolvedDependencies = null;
    setState(() {
      _activeCourseId = courseId;
      _dependenciesFuture = widget.courseLoader!(courseId);
      _resourceNavigationContext = null;
    });
    await previous?.dispose?.call();
  }

  void _retryLoad() {
    if (widget.dependencies != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _resolvedDependencies = null;
    setState(() {
      _dependenciesFuture = widget.courseLoader!(_activeCourseId);
    });
  }

  void _selectDestination(int index) {
    if (index == _selectedDestinationIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedDestinationIndex = index;
      _resourceNavigationContext = null;
    });
  }

  void _openResources(ResourceNavigationContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedDestinationIndex = 2;
      _resourceNavigationContext = context;
    });
  }

  @override
  void dispose() {
    if (widget.dependencies == null) {
      _resolvedDependencies?.dispose?.call();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Öğretmen OS',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.system,
    builder: (context, child) =>
        AppFocusDismissRegion(child: child ?? const SizedBox.shrink()),
    home: FutureBuilder<AppDependencies>(
      future: _dependenciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupPage();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _StartupErrorPage(
            error: snapshot.error,
            onRetry: widget.dependencies == null ? _retryLoad : null,
          );
        }
        _resolvedDependencies = snapshot.data!;
        return _AppShell(
          key: ValueKey(_activeCourseId),
          dependencies: snapshot.data!,
          activeCourseId: _activeCourseId,
          selectedIndex: _selectedDestinationIndex,
          onDestinationChanged: _selectDestination,
          onCourseChanged: widget.dependencies == null ? _switchCourse : null,
          resourceNavigationContext: _resourceNavigationContext,
          onOpenResources: _openResources,
        );
      },
    ),
  );
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ders verileri hazırlanıyor…'),
          ],
        ),
      ),
    ),
  );
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Öğretmen OS')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ders verileri açılamadı.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uygulama ders içeriği ve yerel takip alanı yüklenmeden devam edemiyor.',
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar dene'),
                  ),
                ],
                if (kDebugMode && error != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    'Geliştirici ayrıntısı:\n$error',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    super.key,
    required this.dependencies,
    required this.activeCourseId,
    required this.selectedIndex,
    required this.onDestinationChanged,
    required this.onCourseChanged,
    required this.resourceNavigationContext,
    required this.onOpenResources,
  });

  final AppDependencies dependencies;
  final String activeCourseId;
  final int selectedIndex;
  final ValueChanged<int> onDestinationChanged;
  final ValueChanged<String>? onCourseChanged;
  final ResourceNavigationContext? resourceNavigationContext;
  final ResourceNavigationCallback onOpenResources;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late final OutcomePlanningService _outcomePlanning;
  late final ContinuityRepository _continuity;
  late final LessonPlanProgressRepository _lessonPlanProgress;
  late final InstructionContextRepository _instructionContext;
  late final AssignmentLessonProgressRepository _assignmentLessonProgress;
  late final AssignmentOutcomeTrackingRepository _assignmentOutcomeTracking;
  late final AssignmentLessonTimelineService _assignmentTimeline;
  AnnualPlanPage? _annualPlanPage;
  ResourceLibraryPage? _resourceLibraryPage;
  int _scheduleRevision = 0;

  @override
  void initState() {
    super.initState();
    _continuity =
        widget.dependencies.continuity ?? MemoryContinuityRepository();
    _lessonPlanProgress =
        widget.dependencies.lessonPlanProgress ??
        MemoryLessonPlanProgressRepository();
    _instructionContext =
        widget.dependencies.instructionContext ??
        MemoryInstructionContextRepository();
    _assignmentLessonProgress =
        widget.dependencies.assignmentLessonProgress ??
        MemoryAssignmentLessonProgressRepository();
    _assignmentOutcomeTracking =
        widget.dependencies.assignmentOutcomeTracking ??
        MemoryAssignmentOutcomeTrackingRepository();
    _assignmentTimeline =
        widget.dependencies.assignmentTimeline ??
        AssignmentLessonTimelineService(
          instructionContext: _instructionContext,
          weeklyPlanning: widget.dependencies.weeklyPlanning,
        );
    _outcomePlanning =
        widget.dependencies.outcomePlanning ??
        OutcomePlanningService(
          repository: widget.dependencies.repository,
          weeklyPlanning: widget.dependencies.weeklyPlanning,
          trackingRepository: MemoryOutcomeTrackingRepository(),
        );
  }

  Widget _courseSelector(BuildContext context) {
    final activeCourse = runtimeForCourse(widget.activeCourseId);
    if (widget.onCourseChanged == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Sınıf düzeyi seç',
      initialValue: widget.activeCourseId,
      onSelected: widget.onCourseChanged,
      itemBuilder: (context) => [
        for (final course in supportedCourseRuntimes)
          PopupMenuItem<String>(
            value: course.courseId,
            child: Row(
              children: [
                if (course.courseId == widget.activeCourseId)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    course.isAwaitingTextbook
                        ? '${course.grade}. Sınıf · kitap bekleniyor'
                        : '${course.grade}. Sınıf',
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 20),
            const SizedBox(width: 6),
            Text(
              '${activeCourse.grade}. Sınıf',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _openTeachingSchedule() async {
    final activeCourse = runtimeForCourse(widget.activeCourseId);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeachingSchedulePage(
          repository: _instructionContext,
          weeklyPlanning: widget.dependencies.weeklyPlanning,
          timeline: _assignmentTimeline,
          courseId: widget.activeCourseId,
          grade: activeCourse.grade,
          legacyMigration: widget.dependencies.legacyTeacherStateMigration,
          legacyMigrationDecision: widget.dependencies.legacyMigrationDecision,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _scheduleRevision += 1;
      _annualPlanPage = null;
      _resourceLibraryPage = null;
    });
  }

  Widget _topTrailing(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 4,
    children: [
      _courseSelector(context),
      IconButton(
        tooltip: 'Sınıflar ve ders programı',
        onPressed: _openTeachingSchedule,
        icon: const Icon(Icons.edit_calendar_outlined),
      ),
    ],
  );

  Widget _annualPlan(BuildContext context) {
    final cached = _annualPlanPage;
    if (cached != null) return cached;
    if (widget.selectedIndex != 1) return const SizedBox.shrink();
    return _annualPlanPage = AnnualPlanPage(
      repository: widget.dependencies.repository,
      preferences: widget.dependencies.preferences,
      continuity: _continuity,
      courseId: widget.activeCourseId,
      outcomePlanning: _outcomePlanning,
      weeklyPlanning: widget.dependencies.weeklyPlanning,
      topTrailing: _topTrailing(context),
      onOpenResources: widget.onOpenResources,
    );
  }

  Widget _resourceLibrary(BuildContext context) {
    final cached = _resourceLibraryPage;
    if (cached == null && widget.selectedIndex != 2) {
      return const SizedBox.shrink();
    }
    final activeCourse = runtimeForCourse(widget.activeCourseId);
    return _resourceLibraryPage = ResourceLibraryPage(
      repository: widget.dependencies.repository,
      awaitingTextbook: activeCourse.isAwaitingTextbook,
      isActive: widget.selectedIndex == 2,
      continuity: _continuity,
      weeklyPlanning: widget.dependencies.weeklyPlanning,
      courseId: widget.activeCourseId,
      navigationContext: widget.resourceNavigationContext,
      topTrailing: _topTrailing(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.dependencies.repository;
    final pages = <Widget>[
      ContinuityThisWeekPage(
        key: ValueKey('${widget.activeCourseId}:schedule:$_scheduleRevision'),
        repository: repository,
        service: _outcomePlanning,
        continuity: _continuity,
        lessonPlanProgress: _lessonPlanProgress,
        instructionContext: _instructionContext,
        assignmentLessonProgress: _assignmentLessonProgress,
        assignmentOutcomeTracking: _assignmentOutcomeTracking,
        assignmentTimeline: _assignmentTimeline,
        courseId: widget.activeCourseId,
        topTrailing: _topTrailing(context),
        onConfigureSchedule: _openTeachingSchedule,
        onOpenResources: widget.onOpenResources,
      ),
      _annualPlan(context),
      _resourceLibrary(context),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compactLabels = textScale >= 1.5;
        final extendedRail =
            useRail && constraints.maxWidth >= 1080 && !compactLabels;
        final content = IndexedStack(
          index: widget.selectedIndex,
          children: pages,
        );

        return Scaffold(
          body: useRail
              ? Row(
                  children: [
                    SafeArea(
                      right: false,
                      child: NavigationRail(
                        selectedIndex: widget.selectedIndex,
                        onDestinationSelected: widget.onDestinationChanged,
                        extended: extendedRail,
                        minWidth: 72,
                        minExtendedWidth: 176,
                        labelType: extendedRail
                            ? NavigationRailLabelType.none
                            : compactLabels
                            ? NavigationRailLabelType.selected
                            : NavigationRailLabelType.all,
                        groupAlignment: -0.86,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.today_outlined),
                            selectedIcon: Icon(Icons.today),
                            label: Text('Bu Hafta'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.view_timeline_outlined),
                            selectedIcon: Icon(Icons.view_timeline),
                            label: Text('Plan'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.library_books_outlined),
                            selectedIcon: Icon(Icons.library_books),
                            label: Text('Kaynaklar'),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: widget.selectedIndex,
                  labelBehavior: compactLabels
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: widget.onDestinationChanged,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.today_outlined),
                      selectedIcon: Icon(Icons.today),
                      label: 'Bu Hafta',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.view_timeline_outlined),
                      selectedIcon: Icon(Icons.view_timeline),
                      label: 'Plan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.library_books_outlined),
                      selectedIcon: Icon(Icons.library_books),
                      label: 'Kaynaklar',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
