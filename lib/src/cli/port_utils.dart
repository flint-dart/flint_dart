import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<bool> isPortListening(int port) async {
  try {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(milliseconds: 700),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> waitForPortStopped(
  int port, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!await isPortListening(port)) return true;
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return !await isPortListening(port);
}

Future<Set<int>> findListeningProcessIds(int port) async {
  if (Platform.isWindows) {
    return _findListeningProcessIdsOnWindows(port);
  }
  return _findListeningProcessIdsOnUnix(port);
}

Future<Set<int>> _findListeningProcessIdsOnWindows(int port) async {
  final result = await Process.run('netstat', ['-ano'], runInShell: true);
  if (result.exitCode != 0) return {};

  final pids = <int>{};
  final currentPid = pid;
  for (final line in LineSplitter.split(result.stdout.toString())) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 5 || parts.first.toUpperCase() != 'TCP') continue;
    if (parts[3].toUpperCase() != 'LISTENING') continue;

    final localAddress = parts[1];
    if (!localAddress.endsWith(':$port')) continue;

    final ownerPid = int.tryParse(parts[4]);
    if (ownerPid != null && ownerPid != 0 && ownerPid != currentPid) {
      pids.add(ownerPid);
    }
  }
  return pids;
}

Future<Set<int>> _findListeningProcessIdsOnUnix(int port) async {
  final currentPid = pid;
  final lsof = await _tryRun('lsof', ['-nP', '-tiTCP:$port', '-sTCP:LISTEN']);
  if (lsof.exitCode == 0) {
    return LineSplitter.split(lsof.stdout.toString())
        .map((line) => int.tryParse(line.trim()))
        .whereType<int>()
        .where((ownerPid) => ownerPid != 0 && ownerPid != currentPid)
        .toSet();
  }

  final ss = await _tryRun('ss', ['-ltnp']);
  if (ss.exitCode == 0) {
    final pidPattern = RegExp(r'pid=(\d+)');
    final pids = <int>{};
    for (final line in LineSplitter.split(ss.stdout.toString())) {
      if (!line.contains(':$port ')) continue;
      for (final match in pidPattern.allMatches(line)) {
        final ownerPid = int.tryParse(match.group(1)!);
        if (ownerPid != null && ownerPid != 0 && ownerPid != currentPid) {
          pids.add(ownerPid);
        }
      }
    }
    return pids;
  }

  final netstat = await _tryRun('netstat', ['-ltnp']);
  if (netstat.exitCode != 0) return {};

  final pids = <int>{};
  for (final line in LineSplitter.split(netstat.stdout.toString())) {
    if (!line.contains(':$port ')) continue;
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 7) continue;
    final ownerPid = int.tryParse(parts.last.split('/').first);
    if (ownerPid != null && ownerPid != 0 && ownerPid != currentPid) {
      pids.add(ownerPid);
    }
  }
  return pids;
}

Future<ProcessResult> _tryRun(String executable, List<String> arguments) async {
  try {
    return Process.run(executable, arguments);
  } catch (_) {
    return ProcessResult(0, 1, '', '');
  }
}

Future<bool> forceStopListenersOnPort(
  int port, {
  void Function(String message)? onVerbose,
  void Function(String message)? onWarning,
}) async {
  final pids = await findListeningProcessIds(port);
  if (pids.isEmpty) return false;

  for (final processId in pids) {
    onVerbose?.call('Force stopping PID $processId on port $port...');
    if (Platform.isWindows) {
      await Process.run(
        'taskkill',
        ['/PID', processId.toString(), '/T', '/F'],
        runInShell: true,
      );
    } else {
      try {
        Process.killPid(processId, ProcessSignal.sigterm);
      } catch (e) {
        onVerbose?.call('Could not stop PID $processId: $e');
      }
    }
  }

  if (await waitForPortStopped(port, timeout: const Duration(seconds: 4))) {
    return true;
  }

  if (!Platform.isWindows) {
    for (final processId in pids) {
      try {
        Process.killPid(processId, ProcessSignal.sigkill);
      } catch (e) {
        onWarning?.call('Could not force stop PID $processId: $e');
      }
    }
  }
  return waitForPortStopped(port);
}
