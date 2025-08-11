// lib/src/cli/commands.dart
import 'dart:io';

abstract class FlintCommand {
  final String name;
  final String description;

  FlintCommand(this.name, this.description);

  Future<void> execute(List<String> args);
}

class RunServerCommand extends FlintCommand {
  RunServerCommand() : super('run', 'Runs the development server');

  @override
  Future<void> execute(List<String> args) async {
    final int port = args.isNotEmpty ? int.tryParse(args.first) ?? 8080 : 8080;

    // Run the user's bootstrap file (lib/main.dart)
    // This should define and configure `app` then call listen()
    // Start the server as a child process with signal forwarding
    final child = await Process.start(
      'dart',
      ['run', 'lib/main.dart', port.toString()],
      mode: ProcessStartMode.inheritStdio,
    );

    // Kill child when Ctrl+C is pressed
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n[FLINT] Shutting down...');
      child.kill(ProcessSignal.sigint);
      await child.exitCode;
      exit(0);
    });

    // Wait for the child process to exit
    exit(await child.exitCode);
  }
}
