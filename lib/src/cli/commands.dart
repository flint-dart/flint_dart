import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:flint_dart/src/env_parser.dart';

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

  static int resolveDefaultPort() {
    return FlintEnv.getInt('PORT', 8080);
  }

  static int resolvePort(List<String> args, {int? defaultPort}) {
    defaultPort ??= resolveDefaultPort();
    var port = defaultPort;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('--port=')) {
        port = int.tryParse(arg.substring('--port='.length)) ?? port;
      } else if (arg == '--port' && i + 1 < args.length) {
        port = int.tryParse(args[++i]) ?? port;
      } else if (!arg.startsWith('--')) {
        port = int.tryParse(arg) ?? port;
      }
    }

    return port;
  }

  @override
  Future<void> execute(List<String> args) async {
    var buildWeb = true;
    final port = resolvePort(args);

    for (final arg in args) {
      if (arg == '--no-web-build') {
        buildWeb = false;
      }
    }

    final hotFlag = Platform.environment['FLINT_HOT']?.toLowerCase().trim();
    final hotReloadDisabled = hotFlag == '0' || hotFlag == 'false';
    if (buildWeb && hotReloadDisabled) {
      final built = await FlintWebUiBuilder.compileIfPresent();
      if (!built) {
        Log.debug('[FLINT] No Flint Web UI entry found. Skipping web build.');
      }
    }

    final debugVmService =
        Platform.environment['FLINT_DEBUG_VM_SERVICE']?.toLowerCase().trim();
    final enableVmService = debugVmService == '1' ||
        debugVmService == 'true' ||
        debugVmService == 'yes';
    final hotReloadArgs = [
      if (enableVmService) '--enable-vm-service',
      'run',
      'flint_dart:hot_reload',
      'lib',
      '--port=$port',
    ];

    final child = hotReloadDisabled
        ? await Process.start(
            'dart',
            ['run', 'lib/main.dart', port.toString()],
            environment: {'FLINT_HOT': '0'},
            mode: ProcessStartMode.inheritStdio,
          )
        : await Process.start(
            'dart',
            hotReloadArgs,
            environment: {'FLINT_HOT': '1'},
            mode: ProcessStartMode.inheritStdio,
            runInShell: true,
          );

    // Graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      Log.debug('\n[FLINT] Shutting down...');
      child.kill(ProcessSignal.sigint);
      await child.exitCode;
      exit(0);
    });

    exit(await child.exitCode);
  }
}

/// Runs the app's dedicated Flint jobs worker entrypoint.
class RunJobsWorkerCommand extends FlintCommand {
  RunJobsWorkerCommand() : super('jobs-work', 'Runs the Flint jobs worker');

  static String resolveEntrypoint(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('--entrypoint=')) {
        return arg.substring('--entrypoint='.length);
      }
      if (arg == '--entrypoint' && i + 1 < args.length) {
        return args[++i];
      }
      if (!arg.startsWith('--')) {
        return arg;
      }
    }
    return 'bin/worker.dart';
  }

  @override
  Future<void> execute(List<String> args) async {
    final entrypoint = resolveEntrypoint(args);
    if (!File(entrypoint).existsSync()) {
      Log.error('Jobs worker entrypoint not found: $entrypoint');
      Log.info('Create $entrypoint and call app.runJobsWorker().');
      exit(1);
    }

    final child = await Process.start(
      'dart',
      ['run', entrypoint],
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );

    ProcessSignal.sigint.watch().listen((_) async {
      Log.debug('\n[FLINT] Shutting down jobs worker...');
      child.kill(ProcessSignal.sigint);
      await child.exitCode;
      exit(0);
    });

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) async {
        Log.debug('\n[FLINT] Shutting down jobs worker...');
        child.kill(ProcessSignal.sigterm);
        await child.exitCode;
        exit(0);
      });
    }

    exit(await child.exitCode);
  }
}
