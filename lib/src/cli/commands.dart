import 'dart:io';

/// Base class for all Flint CLI commands.
abstract class FlintCommand {
  final String name;
  final String description;

  FlintCommand(this.name, this.description);

  Future<void> execute(List<String> args);
}

/// 🔥 Runs the development server
class RunServerCommand extends FlintCommand {
  RunServerCommand() : super('run', 'Runs the development server');

  @override
  Future<void> execute(List<String> args) async {
    final int port = args.isNotEmpty ? int.tryParse(args.first) ?? 8080 : 8080;

    final child = await Process.start(
      'dart',
      ['run', 'lib/main.dart', port.toString()],
      mode: ProcessStartMode.inheritStdio,
    );

    // Graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n[FLINT] Shutting down...');
      child.kill(ProcessSignal.sigint);
      await child.exitCode;
      exit(0);
    });

    exit(await child.exitCode);
  }
}

/// 🔄 Updates project dependencies using `dart pub upgrade`
class UpdateCommand extends FlintCommand {
  UpdateCommand() : super('update', 'Updates all project dependencies');

  @override
  Future<void> execute(List<String> args) async {
    print('🔄 Updating dependencies...');
    final result = await Process.run('dart', ['pub', 'upgrade']);

    if (result.exitCode != 0) {
      print('❌ Failed to update dependencies: ${result.stderr}');
      return;
    }

    print(result.stdout);
    print('✅ Dependencies updated successfully!');
  }
}

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
