import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('binding docs preserve the post-phase DEHB and lesson-plan contract', () {
    final product = File('docs/PRODUCT_SCOPE.md').readAsStringSync();
    final blueprint = File('docs/FLUTTER_BLUEPRINT.md').readAsStringSync();
    final agent = File('AGENT.md').readAsStringSync();

    for (final document in [product, blueprint, agent]) {
      expect(document, contains('Bu Hafta'));
      expect(document, contains('Yıllık'));
      expect(document, contains('Kaynaklar'));
      expect(document, contains('LessonPlanPage'));
      expect(document, contains('lesson_plan_progress'));
      expect(document.toLowerCase(), contains('tracking'));
      expect(document, contains('Undo'));
    }

    expect(product, contains('Tracking isteğe bağlıdır'));
    expect(product, contains('Konum ilerleme değildir'));
    expect(product, contains('Ders planı yeni top-level navigation oluşturmaz'));
    expect(
      product,
      contains('Lesson-plan status mutationları önceki persisted snapshot'),
    );
    expect(agent, contains('`İşlendi` zorunlu değildir'));
    expect(agent, contains('previous == null'));
    expect(agent, contains('TDE_11/TDE_12 curriculum-only fallback'));
    expect(
      blueprint,
      contains('Position-derived `LinearProgressIndicator` yasaktır'),
    );
    expect(blueprint, contains('P5 real Undo contract'));
    expect(blueprint, contains('88 package / 172 instructional hours'));

    const staleNavigation = 'Kazanımlar\nHaftalık\nYıllık Plan\nPaket';
    expect(product, isNot(contains(staleNavigation)));
    expect(blueprint, isNot(contains(staleNavigation)));
    expect(agent, isNot(contains(staleNavigation)));
  });
}
