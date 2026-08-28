import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/continuity_repository.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart' as model;
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';
import 'package:ogretmen_os/domain/models/planning_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/outcome_tracking_repository.dart';
import 'package:ogretmen_os/domain/services/outcome_planning_service.dart';
import 'package:ogretmen_os/features/annual_plan/annual_plan_page.dart';
import 'package:ogretmen_os/features/block/block_detail_page.dart';
import 'package:ogretmen_os/features/resources/resource_library_page.dart';

void main() {
  testWidgets(
    'tracking buildPlan uzun sürse bile yıllık plan ana içeriği önce görünür',
    (tester) async {
      _phone(tester);
      final repository = _TabRepository('TDE_9');
      final plan = _planFor(
        repository,
        status: OutcomeTrackingStatus.completed,
      );
      final completer = Completer<AnnualOutcomePlan>();
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
        completer: completer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnualPlanPage(
              repository: repository,
              preferences: _Preferences(),
              continuity: MemoryContinuityRepository(),
              courseId: repository.courseId,
              outcomePlanning: service,
            ),
          ),
        ),
      );

      // Ana yükleme tamamlanır; completer henüz resolve edilmedi
      await tester.pump();
      await tester.pump();

      // Completer unresolved iken ana yıllık plan içeriği görünür
      expect(find.text('1 tema · 45 saat · 1 blok'), findsOneWidget);
      expect(find.text('TDE_9 Tema'), findsOneWidget);
      expect(find.text('Yıllık plan hazırlanıyor…'), findsNothing);
      // Tracking summary henüz yüklenmediği için görünmemeli
      expect(find.text('İSTEĞE BAĞLI TAKİP'), findsNothing);
      expect(find.text('İşlendi 1'), findsNothing);

      // Tracking buildPlan tamamlanıyor
      completer.complete(plan);
      await tester.pumpAndSettle();

      // Artık tracking summary de görünür
      expect(find.text('1 tema · 45 saat · 1 blok'), findsOneWidget);
      expect(find.text('İSTEĞE BAĞLI TAKİP'), findsOneWidget);
      expect(find.text('İşlendi 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tracking summary hatası ana yıllık planı bozmaz', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
      failure: StateError('tracking intentionally failed'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnualPlanPage(
            repository: repository,
            preferences: _Preferences(),
            continuity: MemoryContinuityRepository(),
            courseId: repository.courseId,
            outcomePlanning: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 tema · 45 saat · 1 blok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plan sekmesine dönüşte full loader yeniden başlamaz', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
    );

    await tester.pumpWidget(
      TeacherOsApp(dependencies: _dependencies(repository, service)),
    );
    await tester.pumpAndSettle();
    final initialPlanCalls = service.buildPlanCalls;

    await _tapDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();
    final annualSequenceCalls = repository.annualSequenceCalls;
    final firstPlanCalls = service.buildPlanCalls;

    await _tapDestination(tester, Icons.today_outlined);
    await tester.pumpAndSettle();
    await _tapDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();

    expect(initialPlanCalls, 1);
    expect(repository.annualSequenceCalls, annualSequenceCalls);
    expect(service.buildPlanCalls, firstPlanCalls);
    expect(repository.annualSequenceCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Bu Hafta ekranında başka bloktaki ders açıldığında Plan yıllık listedeki konumu günceller ve buildPlan tekrar çağrılmaz',
    (tester) async {
      _phone(tester);
      final repository = _TwoBlockTabRepository('TDE_9');
      final plan = _twoBlockPlanFor(repository);
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
      );
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1',
          updatedAt: DateTime.now(),
        ),
      );

      final dependencies = AppDependencies(
        repository: repository,
        preferences: _Preferences(),
        weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
        outcomePlanning: service,
        continuity: continuity,
      );

      await tester.pumpWidget(TeacherOsApp(dependencies: dependencies));
      await tester.pumpAndSettle();

      // 1. Plan sekmesine git
      await _tapDestination(tester, Icons.view_timeline_outlined);
      await tester.pumpAndSettle();

      // Plan B1'i göstermeli
      expect(find.text('TDE_9 Blok 1'), findsOneWidget);
      expect(repository.annualSequenceCalls, 1);
      final buildPlanCallsAfterPlan = service.buildPlanCalls;

      // 2. Bu Hafta sekmesine geri dön
      await _tapDestination(tester, Icons.today_outlined);
      await tester.pumpAndSettle();

      // 3. B2'deki dersi aç
      await tester.tap(find.text('Bu haftanın diğerleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TDE_9 ikinci kazanım'));
      await tester.pumpAndSettle();

      // Continuity artık B2 olmalı
      final currentFocus = await continuity.getLastFocus('TDE_9');
      expect(currentFocus?.blockId, 'TDE_9-B2');

      // Outcome detayından geri çık
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();

      // 4. Plan sekmesine geri dön
      await _tapDestination(tester, Icons.view_timeline_outlined);
      await tester.pumpAndSettle();

      // Plan artık B2'yi göstermeli!
      expect(find.text('TDE_9 Blok 2'), findsOneWidget);

      // Annual sequence ve OutcomePlanning buildPlan ekstra çağrılmamış olmalı!
      expect(repository.annualSequenceCalls, 1);
      expect(service.buildPlanCalls, buildPlanCallsAfterPlan);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Kaynaklar ilk açılışında OutcomePlanningService çağrılmaz', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceLibraryPage(
            repository: repository,
            awaitingTextbook: false,
            continuity: MemoryContinuityRepository(),
            weeklyPlanning: _FixedWeeklyPlanning(
              _planFor(repository).weeklyPlan,
            ),
            courseId: repository.courseId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.buildPlanCalls, 0);
    expect(repository.teacherPackageCalls, 1);
    expect(find.text('TDE_9 Tema kaynak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kaynaklar sekmesine dönüşte teacher package yeniden yüklenmez', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TabRepository('TDE_9');
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: _planFor(repository),
    );

    await tester.pumpWidget(
      TeacherOsApp(dependencies: _dependencies(repository, service)),
    );
    await tester.pumpAndSettle();
    final initialPlanCalls = service.buildPlanCalls;

    await _tapDestination(tester, Icons.library_books_outlined);
    await tester.pumpAndSettle();
    final firstPackageCalls = repository.teacherPackageCalls;
    final outcomeCallsBeforeReturn = service.buildPlanCalls;

    await _tapDestination(tester, Icons.today_outlined);
    await tester.pumpAndSettle();
    await _tapDestination(tester, Icons.library_books_outlined);
    await tester.pumpAndSettle();

    expect(initialPlanCalls, 1);
    expect(repository.teacherPackageCalls, firstPackageCalls);
    expect(service.buildPlanCalls, outcomeCallsBeforeReturn);
    expect(repository.teacherPackageCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Bu Hafta geçmiş hafta incelemesi normal Kaynaklar resolverını değiştirmez',
    (tester) async {
      _phone(tester);
      final repository = _TwoThemeTabRepository('TDE_9');
      final plan = _twoThemePlanFor(repository, includeReviewWeek: true);
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
      );
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-T1-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema 1',
          themeId: 'TDE_9-T1',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1',
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        TeacherOsApp(
          dependencies: AppDependencies(
            repository: repository,
            preferences: _Preferences(),
            weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
            outcomePlanning: service,
            continuity: continuity,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hafta değiştir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Hafta'));
      await tester.pumpAndSettle();
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      expect(find.text('TDE_9 Tema 1 kaynak'), findsOneWidget);
      expect(find.text('TDE_9 Tema 2 kaynak'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Bloktan tema kaynaklarına geçiş doğru temayı açar', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TwoThemeTabRepository('TDE_9');
    final plan = _twoThemePlanFor(repository);
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: plan,
    );
    final continuity = MemoryContinuityRepository();
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        weekNumber: 1,
        trackingKey: '2026-2027:TDE_9-T1-O1:1',
        outcomeCode: 'TDE_9.1',
        themeTitle: 'TDE_9 Tema 1',
        themeId: 'TDE_9-T1',
        blockId: 'TDE_9-B1',
        blockTitle: 'TDE_9 Blok 1',
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      TeacherOsApp(
        dependencies: AppDependencies(
          repository: repository,
          preferences: _Preferences(),
          weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
          outcomePlanning: service,
          continuity: continuity,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapDestination(tester, Icons.view_timeline_outlined);
    await tester.pumpAndSettle();
    await tester.tap(find.text('TDE_9 Blok 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu blokta kullanılan kaynaklar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temanın tüm kaynaklarını aç'));
    await tester.pumpAndSettle();

    expect(find.text('TDE_9 Tema 1 kaynak'), findsOneWidget);
    expect(find.text('TDE_9 Tema 2 kaynak'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Plan blok ders planı kaynak bağlantısı üst route zincirini kapatır',
    (tester) async {
      _phone(tester);
      final repository = _StackLessonPlanRepository('TDE_9');
      final plan = _twoThemePlanFor(repository);
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
      );
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-T1-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema 1',
          themeId: 'TDE_9-T1',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1',
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        TeacherOsApp(
          dependencies: AppDependencies(
            repository: repository,
            preferences: _Preferences(),
            weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
            outcomePlanning: service,
            continuity: continuity,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapDestination(tester, Icons.view_timeline_outlined);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TDE_9 Blok 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1. ders saati'));
      await tester.pumpAndSettle();

      final resourceLink = find.text('Kaynaklarda aç');
      await tester.ensureVisible(resourceLink);
      await tester.pumpAndSettle();
      await tester.tap(resourceLink.first);
      await tester.pumpAndSettle();

      expect(find.text('Ders Planı'), findsNothing);
      expect(find.byType(BlockDetailPage), findsNothing);
      expect(find.text('Kaynaklar'), findsWidgets);
      expect(find.text('TDE_9 Tema 1 kaynak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Kaynaklar sekmesine yeniden giriş mevcut resolver ile manuel temayı yeniler',
    (tester) async {
      _phone(tester);
      final repository = _TwoThemeTabRepository('TDE_9');
      final plan = _twoThemePlanFor(repository);
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
      );
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-T1-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema 1',
          themeId: 'TDE_9-T1',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1',
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        TeacherOsApp(
          dependencies: AppDependencies(
            repository: repository,
            preferences: _Preferences(),
            weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
            outcomePlanning: service,
            continuity: continuity,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TDE_9 Tema 2').last);
      await tester.pumpAndSettle();
      expect(find.text('TDE_9 Tema 2 kaynak'), findsOneWidget);

      await _tapDestination(tester, Icons.today_outlined);
      await tester.pumpAndSettle();
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      expect(find.text('TDE_9 Tema 1 kaynak'), findsOneWidget);
      expect(find.text('TDE_9 Tema 2 kaynak'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Kaynaklar sekmesi açıldıktan sonra Bu Hafta sekmesinde farklı temadaki ders açıldığında Kaynaklar yeni temayı gösterir',
    (tester) async {
      _phone(tester);
      final repository = _TwoThemeTabRepository('TDE_9');
      final plan = _twoThemePlanFor(repository);
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
      );
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-T1-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema 1',
          themeId: 'TDE_9-T1',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1',
          updatedAt: DateTime.now(),
        ),
      );

      final dependencies = AppDependencies(
        repository: repository,
        preferences: _Preferences(),
        weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
        outcomePlanning: service,
        continuity: continuity,
      );

      await tester.pumpWidget(TeacherOsApp(dependencies: dependencies));
      await tester.pumpAndSettle();

      // 1. Kaynaklar sekmesine git
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      // Tema 1 kaynakları görünmeli
      expect(find.text('TDE_9 Tema 1 kaynak'), findsOneWidget);
      expect(repository.teacherPackageCalls, 1);
      expect(repository.getThemesCalls, 1);

      // 2. Bu Hafta sekmesine git
      await _tapDestination(tester, Icons.today_outlined);
      await tester.pumpAndSettle();

      // 3. Tema 2'deki dersi aç
      await tester.tap(find.text('Bu haftanın diğerleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TDE_9 Tema 2 kazanımı'));
      await tester.pumpAndSettle();

      // Focus artık Tema 2 olmalı
      final currentFocus = await continuity.getLastFocus('TDE_9');
      expect(currentFocus?.themeId, 'TDE_9-T2');

      // Outcome detayından geri çık
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();

      // 4. Kaynaklar sekmesine geri dön
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      // Tema 2 kaynakları görünmeli!
      expect(find.text('TDE_9 Tema 2 kaynak'), findsOneWidget);

      // getThemes tekrar çağrılmamış olmalı (hala 1), teacherPackageCalls 2 olmalı (yalnızca Tema 2 için 1 kez çağrıldı)
      expect(repository.getThemesCalls, 1);
      expect(repository.teacherPackageCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LastFocus değişirse cached Plan kendini cheap şekilde günceller',
    (tester) async {
      _phone(tester);
      final repository = _TwoBlockTabRepository('TDE_9');
      final plan = _twoBlockPlanFor(repository);
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
      );
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1',
          updatedAt: DateTime.now(),
        ),
      );

      final dependencies = AppDependencies(
        repository: repository,
        preferences: _Preferences(),
        weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
        outcomePlanning: service,
        continuity: continuity,
      );

      await tester.pumpWidget(TeacherOsApp(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Plan sekmesine git
      await _tapDestination(tester, Icons.view_timeline_outlined);
      await tester.pumpAndSettle();

      expect(find.text('TDE_9 Blok 1'), findsOneWidget);
      expect(repository.annualSequenceCalls, 1);
      final buildPlanCalls = service.buildPlanCalls;

      // LastFocus B2 olarak değişir
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-O2:1',
          outcomeCode: 'TDE_9.2',
          themeTitle: 'TDE_9 Tema',
          blockId: 'TDE_9-B2',
          blockTitle: 'TDE_9 Blok 2',
          updatedAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      // Plan anında B2'yi göstermeli
      expect(find.text('TDE_9 Blok 2'), findsOneWidget);

      // getAnnualSequence ve buildPlan ekstra çağrılmamış olmalı (cheap update)
      expect(repository.annualSequenceCalls, 1);
      expect(service.buildPlanCalls, buildPlanCalls);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LastFocus değişirse cached Resources yalnız theme değişmişse package değiştirir',
    (tester) async {
      _phone(tester);
      final repository = _TwoThemeTabRepository('TDE_9');
      final plan = _twoThemePlanFor(repository);
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: plan,
      );
      final continuity = MemoryContinuityRepository();
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-T1-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema 1',
          themeId: 'TDE_9-T1',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1',
          updatedAt: DateTime.now(),
        ),
      );

      final dependencies = AppDependencies(
        repository: repository,
        preferences: _Preferences(),
        weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
        outcomePlanning: service,
        continuity: continuity,
      );

      await tester.pumpWidget(TeacherOsApp(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Kaynaklar sekmesine git
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      expect(find.text('TDE_9 Tema 1 kaynak'), findsOneWidget);
      expect(repository.getThemesCalls, 1);
      expect(repository.teacherPackageCalls, 1);

      // 1. Durum: Aynı tema içinde farklı bir blok/ders odağı (Tema 1 içinde kalır)
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-T1-O1:1',
          outcomeCode: 'TDE_9.1',
          themeTitle: 'TDE_9 Tema 1',
          themeId: 'TDE_9-T1',
          blockId: 'TDE_9-B1',
          blockTitle: 'TDE_9 Blok 1 (güncel ders)',
          updatedAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      // Tema değişmediği için teacher package yeniden çağrılmamalı (0 ek çağrı)
      expect(repository.teacherPackageCalls, 1);
      expect(repository.getThemesCalls, 1);

      // 2. Durum: Farklı tema (Tema 2) odağı gelir
      await continuity.setLastFocus(
        LastFocusState(
          courseId: 'TDE_9',
          academicYear: '2026-2027',
          weekNumber: 1,
          trackingKey: '2026-2027:TDE_9-T2-O2:1',
          outcomeCode: 'TDE_9.2',
          themeTitle: 'TDE_9 Tema 2',
          themeId: 'TDE_9-T2',
          blockId: 'TDE_9-B2',
          blockTitle: 'TDE_9 Blok 2',
          updatedAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      // Tema 2 kaynakları görünmeli, getTeacherPackage 1 kez daha çağrılmalı, getThemes çağrılmamalı
      expect(find.text('TDE_9 Tema 2 kaynak'), findsOneWidget);
      expect(repository.teacherPackageCalls, 2);
      expect(repository.getThemesCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('eski academicYear focus\'u Resources tarafından kullanılmaz', (
    tester,
  ) async {
    _phone(tester);
    final repository = _TwoThemeTabRepository('TDE_9');
    final plan = _twoThemePlanFor(repository);
    final service = _CountingOutcomePlanningService(
      repository: repository,
      plan: plan,
    );
    final continuity = MemoryContinuityRepository();

    // 2025-2026 eski akademik yıla ait Tema 2 odağı kaydedilmiş
    await continuity.setLastFocus(
      LastFocusState(
        courseId: 'TDE_9',
        academicYear: '2025-2026',
        weekNumber: 36,
        trackingKey: '2025-2026:TDE_9-T2-O2:36',
        outcomeCode: 'TDE_9.2',
        themeTitle: 'TDE_9 Tema 2',
        themeId: 'TDE_9-T2',
        blockId: 'TDE_9-B2',
        blockTitle: 'TDE_9 Blok 2',
        updatedAt: DateTime(2026, 6, 15),
      ),
    );

    final dependencies = AppDependencies(
      repository: repository,
      preferences: _Preferences(),
      weeklyPlanning: _FixedWeeklyPlanning(plan.weeklyPlan),
      outcomePlanning: service,
      continuity: continuity,
    );

    await tester.pumpWidget(TeacherOsApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    // Kaynaklar sekmesine git
    await _tapDestination(tester, Icons.library_books_outlined);
    await tester.pumpAndSettle();

    // 2026-2027 mevcut haftasının teması (Tema 1) açılmalı, eski yılın Tema 2'si açılmamalı
    expect(find.text('TDE_9 Tema 1 kaynak'), findsOneWidget);
    expect(find.text('TDE_9 Tema 2 kaynak'), findsNothing);

    // Stale focus continuity'den temizlenmiş olmalı
    expect(await continuity.getLastFocus('TDE_9'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uygulama Bu Hafta ile açıldığında Plan ve Kaynaklar lazy kalır',
    (tester) async {
      _phone(tester);
      final repository = _TabRepository('TDE_9');
      final service = _CountingOutcomePlanningService(
        repository: repository,
        plan: _planFor(repository),
      );

      await tester.pumpWidget(
        TeacherOsApp(dependencies: _dependencies(repository, service)),
      );
      await tester.pumpAndSettle();

      expect(repository.annualSequenceCalls, 0);
      expect(repository.getThemesCalls, 0);
      expect(repository.teacherPackageCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'courseId değiştiğinde lazy tab state yeni course için yenilenir',
    (tester) async {
      _phone(tester);
      final repositories = <String, _TabRepository>{};
      final services = <String, _CountingOutcomePlanningService>{};

      AppDependencies dependenciesFor(String courseId) {
        final repository = _TabRepository(courseId);
        final service = _CountingOutcomePlanningService(
          repository: repository,
          plan: _planFor(repository),
        );
        repositories[courseId] = repository;
        services[courseId] = service;
        return _dependencies(repository, service);
      }

      await tester.pumpWidget(
        TeacherOsApp(
          courseLoader: (courseId) async => dependenciesFor(courseId),
        ),
      );
      await tester.pumpAndSettle();
      await _tapDestination(tester, Icons.library_books_outlined);
      await tester.pumpAndSettle();

      expect(repositories['TDE_9']!.teacherPackageCalls, 1);
      await tester.tap(find.byTooltip('Sınıf seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10. Sınıf'));
      await tester.pumpAndSettle();

      expect(find.text('TDE_10 Tema kaynak'), findsOneWidget);
      expect(repositories['TDE_10']!.teacherPackageCalls, 1);
      expect(services['TDE_9']!.buildPlanCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'lightweight planning context çıktıyı korur ve full block hydration yapmaz',
    () async {
      final legacyRepository = _TabRepository('TDE_9');
      final projectionRepository = _TabRepository('TDE_9');
      final legacy = await OutcomePlanningService(
        repository: legacyRepository,
        weeklyPlanning: _ProjectionWeeklyPlanning(
          legacyRepository,
          includeProjection: false,
        ),
        trackingRepository: MemoryOutcomeTrackingRepository(),
      ).buildPlan();
      final projected = await OutcomePlanningService(
        repository: projectionRepository,
        weeklyPlanning: _ProjectionWeeklyPlanning(
          projectionRepository,
          includeProjection: true,
        ),
        trackingRepository: MemoryOutcomeTrackingRepository(),
      ).buildPlan();

      final legacyItem = legacy.week(1)!.outcomes.single;
      final projectedItem = projected.week(1)!.outcomes.single;
      expect(projectedItem.outcome.id, legacyItem.outcome.id);
      expect(projectedItem.status, legacyItem.status);
      expect(projectedItem.primaryTheme?.id, legacyItem.primaryTheme?.id);
      expect(projectedItem.primaryBlock?.id, legacyItem.primaryBlock?.id);
      expect(projectedItem.contexts.single.detail, isNull);
      expect(legacyRepository.getBlockCalls, 1);
      expect(projectionRepository.getBlockCalls, 0);
    },
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapDestination(WidgetTester tester, IconData icon) async {
  final bar = find.byType(NavigationBar);
  expect(bar, findsOneWidget);
  await tester.tap(find.descendant(of: bar, matching: find.byIcon(icon)));
}

AppDependencies _dependencies(
  _TabRepository repository,
  _CountingOutcomePlanningService service,
) => AppDependencies(
  repository: repository,
  preferences: _Preferences(),
  weeklyPlanning: _FixedWeeklyPlanning(_planFor(repository).weeklyPlan),
  outcomePlanning: service,
  continuity: MemoryContinuityRepository(),
);

AnnualOutcomePlan _planFor(
  _TabRepository repository, {
  OutcomeTrackingStatus status = OutcomeTrackingStatus.planned,
}) {
  final planningBlock = PlanningBlock(
    theme: repository.theme,
    block: repository.block,
    outcomes: [repository.outcome],
  );
  final week = AcademicWeekPlan(
    weekNumber: 1,
    start: DateTime(2026, 9, 14),
    end: DateTime(2026, 9, 18),
    type: AcademicWeekType.instruction,
    label: '1. Hafta',
    plannedLessonHours: 5,
    segments: [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: repository.theme,
        hours: 5,
        block: repository.block,
        planningBlock: planningBlock,
      ),
    ],
    outcomes: [repository.outcome],
  );
  final weeklyPlan = AnnualWeeklyPlan(
    academicYear: '2026-2027',
    courseId: repository.courseId,
    weeklyLessonHours: 5,
    annualHours: 45,
    currentWeekNumber: 1,
    weeks: [week],
  );
  return AnnualOutcomePlan(
    weeklyPlan: weeklyPlan,
    weeks: [
      WeeklyOutcomeSummary(
        week: week,
        outcomes: [
          TrackedOutcome(
            outcome: repository.outcome,
            academicYear: '2026-2027',
            plannedWeekNumber: 1,
            displayWeekNumber: 1,
            status: status,
            contexts: [
              OutcomeBlockContext.lightweight(
                theme: repository.theme,
                block: repository.block,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _CountingOutcomePlanningService extends OutcomePlanningService {
  _CountingOutcomePlanningService({
    required super.repository,
    required this.plan,
    this.completer,
    this.failure,
  }) : super(
         weeklyPlanning: _ThrowingWeeklyPlanning(),
         trackingRepository: MemoryOutcomeTrackingRepository(),
       );

  final AnnualOutcomePlan plan;
  final Completer<AnnualOutcomePlan>? completer;
  final Object? failure;
  int buildPlanCalls = 0;

  @override
  Future<AnnualOutcomePlan> buildPlan({DateTime? today}) {
    buildPlanCalls++;
    final failure = this.failure;
    if (failure != null) {
      return Future<AnnualOutcomePlan>.error(failure);
    }
    final completer = this.completer;
    if (completer != null) {
      return completer.future;
    }
    return Future.value(plan);
  }
}

class _ThrowingWeeklyPlanning implements WeeklyPlanningService {
  const _ThrowingWeeklyPlanning();

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) =>
      Future<AnnualWeeklyPlan>.error(StateError('not used'));
}

class _FixedWeeklyPlanning implements WeeklyPlanningService {
  const _FixedWeeklyPlanning(this.plan);

  final AnnualWeeklyPlan plan;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async => plan;
}

class _ProjectionWeeklyPlanning implements WeeklyPlanningService {
  _ProjectionWeeklyPlanning(this.repository, {required this.includeProjection});

  final _TabRepository repository;
  final bool includeProjection;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async {
    final segment = WeeklyPlanSegment(
      type: WeeklyPlanSegmentType.block,
      theme: repository.theme,
      hours: 5,
      block: repository.block,
      planningBlock: includeProjection
          ? PlanningBlock(
              theme: repository.theme,
              block: repository.block,
              outcomes: [repository.outcome],
            )
          : null,
    );
    final week = AcademicWeekPlan(
      weekNumber: 1,
      start: DateTime(2026, 9, 14),
      end: DateTime(2026, 9, 18),
      type: AcademicWeekType.instruction,
      label: '1. Hafta',
      plannedLessonHours: 5,
      segments: [segment],
      outcomes: [repository.outcome],
    );
    return AnnualWeeklyPlan(
      academicYear: '2026-2027',
      courseId: repository.courseId,
      weeklyLessonHours: 5,
      annualHours: 45,
      currentWeekNumber: 1,
      weeks: [week],
    );
  }
}

class _Preferences implements UserPreferencesRepository {
  String? value;

  @override
  Future<String?> getManualPositionOverride() async => value;

  @override
  Future<void> setManualPositionOverride(String blockId) async {
    value = blockId;
  }

  @override
  Future<void> clearManualPositionOverride() async {
    value = null;
  }
}

class _TabRepository implements CourseKnowledgeRepository {
  _TabRepository(this.courseId)
    : theme = model.Theme(
        id: '$courseId-T1',
        order: 1,
        title: '$courseId Tema',
        pageRange: null,
        plannedHours: 45,
        anlamaHours: null,
        anlatmaHours: null,
        sourceLocator: null,
      ),
      block = model.Block(
        id: '$courseId-B1',
        themeId: '$courseId-T1',
        order: 1,
        title: '$courseId Blok',
        skillDomain: 'Okuma',
        learningArea: null,
        plannedHours: null,
        timeStatus: 'ORDER_ONLY',
        sourceLocators: const [],
      ),
      outcome = model.Outcome(
        id: '$courseId-O1',
        themeId: '$courseId-T1',
        code: '$courseId.1',
        officialText: '$courseId kazanımı',
        processComponents: null,
        sourceLocator: null,
        verificationStatus: 'PASS',
      );

  final String courseId;
  final model.Theme theme;
  final model.Block block;
  final model.Outcome outcome;
  int annualSequenceCalls = 0;
  int getThemesCalls = 0;
  int teacherPackageCalls = 0;
  int getBlockCalls = 0;

  model.BlockDetail get detail => model.BlockDetail(
    theme: theme,
    block: block,
    outcomes: [outcome],
    textbookSections: [
      model.TextbookSection(
        id: '$courseId-S1',
        themeId: theme.id,
        title: '$courseId Tema kaynak',
        genre: 'Metin',
        printedPageRange: '1-2',
        pdfPageRange: null,
        sourceId: null,
      ),
    ],
    activities: const [],
    forms: const [],
    assessmentArtifacts: const [],
    assessmentGaps: const [],
    assessmentTaskBindings: const [],
    resourceDecisions: const [],
    sourceReferences: const [],
    previousBlock: null,
    nextBlock: null,
  );

  @override
  Future<model.Course> getCourse() async => model.Course(
    courseId: courseId,
    grade: courseId == 'TDE_10' ? 10 : 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: courseId,
  );

  @override
  Future<model.RuntimeManifest> getManifest() async => model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: courseId,
    validationStatus: 'PASS',
    canonicalContentFingerprint: courseId,
    rowCounts: const {},
    timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
    timelineUnresolvedFields: const {},
  );

  @override
  Future<List<model.Theme>> getThemes() async {
    getThemesCalls++;
    return [theme];
  }

  @override
  Future<model.Theme> getTheme(String themeId) async => theme;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => [block];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async {
    getBlockCalls++;
    return detail;
  }

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async {
    annualSequenceCalls++;
    return [
      model.TimelineEntry(
        sequencePosition: 1,
        theme: theme,
        block: block,
        officialTotalHours: 45,
        coreInstructionHours: 45,
        schoolBasedHours: 0,
        schoolBasedHoursStatus: 'CONFIRMED',
      ),
    ];
  }

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(
    String themeId,
  ) async => const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async {
    teacherPackageCalls++;
    return model.TeacherPackage(
      theme: theme,
      blocks: [block],
      outcomes: [outcome],
      textbookSections: detail.textbookSections,
      activities: const [],
      forms: const [],
      assessmentArtifacts: const [],
      assessmentGaps: const [],
      assessmentTaskBindings: const [],
      resourceDecisions: const [],
      sourceReferences: const [],
    );
  }
}

AnnualOutcomePlan _twoBlockPlanFor(_TwoBlockTabRepository repository) {
  final planningBlock1 = PlanningBlock(
    theme: repository.theme,
    block: repository.block1,
    outcomes: [repository.outcome1],
  );
  final planningBlock2 = PlanningBlock(
    theme: repository.theme,
    block: repository.block2,
    outcomes: [repository.outcome2],
  );
  final week = AcademicWeekPlan(
    weekNumber: 1,
    start: DateTime(2026, 9, 14),
    end: DateTime(2026, 9, 18),
    type: AcademicWeekType.instruction,
    label: '1. Hafta',
    plannedLessonHours: 5,
    segments: [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: repository.theme,
        hours: 3,
        block: repository.block1,
        planningBlock: planningBlock1,
      ),
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: repository.theme,
        hours: 2,
        block: repository.block2,
        planningBlock: planningBlock2,
      ),
    ],
    outcomes: [repository.outcome1, repository.outcome2],
  );
  final weeklyPlan = AnnualWeeklyPlan(
    academicYear: '2026-2027',
    courseId: repository.courseId,
    weeklyLessonHours: 5,
    annualHours: 45,
    currentWeekNumber: 1,
    weeks: [week],
  );
  return AnnualOutcomePlan(
    weeklyPlan: weeklyPlan,
    weeks: [
      WeeklyOutcomeSummary(
        week: week,
        outcomes: [
          TrackedOutcome(
            outcome: repository.outcome1,
            academicYear: '2026-2027',
            plannedWeekNumber: 1,
            displayWeekNumber: 1,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext.lightweight(
                theme: repository.theme,
                block: repository.block1,
              ),
            ],
          ),
          TrackedOutcome(
            outcome: repository.outcome2,
            academicYear: '2026-2027',
            plannedWeekNumber: 1,
            displayWeekNumber: 1,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext.lightweight(
                theme: repository.theme,
                block: repository.block2,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _TwoBlockTabRepository implements CourseKnowledgeRepository {
  _TwoBlockTabRepository(this.courseId)
    : theme = model.Theme(
        id: '$courseId-T1',
        order: 1,
        title: '$courseId Tema',
        pageRange: null,
        plannedHours: 45,
        anlamaHours: null,
        anlatmaHours: null,
        sourceLocator: null,
      ),
      block1 = model.Block(
        id: '$courseId-B1',
        themeId: '$courseId-T1',
        order: 1,
        title: '$courseId Blok 1',
        skillDomain: 'Okuma',
        learningArea: null,
        plannedHours: null,
        timeStatus: 'ORDER_ONLY',
        sourceLocators: const [],
      ),
      block2 = model.Block(
        id: '$courseId-B2',
        themeId: '$courseId-T1',
        order: 2,
        title: '$courseId Blok 2',
        skillDomain: 'Yazma',
        learningArea: null,
        plannedHours: null,
        timeStatus: 'ORDER_ONLY',
        sourceLocators: const [],
      ),
      outcome1 = model.Outcome(
        id: '$courseId-O1',
        themeId: '$courseId-T1',
        code: '$courseId.1',
        officialText: '$courseId birinci kazanım',
        processComponents: null,
        sourceLocator: null,
        verificationStatus: 'PASS',
      ),
      outcome2 = model.Outcome(
        id: '$courseId-O2',
        themeId: '$courseId-T1',
        code: '$courseId.2',
        officialText: '$courseId ikinci kazanım',
        processComponents: null,
        sourceLocator: null,
        verificationStatus: 'PASS',
      );

  final String courseId;
  final model.Theme theme;
  final model.Block block1;
  final model.Block block2;
  final model.Outcome outcome1;
  final model.Outcome outcome2;
  int annualSequenceCalls = 0;
  int getThemesCalls = 0;
  int teacherPackageCalls = 0;
  int getBlockCalls = 0;

  @override
  Future<model.Course> getCourse() async => model.Course(
    courseId: courseId,
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: courseId,
  );

  @override
  Future<model.RuntimeManifest> getManifest() async => model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: courseId,
    validationStatus: 'PASS',
    canonicalContentFingerprint: courseId,
    rowCounts: const {},
    timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
    timelineUnresolvedFields: const {},
  );

  @override
  Future<List<model.Theme>> getThemes() async {
    getThemesCalls++;
    return [theme];
  }

  @override
  Future<model.Theme> getTheme(String themeId) async => theme;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async => [block1, block2];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async {
    getBlockCalls++;
    final isB1 = blockId == block1.id;
    return model.BlockDetail(
      theme: theme,
      block: isB1 ? block1 : block2,
      outcomes: [isB1 ? outcome1 : outcome2],
      textbookSections: const [],
      activities: const [],
      forms: const [],
      assessmentArtifacts: const [],
      assessmentGaps: const [],
      assessmentTaskBindings: const [],
      resourceDecisions: const [],
      sourceReferences: const [],
      previousBlock: isB1 ? null : block1,
      nextBlock: isB1 ? block2 : null,
    );
  }

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async {
    annualSequenceCalls++;
    return [
      model.TimelineEntry(
        sequencePosition: 1,
        theme: theme,
        block: block1,
        officialTotalHours: 45,
        coreInstructionHours: 20,
        schoolBasedHours: 0,
        schoolBasedHoursStatus: 'CONFIRMED',
      ),
      model.TimelineEntry(
        sequencePosition: 2,
        theme: theme,
        block: block2,
        officialTotalHours: 45,
        coreInstructionHours: 25,
        schoolBasedHours: 0,
        schoolBasedHoursStatus: 'CONFIRMED',
      ),
    ];
  }

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(
    String themeId,
  ) async => const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async {
    teacherPackageCalls++;
    return model.TeacherPackage(
      theme: theme,
      blocks: [block1, block2],
      outcomes: [outcome1, outcome2],
      textbookSections: const [],
      activities: const [],
      forms: const [],
      assessmentArtifacts: const [],
      assessmentGaps: const [],
      assessmentTaskBindings: const [],
      resourceDecisions: const [],
      sourceReferences: const [],
    );
  }
}

AnnualOutcomePlan _twoThemePlanFor(
  _TwoThemeTabRepository repository, {
  bool includeReviewWeek = false,
}) {
  final planningBlock1 = PlanningBlock(
    theme: repository.theme1,
    block: repository.block1,
    outcomes: [repository.outcome1],
  );
  final planningBlock2 = PlanningBlock(
    theme: repository.theme2,
    block: repository.block2,
    outcomes: [repository.outcome2],
  );
  final week = AcademicWeekPlan(
    weekNumber: 1,
    start: DateTime(2026, 9, 14),
    end: DateTime(2026, 9, 18),
    type: AcademicWeekType.instruction,
    label: '1. Hafta',
    plannedLessonHours: 5,
    segments: [
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: repository.theme1,
        hours: 3,
        block: repository.block1,
        planningBlock: planningBlock1,
      ),
      WeeklyPlanSegment(
        type: WeeklyPlanSegmentType.block,
        theme: repository.theme2,
        hours: 2,
        block: repository.block2,
        planningBlock: planningBlock2,
      ),
    ],
    outcomes: [repository.outcome1, repository.outcome2],
  );
  final weeks = <AcademicWeekPlan>[week];
  if (includeReviewWeek) {
    weeks.add(
      AcademicWeekPlan(
        weekNumber: 2,
        start: DateTime(2026, 9, 21),
        end: DateTime(2026, 9, 25),
        type: AcademicWeekType.instruction,
        label: '2. Hafta',
        plannedLessonHours: 5,
        segments: [
          WeeklyPlanSegment(
            type: WeeklyPlanSegmentType.block,
            theme: repository.theme2,
            hours: 5,
            block: repository.block2,
            planningBlock: planningBlock2,
          ),
        ],
        outcomes: [repository.outcome2],
      ),
    );
  }
  final weeklyPlan = AnnualWeeklyPlan(
    academicYear: '2026-2027',
    courseId: repository.courseId,
    weeklyLessonHours: 5,
    annualHours: 45,
    currentWeekNumber: 1,
    weeks: weeks,
  );
  final summaries = <WeeklyOutcomeSummary>[
    WeeklyOutcomeSummary(
      week: week,
      outcomes: [
        TrackedOutcome(
          outcome: repository.outcome1,
          academicYear: '2026-2027',
          plannedWeekNumber: 1,
          displayWeekNumber: 1,
          status: OutcomeTrackingStatus.planned,
          contexts: [
            OutcomeBlockContext.lightweight(
              theme: repository.theme1,
              block: repository.block1,
            ),
          ],
        ),
        TrackedOutcome(
          outcome: repository.outcome2,
          academicYear: '2026-2027',
          plannedWeekNumber: 1,
          displayWeekNumber: 1,
          status: OutcomeTrackingStatus.planned,
          contexts: [
            OutcomeBlockContext.lightweight(
              theme: repository.theme2,
              block: repository.block2,
            ),
          ],
        ),
      ],
    ),
  ];
  if (includeReviewWeek) {
    summaries.add(
      WeeklyOutcomeSummary(
        week: weeks[1],
        outcomes: [
          TrackedOutcome(
            outcome: repository.outcome2,
            academicYear: '2026-2027',
            plannedWeekNumber: 2,
            displayWeekNumber: 2,
            status: OutcomeTrackingStatus.planned,
            contexts: [
              OutcomeBlockContext.lightweight(
                theme: repository.theme2,
                block: repository.block2,
              ),
            ],
          ),
        ],
      ),
    );
  }
  return AnnualOutcomePlan(weeklyPlan: weeklyPlan, weeks: summaries);
}

class _StackLessonPlanRepository extends _TwoThemeTabRepository
    implements LessonPlanKnowledgeRepository {
  _StackLessonPlanRepository(super.courseId)
    : package = LessonPlanPackage(
        packageId: '$courseId-B1-P1',
        courseId: courseId,
        themeId: '$courseId-T1',
        blockId: '$courseId-B1',
        packageNo: 1,
        lessonHours: 1,
        title: 'Blok dersi',
        summary: 'Tek derslik akış',
        remainingBlockHours: 0,
        schemaVersion: '1.0.0',
        validationStatus: 'PASS',
        sourcePath: 'test/lesson_plan.json',
        payloadSha256: 'test-lesson-plan',
        outcomeCodes: const ['TDE_9.1'],
        usedActivityIds: const ['ACTIVITY_A'],
        usedFormIds: const [],
        lessons: const [
          LessonPlanLesson(
            lessonNo: 1,
            durationLessonHours: 1,
            title: 'Metni yorumlayalım',
            objective: 'Metni yorumlar.',
            outcomeCodes: ['TDE_9.1'],
            opening: 'Başlangıç',
            teacherActions: ['Yönlendirir'],
            studentActions: ['Yorumlar'],
            activityIds: ['ACTIVITY_A'],
            formIds: [],
            assessment: 'Kontrol eder.',
            closure: 'Özetler.',
            materials: ['Ders kitabı'],
            raw: {},
          ),
        ],
        teacherNotes: null,
        continuation: LessonPlanContinuation(
          plannedNowHours: 1,
          remainingBlockHours: 0,
          coveredOutcomeCodes: const ['TDE_9.1'],
          usedActivityIds: const ['ACTIVITY_A'],
          nextStepHint: null,
          raw: const {},
        ),
        rawPayload: const {},
      );

  final LessonPlanPackage package;

  @override
  Future<LessonPlanCapability> getLessonPlanCapability() async =>
      const LessonPlanCapability(
        available: true,
        manifestAdvertised: true,
        tableAvailable: true,
        packageCount: 1,
        instructionHours: 1,
        schemaVersion: '1.0.0',
        validationStatus: 'PASS',
      );

  @override
  Future<List<LessonPlanPackage>> getLessonPlansForBlock(
    String blockId,
  ) async => blockId == package.blockId ? [package] : const [];

  @override
  Future<LessonPlanPackage?> getLessonPlan(String packageId) async =>
      packageId == package.packageId ? package : null;

  @override
  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) async =>
      null;

  @override
  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) async => null;
}

class _TwoThemeTabRepository implements CourseKnowledgeRepository {
  _TwoThemeTabRepository(this.courseId)
    : theme1 = model.Theme(
        id: '$courseId-T1',
        order: 1,
        title: '$courseId Tema 1',
        pageRange: null,
        plannedHours: 45,
        anlamaHours: null,
        anlatmaHours: null,
        sourceLocator: null,
      ),
      theme2 = model.Theme(
        id: '$courseId-T2',
        order: 2,
        title: '$courseId Tema 2',
        pageRange: null,
        plannedHours: 45,
        anlamaHours: null,
        anlatmaHours: null,
        sourceLocator: null,
      ),
      block1 = model.Block(
        id: '$courseId-B1',
        themeId: '$courseId-T1',
        order: 1,
        title: '$courseId Blok 1',
        skillDomain: 'Okuma',
        learningArea: null,
        plannedHours: null,
        timeStatus: 'ORDER_ONLY',
        sourceLocators: const [],
      ),
      block2 = model.Block(
        id: '$courseId-B2',
        themeId: '$courseId-T2',
        order: 1,
        title: '$courseId Blok 2',
        skillDomain: 'Yazma',
        learningArea: null,
        plannedHours: null,
        timeStatus: 'ORDER_ONLY',
        sourceLocators: const [],
      ),
      outcome1 = model.Outcome(
        id: '$courseId-T1-O1',
        themeId: '$courseId-T1',
        code: '$courseId.1',
        officialText: '$courseId Tema 1 kazanımı',
        processComponents: null,
        sourceLocator: null,
        verificationStatus: 'PASS',
      ),
      outcome2 = model.Outcome(
        id: '$courseId-T2-O2',
        themeId: '$courseId-T2',
        code: '$courseId.2',
        officialText: '$courseId Tema 2 kazanımı',
        processComponents: null,
        sourceLocator: null,
        verificationStatus: 'PASS',
      );

  final String courseId;
  final model.Theme theme1;
  final model.Theme theme2;
  final model.Block block1;
  final model.Block block2;
  final model.Outcome outcome1;
  final model.Outcome outcome2;
  int annualSequenceCalls = 0;
  int getThemesCalls = 0;
  int teacherPackageCalls = 0;
  int getBlockCalls = 0;

  @override
  Future<model.Course> getCourse() async => model.Course(
    courseId: courseId,
    grade: 9,
    title: 'Türk Dili ve Edebiyatı',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: courseId,
  );

  @override
  Future<model.RuntimeManifest> getManifest() async => model.RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: courseId,
    validationStatus: 'PASS',
    canonicalContentFingerprint: courseId,
    rowCounts: const {},
    timelineResolution: 'THEME_AND_BLOCK_ORDER_RESOLVED',
    timelineUnresolvedFields: const {},
  );

  @override
  Future<List<model.Theme>> getThemes() async {
    getThemesCalls++;
    return [theme1, theme2];
  }

  @override
  Future<model.Theme> getTheme(String themeId) async =>
      themeId == theme1.id ? theme1 : theme2;

  @override
  Future<List<model.Block>> getBlocks(String themeId) async =>
      themeId == theme1.id ? [block1] : [block2];

  @override
  Future<model.BlockDetail> getBlock(String blockId) async {
    getBlockCalls++;
    final isB1 = blockId == block1.id;
    return model.BlockDetail(
      theme: isB1 ? theme1 : theme2,
      block: isB1 ? block1 : block2,
      outcomes: [isB1 ? outcome1 : outcome2],
      textbookSections: [
        model.TextbookSection(
          id: '$courseId-S-${isB1 ? "1" : "2"}',
          themeId: isB1 ? theme1.id : theme2.id,
          title: '$courseId ${isB1 ? "Tema 1" : "Tema 2"} kaynak',
          genre: 'Metin',
          printedPageRange: '1-2',
          pdfPageRange: null,
          sourceId: null,
        ),
      ],
      activities: const [],
      forms: const [],
      assessmentArtifacts: const [],
      assessmentGaps: const [],
      assessmentTaskBindings: const [],
      resourceDecisions: const [],
      sourceReferences: const [],
      previousBlock: null,
      nextBlock: null,
    );
  }

  @override
  Future<List<model.TimelineEntry>> getAnnualSequence() async {
    annualSequenceCalls++;
    return [
      model.TimelineEntry(
        sequencePosition: 1,
        theme: theme1,
        block: block1,
        officialTotalHours: 45,
        coreInstructionHours: 45,
        schoolBasedHours: 0,
        schoolBasedHoursStatus: 'CONFIRMED',
      ),
      model.TimelineEntry(
        sequencePosition: 2,
        theme: theme2,
        block: block2,
        officialTotalHours: 45,
        coreInstructionHours: 45,
        schoolBasedHours: 0,
        schoolBasedHoursStatus: 'CONFIRMED',
      ),
    ];
  }

  @override
  Future<List<model.ResourceDecision>> getResourceDecisions(
    String themeId,
  ) async => const [];

  @override
  Future<model.TeacherPackage> getTeacherPackage(String themeId) async {
    teacherPackageCalls++;
    final isT1 = themeId == theme1.id;
    return model.TeacherPackage(
      theme: isT1 ? theme1 : theme2,
      blocks: [isT1 ? block1 : block2],
      outcomes: [isT1 ? outcome1 : outcome2],
      textbookSections: [
        model.TextbookSection(
          id: '$courseId-S-${isT1 ? "1" : "2"}',
          themeId: isT1 ? theme1.id : theme2.id,
          title: '$courseId ${isT1 ? "Tema 1" : "Tema 2"} kaynak',
          genre: 'Metin',
          printedPageRange: '1-2',
          pdfPageRange: null,
          sourceId: null,
        ),
      ],
      activities: const [],
      forms: const [],
      assessmentArtifacts: const [],
      assessmentGaps: const [],
      assessmentTaskBindings: const [],
      resourceDecisions: const [],
      sourceReferences: const [],
    );
  }
}
