import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/repositories/outcome_tracking_repository.dart';
import '../domain/services/outcome_planning_service.dart';
import '../features/annual_plan/annual_plan_page.dart';
import '../features/outcomes/outcome_tracker_page.dart';
import '../features/teacher_package/teacher_package_page.dart';
import '../features/weekly_plan/weekly_plan_page.dart';
import 'app_dependencies.dart';
import 'theme/app_theme.dart';
import 'widgets/system_viewport_guard.dart';

class TeacherOsApp extends StatefulWidget {
  const TeacherOsApp({
    super.key,
    this.dependencies,
    this.loader = loadProductionDependencies,
  });

  final AppDependencies? dependencies;
  final Future<AppDependencies> Function()? loader;

  @override
  State<TeacherOsApp> createState() => _TeacherOsAppState();
}

class _TeacherOsAppState extends State<TeacherOsApp> {
  late final Future<AppDependencies> _dependenciesFuture;

  @override
  void initState() {
    super.initState();
    _dependenciesFuture = widget.dependencies != null
        ? Future.value(widget.dependencies)
        : widget.loader!();
  }

  @override
  void dispose() {
    if (widget.dependencies == null) {
      _dependenciesFuture.then((dependencies) => dependencies.dispose?.call());
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
    builder: (context, child) => SystemViewportGuard(
      child: child ?? const SizedBox.shrink(),
    ),
    home: FutureBuilder<AppDependencies>(
      future: _dependenciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupPage();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _StartupErrorPage(error: snapshot.error);
        }
        return _AppShell(dependencies: snapshot.data!);
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
  const _AppShell({required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  late final OutcomePlanningService _outcomePlanning;

  @override
  void initState() {
    super.initState();
    _outcomePlanning = widget.dependencies.outcomePlanning ??
        OutcomePlanningService(
          repository: widget.dependencies.repository,
          weeklyPlanning: widget.dependencies.weeklyPlanning,
          trackingRepository: MemoryOutcomeTrackingRepository(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.dependencies.repository;
    final preferences = widget.dependencies.preferences;
    final weeklyPlanning = widget.dependencies.weeklyPlanning;
    final pages = <Widget>[
      OutcomeTrackerPage(repository: repository, service: _outcomePlanning),
      WeeklyPlanPage(
        repository: repository,
        planningService: weeklyPlanning,
      ),
      AnnualPlanPage(repository: repository, preferences: preferences),
      TeacherPackagePage(repository: repository),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compactLabels = textScale >= 1.5;
        final content = IndexedStack(index: _selectedIndex, children: pages);

        return Scaffold(
          appBar: AppBar(title: const Text('ÖğretmenOS')),
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
                        groupAlignment: -0.75,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.fact_check_outlined),
                            selectedIcon: Icon(Icons.fact_check),
                            label: Text('Kazanımlar'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.calendar_view_week_outlined),
                            selectedIcon: Icon(Icons.calendar_view_week),
                            label: Text('Haftalık'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.view_timeline_outlined),
                            selectedIcon: Icon(Icons.view_timeline),
                            label: Text('Yıllık Plan'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.inventory_2_outlined),
                            selectedIcon: Icon(Icons.inventory_2),
                            label: Text('Paket'),
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
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check),
                      label: 'Kazanımlar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_view_week_outlined),
                      selectedIcon: Icon(Icons.calendar_view_week),
                      label: 'Haftalık',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.view_timeline_outlined),
                      selectedIcon: Icon(Icons.view_timeline),
                      label: 'Yıllık Plan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Paket',
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selectedIndex = index);
  }
}
