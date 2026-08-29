import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/instruction_context_repository.dart';
import 'package:ogretmen_os/domain/services/assignment_lesson_timeline_service.dart';
import 'package:ogretmen_os/features/settings/teaching_schedule_page.dart';

void main() {
  testWidgets('sınıf eklerken 9-12 düzeyleri seçilebilir', (tester) async {
    _phone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = MemoryInstructionContextRepository();
    final planning = _EmptyWeeklyPlanning();

    await _pumpSchedule(tester, repository, planning);
    await tester.tap(find.widgetWithText(FilledButton, 'Sınıf ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Sınıf düzeyi'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    for (var grade = 9; grade <= 12; grade++) {
      expect(find.text('$grade. sınıf'), findsWidgets);
    }

    await tester.tap(find.text('10. sınıf'));
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    final classes = await repository.getClasses('2026-2027');
    final assignments = await repository.getAssignments(
      academicYear: '2026-2027',
      activeOnly: false,
    );
    expect(classes.single.grade, 10);
    expect(classes.single.displayName, '10/A');
    expect(assignments.single.courseId, 'TDE_10');
  });

  testWidgets('ders saatleri kısa kurulumla varsayılan 40 dakikada oluşur', (
    tester,
  ) async {
    _phone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = MemoryInstructionContextRepository();
    final planning = _EmptyWeeklyPlanning();

    await _pumpSchedule(tester, repository, planning);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Ders saatlerini tanımla'),
    );
    await tester.pumpAndSettle();

    expect(find.text('İlk ders başlangıcı'), findsOneWidget);
    expect(
      find.text('Öğle arasından önce kaç ders saati var?'),
      findsOneWidget,
    );
    expect(find.text('Başlangıç değeri: 40 dakika'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(
      find.widgetWithText(FilledButton, 'Saatleri oluştur ve kaydet'),
    );
    await tester.pumpAndSettle();

    final periods = await repository.getBellPeriods();
    expect(periods, hasLength(8));
    expect(periods[3].endMinute, 700);
    expect(periods[4].startMinute, 745);
    expect(
      periods.every((period) => period.endMinute - period.startMinute == 40),
      isTrue,
    );
  });
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
}

Future<void> _pumpSchedule(
  WidgetTester tester,
  MemoryInstructionContextRepository repository,
  WeeklyPlanningService planning,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TeachingSchedulePage(
        repository: repository,
        weeklyPlanning: planning,
        timeline: AssignmentLessonTimelineService(
          instructionContext: repository,
          weeklyPlanning: planning,
        ),
        courseId: 'TDE_9',
        grade: 9,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _EmptyWeeklyPlanning implements WeeklyPlanningService {
  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async =>
      const AnnualWeeklyPlan(
        academicYear: '2026-2027',
        courseId: 'TDE_9',
        weeklyLessonHours: 5,
        annualHours: 180,
        weeks: [],
        currentWeekNumber: null,
      );
}
