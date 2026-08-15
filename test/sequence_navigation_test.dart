import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/services/sequence_navigation.dart';

void main() {
  final sequence = <TimelineEntry>[
    _entry(position: 1, themeId: 'TEMA_01', themeOrder: 1, blockId: 'B1'),
    _entry(position: 2, themeId: 'TEMA_01', themeOrder: 1, blockId: 'B2'),
    _entry(position: 3, themeId: 'TEMA_02', themeOrder: 2, blockId: 'B3'),
  ];

  test('önceki ve sonraki blok authoritative sequence sırasından çözülür', () {
    expect(previousBlockInSequence(sequence, 'B2')?.id, 'B1');
    expect(nextBlockInSequence(sequence, 'B2')?.id, 'B3');
  });

  test('tema sınırında sequence komşuluğu korunur', () {
    expect(previousBlockInSequence(sequence, 'B3')?.id, 'B2');
  });

  test('sequence sınırları ve bilinmeyen blok null döndürür', () {
    expect(previousBlockInSequence(sequence, 'B1'), isNull);
    expect(nextBlockInSequence(sequence, 'B3'), isNull);
    expect(nextBlockInSequence(sequence, 'UNKNOWN'), isNull);
  });
}

TimelineEntry _entry({
  required int position,
  required String themeId,
  required int themeOrder,
  required String blockId,
}) => TimelineEntry(
  sequencePosition: position,
  theme: Theme(
    id: themeId,
    order: themeOrder,
    title: themeId,
    pageRange: null,
    plannedHours: null,
    anlamaHours: null,
    anlatmaHours: null,
    sourceLocator: null,
  ),
  block: Block(
    id: blockId,
    themeId: themeId,
    order: position,
    title: blockId,
    skillDomain: null,
    learningArea: null,
    plannedHours: null,
    timeStatus: 'ORDER_ONLY',
    sourceLocators: const [],
  ),
  officialTotalHours: null,
  coreInstructionHours: null,
  schoolBasedHours: null,
  schoolBasedHoursStatus: null,
);
