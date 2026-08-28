import 'dart:developer' as developer;

/// Timeline-only instrumentation for profile/debug performance inspection.
///
/// It emits no console output and is compiled out of product builds, so
/// production behavior is not coupled to a logging sink.
class RuntimePerformanceTrace {
  const RuntimePerformanceTrace._();

  static const _enabled = !bool.fromEnvironment('dart.vm.product');

  static void count(String name) {
    if (!_enabled) return;
    developer.Timeline.instantSync('$name.call');
  }

  static void instant(
    String name, {
    Map<String, dynamic> arguments = const {},
  }) {
    if (!_enabled) return;
    developer.Timeline.instantSync(name, arguments: arguments);
  }

  static Future<T> measure<T>(String name, Future<T> Function() action) async {
    if (!_enabled) return action();

    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      instant(
        name,
        arguments: {'durationMs': stopwatch.elapsedMicroseconds / 1000},
      );
    }
  }
}
