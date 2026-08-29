import 'package:flutter/material.dart' hide Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_progress_models.dart';
import 'package:ogretmen_os/domain/repositories/course_knowledge_repository.dart';
import 'package:ogretmen_os/domain/repositories/lesson_plan_progress_repository.dart';
import 'package:ogretmen_os/features/lesson_plan/lesson_plan_page.dart';

void main() {
  testWidgets('plan takibi ikincildir ve kısmen işlendi/işlendi kaydedilir', (
    tester,
  ) async {
    final packages = [
      _package('BLOCK_A_P01', 1, title: 'Başlangıç'),
      _package('BLOCK_A_P02', 2, title: 'Yakın okuma'),
    ];
    final knowledge = _FakeRepository(packages);
    final progress = MemoryLessonPlanProgressRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlanPage(
          repository: knowledge,
          initialPackageId: 'BLOCK_A_P01',
          progressRepository: progress,
          academicYear: '2026-2027',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DERS DURUMU'), findsNothing);
    expect(find.text('İsteğe bağlı takip'), findsOneWidget);
    expect(
      find.text('Takip yok · ders planı sırası bundan bağımsız ilerler'),
      findsOneWidget,
    );
    expect(find.text('Sonraki ders planına geç'), findsNothing);

    await _expandTracking(tester);
    expect(find.text('Başlanmadı'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Kısmen işlendi'));
    await tester.pumpAndSettle();

    var record = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: 'BLOCK_A_P01',
    );
    await tester.pumpAndSettle();
    expect(record?.status, LessonPlanProgressStatus.inProgress);
    expect(record?.payloadSha256, packages.first.payloadSha256);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Kısmen işlendi'),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'İşlendi'));
    await tester.pumpAndSettle();

    record = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: 'BLOCK_A_P01',
    );
    await tester.pumpAndSettle();
    expect(record?.status, LessonPlanProgressStatus.completed);
    expect(record?.completedAt, isNotNull);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'İşlendi')).selected,
      isTrue,
    );
    expect(find.text('Sonraki ders planına geç'), findsNothing);
  });

  testWidgets('başlanmadı seçimi ilerleme kaydını temizler', (tester) async {
    final package = _package('BLOCK_A_P01', 1, title: 'Başlangıç');
    final knowledge = _FakeRepository([package]);
    final progress = MemoryLessonPlanProgressRepository();
    await progress.save(
      LessonPlanProgressRecord(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: package.packageId,
        payloadSha256: package.payloadSha256,
        status: LessonPlanProgressStatus.inProgress,
        startedAt: DateTime(2026, 9, 7, 10),
        updatedAt: DateTime(2026, 9, 7, 10),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlanPage(
          repository: knowledge,
          initialPackageId: package.packageId,
          progressRepository: progress,
          academicYear: '2026-2027',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _expandTracking(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Başlanmadı'));
    await tester.pumpAndSettle();

    final record = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
    );
    await tester.pumpAndSettle();
    expect(record, isNull);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Başlanmadı'))
          .selected,
      isTrue,
    );
  });

  testWidgets('ilk durum değişikliği gerçek geri alma ile kaydı tamamen kaldırır', (
    tester,
  ) async {
    final package = _package('BLOCK_A_P01', 1, title: 'Başlangıç');
    final progress = MemoryLessonPlanProgressRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlanPage(
          repository: _FakeRepository([package]),
          initialPackageId: package.packageId,
          progressRepository: progress,
          academicYear: '2026-2027',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _expandTracking(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Kısmen işlendi'));
    await tester.pumpAndSettle();
    expect(find.text('Geri al'), findsOneWidget);
    expect(
      (await progress.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: package.packageId,
      ))
          ?.status,
      LessonPlanProgressStatus.inProgress,
    );

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    expect(
      await progress.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: package.packageId,
      ),
      isNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Başlanmadı'))
          .selected,
      isTrue,
    );
  });

  testWidgets('geri alma önceki kalıcı snapshot ve zamanlarını aynen geri yükler', (
    tester,
  ) async {
    final package = _package('BLOCK_A_P01', 1, title: 'Başlangıç');
    final progress = MemoryLessonPlanProgressRepository();
    final previous = LessonPlanProgressRecord(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
      payloadSha256: package.payloadSha256,
      status: LessonPlanProgressStatus.inProgress,
      startedAt: DateTime(2026, 9, 7, 10),
      updatedAt: DateTime(2026, 9, 8, 11, 30),
    );
    await progress.save(previous);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlanPage(
          repository: _FakeRepository([package]),
          initialPackageId: package.packageId,
          progressRepository: progress,
          academicYear: '2026-2027',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _expandTracking(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'İşlendi'));
    await tester.pumpAndSettle();
    final completed = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
    );
    expect(completed?.status, LessonPlanProgressStatus.completed);
    expect(completed?.startedAt, previous.startedAt);
    expect(completed?.completedAt, isNotNull);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    final restored = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
    );
    expect(restored, isNotNull);
    expect(restored!.status, previous.status);
    expect(restored.payloadSha256, previous.payloadSha256);
    expect(restored.startedAt, previous.startedAt);
    expect(restored.completedAt, previous.completedAt);
    expect(restored.updatedAt, previous.updatedAt);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Kısmen işlendi'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('başlanmadı ile silinen önceki kayıt geri alma ile geri gelir', (
    tester,
  ) async {
    final package = _package('BLOCK_A_P01', 1, title: 'Başlangıç');
    final progress = MemoryLessonPlanProgressRepository();
    final previous = LessonPlanProgressRecord(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
      payloadSha256: package.payloadSha256,
      status: LessonPlanProgressStatus.inProgress,
      startedAt: DateTime(2026, 9, 7, 10),
      updatedAt: DateTime(2026, 9, 7, 10, 15),
    );
    await progress.save(previous);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlanPage(
          repository: _FakeRepository([package]),
          initialPackageId: package.packageId,
          progressRepository: progress,
          academicYear: '2026-2027',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _expandTracking(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Başlanmadı'));
    await tester.pumpAndSettle();
    expect(
      await progress.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: package.packageId,
      ),
      isNull,
    );

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    final restored = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
    );
    expect(restored, isNotNull);
    expect(restored!.status, previous.status);
    expect(restored.payloadSha256, previous.payloadSha256);
    expect(restored.startedAt, previous.startedAt);
    expect(restored.updatedAt, previous.updatedAt);
  });

  testWidgets('değişen payload eski durumu stale gösterir ve yeniden onay ister', (
    tester,
  ) async {
    final package = _package('BLOCK_A_P01', 1, title: 'Güncel plan');
    final progress = MemoryLessonPlanProgressRepository();
    final previous = LessonPlanProgressRecord(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
      payloadSha256: 'sha256-old-content',
      status: LessonPlanProgressStatus.completed,
      startedAt: DateTime(2026, 9, 7, 10),
      completedAt: DateTime(2026, 9, 7, 12),
      updatedAt: DateTime(2026, 9, 7, 12),
    );
    await progress.save(previous);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlanPage(
          repository: _FakeRepository([package]),
          initialPackageId: package.packageId,
          progressRepository: progress,
          academicYear: '2026-2027',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Plan güncellendi'), findsWidgets);
    expect(find.textContaining('İşlendi'), findsWidgets);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'İşlendi')).selected,
      isFalse,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Kısmen işlendi'));
    await tester.pumpAndSettle();

    final reconfirmed = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
    );
    expect(reconfirmed?.status, LessonPlanProgressStatus.inProgress);
    expect(reconfirmed?.payloadSha256, package.payloadSha256);
    expect(find.textContaining('Plan güncellendi'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Kısmen işlendi'),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    final restored = await progress.get(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: package.packageId,
    );
    expect(restored?.payloadSha256, 'sha256-old-content');
    expect(restored?.status, LessonPlanProgressStatus.completed);
    expect(find.textContaining('Plan güncellendi'), findsWidgets);
  });
}

Future<void> _expandTracking(WidgetTester tester) async {
  if (find.widgetWithText(ChoiceChip, 'Başlanmadı').evaluate().isNotEmpty) {
    return;
  }
  await tester.tap(find.text('İsteğe bağlı takip'));
  await tester.pumpAndSettle();
}

LessonPlanPackage _package(
  String packageId,
  int packageNo, {
  required String title,
}) => LessonPlanPackage(
  packageId: packageId,
  courseId: 'TDE_9',
  themeId: 'TEMA_01',
  blockId: 'BLOCK_A',
  packageNo: packageNo,
  lessonHours: 2,
  title: title,
  summary: 'Sınıf içi uygulama özeti',
  remainingBlockHours: (2 - packageNo) * 2,
  schemaVersion: '1.0.0',
  validationStatus: 'PASS',
  sourcePath: 'generated/$packageId.json',
  payloadSha256: 'sha256-$packageId',
  outcomeCodes: const ['TDE9.1.1'],
  usedActivityIds: const [],
  usedFormIds: const [],
  lessons: const [],
  teacherNotes: null,
  continuation: const LessonPlanContinuation(
    plannedNowHours: 2,
    remainingBlockHours: 0,
    coveredOutcomeCodes: ['TDE9.1.1'],
    usedActivityIds: [],
    nextStepHint: null,
    raw: {},
  ),
  rawPayload: const {},
);

class _FakeRepository
    implements CourseKnowledgeRepository, LessonPlanKnowledgeRepository {
  _FakeRepository(this.packages);

  final List<LessonPlanPackage> packages;

  @override
  Future<LessonPlanCapability> getLessonPlanCapability() async =>
      const LessonPlanCapability(
        available: true,
        manifestAdvertised: true,
        tableAvailable: true,
        packageCount: 2,
        instructionHours: 4,
        schemaVersion: '1.0.0',
        validationStatus: 'PASS',
      );

  @override
  Future<List<LessonPlanPackage>> getLessonPlansForBlock(String blockId) async =>
      packages.where((plan) => plan.blockId == blockId).toList(growable: false);

  @override
  Future<LessonPlanPackage?> getLessonPlan(String packageId) async {
    for (final plan in packages) {
      if (plan.packageId == packageId) return plan;
    }
    return null;
  }

  @override
  Future<LessonPlanPackage?> getPreviousLessonPlan(String packageId) async {
    final index = packages.indexWhere((plan) => plan.packageId == packageId);
    return index <= 0 ? null : packages[index - 1];
  }

  @override
  Future<LessonPlanPackage?> getNextLessonPlan(String packageId) async {
    final index = packages.indexWhere((plan) => plan.packageId == packageId);
    return index < 0 || index >= packages.length - 1
        ? null
        : packages[index + 1];
  }

  @override
  Future<Course> getCourse() async => throw UnimplementedError();

  @override
  Future<RuntimeManifest> getManifest() async => throw UnimplementedError();

  @override
  Future<List<Theme>> getThemes() async => throw UnimplementedError();

  @override
  Future<Theme> getTheme(String themeId) async => throw UnimplementedError();

  @override
  Future<List<Block>> getBlocks(String themeId) async =>
      throw UnimplementedError();

  @override
  Future<BlockDetail> getBlock(String blockId) async => throw UnimplementedError();

  @override
  Future<List<TimelineEntry>> getAnnualSequence() async =>
      throw UnimplementedError();

  @override
  Future<List<ResourceDecision>> getResourceDecisions(String themeId) async =>
      throw UnimplementedError();

  @override
  Future<TeacherPackage> getTeacherPackage(String themeId) async =>
      throw UnimplementedError();
}
