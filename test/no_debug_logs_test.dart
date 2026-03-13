import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib directory does not contain ad-hoc debug logs', () {
    final forbiddenPattern = RegExp(
      r'\b(?:print|debugPrint)\s*\(|console\.(?:log|error|warn|info)\s*\(',
    );
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final content = entity.readAsStringSync();
      final matches = forbiddenPattern.allMatches(content);

      if (matches.isNotEmpty) {
        violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Remove development-time debug logging from these files:\n'
          '${violations.join('\n')}',
    );
  });
}
