import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('binding docs preserve the assignment-aware schedule contract', () {
    final product = File('docs/PRODUCT_SCOPE.md').readAsStringSync();
    final blueprint = File('docs/FLUTTER_BLUEPRINT.md').readAsStringSync();
    final agent = File('AGENT.md').readAsStringSync();

    for (final document in [product, blueprint, agent]) {
      expect(document, contains('Bu Hafta'));
      expect(document, contains('Kaynaklar'));
      expect(document, contains('TeachingAssignment'));
      expect(document.toLowerCase(), contains('tracking'));
      expect(document, contains('payload_sha256'));
      expect(document, contains('assignment_lesson_progress'));
      expect(document, contains('assignment_outcome_tracking'));
      expect(document, contains('teacher_state.sqlite'));
    }

    expect(product, contains('Tracking isteğe bağlıdır'));
    expect(product, contains('SchoolScheduleException'));
    expect(product, contains('Ders programına göre otomatik'));
    expect(product, contains('Program konumu completion değildir'));
    expect(product, contains('actualOrdinal = plannedOrdinal'));
    expect(product, contains('legacy kayıtlar silinmez'));
    expect(product, contains('mevcut assignment kayıtları overwrite edilmez'));

    expect(blueprint, contains('OutcomeTrackingDatabase.schemaVersion = 6'));
    expect(
      blueprint,
      contains('UNIQUE (academic_year, weekday, period_number)'),
    );
    expect(blueprint, contains('v4 → v6 migration'));
    expect(blueprint, contains('TeachingCourseContextService'));
    expect(blueprint, contains('SchoolScheduleExceptionRepository'));
    expect(blueprint, contains('AssignmentAwareWeeklyLessonPlanSection'));
    expect(blueprint, contains('SingleLessonPlanPage'));
    expect(blueprint, contains('schedule position does not persist completed'));

    expect(agent, contains('`İşlendi` zorunlu değildir'));
    expect(
      agent,
      contains('Eksik weekly schedule `ŞU AN` üretmek için geçerli sayılmaz'),
    );
    expect(
      agent,
      contains('Default course mode `Ders programına göre otomatik`tir'),
    );
    expect(agent, contains('schedule exception'));
    expect(agent, contains('v4→v5 timetable migration preserves rows'));

    const staleNavigation = 'Kazanımlar\nHaftalık\nYıllık Plan\nPaket';
    expect(product, isNot(contains(staleNavigation)));
    expect(blueprint, isNot(contains(staleNavigation)));
    expect(agent, isNot(contains(staleNavigation)));
  });
}
