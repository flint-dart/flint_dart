import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/web_ui_builder.dart';

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
    var buildWeb = true;
    int port = 8080;

    for (final arg in args) {
      if (arg == '--no-web-build') {
        buildWeb = false;
      } else if (!arg.startsWith('--')) {
        port = int.tryParse(arg) ?? port;
      }
    }

    if (buildWeb) {
      final built = await FlintWebUiBuilder.compileIfPresent();
      if (!built) {
        Log.debug('[FLINT] No Flint Web UI entry found. Skipping web build.');
      }
    }

    final child = await Process.start(
      'dart',
      ['run', 'lib/main.dart', port.toString()],
      mode: ProcessStartMode.inheritStdio,
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
