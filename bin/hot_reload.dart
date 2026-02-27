import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/generate_docs_command.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/template_engine/template.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

Process? server;
Timer? _debounce;
HttpClient? _httpClient;
int _serverPort = FlintEnv.getInt('PORT', 3001);

Future<bool> _notifyServerHotReload(
  String templateName,
  String htmlContent,
  int port,
) async {
  try {
    _httpClient ??= HttpClient();

    final request = await _httpClient!.postUrl(
      Uri.parse('http://localhost:$port/_flint/internal/hot-reload'),
    );

    request.headers.contentType = ContentType.json;
    request.headers.add('X-Flint-Hot-Reload', 'true');

    final body = jsonEncode({
      'template': templateName,
      'html': htmlContent,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'hot_reload_watcher',
    });

    request.write(body);
    final response = await request.close();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<bool> startServer() async {
  Log.debug('[HOT-RELOAD] Starting server...');
  server = await Process.start(
    'dart',
    ['run', 'lib/main.dart', _serverPort.toString()],
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await server!.exitCode.timeout(
    const Duration(seconds: 2),
    onTimeout: () => -1,
  );

  if (exitCode != -1) {
    Log.debug('[HOT-RELOAD] Server failed to start: $exitCode');
    return false;
  }

  Log.debug('[HOT-RELOAD] Server started');
  await Future.delayed(const Duration(seconds: 1));
  return true;
}

Future<void> restartServer() async {
  if (server != null) {
    Log.debug('[HOT-RELOAD] Stopping old server...');
    server!.kill(ProcessSignal.sigint);
    await server!.exitCode;
  }
  await startServer();
  await generateSwaggerDocs();
}

Future<void> generateSwaggerDocs() async {
  await GenerateDocsCommand().execute([]);
}

void watchFiles(int serverPort) {
  final libWatcher = DirectoryWatcher('lib');
  final envWatcher = FileWatcher('.env');
  final Map<String, DateTime> lastModified = {};

  Future<void> onEvent(WatchEvent event) async {
    final ext = p.extension(event.path);
    final isEnvFile = p.basename(event.path) == '.env';
    final isTemplate = ext == '.flint.html' || ext == '.html';
    final isServerCode = ext == '.dart' || isEnvFile;

    if (!isTemplate && !isServerCode) return;
    if (event.type == ChangeType.REMOVE && !isEnvFile) return;

    final now = DateTime.now();
    final last = lastModified[event.path];
    if (last != null && now.difference(last).inMilliseconds < 100) {
      return;
    }
    lastModified[event.path] = now;

    if (isTemplate) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () async {
        try {
          final relative = p.relative(event.path, from: 'lib/views');
          final templateName = relative
              .replaceAll(Platform.pathSeparator, '.')
              .replaceAll(RegExp(r'\.flint\.html|\.html'), '');

          final htmlContent = TemplateEngine().render(templateName);
          Log.debug('[HOT-RELOAD] Template changed: $templateName');
          Log.debug('[HOT-RELOAD] File: ${event.path}');

          await _notifyServerHotReload(templateName, htmlContent, serverPort);
        } catch (e, stack) {
          Log.error(
            '[HOT-RELOAD] Error processing template',
            error: e,
            stackTrace: stack,
          );
        }
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      Log.debug('[HOT-RELOAD] Restarting server...');
      await restartServer();
    });
  }

  libWatcher.events.listen(onEvent);
  envWatcher.events.listen(onEvent);
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: FlintEnv.getInt('PORT', 3001).toString(),
    );

  final results = parser.parse(args);
  _serverPort = int.tryParse(results['port']) ?? 3000;

  Log.debug('[HOT-RELOAD] Flint watcher started');
  Log.debug('[HOT-RELOAD] Watching: lib/');
  Log.debug('[HOT-RELOAD] Watching: .env');
  Log.debug('[HOT-RELOAD] Debounce: 300ms templates, 500ms server code');
  Log.debug(
    '[HOT-RELOAD] Endpoint: http://localhost:$_serverPort/_flint/internal/hot-reload',
  );

  await restartServer();
  watchFiles(_serverPort);

  await Future.delayed(const Duration(days: 365));
}
