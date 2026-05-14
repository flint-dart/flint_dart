import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:flint_dart/src/cli/generate_docs_command.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/template_engine/template.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

Process? server;
Timer? _debounce;
HttpClient? _httpClient;
int _serverPort = FlintEnv.getInt('PORT', 3001);
FlintWebUiBuild? _webBuild;

Future<bool> _notifyServerHotReload(
  String sourceName,
  String htmlContent,
  int port, {
  String event = 'flint:reload',
  String? message,
}) async {
  try {
    _httpClient ??= HttpClient();

    final request = await _httpClient!.postUrl(
      Uri.parse('http://localhost:$port/_flint/internal/hot-reload'),
    );

    request.headers.contentType = ContentType.json;
    request.headers.add('X-Flint-Hot-Reload', 'true');

    final body = jsonEncode({
      'template': sourceName,
      'html': htmlContent,
      'timestamp': DateTime.now().toIso8601String(),
      'source': sourceName,
      'event': event,
      if (message != null) 'message': message,
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

Future<void> _triggerBrowserReload(int port,
    {required String sourceName}) async {
  await _notifyServerHotReload(sourceName, '', port);
}

Future<void> _triggerBrowserBuildStart(
  int port, {
  required String sourceName,
}) async {
  await _notifyServerHotReload(
    sourceName,
    '',
    port,
    event: 'flint:building',
    message: 'Rebuilding Flint UI...',
  );
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
  final uiWatcher = _watchDirectoryIfPresent(_webBuild?.uiDir.path);
  final webWatcher = _watchDirectoryIfPresent(_webBuild?.webDir.path);
  final Map<String, DateTime> lastModified = {};

  Future<void> onEvent(WatchEvent event) async {
    final ext = p.extension(event.path);
    final isEnvFile = p.basename(event.path) == '.env';
    final isTemplate = ext == '.flint.html' || ext == '.html';
    final isServerCode = ext == '.dart' || isEnvFile;
    final isUiSource = _webBuild != null &&
        _isWithin(_webBuild!.uiDir.path, event.path) &&
        (ext == '.dart' || p.basename(event.path) == 'tailwind.css');
    final isWebAsset = _webBuild != null &&
        _isWithin(_webBuild!.webDir.path, event.path) &&
        !p.equals(p.normalize(event.path), p.normalize(_webBuild!.jsOut)) &&
        ext != '.deps' &&
        ext != '.map';

    if (!isTemplate && !isServerCode && !isUiSource && !isWebAsset) return;
    if (event.type == ChangeType.REMOVE && !isEnvFile) return;

    final now = DateTime.now();
    final last = lastModified[event.path];
    if (last != null && now.difference(last).inMilliseconds < 100) {
      return;
    }
    lastModified[event.path] = now;

    if (isUiSource) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        try {
          Log.debug('[HOT-RELOAD] Flint UI changed: ${event.path}');
          if (_webBuild != null) {
            await _triggerBrowserBuildStart(
              serverPort,
              sourceName: 'flint_ui:${p.basename(event.path)}',
            );
            await FlintWebUiBuilder.compile(_webBuild!);
            await _triggerBrowserReload(
              serverPort,
              sourceName: 'flint_ui:${p.basename(event.path)}',
            );
          }
        } catch (e, stack) {
          await _notifyServerHotReload(
            'flint_ui:${p.basename(event.path)}',
            '',
            serverPort,
            event: 'flint:error',
            message: 'Flint UI build failed. Check the terminal.',
          );
          Log.error(
            '[HOT-RELOAD] Error rebuilding Flint UI',
            error: e,
            stackTrace: stack,
          );
        }
      });
      return;
    }

    if (isWebAsset) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () async {
        try {
          Log.debug('[HOT-RELOAD] Web asset changed: ${event.path}');
          await _triggerBrowserReload(
            serverPort,
            sourceName: 'web_asset:${p.basename(event.path)}',
          );
        } catch (e, stack) {
          Log.error(
            '[HOT-RELOAD] Error reloading web asset',
            error: e,
            stackTrace: stack,
          );
        }
      });
      return;
    }

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
  uiWatcher?.events.listen(onEvent);
  webWatcher?.events.listen(onEvent);
}

DirectoryWatcher? _watchDirectoryIfPresent(String? path) {
  if (path == null) return null;
  final dir = Directory(path);
  if (!dir.existsSync()) return null;
  return DirectoryWatcher(path);
}

bool _isWithin(String rootPath, String filePath) {
  final normalizedRoot = p.normalize(p.absolute(rootPath));
  final normalizedFile = p.normalize(p.absolute(filePath));
  return p.isWithin(normalizedRoot, normalizedFile) ||
      p.equals(normalizedRoot, normalizedFile);
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
  _webBuild = FlintWebUiBuilder.resolve();

  Log.debug('[HOT-RELOAD] Flint watcher started');
  Log.debug('[HOT-RELOAD] Watching: lib/');
  Log.debug('[HOT-RELOAD] Watching: .env');
  if (_webBuild != null) {
    Log.debug('[HOT-RELOAD] Watching: ${_webBuild!.uiDir.path}');
    Log.debug('[HOT-RELOAD] Watching: ${_webBuild!.webDir.path}');
  }
  Log.debug('[HOT-RELOAD] Debounce: 300ms templates, 500ms server code');
  Log.debug(
    '[HOT-RELOAD] Endpoint: http://localhost:$_serverPort/_flint/internal/hot-reload',
  );

  if (_webBuild != null) {
    await FlintWebUiBuilder.compile(_webBuild!);
  }

  await restartServer();
  watchFiles(_serverPort);

  await Future.delayed(const Duration(days: 365));
}
