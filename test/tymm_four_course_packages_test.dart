import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/domain/runtime/course_runtime_registry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('TDE registry exposes grades 9 through 12 under one subject', () {
    expect(
      supportedCourseRuntimes.map((item) => item.courseId),
      orderedEquals(['TDE_9', 'TDE_10', 'TDE_11', 'TDE_12']),
    );
    expect(supportedCourseRuntimes.map((item) => item.subjectId).toSet(), {
      'turk-dili-ve-edebiyati',
    });
    expect(runtimeForCourse('TDE_11').isAwaitingTextbook, isFalse);
    expect(runtimeForCourse('TDE_11').isCurriculumOnly, isFalse);
    expect(runtimeForCourse('TDE_11').hasOfficialTextbook, isTrue);
    expect(runtimeForCourse('TDE_12').isCurriculumOnly, isTrue);
    expect(runtimeForCourse('TDE_9').hasOfficialTextbook, isTrue);
  });

  for (final courseId in ['TDE_12']) {
    test(
      '$courseId curriculum-only runtime is usable without a textbook',
      () async {
        final descriptor = runtimeForCourse(courseId);
        final databasePath = p.join(
          Directory.current.path,
          descriptor.databaseAsset,
        );
        final databaseFile = File(databasePath);
        expect(databaseFile.existsSync(), isTrue);
        final database = await databaseFactoryFfi.openDatabase(
          databaseFile.path,
          options: OpenDatabaseOptions(readOnly: true),
        );
        try {
          final dataSource = CourseDatabaseDataSource(database);
          final course = await dataSource.getCourse();
          expect(course.courseId, courseId);
          expect((await dataSource.getThemes()).length, 4);
          expect((await dataSource.getAnnualSequence()).length, 16);

          var outcomeCount = 0;
          for (final theme in await dataSource.getThemes()) {
            final outcomes = await dataSource.getOutcomesForTheme(theme.id);
            outcomeCount += outcomes.length;
            expect(outcomes, isNotEmpty);
            expect(
              outcomes.every(
                (outcome) => outcome.processComponentOrigin == 'ROOF_INHERITED',
              ),
              isTrue,
            );
            expect(
              outcomes.every(
                (outcome) => outcome.processComponents?.isNotEmpty == true,
              ),
              isTrue,
            );
            expect(await dataSource.getTextbookSections(theme.id), isEmpty);
            expect(await dataSource.getActivitiesForTheme(theme.id), isEmpty);
          }
          expect(outcomeCount, 64);

          final processRows = await database.rawQuery('''
          SELECT process_components, process_component_origin
          FROM outcomes
          ORDER BY outcome_id
        ''');
          expect(processRows.length, 64);
          for (final row in processRows) {
            expect(row['process_component_origin'], 'ROOF_INHERITED');
            final raw = row['process_components']?.toString() ?? '';
            expect(raw, isNotEmpty);
            final decoded = jsonDecode(raw);
            expect(decoded, isA<List<dynamic>>());
            expect(decoded as List<dynamic>, isNotEmpty);
          }

          final manifestFile = File(
            p.join(
              Directory.current.path,
              descriptor.runtimeRoot,
              'runtime_manifest.json',
            ),
          );
          final manifest =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, dynamic>;
          expect(manifest['process_component_resolution_status'], 'PASS');
          final processCounts =
              manifest['process_component_counts'] as Map<String, dynamic>;
          expect(processCounts['total_outcomes'], 64);
          expect(processCounts['outcomes_with_roof_components'], 64);
          expect(processCounts['explicit_component_outcomes'], 0);
          expect(processCounts['inherited_component_outcomes'], 64);
          expect(processCounts['unresolved_component_outcomes'], 0);
          expect(processCounts['inheritance_missing_count'], 0);
          expect(
            (manifest['canonical_source_files'] as List<dynamic>),
            contains('../TDE_SHARED/curriculum_process_component_catalog.json'),
          );
          expect(
            (manifest['canonical_source_files'] as List<dynamic>),
            contains('curriculum/curriculum_process_component_resolution.json'),
          );

          final firstBlock = (await dataSource.getAnnualSequence()).first.block;
          final detail = await dataSource.getBlockDetail(firstBlock.id);
          expect(detail.outcomes, isNotEmpty);
          expect(
            detail.outcomes.every(
              (outcome) => outcome.processComponentOrigin == 'ROOF_INHERITED',
            ),
            isTrue,
          );
          expect(detail.textbookSections, isEmpty);
          expect(detail.activities, isEmpty);
          expect(detail.forms, isEmpty);
          expect(detail.sourceReferences, isNotEmpty);
        } finally {
          await database.close();
        }
      },
    );
  }

  test(
    'TDE_11 full runtime exposes its canonical textbook projection',
    () async {
      final descriptor = runtimeForCourse('TDE_11');
      expect(descriptor.dataMode, CourseDataMode.fullRuntime);
      expect(descriptor.hasOfficialTextbook, isTrue);

      final databasePath = p.join(
        Directory.current.path,
        descriptor.databaseAsset,
      );
      final database = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(readOnly: true),
      );
      try {
        final dataSource = CourseDatabaseDataSource(database);
        expect((await dataSource.getThemes()).length, 4);
        expect((await dataSource.getAnnualSequence()).length, 16);

        var textbookSectionCount = 0;
        var activityCount = 0;
        for (final theme in await dataSource.getThemes()) {
          textbookSectionCount += (await dataSource.getTextbookSections(
            theme.id,
          )).length;
          activityCount += (await dataSource.getActivitiesForTheme(
            theme.id,
          )).length;
        }
        expect(textbookSectionCount, 24);
        expect(activityCount, 84);

        final manifestFile = File(
          p.join(
            Directory.current.path,
            descriptor.runtimeRoot,
            'runtime_manifest.json',
          ),
        );
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, dynamic>;
        final capabilities = manifest['capabilities'] as Map<String, dynamic>;
        expect(capabilities['teacher_guide'], isTrue);
        expect(capabilities['assessment'], isFalse);
      } finally {
        await database.close();
      }
    },
  );

  test('academic calendar has 180-hour profiles for all four grades', () async {
    final file = File(
      p.join(
        Directory.current.path,
        'assets',
        'calendars',
        'academic_calendar_2026_2027.json',
      ),
    );
    final calendar =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final profiles = calendar['course_profiles'] as Map<String, dynamic>;
    for (final courseId in ['TDE_9', 'TDE_10', 'TDE_11', 'TDE_12']) {
      final profile = profiles[courseId] as Map<String, dynamic>;
      expect(profile['weekly_lesson_hours'], 5);
      expect(profile['annual_hours'], 180);
      expect(profile['structured_hours_per_theme'], 43);
      expect(profile['school_based_hours_per_theme'], 2);
      expect(profile['block_hour_allocation'], [12, 11, 10, 10]);
    }
  });
}
