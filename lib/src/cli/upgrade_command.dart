import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';

/// 🔄 Updates project dependencies using `dart pub upgrade`
/// 🚀 Upgrades both Flint CLI and (if applicable) the current project
class UpgradeCommand extends FlintCommand {
  UpgradeCommand()
      : super('upgrade', 'Upgrades Flint Dart CLI and project dependencies');

  @override
  Future<void> execute(List<String> args) async {
    final pubspec = File('pubspec.yaml');
    final insideProject = await pubspec.exists();

    if (insideProject) {
      print('📦 Project detected. Upgrading project dependencies...');
      final upgradeResult = await Process.run('dart', ['pub', 'upgrade']);
      if (upgradeResult.exitCode != 0) {
        print(
            '❌ Failed to update project dependencies: ${upgradeResult.stderr}');
      } else {
        print(upgradeResult.stdout);
        print('✅ Project dependencies updated successfully!');
      }
    } else {
      print('📂 No pubspec.yaml found — running CLI upgrade only.');
    }

    print('🚀 Upgrading Flint Dart CLI via pub.dev...');
    final cliUpgrade = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'flint_dart'],
    );

    if (cliUpgrade.exitCode != 0) {
      print('❌ Failed to upgrade Flint CLI: ${cliUpgrade.stderr}');
      return;
    }

    print(cliUpgrade.stdout);
    print(
        '✅ Flint Dart CLI upgraded to the latest stable version from pub.dev!');
  }
}
