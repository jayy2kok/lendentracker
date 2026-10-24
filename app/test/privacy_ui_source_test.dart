import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loan creation does not silently bind a different contact to an existing phone', () {
    final repository = File('lib/data/repositories/repositories.dart')
        .readAsStringSync();
    expect(repository, contains("existing.first['contact_id']"));
    expect(repository, contains('Re-link the existing person'));
  });

  test('presentation never renders raw caught exceptions or prints stacks', () {
    final sources = Directory('lib/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final forbidden = [
      RegExp(r'catch\s*\(e\)'),
      RegExp(r'catch\s*\(error\)'),
      RegExp(r'\.toString\(\)\s*\.replaceAll\('),
      RegExp(r'\bdebugPrint\s*\('),
      RegExp(r'\bprint\s*\('),
    ];
    for (final file in sources) {
      final contents = file.readAsStringSync();
      for (final pattern in forbidden) {
        expect(contents, isNot(matches(pattern)), reason: file.path);
      }
    }
  });
}
