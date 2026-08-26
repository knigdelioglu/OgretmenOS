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
}

LessonPlanPackage _package(String packageId, int packageNo) => LessonPlanPackage(
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
