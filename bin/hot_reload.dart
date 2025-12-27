import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flint_dart/src/cli/generate_docs_command.dart';
import 'package:flint_dart/src/template_engine/template.dart';
import 'package:path/path.dart' as p;
import 'package:args/args.dart'; // Add this dependency to pubspec.yaml

Process? server;
Timer? _debounce;
HttpClient? _httpClient;
int _serverPort = 3000;

/// Make HTTP call to server's internal endpoint
Future<bool> _notifyServerHotReload(
    String templateName, String htmlContent, int port) async {
  try {
    _httpClient ??= HttpClient();

    final request = await _httpClient!.postUrl(
        Uri.parse('http://localhost:$port/_flint/internal/hot-reload'));

    request.headers.contentType = ContentType.json;
    request.headers.add('X-Flint-Hot-Reload', 'true');

    final body = jsonEncode({
      'template': templateName,
      'html': htmlContent,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'hot_reload_watcher'
    });

    request.write(body);
    final response = await request.close();
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}

Future<bool> startServer() async {
  print('🚀 Starting server...');
  server = await Process.start(
    'dart',
    ['run', 'lib/main.dart'],
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await server!.exitCode.timeout(
    const Duration(seconds: 2),
    onTimeout: () => -1,
  );

  if (exitCode != -1) {
    print('⚠️ Server failed to start: $exitCode');
    return false;
  }

  print('✅ Server started');

  // Give server time to start
  await Future.delayed(Duration(seconds: 1));
  return true;
}

Future<void> restartServer() async {
  if (server != null) {
    print('♻️ Stopping old server...');
    server!.kill(ProcessSignal.sigint);
    await server!.exitCode;
  }
  await startServer();
  generateSwaggerDocs();
}

Future<void> generateSwaggerDocs() async {
  await GenerateDocsCommand().execute([]);
}

void watchFiles(int serverPort) {
  final watcher = Directory('lib').watch(recursive: true);
  final Map<String, DateTime> lastModified = {};

  watcher.listen((event) async {
    final ext = p.extension(event.path);
    if (event.type != FileSystemEvent.modify) return;

    // Debounce: ignore rapid successive changes
    final now = DateTime.now();
    final last = lastModified[event.path];
    if (last != null && now.difference(last).inMilliseconds < 100) {
      return;
    }
    lastModified[event.path] = now;

    // Templates
    if (ext == '.flint.html' || ext == '.html') {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () async {
        try {
          final relative = p.relative(event.path, from: 'lib/views');
          final templateName = relative
              .replaceAll(Platform.pathSeparator, '.')
              .replaceAll(RegExp(r'\.flint\.html|\.html'), '');

          // Render template
          final htmlContent = TemplateEngine().render(templateName);

          print('[HOT-RELOAD] 🔄 Template changed: $templateName');
          print('[HOT-RELOAD] 📁 File: ${event.path}');

          // Call HTTP endpoint instead of directly accessing wsManager
          await _notifyServerHotReload(templateName, htmlContent, serverPort);
        } catch (e) {
          print('[HOT-RELOAD] ❌ Error processing template: $e');
        }
      });
    }

    // Server code
    else if (ext == '.dart' || ext == '.env') {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        print('[HOT-RELOAD] 🔄 Restarting server...');
        await restartServer();
      });
    }
  });
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()..addOption('port', abbr: 'p', defaultsTo: '3000');

  final results = parser.parse(args);
  _serverPort = int.tryParse(results['port']) ?? 3000;
  print('🔥 Flint Hot Reload Watcher Started');
  print('📂 Watching: lib/');
  print('⏱️  Debounce: 300ms for templates, 500ms for server code');
  print('📡 Server endpoint: http://localhost:3000/_flint/internal/hot-reload');
  print('────────────────────────────────────────────────');

  await restartServer();
  watchFiles(_serverPort);

  // Keep the process alive
  await Future.delayed(Duration(days: 365));
}
