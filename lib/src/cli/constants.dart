import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

const String fallbackFlintVersion = 'unknown';

Future<String> getFlintVersion() async {
  final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:flint_dart/flint_dart.dart'));
  if (packageUri == null) {
    return fallbackFlintVersion;
  }

  final libFilePath = packageUri.toFilePath(windows: Platform.isWindows);
  final pubspecFile =
      File(path.join(path.dirname(libFilePath), '..', 'pubspec.yaml'));

  if (!await pubspecFile.exists()) {
    return fallbackFlintVersion;
  }

  final contents = await pubspecFile.readAsString();
  final versionMatch =
      RegExp(r'^version:\s*([^\s#]+)', multiLine: true).firstMatch(contents);

  return versionMatch?.group(1) ?? fallbackFlintVersion;
}
