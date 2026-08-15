import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/annual_plan/annual_plan_page.dart';
import '../features/home/home_page.dart';
import '../features/runtime_spike/runtime_spike_page.dart';
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
    title: 'TYMM Teacher OS',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
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
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Runtime paketi hazırlanıyor…'),
        ],
      ),
    ),
  );
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TYMM Teacher OS')),
    body: Center(
      child: Padding(
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
                'Runtime paketi açılamadı.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Uygulama doğrulanmış ders verisi olmadan devam etmiyor.',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Runtime doğrulama',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RuntimeSpikePage(repository: repository),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            repository: repository,
            preferences: preferences,
            onOpenAnnualPlan: () => setState(() => _selectedIndex = 1),
            onOpenTeacherPackage: () => setState(() => _selectedIndex = 2),
          ),
          AnnualPlanPage(repository: repository, preferences: preferences),
          TeacherPackagePage(repository: repository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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
  }
}
