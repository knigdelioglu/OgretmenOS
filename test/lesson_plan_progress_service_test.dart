import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_models.dart';
import 'package:ogretmen_os/domain/models/lesson_plan_progress_models.dart';
import 'package:ogretmen_os/domain/repositories/lesson_plan_progress_repository.dart';
import 'package:ogretmen_os/domain/services/lesson_plan_progress_service.dart';

void main() {
  late MemoryLessonPlanProgressRepository repository;
  late LessonPlanProgressService service;
  late List<LessonPlanPackage> packages;

  setUp(() {
    repository = MemoryLessonPlanProgressRepository();
    service = LessonPlanProgressService(repository: repository);
    packages = [
      _package('BLOCK_A_P01', 1),
      _package('BLOCK_A_P02', 2),
      _package('BLOCK_A_P03', 3),
    ];
  });

  test('kayıt yoksa ilk paket şu an, ikinci paket sonraki olur', () async {
    final snapshot = await service.snapshot(
      orderedPackages: packages,
      academicYear: '2026-2027',
    );

    expect(snapshot.currentPackageId, 'BLOCK_A_P01');
    expect(snapshot.nextPackageId, 'BLOCK_A_P02');
    expect(snapshot.stalePackageIds, isEmpty);
    expect(
      snapshot.statusFor('BLOCK_A_P01'),
      LessonPlanProgressStatus.notStarted,
    );
  });

  test('tamamlanan paket atlanır ve ilk açık paket odağa gelir', () async {
    await service.setStatus(
      package: packages[0],
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.completed,
      now: DateTime(2026, 9, 7, 10),
    );

    final snapshot = await service.snapshot(
      orderedPackages: packages,
      academicYear: '2026-2027',
    );

    expect(snapshot.currentPackageId, 'BLOCK_A_P02');
    expect(snapshot.nextPackageId, 'BLOCK_A_P03');
    expect(
      snapshot.statusFor('BLOCK_A_P01'),
      LessonPlanProgressStatus.completed,
    );
  });

  test('kısmen işlenen paket tamamlanmamış ilk paketten önce odağa alınır', () async {
    await service.setStatus(
      package: packages[1],
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.inProgress,
      now: DateTime(2026, 9, 8, 10),
    );

    final snapshot = await service.snapshot(
      orderedPackages: packages,
      academicYear: '2026-2027',
    );

    expect(snapshot.currentPackageId, 'BLOCK_A_P02');
    expect(snapshot.nextPackageId, 'BLOCK_A_P03');
  });

  test('tüm paketler işlendiğinde şu an ve sonraki boş kalır', () async {
    for (var index = 0; index < packages.length; index++) {
      await service.setStatus(
        package: packages[index],
        academicYear: '2026-2027',
        status: LessonPlanProgressStatus.completed,
        now: DateTime(2026, 9, 7 + index, 10),
      );
    }

    final snapshot = await service.snapshot(
      orderedPackages: packages,
      academicYear: '2026-2027',
    );

    expect(snapshot.currentPackageId, isNull);
    expect(snapshot.nextPackageId, isNull);
  });

  test('ilerleme eğitim yılına göre izole edilir', () async {
    await service.setStatus(
      package: packages[0],
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.completed,
      now: DateTime(2026, 9, 7, 10),
    );

    final nextYear = await service.snapshot(
      orderedPackages: packages,
      academicYear: '2027-2028',
    );

    expect(nextYear.currentPackageId, 'BLOCK_A_P01');
    expect(
      nextYear.statusFor('BLOCK_A_P01'),
      LessonPlanProgressStatus.notStarted,
    );
  });

  test('kısmen işlendi -> işlendi geçişi başlangıç zamanını korur', () async {
    final startedAt = DateTime(2026, 9, 7, 10);
    final completedAt = DateTime(2026, 9, 9, 11);

    await service.setStatus(
      package: packages[0],
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.inProgress,
      now: startedAt,
    );
    final completed = await service.setStatus(
      package: packages[0],
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.completed,
      now: completedAt,
    );

    expect(completed, isNotNull);
    expect(completed!.startedAt, startedAt);
    expect(completed.completedAt, completedAt);
    expect(completed.status, LessonPlanProgressStatus.completed);
    expect(completed.payloadSha256, packages[0].payloadSha256);
  });

  test('başlanmadı seçimi açık ilerleme kaydını siler', () async {
    await service.setStatus(
      package: packages[0],
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.inProgress,
    );
    await service.setStatus(
      package: packages[0],
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.notStarted,
    );

    expect(
      await repository.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: 'BLOCK_A_P01',
      ),
      isNull,
    );
  });

  test('aynı package id altında içerik değişirse eski completed kayıt stale olur', () async {
    final oldPackage = packages[0];
    await service.setStatus(
      package: oldPackage,
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.completed,
      now: DateTime(2026, 9, 7, 10),
    );
    final updatedPackage = _package(
      oldPackage.packageId,
      oldPackage.packageNo,
      payloadSha256: 'sha256-updated-content',
    );

    final resolution = await service.resolve(
      package: updatedPackage,
      academicYear: '2026-2027',
    );
    final snapshot = await service.snapshot(
      orderedPackages: [updatedPackage, packages[1], packages[2]],
      academicYear: '2026-2027',
    );

    expect(resolution.isStale, isTrue);
    expect(resolution.record?.status, LessonPlanProgressStatus.completed);
    expect(resolution.effectiveStatus, LessonPlanProgressStatus.notStarted);
    expect(snapshot.isStale(oldPackage.packageId), isTrue);
    expect(snapshot.currentPackageId, oldPackage.packageId);
    expect(
      snapshot.statusFor(oldPackage.packageId),
      LessonPlanProgressStatus.notStarted,
    );
  });

  test('v2den kalan hashesiz kayıt stale kabul edilir ama silinmez', () async {
    final legacy = LessonPlanProgressRecord(
      courseId: 'TDE_9',
      academicYear: '2026-2027',
      packageId: packages[0].packageId,
      status: LessonPlanProgressStatus.inProgress,
      startedAt: DateTime(2026, 9, 7, 10),
      updatedAt: DateTime(2026, 9, 7, 10),
    );
    await repository.save(legacy);

    final resolution = await service.resolve(
      package: packages[0],
      academicYear: '2026-2027',
    );

    expect(resolution.isStale, isTrue);
    expect(resolution.record, same(legacy));
    expect(
      await repository.get(
        courseId: 'TDE_9',
        academicYear: '2026-2027',
        packageId: packages[0].packageId,
      ),
      isNotNull,
    );
  });

  test('stale kayıt yeniden işaretlenince yeni hash ve yeni başlangıç zamanı kullanılır', () async {
    final oldPackage = packages[0];
    final oldStartedAt = DateTime(2026, 9, 7, 10);
    await service.setStatus(
      package: oldPackage,
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.inProgress,
      now: oldStartedAt,
    );
    final updatedPackage = _package(
      oldPackage.packageId,
      oldPackage.packageNo,
      payloadSha256: 'sha256-updated-content',
    );
    final reconfirmedAt = DateTime(2026, 9, 12, 14);

    final record = await service.setStatus(
      package: updatedPackage,
      academicYear: '2026-2027',
      status: LessonPlanProgressStatus.inProgress,
      now: reconfirmedAt,
    );
    final resolution = await service.resolve(
      package: updatedPackage,
      academicYear: '2026-2027',
    );

    expect(record?.payloadSha256, 'sha256-updated-content');
    expect(record?.startedAt, reconfirmedAt);
    expect(record?.startedAt, isNot(oldStartedAt));
    expect(resolution.isCurrent, isTrue);
  });

  test('payload hash olmayan canonical paket için ilerleme başlatılmaz', () async {
    final invalid = _package(
      'BLOCK_A_P99',
      99,
      payloadSha256: '   ',
    );

    expect(
      () => service.setStatus(
        package: invalid,
        academicYear: '2026-2027',
        status: LessonPlanProgressStatus.inProgress,
      ),
      throwsStateError,
    );
  });
}

LessonPlanPackage _package(
  String packageId,
  int packageNo, {
  String? payloadSha256,
}) => LessonPlanPackage(
  packageId: packageId,
  courseId: 'TDE_9',
  themeId: 'TEMA_01',
  blockId: 'BLOCK_A',
  packageNo: packageNo,
  lessonHours: 2,
  title: 'Paket $packageNo',
  summary: 'Sınıf içi uygulama özeti',
  remainingBlockHours: (3 - packageNo) * 2,
  schemaVersion: '1.0.0',
  validationStatus: 'PASS',
  sourcePath: 'generated/$packageId.json',
  payloadSha256: payloadSha256 ?? 'sha256-$packageId',
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
