import 'dart:io';
import 'dart:convert';
import 'package:flint_dart/logs.dart';

import "commands.dart";

class UpdateCommand extends FlintCommand {
  UpdateCommand()
      : super('update', 'Updates Flint Dart-related dependencies only');

  @override
  Future<void> execute(List<String> args) async {
    Log.debug('🔍 Checking for newer Flint package versions...');
    final outdated = await Process.run('dart', ['pub', 'outdated', '--json']);

    if (outdated.exitCode != 0) {
      Log.debug('❌ Failed to check for outdated dependencies.');
      Log.debug(outdated.stderr);
      return;
    }

    final data = jsonDecode(outdated.stdout);
    final packages = data['packages'] as List?;

    if (packages == null || packages.isEmpty) {
      Log.debug('✅ No outdated dependencies found.');
      return;
    }

    final pubspec = File('pubspec.yaml');
    if (!(await pubspec.exists())) {
      Log.debug('❌ No pubspec.yaml found in this directory.');
      return;
    }

    var content = await pubspec.readAsString();
    bool updatedAny = false;

    for (final pkg in packages) {
      final name = pkg['package'];
      final latest = pkg['latest']['version'];
      final current = pkg['current']['version'];
      final dependencyType = pkg['dependency'] ?? 'transitive';

      // ✅ Only update Flint packages that are direct dependencies
      if (dependencyType == 'direct' &&
          name.startsWith('flint_') &&
          current != latest) {
        final regex = RegExp('$name:\\s*\\^?[$current\\+\\.0-9a-zA-Z-]*');
        content = content.replaceAll(regex, '$name: ^$latest');
        Log.debug('⬆️  Updated $name: ^$current → ^$latest');
        updatedAny = true;
      }
    }

    if (!updatedAny) {
      Log.debug('✅ All Flint packages are already up to date.');
      return;
    }

    await pubspec.writeAsString(content);
    Log.debug('✅ pubspec.yaml updated successfully!');
    Log.debug('📦 Running dart pub get...');
    await Process.run(
      'dart',
      ['pub', 'get'],
    );
    Log.debug('✅ Flint dependencies synced successfully!');
  }
}
