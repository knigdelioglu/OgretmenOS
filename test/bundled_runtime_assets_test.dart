import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final descriptor in supportedCourseRuntimes) {
    test('${descriptor.courseId} manifest and SQLite are in rootBundle', () async {
      final manifestJson = await rootBundle.loadString(descriptor.manifestAsset);
      final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
      expect(manifest['course_id'], descriptor.courseId);

      final database = await rootBundle.load(descriptor.databaseAsset);
      expect(database.lengthInBytes, greaterThan(0));
    });
  }
}
