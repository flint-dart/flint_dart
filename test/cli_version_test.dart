import 'dart:io';
import 'dart:isolate';

import 'package:flint_dart/src/cli/constants.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('getFlintVersion reads the current package version', () async {
    final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:flint_dart/flint_dart.dart'),
    );
    final libFilePath = packageUri!.toFilePath(windows: Platform.isWindows);
    final pubspecFile =
        File(path.join(path.dirname(libFilePath), '..', 'pubspec.yaml'));
    final pubspec = await pubspecFile.readAsString();
    final expectedVersion = RegExp(r'^version:\s*([^\s#]+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    final version = await getFlintVersion();
    expect(version, expectedVersion);
  });
}
