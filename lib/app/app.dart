import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/repositories/outcome_tracking_repository.dart';
import '../domain/runtime/course_runtime_registry.dart';
import '../domain/services/outcome_planning_service.dart';
import '../features/annual_plan/annual_plan_page.dart';
import '../features/resources/resource_library_page.dart';
import '../features/this_week/this_week_page.dart';
import 'app_dependencies.dart';
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
    final previous = _resolvedDependencies;
    _resolvedDependencies = null;
    setState(() {
      _activeCourseId = courseId;
      _dependenciesFuture = widget.courseLoader!(courseId);
    });
    await previous?.dispose?.call();
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
    home: FutureBuilder<AppDependencies>(
      future: _dependenciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupPage();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _StartupErrorPage(error: snapshot.error);
        }
        _resolvedDependencies = snapshot.data!;
        return _AppShell(
          key: ValueKey(_activeCourseId),
          dependencies: snapshot.data!,
          activeCourseId: _activeCourseId,
          onCourseChanged: widget.dependencies == null ? _switchCourse : null,
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
  const _StartupErrorPage({this.error});

  final Object? error;

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
    required this.onCourseChanged,
  });

  final AppDependencies dependencies;
  final String activeCourseId;
  final ValueChanged<String>? onCourseChanged;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  late final OutcomePlanningService _outcomePlanning;

  static const _titles = ['Bu Hafta', 'Yıllık Plan', 'Kaynaklar'];

  @override
  void initState() {
    super.initState();
    _outcomePlanning =
        widget.dependencies.outcomePlanning ??
        OutcomePlanningService(
          repository: widget.dependencies.repository,
          weeklyPlanning: widget.dependencies.weeklyPlanning,
          trackingRepository: MemoryOutcomeTrackingRepository(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.dependencies.repository;
    final activeCourse = runtimeForCourse(widget.activeCourseId);
    final pages = <Widget>[
      ThisWeekPage(repository: repository, service: _outcomePlanning),
      AnnualPlanPage(
        repository: repository,
        preferences: widget.dependencies.preferences,
      ),
      ResourceLibraryPage(
        repository: repository,
        awaitingTextbook: activeCourse.isAwaitingTextbook,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compactLabels = textScale >= 1.5;
        final content = IndexedStack(index: _selectedIndex, children: pages);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_titles[_selectedIndex]),
                Text(
                  activeCourse.isAwaitingTextbook
                      ? '${activeCourse.grade}. Sınıf · Kitap bekleniyor'
                      : '${activeCourse.grade}. Sınıf',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.onCourseChanged != null)
                PopupMenuButton<String>(
                  tooltip: 'Sınıf seç',
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
                  icon: const Icon(Icons.school_outlined),
                ),
            ],
          ),
          body: useRail
              ? Row(
                  children: [
                    SafeArea(
                      right: false,
                      child: NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _selectDestination,
                        labelType: compactLabels
                            ? NavigationRailLabelType.selected
                            : NavigationRailLabelType.all,
                        groupAlignment: -0.78,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.today_outlined),
                            selectedIcon: Icon(Icons.today),
                            label: Text('Bu Hafta'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.view_timeline_outlined),
                            selectedIcon: Icon(Icons.view_timeline),
                            label: Text('Yıllık'),
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
                  selectedIndex: _selectedIndex,
                  labelBehavior: compactLabels
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: _selectDestination,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.today_outlined),
                      selectedIcon: Icon(Icons.today),
                      label: 'Bu Hafta',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.view_timeline_outlined),
                      selectedIcon: Icon(Icons.view_timeline),
                      label: 'Yıllık',
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

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }
}
