import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('binding docs preserve the post-phase DEHB product contract', () {
    final product = File('docs/PRODUCT_SCOPE.md').readAsStringSync();
    final blueprint = File('docs/FLUTTER_BLUEPRINT.md').readAsStringSync();
    final agent = File('AGENT.md').readAsStringSync();

    for (final document in [product, blueprint, agent]) {
      expect(document, contains('Bu Hafta'));
      expect(document, contains('Yıllık'));
      expect(document, contains('Kaynaklar'));
      expect(document.toLowerCase(), contains('tracking'));
    }

    expect(product, contains('Tracking isteğe bağlıdır'));
    expect(product, contains('Konum ilerleme değildir'));
    expect(agent, contains('`İşlendi` zorunlu değildir'));
    expect(
      blueprint,
      contains('Position-derived `LinearProgressIndicator` yasaktır'),
    );

    const staleNavigation = 'Kazanımlar\nHaftalık\nYıllık Plan\nPaket';
    expect(product, isNot(contains(staleNavigation)));
    expect(blueprint, isNot(contains(staleNavigation)));
    expect(agent, isNot(contains(staleNavigation)));
  });
}
