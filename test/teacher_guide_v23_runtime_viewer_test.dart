import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/data/course/course_database_data_source.dart';
import 'package:ogretmen_os/data/course/course_knowledge_repository_impl.dart';
import 'package:ogretmen_os/data/course/teacher_guide_database_data_source.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/teacher_guide_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'real TDE11 V2.3 runtime exposes deterministic printed-page targets via bulk read',
    () async {
      final fixture = await _openRuntime();
      addTearDown(fixture.database.close);

      final guide = await fixture.repository.getTeacherGuideForScope(
        scopeType: 'theme',
        scopeId: 'TEMA_01',
      );
      expect(guide, isNotNull);
      expect(fixture.repository, isA<TeacherGuideBulkKnowledgeRepository>());

      final bulk = fixture.repository as TeacherGuideBulkKnowledgeRepository;
      final units = await bulk.getTeacherGuideUnitsForGuide(guide!.guideId);
      final items = await bulk.getTeacherGuideItemsForGuide(guide.guideId);
      expect(units, isNotEmpty);
      expect(items, isNotEmpty);
      expect(items.every((item) => item.provenance.contentClass == 'BOOK_FIRST_V2_3_ITEM'), isTrue);

      final questions = items
          .where((item) => item.itemType.toUpperCase() == 'QUESTION')
          .toList(growable: false);
      expect(questions, isNotEmpty);
      expect(
        questions.every(
          (item) => const {'VERBATIM_SHORT', 'VERIFIED_SUMMARY'}.contains(
            item.provenance.additional['prompt_mode'],
          ),
        ),
        isTrue,
      );

      final targets = _pageTargetsFromItems(items);
      expect(targets.length, greaterThan(1));
      expect(_pageSortKey(targets.first.locator), 12);
      for (var index = 1; index < targets.length; index++) {
        expect(
          _pageSortKey(targets[index - 1].locator),
          lessThanOrEqualTo(_pageSortKey(targets[index].locator)),
        );
      }
      expect(targets.every((target) => target.title.trim().isNotEmpty), isTrue);
    },
  );

  test(
    'real visual-dependent question remains source-bound without an invented answer',
    () async {
      final fixture = await _openRuntime();
      addTearDown(fixture.database.close);

      const itemId = '__v23_item__T4V23_P305_Q05';
      final item = await fixture.repository.getTeacherGuideItem(itemId);
      expect(item, isNotNull);
      expect(item!.itemType, 'QUESTION');
      expect(item.expectedResponse, isEmpty);
      expect(item.acceptanceCriteria, isNotEmpty);
      expect(item.provenance.contentClass, 'BOOK_FIRST_V2_3_ITEM');
      expect(item.provenance.additional['rights_mode'], 'PAGE_REFERENCE');
      expect(item.provenance.sourceLocators, isNotEmpty);
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

List<_PageTarget> _pageTargetsFromItems(List<TeacherGuideItem> items) {
  final byLocator = <String, _PageTarget>{};
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
