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
Future<void>? _restartFuture;
bool _restartAgain = false;

bool get _verboseHotReload {
  final value =
      Platform.environment['FLINT_HOT_RELOAD_VERBOSE']?.toLowerCase().trim();
  return value == '1' || value == 'true' || value == 'yes';
}

void _logVerbose(String message) {
  if (_verboseHotReload) Log.debug(message);
}

int? extractServerWorkerPortFromLog(String line) {
  final match = RegExp(
    r'Server Worker running on http://localhost:(\d+)',
  ).firstMatch(line);
  return match == null ? null : int.tryParse(match.group(1)!);
}

Future<bool> _isServerListening(int port) async {
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

Future<bool> _waitForServerStopped(
  int port, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!await _isServerListening(port)) return true;
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return !await _isServerListening(port);
}

Future<Set<int>> _findListeningProcessIds(int port) async {
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

Future<bool> _forceStopListenersOnPort(int port) async {
  final pids = await _findListeningProcessIds(port);
  if (pids.isEmpty) return false;

  for (final pid in pids) {
    Log.debug('[HOT-RELOAD] Force stopping PID $pid on port $port...');
    if (Platform.isWindows) {
      await Process.run(
        'taskkill',
        ['/PID', pid.toString(), '/T', '/F'],
        runInShell: true,
      );
    } else {
      try {
        Process.killPid(pid, ProcessSignal.sigterm);
      } catch (e) {
        Log.debug('[HOT-RELOAD] Could not stop PID $pid: $e');
      }
    }
  }

  if (await _waitForServerStopped(port, timeout: const Duration(seconds: 4))) {
    return true;
  }

  if (!Platform.isWindows) {
    for (final pid in pids) {
      try {
        Process.killPid(pid, ProcessSignal.sigkill);
      } catch (e) {
        Log.debug('[HOT-RELOAD] Could not force stop PID $pid: $e');
      }
    }
  }
  return _waitForServerStopped(port);
}

Future<void> _killProcessTree(Process process) async {
  if (Platform.isWindows) {
    await Process.run(
      'taskkill',
      ['/PID', process.pid.toString(), '/T', '/F'],
      runInShell: true,
    );
    return;
  }

  process.kill(ProcessSignal.sigint);
}

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
  if (await _isServerListening(_serverPort)) {
    Log.debug(
      '[HOT-RELOAD] Port $_serverPort is already in use. Force stopping listener...',
    );
    final stopped = await _forceStopListenersOnPort(_serverPort);
    if (!stopped && !await _waitForServerStopped(_serverPort)) {
      Log.debug(
        '[HOT-RELOAD] Port $_serverPort is still busy; server start skipped.',
      );
      return false;
    }
  }

  _logVerbose('[HOT-RELOAD] Starting server...');
  int? announcedPort;
  server = await Process.start(
    'dart',
    ['run', 'lib/main.dart', _serverPort.toString()],
    environment: {
      'FLINT_HOT': '1',
      'PORT': _serverPort.toString(),
    },
  );

  void pipeOutput(Stream<List<int>> stream) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln(line);
      final port = extractServerWorkerPortFromLog(line);
      if (port != null) announcedPort = port;
    });
  }

  pipeOutput(server!.stdout);
  pipeOutput(server!.stderr);

  final exitCode = await server!.exitCode.timeout(
    const Duration(seconds: 2),
    onTimeout: () => -1,
  );

  if (exitCode != -1) {
    Log.debug('[HOT-RELOAD] Server failed to start: $exitCode');
    return false;
  }

  final listeningPort = await _waitForStartedServerPort(
    expectedPort: _serverPort,
    announcedPort: () => announcedPort,
  );
  if (listeningPort == null) {
    Log.warning(
      '[HOT-RELOAD] Server process started but port $_serverPort is not reachable.',
    );
    await _killProcessTree(server!);
    return false;
  }

  if (listeningPort != _serverPort) {
    Log.debug(
      '[HOT-RELOAD] Worker is listening on port $listeningPort; updating watcher port from $_serverPort.',
    );
    _serverPort = listeningPort;
  }

  Log.debug('[HOT-RELOAD] Server started on http://localhost:$_serverPort');
  return true;
}

Future<int?> _waitForStartedServerPort({
  required int expectedPort,
  required int? Function() announcedPort,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await _isServerListening(expectedPort)) return expectedPort;

    final workerPort = announcedPort();
    if (workerPort != null && await _isServerListening(workerPort)) {
      return workerPort;
    }

    await Future.delayed(const Duration(milliseconds: 350));
  }

  return null;
}

Future<void> _triggerBrowserReload(
  int port, {
  required String sourceName,
  bool restartServerIfUnavailable = true,
}) async {
  var notified = await _notifyServerHotReload(sourceName, '', port);
  if (!notified && restartServerIfUnavailable) {
    Log.debug(
      '[HOT-RELOAD] Server reload endpoint is not reachable. Restarting server...',
    );
    await restartServer();
    notified = await _notifyServerHotReload(sourceName, '', port);
  }
  if (!notified) {
    Log.debug('[HOT-RELOAD] Browser reload skipped; server is still down.');
  }
}

Future<void> _triggerBrowserBuildStart(
  int port, {
  required String sourceName,
}) async {
  final notified = await _notifyServerHotReload(
    sourceName,
    '',
    port,
    event: 'flint:building',
    message: 'Rebuilding Flint UI...',
  );
  if (!notified && !await _isServerListening(port)) {
    Log.debug(
      '[HOT-RELOAD] Build notice skipped because server is not listening.',
    );
  }
}

Future<void> restartServer() async {
  if (_restartFuture != null) {
    _restartAgain = true;
    return _restartFuture;
  }

  _restartFuture = _restartServerOnce();
  try {
    await _restartFuture;
  } finally {
    _restartFuture = null;
  }

  if (_restartAgain) {
    _restartAgain = false;
    await restartServer();
  }
}

Future<void> _restartServerOnce() async {
  if (server != null) {
    Log.debug('[HOT-RELOAD] Stopping old server...');
    await _killProcessTree(server!);
    try {
      await server!.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      Log.debug('[HOT-RELOAD] Old server did not exit cleanly.');
    }
    server = null;

    if (!await _waitForServerStopped(_serverPort)) {
      Log.debug(
        '[HOT-RELOAD] Old server is still holding port $_serverPort.',
      );
      return;
    }
  }

  final started = await startServer();
  if (!started) {
    return;
  }
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
    final isWebAsset =
        _webBuild != null && isHotReloadWebAsset(_webBuild!, event.path);

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
          Log.debug('Rebuilding Flint UI...');
          if (_webBuild != null) {
            await _triggerBrowserBuildStart(
              serverPort,
              sourceName: 'flint_ui:${p.basename(event.path)}',
            );
            final rebuiltPage = await _compileChangedUiSource(event.path);
            if (rebuiltPage == null) {
              await FlintWebUiBuilder.compileDefault(_webBuild!);
            }
            await _triggerBrowserReload(
              serverPort,
              sourceName: rebuiltPage == null
                  ? 'flint_ui:${p.basename(event.path)}'
                  : 'flint_ui:page:$rebuiltPage',
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
            restartServerIfUnavailable: false,
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

Future<String?> _compileChangedUiSource(String filePath) async {
  final build = _webBuild;
  if (build == null) return null;

  if (p.basename(filePath) == 'tailwind.css') return null;
  if (p.equals(p.normalize(filePath), p.normalize(build.entry.path))) {
    return null;
  }

  final config = FlintWebUiBuilder.discoverPageBundleConfig(build);
  if (config == null || config.pageTargets.isEmpty) return null;

  final changedImport = _packageImportForSource(filePath);
  if (changedImport == null) return null;

  for (final entry in config.pageTargets.entries) {
    if (entry.value.importUri != changedImport) continue;

    _logVerbose(
      '[HOT-RELOAD] Rebuilding Flint UI page bundle only: ${entry.key}',
    );
    await FlintWebUiBuilder.compilePageBundles(build, onlyPage: entry.key);
    return entry.key;
  }

  return null;
}

String? _packageImportForSource(String filePath) {
  final packageName = _readPackageName();
  if (packageName == null) return null;

  final absolute = p.normalize(p.absolute(filePath));
  final libRoot = p.normalize(p.absolute('lib'));
  if (!_isWithin(libRoot, absolute)) return null;

  final relative = p.relative(absolute, from: libRoot);
  return 'package:$packageName/${p.split(relative).join('/')}';
}

String? _readPackageName() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) return null;

  for (final rawLine in pubspec.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.startsWith('name:')) {
      final name = line.substring(5).trim();
      return name.isEmpty ? null : name;
    }
  }
  return null;
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
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);
  if (results['help'] == true) {
    Log.debug('Usage: dart run flint_dart:hot_reload [--port <port>]');
    return;
  }
  _serverPort = int.tryParse(results['port']) ?? 3000;
  _webBuild = FlintWebUiBuilder.resolve();

  _logVerbose('[HOT-RELOAD] Flint watcher started');
  _logVerbose('[HOT-RELOAD] Watching: lib/');
  _logVerbose('[HOT-RELOAD] Watching: .env');
  if (_webBuild != null) {
    _logVerbose('[HOT-RELOAD] Watching: ${_webBuild!.uiDir.path}');
    _logVerbose('[HOT-RELOAD] Watching: ${_webBuild!.webDir.path}');
  }
  _logVerbose('[HOT-RELOAD] Debounce: 300ms templates, 500ms server code');
  _logVerbose(
    '[HOT-RELOAD] Endpoint: http://localhost:$_serverPort/_flint/internal/hot-reload',
  );

  await restartServer();

  if (_webBuild != null && await _isServerListening(_serverPort)) {
    await _triggerBrowserBuildStart(
      _serverPort,
      sourceName: 'flint_ui:initial',
    );
    try {
      await FlintWebUiBuilder.compileDefault(_webBuild!);
      await _triggerBrowserReload(
        _serverPort,
        sourceName: 'flint_ui:initial',
      );
    } catch (e, stack) {
      await _notifyServerHotReload(
        'flint_ui:initial',
        '',
        _serverPort,
        event: 'flint:error',
        message: 'Flint UI build failed. Check the terminal.',
      );
      Log.error(
        '[HOT-RELOAD] Error rebuilding Flint UI',
        error: e,
        stackTrace: stack,
      );
    }
  }

  watchFiles(_serverPort);

  await Future.delayed(const Duration(days: 365));
}

bool isHotReloadWebAsset(FlintWebUiBuild build, String filePath) {
  final ext = p.extension(filePath);
  if (!_isWithin(build.webDir.path, filePath)) return false;
  if (_isWithin(p.join(build.webDir.path, 'uploads'), filePath)) return false;
  if (_isGeneratedFlintUiAsset(build, filePath)) return false;
  if (ext == '.deps' || ext == '.map') return false;
  return true;
}

bool _isGeneratedFlintUiAsset(FlintWebUiBuild build, String filePath) {
  final jsOutDir = p.dirname(build.jsOut);
  if (_isWithin(jsOutDir, filePath)) return true;

  final cssOut = build.cssOut;
  if (cssOut != null) {
    final cssOutDir = p.dirname(cssOut);
    if (_isWithin(cssOutDir, filePath)) return true;
  }

  final normalizedFile = p.normalize(p.absolute(filePath));
  final serviceWorkerPath = p.normalize(
    p.absolute(p.join(build.webDir.path, 'flint-sw.js')),
  );
  return normalizedFile == serviceWorkerPath ||
      normalizedFile == '$serviceWorkerPath.gz' ||
      normalizedFile == '$serviceWorkerPath.br';
}
