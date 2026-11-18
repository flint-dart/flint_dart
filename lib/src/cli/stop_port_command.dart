import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/cli/port_utils.dart';

class StopPortCommand extends FlintCommand {
  StopPortCommand() : super('stop', 'Stops the process listening on a port');

  static int? resolvePort(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('--port=')) {
        return int.tryParse(arg.substring('--port='.length));
      }
      if ((arg == '--port' || arg == '-p') && i + 1 < args.length) {
        return int.tryParse(args[++i]);
      }
      if (!arg.startsWith('-')) {
        return int.tryParse(arg);
      }
    }
    return null;
  }

  @override
  Future<void> execute(List<String> args) async {
    final port = resolvePort(args);
    if (port == null || port < 1 || port > 65535) {
      Log.error('Usage: flint stop <port>');
      exit(1);
    }

    final pids = await findListeningProcessIds(port);
    if (pids.isEmpty) {
      Log.info('No process is listening on port $port.');
      return;
    }

    Log.info(
        'Stopping port $port (${pids.length} process${pids.length == 1 ? '' : 'es'}: ${pids.join(', ')})...');
    final stopped = await forceStopListenersOnPort(
      port,
      onVerbose: (message) => Log.debug('[FLINT] $message'),
      onWarning: (message) => Log.warning('[FLINT] $message'),
    );

    if (!stopped) {
      Log.error('Could not stop the process listening on port $port.');
      exit(1);
    }

    Log.info('Port $port is now free.');
  }
}
