import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/runtime/runtime_manifest_policy.dart';

void main() {
  Map<String, dynamic> validManifest() => <String, dynamic>{
    'course_id': 'TDE_9',
    'schema_version': '1.0.0',
    'runtime_package_version': '1.0.0',
    'validation_status': 'PASS',
    'runtime_status': 'RUNTIME_FRESH',
    'canonical_content_fingerprint': 'fingerprint',
    'runtime_database_path': 'runtime/course_runtime.sqlite',
  };

  test('fresh ve doğrulanmış runtime manifest kabul edilir', () {
    expect(() => validateRuntimeManifest(validManifest()), returnsNormally);
  });

  test('stale runtime manifest reddedilir', () {
    final manifest = validManifest()..['runtime_status'] = 'RUNTIME_STALE';
    expect(
      () => validateRuntimeManifest(manifest),
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
