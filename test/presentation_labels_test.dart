import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/features/shared/feature_widgets.dart';

void main() {
  test('runtime zaman kodları öğretmen diline çevrilir', () {
    expect(
      timelineResolutionLabel('THEME_TIME_RESOLVED'),
      'Tema süreleri doğrulanmış',
    );
    expect(
      blockTimeStatusLabel('ORDER_ONLY'),
      'Yalnız plan sırası doğrulanmış',
    );
  });

  test('bilinmeyen öncelik kodu kullanıcıya ham olarak gösterilmez', () {
    expect(resourcePriorityLabel('HIGH'), 'Yüksek öncelik');
    expect(resourcePriorityLabel('SOMETHING_NEW'), isNull);
  });
}
