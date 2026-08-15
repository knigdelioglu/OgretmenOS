import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/annual_plan/annual_plan_page.dart';
import '../features/home/home_page.dart';
import '../features/teacher_package/teacher_package_page.dart';
import 'app_dependencies.dart';
import 'theme/app_theme.dart';

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
                  'Uygulama ders içeriği yüklenmeden devam edemiyor.',
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

  static const _titles = ['Ana Sayfa', 'Yıllık Plan', 'Öğretmen Paketi'];

  @override
  Widget build(BuildContext context) {
    final repository = widget.dependencies.repository;
    final preferences = widget.dependencies.preferences;
    final pages = <Widget>[
      HomePage(
        repository: repository,
        preferences: preferences,
        onOpenAnnualPlan: () => _selectDestination(1),
        onOpenTeacherPackage: () => _selectDestination(2),
      ),
      AnnualPlanPage(repository: repository, preferences: preferences),
      TeacherPackagePage(repository: repository),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 840;
        final content = IndexedStack(index: _selectedIndex, children: pages);

        return Scaffold(
          appBar: AppBar(title: Text(_titles[_selectedIndex])),
          body: useRail
              ? Row(
                  children: [
                    SafeArea(
                      right: false,
                      child: NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _selectDestination,
                        labelType: NavigationRailLabelType.all,
                        groupAlignment: -0.75,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text('Ana Sayfa'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.view_timeline_outlined),
                            selectedIcon: Icon(Icons.view_timeline),
                            label: Text('Yıllık Plan'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.inventory_2_outlined),
                            selectedIcon: Icon(Icons.inventory_2),
                            label: Text('Öğretmen Paketi'),
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
                  onDestinationSelected: _selectDestination,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Ana Sayfa',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.view_timeline_outlined),
                      selectedIcon: Icon(Icons.view_timeline),
                      label: 'Yıllık Plan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Öğretmen Paketi',
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
