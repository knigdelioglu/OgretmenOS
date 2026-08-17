import 'package:shared_preferences/shared_preferences.dart';

import '../data/calendar/asset_weekly_planning_service.dart';
import '../data/course/course_database_installer.dart';
import '../data/course/course_knowledge_repository_impl.dart';
import '../data/preferences/user_preferences_repository.dart';
import '../data/tracking/outcome_tracking_database.dart';
import '../domain/models/weekly_plan_models.dart';
import '../domain/repositories/course_knowledge_repository.dart';
import '../domain/services/outcome_planning_service.dart';

class AppDependencies {
  const AppDependencies({
    required this.repository,
    required this.preferences,
    required this.weeklyPlanning,
    this.outcomePlanning,
    this.dispose,
  });

  final CourseKnowledgeRepository repository;
  final UserPreferencesRepository preferences;
  final WeeklyPlanningService weeklyPlanning;
  final OutcomePlanningService? outcomePlanning;
  final Future<void> Function()? dispose;
}

Future<AppDependencies> loadProductionDependencies() async {
  final database = await CourseDatabase.open();
  OutcomeTrackingDatabase? trackingDatabase;
  try {
    final preferences = await SharedPreferences.getInstance();
    final repository = CourseKnowledgeRepositoryImpl(
      dataSource: database.dataSource,
      manifest: database.manifest,
    );
    final weeklyPlanning = AssetWeeklyPlanningService(repository: repository);
    trackingDatabase = await OutcomeTrackingDatabase.open();
    final trackingRepository = SqfliteOutcomeTrackingRepository(
      trackingDatabase.database,
    );
    final outcomePlanning = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: weeklyPlanning,
      trackingRepository: trackingRepository,
    );

    return AppDependencies(
      repository: repository,
      preferences: SharedPreferencesUserPreferences(preferences),
      weeklyPlanning: weeklyPlanning,
      outcomePlanning: outcomePlanning,
      dispose: () async {
        await trackingDatabase?.close();
        await database.close();
      },
    );
  } on Object {
    await trackingDatabase?.close();
    await database.close();
    rethrow;
  }
}
