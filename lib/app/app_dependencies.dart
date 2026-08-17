import 'package:shared_preferences/shared_preferences.dart';

import '../data/calendar/asset_weekly_planning_service.dart';
import '../data/course/course_database_installer.dart';
import '../data/course/course_knowledge_repository_impl.dart';
import '../data/preferences/user_preferences_repository.dart';
import '../domain/models/weekly_plan_models.dart';
import '../domain/repositories/course_knowledge_repository.dart';

class AppDependencies {
  const AppDependencies({
    required this.repository,
    required this.preferences,
    required this.weeklyPlanning,
    this.dispose,
  });

  final CourseKnowledgeRepository repository;
  final UserPreferencesRepository preferences;
  final WeeklyPlanningService weeklyPlanning;
  final Future<void> Function()? dispose;
}

Future<AppDependencies> loadProductionDependencies() async {
  final database = await CourseDatabase.open();
  try {
    final preferences = await SharedPreferences.getInstance();
    final repository = CourseKnowledgeRepositoryImpl(
      dataSource: database.dataSource,
      manifest: database.manifest,
    );
    return AppDependencies(
      repository: repository,
      preferences: SharedPreferencesUserPreferences(preferences),
      weeklyPlanning: AssetWeeklyPlanningService(repository: repository),
      dispose: database.close,
    );
  } on Object {
    await database.close();
    rethrow;
  }
}
