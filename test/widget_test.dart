// Project-level smoke test; does not require a running database or platform UI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DayArk version is a valid Flutter application version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', multiLine: true);
    expect(version.hasMatch(pubspec), isTrue);
  });
}
