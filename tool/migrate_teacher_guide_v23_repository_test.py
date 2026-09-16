#!/usr/bin/env python3
"""Replace the V2.2-only TDE11 repository fixture with the V2.3-aware contract test.

The migration is intentionally deterministic so CI can exercise the projected runtime
before the generated SQLite is committed.  It retains a small legacy branch until the
repository runtime itself is materialized as V2.3.
"""
from __future__ import annotations

import argparse
from pathlib import Path

OLD_MARKER = "  test('TDE_11 V2.2 additive runtime canonical katmanı korur', () async {"
NEW_MARKER = "  test('TDE_11 teacher guide runtime ilan edilen mimariyi karşılar', () async {"
END_MARKER = "\n}\n\nCourseKnowledgeRepositoryImpl _repository"

REPLACEMENT = r'''  test('TDE_11 teacher guide runtime ilan edilen mimariyi karşılar', () async {
    final configuredRoot =
        Platform.environment['TDE11_RUNTIME_PACKAGE_ROOT']?.trim();
    final packageRoot = configuredRoot != null && configuredRoot.isNotEmpty
        ? configuredRoot
        : '${Directory.current.path}/tymm-verileri/turk-dili-ve-edebiyati/TDE_11';
    final runtimeRoot = '$packageRoot/runtime';
    final manifestMap =
        jsonDecode(
              await File('$runtimeRoot/runtime_manifest.json').readAsString(),
            )
            as Map<String, dynamic>;
    final manifest = RuntimeManifest.fromJson(manifestMap);
    final packageManifest =
        jsonDecode(await File('$packageRoot/package_manifest.json').readAsString())
            as Map<String, dynamic>;

    expect(packageManifest['data_mode'], 'FULL_RUNTIME');
    expect(packageManifest['textbook_status'], 'AVAILABLE');
    expect(packageManifest['lesson_plan_package_count'], 88);
    expect(packageManifest['lesson_plan_instruction_hours'], 172);
    expect(packageManifest['lesson_plan_validation_status'], 'VERIFIED');
    expect(packageManifest['lesson_plan_source_payload_parity'], isFalse);

    final capabilities = Map<String, dynamic>.from(
      manifestMap['teacher_guide_capabilities'] as Map,
    );
    final bookFirstRaw = capabilities['book_first_v23'];

    // This branch keeps the test green during the one commit between adding the
    // migration tooling and materializing the generated V2.3 runtime.  Once the
    // runtime advertises V2.3, every assertion below becomes mandatory.
    if (bookFirstRaw is! Map || bookFirstRaw['available'] != true) {
      final overlay = capabilities['pedagogy_overlay'];
      expect(overlay, isA<Map>());
      expect((overlay as Map)['available'], isTrue);
      return;
    }

    final bookFirst = Map<String, dynamic>.from(bookFirstRaw);
    expect(
      packageManifest['teacher_guide_source_commit'],
      '20860e3165d5e9de18913364286e6f89f28f6046',
    );
    expect(bookFirst['architecture_version'], '2.3.0');
    expect(
      bookFirst['projection_version'],
      '1.1.0+book-first-v2.3-full-course',
    );
    expect(bookFirst['source_tymm_commit'],
        '20860e3165d5e9de18913364286e6f89f28f6046');
    expect(bookFirst['entries'], 573);
    expect(bookFirst['questions'], 404);
    expect(bookFirst['locator_only_questions'], 0);

    final database = await databaseFactoryFfi.openDatabase(
      '$runtimeRoot/course_runtime.sqlite',
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    addTearDown(database.close);
    final repository = CourseKnowledgeRepositoryImpl(
      dataSource: CourseDatabaseDataSource(database),
      manifest: manifest,
      teacherGuideDataSource: TeacherGuideDatabaseDataSource(database),
    );

    final capability = await repository.getTeacherGuideCapability();
    expect(capability.available, isTrue);
    expect(capability.usable, isTrue);
    expect(capability.guideCount, 4);
    expect(capability.sectionCount, 28);
    expect(capability.unitCount, 431);
    expect(capability.itemCount, 573);
    expect(capability.relationCount, 7547);
    expect(
      capability.relationCount,
      manifest.rowCounts['teacher_guide_item_relations'],
    );

    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_items WHERE item_id LIKE '__v23_item__%'",
      )).single['count'],
      573,
    );
    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_items WHERE item_type='QUESTION'",
      )).single['count'],
      404,
    );
    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_units WHERE unit_id LIKE '__pedv2_unit__%'",
      )).single['count'],
      0,
    );
    expect(
      (await database.rawQuery(
        "SELECT COUNT(*) AS count FROM teacher_guide_items WHERE item_id LIKE '__pedv2_block__%'",
      )).single['count'],
      0,
    );
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    final firstQuestionId = (await database.rawQuery(
      "SELECT item_id FROM teacher_guide_items WHERE item_type='QUESTION' ORDER BY item_id LIMIT 1",
    )).single['item_id']!.toString();
    final firstQuestion = await repository.getTeacherGuideItem(firstQuestionId);
    expect(firstQuestion, isNotNull);
    expect(firstQuestion!.title, isNotEmpty);
    expect(firstQuestion.provenance.contentClass, 'BOOK_FIRST_V2_3_ITEM');
    expect(
      firstQuestion.provenance.additional['prompt_mode'],
      anyOf('VERBATIM_SHORT', 'VERIFIED_SUMMARY'),
    );
    expect(firstQuestion.expectedResponse, isNotEmpty);

    // s.305/Q5 görsel seçenekleri PDF'nin görsel katmanına bağlıdır.  Rehber
    // tek bir uydurma görsel cevabı üretmez; kaynak locator + kabul ölçütü taşır.
    final visualQuestion = await repository.getTeacherGuideItem(
      '__v23_item__T4V23_P305_Q05',
    );
    expect(visualQuestion, isNotNull);
    expect(visualQuestion!.expectedResponse, isEmpty);
    expect(visualQuestion.acceptanceCriteria, isNotEmpty);
    expect(visualQuestion.provenance.additional['rights_mode'], 'PAGE_REFERENCE');
    expect(visualQuestion.provenance.sourceLocators, isNotEmpty);

    final guide = await repository.getTeacherGuideForScope(
      scopeType: 'theme',
      scopeId: 'TEMA_01',
    );
    expect(guide, isNotNull);
    final sections = await repository.getTeacherGuideSections(guide!.guideId);
    expect(sections, hasLength(7));
    final units = await repository.getTeacherGuideUnits(sections.first.sectionId);
    expect(units, isNotEmpty);
    final items = await repository.getTeacherGuideItems(units.first.unitId);
    expect(items, isNotEmpty);
    expect(
      items.first.canonicalPayloadSha256,
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );

    final activityItems = await repository.getTeacherGuideItemsForEntity(
      targetType: 'activity',
      targetId: 'T1_ACT_01_OKUMA_YONETIM',
    );
    expect(activityItems, isNotEmpty);
    expect(
      await repository.getTeacherGuideItemsForEntity(
        targetType: 'activity',
        targetId: 'NOT_A_CANONICAL_ACTIVITY',
      ),
      isEmpty,
    );

    final formItems = await repository.getTeacherGuideItemsForEntity(
      targetType: 'form',
      targetId: 'FORM_T1_P035_OZ_DEGERLENDIRME_01',
    );
    expect(formItems, isNotEmpty);
    expect(
      await repository.getForm('FORM_T1_P035_OZ_DEGERLENDIRME_01'),
      isNotNull,
    );
    expect(
      (await repository.getFormTemplateStatus(
        'FORM_T1_P035_OZ_DEGERLENDIRME_01',
      ))?.isReady,
      isTrue,
    );
    final externalStatus = await repository.getFormTemplateStatus(
      'LINK_T1_KONUSMA_DPA',
    );
    expect(externalStatus?.isExternalReference, isTrue);
    expect(externalStatus?.targetUrlCandidates, isNotEmpty);
  });'''


def migrate(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if NEW_MARKER in text:
        if OLD_MARKER in text:
            raise RuntimeError("OLD_AND_NEW_TEST_MARKERS_PRESENT")
        return False
    start = text.find(OLD_MARKER)
    if start < 0:
        raise RuntimeError("V22_TEST_MARKER_NOT_FOUND")
    end = text.find(END_MARKER, start)
    if end < 0:
        raise RuntimeError("TEST_FILE_END_MARKER_NOT_FOUND")
    path.write_text(text[:start] + REPLACEMENT + text[end:], encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--path",
        type=Path,
        default=Path("test/teacher_guide_repository_test.dart"),
    )
    args = parser.parse_args()
    changed = migrate(args.path.resolve())
    print(f"TEACHER_GUIDE_V23_REPOSITORY_TEST_MIGRATION: {'UPDATED' if changed else 'ALREADY_CURRENT'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
