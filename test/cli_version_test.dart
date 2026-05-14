import 'dart:io';

import 'package:flint_dart/src/cli/constants.dart';
import 'package:test/test.dart';

void main() {
  test('getFlintVersion reads the current package version', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final expectedVersion = RegExp(r'^version:\s*([^\s#]+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    final version = await getFlintVersion();
    expect(version, expectedVersion);
  });
}
