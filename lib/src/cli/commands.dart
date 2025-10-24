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
