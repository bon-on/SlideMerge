import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('game scaffold stays fixed while the score-name keyboard opens', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('resizeToAvoidBottomInset: false'));
  });
}
