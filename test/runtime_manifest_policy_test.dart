import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/course_models.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';

void main() {
  Map<String, dynamic> validManifest({
    String schemaVersion = '1.0.0',
    String runtimePackageVersion = '1.0.0',
    String fingerprint = 'fingerprint',
    int? lessonPlanPackages,
  }) => <String, dynamic>{
    'course_id': 'TDE_9',
    'schema_version': schemaVersion,
    'runtime_package_version': runtimePackageVersion,
    'validation_status': 'PASS',
    'canonical_content_fingerprint': fingerprint,
    'runtime_database_path': 'runtime/course_runtime.sqlite',
    'row_counts': <String, dynamic>{
      'lesson_plan_packages': ?lessonPlanPackages,
    },
    'timeline_resolution': 'BLOCK_TIME_RESOLVED',
    'timeline_unresolved_fields': <String, dynamic>{},
  };

  RuntimeManifest runtime({
    String schemaVersion = '1.2.0',
    String runtimePackageVersion = '1.3.0',
    String fingerprint = 'lesson-plan-fingerprint',
    int lessonPlanPackages = 88,
  }) => RuntimeManifest.fromJson(
    validManifest(
      schemaVersion: schemaVersion,
      runtimePackageVersion: runtimePackageVersion,
      fingerprint: fingerprint,
      lessonPlanPackages: lessonPlanPackages,
    ),
  );

  test('uyumlu ve doğrulanmış runtime manifest startup için kabul edilir', () {
    expect(() => validateRuntimeManifest(validManifest()), returnsNormally);
  });

  test('manifest runtime_status taşıyorsa freshness doğrudan doğrulanır', () {
    final manifest = validManifest()..['runtime_status'] = 'RUNTIME_FRESH';
    expect(
      () => validateRuntimeFreshnessEvidence(manifest),
      returnsNormally,
    );
  });

  test('compiler validation raporu current canonical runtime freshness kanıtıdır', () {
    const report = '''
| Check | Status | Detail |
| source fingerprint status | PASS | RUNTIME_FRESH |
''';
    expect(
      () => validateRuntimeFreshnessEvidence(
        validManifest(),
        validationReport: report,
      ),
      returnsNormally,
    );
  });

  test('freshness kanıtı yoksa build-time doğrulama reddedilir', () {
    expect(
      () => validateRuntimeFreshnessEvidence(validManifest()),
      throwsA(isA<StateError>()),
    );
  });

  test('stale runtime_status freshness doğrulamasında reddedilir', () {
    final manifest = validManifest()..['runtime_status'] = 'RUNTIME_STALE';
    expect(
      () => validateRuntimeFreshnessEvidence(manifest),
      throwsA(isA<StateError>()),
    );
  });

  test('canonical fingerprint eksikse manifest reddedilir', () {
    final manifest = validManifest()..['canonical_content_fingerprint'] = '';
    expect(
      () => validateRuntimeManifest(manifest),
      throwsA(isA<StateError>()),
    );
  });

  test('desteklenmeyen schema major reddedilir', () {
    final manifest = validManifest()..['schema_version'] = '2.0.0';
    expect(
      () => validateRuntimeManifest(manifest),
      throwsA(isA<StateError>()),
    );
  });

  test('aynı runtime identity yeniden kurulum gerektirmez', () {
    final local = runtime();
    final expected = runtime();

    expect(runtimePackageIdentityMatches(local, expected), isTrue);
    expect(runtimePackageRequiresInstall(local, expected), isFalse);
  });

  test('legacy 1.2/1.1 runtime lesson-plan 1.3/1.2 pakete yükseltilir', () {
    final local = runtime(
      schemaVersion: '1.1.0',
      runtimePackageVersion: '1.2.0',
      fingerprint: 'legacy-fingerprint',
      lessonPlanPackages: 0,
    );
    final expected = runtime();

    expect(runtimePackageRequiresInstall(local, expected), isTrue);
  });

  test('canonical fingerprint drift yeniden kurulum gerektirir', () {
    final local = runtime(fingerprint: 'old-fingerprint');
    final expected = runtime();

    expect(runtimePackageRequiresInstall(local, expected), isTrue);
  });

  test('lesson-plan row count drift aynı fingerprintte bile fail closed', () {
    final local = runtime(lessonPlanPackages: 87);
    final expected = runtime();

    expect(runtimePackageRequiresInstall(local, expected), isTrue);
  });
}
