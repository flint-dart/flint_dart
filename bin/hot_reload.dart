import 'dart:async';
import 'dart:io';

import 'package:flint_dart/src/cli/generate_docs_command.dart';

Process? server;
Timer? _debounce;

// Start the server
Future<bool> startServer() async {
  print('🚀 Attempting to start server...');
  server = await Process.start(
    'dart',
    ['lib/main.dart'],
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await server!.exitCode.timeout(
    const Duration(seconds: 2),
    onTimeout: () => -1,
  );

  if (exitCode != -1) {
    print('⚠️ Server failed to start with exit code: $exitCode');
    return false;
  }

  print('✅ Server started successfully.');
  return true;
}

// Restart the server
Future<void> restartServer() async {
  int attempts = 0;
  bool started = false;

  // Only stop the old server here, after debounce
  if (server != null) {
    print('♻️ Shutting down old server...');
    server!.kill(ProcessSignal.sigint);
    await server!.exitCode;
  }

  while (attempts < 5 && !started) {
    attempts++;
    print('[Attempt $attempts/5]');
    started = await startServer();
    if (!started && attempts < 5) {
      await Future.delayed(const Duration(milliseconds: 750));
    }
  }

  if (!started) {
    print('❌ CRITICAL: Could not restart server after 5 attempts.');
  } else {
    generateSwaggerDocs();
  }
}

// Run Flint Swagger Docs generator
Future<void> generateSwaggerDocs() async {
  GenerateDocsCommand().execute([]);
}

Future<void> main(List<String> args) async {
  // Initial start
  await restartServer();

  // Watch for changes
  final watcher = Directory('lib').watch(recursive: true);

  await for (final event in watcher) {
    if (event.type == FileSystemEvent.modify &&
        (event.path.endsWith('.dart') ||
            event.path.endsWith('.env') ||
            event.path.endsWith('.flint.html'))) {
      // Cancel previous debounce
      _debounce?.cancel();

      // Start a new debounce timer
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        print('\n[HotReload] Changes settled. Restarting server...');
        await restartServer();
      });
    }
  }
}
