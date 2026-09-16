import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/data/course/course_knowledge_repository_impl.dart';
import 'package:ogretmen_os/data/course/teacher_guide_database_data_source.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/features/resources/teacher_guide_viewer_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets(
    'real TDE11 V2.3 runtime supports printed-page jump without filler',
    (tester) async {
      _useSize(tester, const Size(412, 915));
      final fixture = await _openRuntime();
      addTearDown(fixture.database.close);

      final guide = await fixture.repository.getTeacherGuideForScope(
        scopeType: 'theme',
        scopeId: 'TEMA_01',
      );
      expect(guide, isNotNull);

      final targets = await _pageTargets(
        fixture.repository,
        guide!.guideId,
      );
      expect(targets.length, greaterThan(1));
      final first = targets.first;
      final second = targets[1];

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherGuideViewerPage(
            repository: fixture.repository,
            scopeType: 'theme',
            scopeId: 'TEMA_01',
            guideId: guide.guideId,
            itemId: first.itemId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pageJump = find.byKey(const ValueKey('book-first-page-jump'));
      expect(pageJump, findsOneWidget);
      expect(find.text('Kitap sayfasına git'), findsOneWidget);
      expect(find.text(first.title), findsWidgets);
      expect(find.text('Belirtilmemiş'), findsNothing);

      await tester.tap(pageJump);
      await tester.pumpAndSettle();
      final secondOption = find.textContaining('s. ${second.locator} —');
      expect(secondOption, findsWidgets);
      await tester.tap(secondOption.last);
      await tester.pumpAndSettle();

      expect(find.text(second.title), findsWidgets);
      expect(find.text('Belirtilmemiş'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real visual-dependent question stays source-bound in the viewer',
    (tester) async {
      _useSize(tester, const Size(412, 915));
      final fixture = await _openRuntime();
      addTearDown(fixture.database.close);

      const itemId = '__v23_item__T4V23_P305_Q05';
      final item = await fixture.repository.getTeacherGuideItem(itemId);
      expect(item, isNotNull);
      expect(item!.expectedResponse, isEmpty);
      expect(item.provenance.additional['rights_mode'], 'PAGE_REFERENCE');

      final guide = await fixture.repository.getTeacherGuideForScope(
        scopeType: 'theme',
        scopeId: 'TEMA_04',
      );
      expect(guide, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherGuideViewerPage(
            repository: fixture.repository,
            scopeType: 'theme',
            scopeId: 'TEMA_04',
            guideId: guide!.guideId,
            itemId: itemId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cevap, ders kitabındaki görsel veya kaynak katmanına bağlı'),
        findsOneWidget,
      );
      expect(find.text('Belirtilmemiş'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_RuntimeFixture> _openRuntime() async {
  final packageRoot =
      '${Directory.current.path}/tymm-verileri/turk-dili-ve-edebiyati/TDE_11';
  final runtimeRoot = '$packageRoot/runtime';
  final manifestMap =
      jsonDecode(await File('$runtimeRoot/runtime_manifest.json').readAsString())
          as Map<String, dynamic>;
  final manifest = RuntimeManifest.fromJson(manifestMap);
  final database = await databaseFactoryFfi.openDatabase(
    '$runtimeRoot/course_runtime.sqlite',
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );
  final repository = CourseKnowledgeRepositoryImpl(
    dataSource: CourseDatabaseDataSource(database),
    manifest: manifest,
    teacherGuideDataSource: TeacherGuideDatabaseDataSource(database),
  );
  return _RuntimeFixture(database: database, repository: repository);
}

Future<List<_PageTarget>> _pageTargets(
  CourseKnowledgeRepository repository,
  String guideId,
) async {
  final byLocator = <String, _PageTarget>{};
  final sections = await repository.getTeacherGuideSections(guideId);
  for (final section in sections) {
    final units = await repository.getTeacherGuideUnits(section.sectionId);
    for (final unit in units) {
      final items = await repository.getTeacherGuideItems(unit.unitId);
      for (final item in items) {
        final locator = item.pageLocator?.trim();
        if (locator == null || locator.isEmpty) continue;
        byLocator.putIfAbsent(
          locator,
          () => _PageTarget(
            locator: locator,
            itemId: item.itemId,
            title: item.title ?? item.label,
          ),
        );
      }
    }
  }
  final result = byLocator.values.toList(growable: false)
    ..sort((a, b) {
      final pageCompare = _pageSortKey(a.locator).compareTo(
        _pageSortKey(b.locator),
      );
      return pageCompare != 0 ? pageCompare : a.locator.compareTo(b.locator);
    });
  return result;
}

int _pageSortKey(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return int.tryParse(match?.group(0) ?? '') ?? (1 << 30);
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _RuntimeFixture {
  const _RuntimeFixture({required this.database, required this.repository});

  final Database database;
  final CourseKnowledgeRepository repository;
}

class _PageTarget {
  const _PageTarget({
    required this.locator,
    required this.itemId,
    required this.title,
  });

  final String locator;
  final String itemId;
  final String title;
}
