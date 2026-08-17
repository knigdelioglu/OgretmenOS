import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/app/app.dart';
import 'package:ogretmen_os/app/app_dependencies.dart';
import 'package:ogretmen_os/data/preferences/user_preferences_repository.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/weekly_plan_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';

void main() {
  testWidgets('kazanım planı hatası kullanıcıya error state olarak gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      TeacherOsApp(
        dependencies: AppDependencies(
          repository: _EmptyRepository(),
          preferences: _Preferences(),
          weeklyPlanning: _FailingWeeklyPlanning(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kazanım takip görünümü yüklenemedi.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('boş akademik plan unresolved state olarak gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      TeacherOsApp(
        dependencies: AppDependencies(
          repository: _EmptyRepository(),
          preferences: _Preferences(),
          weeklyPlanning: _EmptyWeeklyPlanning(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gösterilebilir okul haftası bulunmuyor.'), findsOneWidget);
  });
}

class _EmptyRepository implements CourseKnowledgeRepository {
  @override
  Future<Course> getCourse() async => const Course(
    courseId: 'TDE_9',
    grade: 9,
    title: 'Test Course',
    schemaVersion: '1.0.0',
    sourceManifestFingerprint: 'fixture',
  );

  @override
  Future<RuntimeManifest> getManifest() async => const RuntimeManifest(
    runtimePackageVersion: '1.0.0',
    schemaVersion: '1.0.0',
    courseId: 'TDE_9',
    validationStatus: 'PASS',
    canonicalContentFingerprint: 'fixture',
    rowCounts: {},
    timelineResolution: 'THEME_TIME_RESOLVED',
    timelineUnresolvedFields: {},
  );

  @override
  Future<List<Theme>> getThemes() async => const [];

  @override
  Future<List<TimelineEntry>> getAnnualSequence() async => const [];

  @override
  Future<Theme> getTheme(String themeId) => throw UnimplementedError();

  @override
  Future<List<Block>> getBlocks(String themeId) => throw UnimplementedError();

  @override
  Future<BlockDetail> getBlock(String blockId) => throw UnimplementedError();

  @override
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) =>
      throw UnimplementedError();

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) =>
      throw UnimplementedError();
}

class _FailingWeeklyPlanning implements WeeklyPlanningService {
  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) =>
      Future<AnnualWeeklyPlan>.error(StateError('fixture failure'));
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

class _Preferences implements UserPreferencesRepository {
  @override
  Future<void> clearManualPositionOverride() async {}

  @override
  Future<String?> getManualPositionOverride() async => null;

  @override
  Future<void> setManualPositionOverride(String blockId) async {}
}
