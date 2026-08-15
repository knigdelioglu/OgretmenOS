import 'package:shared_preferences/shared_preferences.dart';

import '../data/course/course_database_installer.dart';
import '../data/course/course_knowledge_repository_impl.dart';
import '../data/preferences/user_preferences_repository.dart';
import '../domain/repositories/course_knowledge_repository.dart';

class AppDependencies {
  const AppDependencies({
    required this.repository,
    required this.preferences,
    this.dispose,
  });

  final CourseKnowledgeRepository repository;
  final UserPreferencesRepository preferences;
  final Future<void> Function()? dispose;
}

Future<AppDependencies> loadProductionDependencies() async {
  final database = await CourseDatabase.open();
  try {
    final preferences = await SharedPreferences.getInstance();
    return AppDependencies(
      repository: CourseKnowledgeRepositoryImpl(
        dataSource: database.dataSource,
        manifest: database.manifest,
      ),
      preferences: SharedPreferencesUserPreferences(preferences),
      dispose: database.close,
    );
  } on Object {
    await database.close();
    rethrow;
  }
}
