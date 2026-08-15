import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';

void main() {
  Map<String, dynamic> validManifest() => <String, dynamic>{
    'course_id': 'TDE_9',
    'schema_version': '1.0.0',
    'runtime_package_version': '1.0.0',
    'validation_status': 'PASS',
    'canonical_content_fingerprint': 'fingerprint',
    'runtime_database_path': 'runtime/course_runtime.sqlite',
  };

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
}
