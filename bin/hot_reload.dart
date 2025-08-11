import 'dart:async';
import 'dart:io';

Process? server;

// 1. Modify startServer to return `true` on success and `false` on failure.
Future<bool> startServer() async {
  print('🚀 Attempting to start server...');
  server = await Process.start(
    'dart',
    // Ensure you're running your main entry file
    ['lib/main.dart'], // Or 'lib/main.dart', whatever your entry file is
    mode: ProcessStartMode.inheritStdio,
  );

  // We'll wait for a short period to see if the process exits with an error.
  // An immediate exit usually means a startup failure (like port binding).
  final exitCode = await server!.exitCode.timeout(
    const Duration(seconds: 2),
    onTimeout: () => -1, // -1 means it's still running, which is good.
  );

  if (exitCode != -1) {
    print('⚠️ Server failed to start with exit code: $exitCode');
    return false; // Startup failed
  }

  print('✅ Server started successfully.');
  return true; // Startup was successful
}

// 2. Modify restartServer to include the retry logic.
Future<void> restartServer() async {
  if (server != null) {
    print('♻️ Shutting down old server...');
    server!.kill(ProcessSignal.sigint);
    await server!.exitCode;
  }

  int attempts = 0;
  bool started = false;

  while (attempts < 5 && !started) {
    attempts++;
    print('[Attempt $attempts/5]');
    started = await startServer();
    if (!started && attempts < 5) {
      // Wait before trying again
      await Future.delayed(const Duration(milliseconds: 750));
    }
  }

  if (!started) {
    print('❌ CRITICAL: Could not restart server after 5 attempts.');
  }
}

Future<void> main(List<String> args) async {
  // Initial start
  await restartServer();

  // Watch for changes in lib/
  final watcher = Directory('lib').watch(recursive: true);
  await for (final event in watcher) {
    if (event.type == FileSystemEvent.modify && event.path.endsWith('.dart')) {
      print('\n[HotReload] Change detected in ${event.path}');
      await restartServer();
    }
  }
}
