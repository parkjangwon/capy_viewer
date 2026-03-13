import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' as logger_pkg;
import 'package:manga_view_flutter/core/logger.dart';

void main() {
  test('DebugOnlyFilter suppresses every log when disabled', () {
    final filter = DebugOnlyFilter(isEnabled: () => false)
      ..level = logger_pkg.Level.trace;

    expect(
      filter.shouldLog(
        logger_pkg.LogEvent(logger_pkg.Level.error, 'should be suppressed'),
      ),
      isFalse,
    );
  });

  test('DebugOnlyFilter still respects log level when enabled', () {
    final filter = DebugOnlyFilter(isEnabled: () => true)
      ..level = logger_pkg.Level.warning;

    expect(
      filter.shouldLog(
        logger_pkg.LogEvent(logger_pkg.Level.info, 'below threshold'),
      ),
      isFalse,
    );
    expect(
      filter.shouldLog(
        logger_pkg.LogEvent(logger_pkg.Level.error, 'above threshold'),
      ),
      isTrue,
    );
  });
}
