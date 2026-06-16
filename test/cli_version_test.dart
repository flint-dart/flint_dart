import 'dart:io';
import 'dart:isolate';

import 'package:flint_dart/src/cli/constants.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/env_parser.dart';
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

  test('RunServerCommand resolves positional and named ports', () {
    expect(RunServerCommand.resolvePort(['3101']), 3101);
    expect(RunServerCommand.resolvePort(['--port=3102']), 3102);
    expect(RunServerCommand.resolvePort(['--port', '3103']), 3103);
    expect(
      RunServerCommand.resolvePort(['--no-web-build', '--port=3104']),
      3104,
    );
  });

  test('RunServerCommand defaults to PORT from .env', () async {
    final dir = await Directory.systemTemp.createTemp('flint_cli_env_port_');
    final envFile = File(path.join(dir.path, '.env'));
    await envFile.writeAsString('PORT=3030\n');

    FlintEnv.setEnvFilePath(envFile.path);
    try {
      expect(RunServerCommand.resolvePort([]), 3030);
    } finally {
      FlintEnv.setEnvFilePath(null);
      await dir.delete(recursive: true);
    }
  });
}
