import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class WebUiCommand extends FlintCommand {
  WebUiCommand() : super('web', 'Builds and serves a Flint Web UI browser app');

  @override
  Future<void> execute(List<String> args) async {
    var port = 8080;
    var buildOnly = false;
    String? entryArg;
    String? webDirArg;
    String? outArg;
    String? pagesConfigArg;
    String? pageArg;
    var pageBundles = false;
    var sharedRuntime = true;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--entry' && i + 1 < args.length) {
        entryArg = args[++i];
      } else if (arg == '--web-dir' && i + 1 < args.length) {
        webDirArg = args[++i];
      } else if (arg == '--out' && i + 1 < args.length) {
        outArg = args[++i];
      } else if (arg == '--pages-config' && i + 1 < args.length) {
        pagesConfigArg = args[++i];
      } else if (arg == '--page' && i + 1 < args.length) {
        pageArg = args[++i];
        pageBundles = true;
        sharedRuntime = false;
      } else if (arg == '--port' && i + 1 < args.length) {
        final parsed = int.tryParse(args[++i]);
        if (parsed == null || parsed <= 0) {
          Log.debug('Invalid --port value.');
          exit(1);
        }
        port = parsed;
      } else if (arg == '--build-only') {
        buildOnly = true;
      } else if (arg == '--page-bundles') {
        pageBundles = true;
        sharedRuntime = false;
      } else if (arg == '--no-page-bundles') {
        pageBundles = false;
        sharedRuntime = false;
      } else if (arg == '--shared-runtime') {
        sharedRuntime = true;
        pageBundles = false;
      } else if (arg == '--no-shared-runtime') {
        sharedRuntime = false;
      } else if (arg == '--help' || arg == '-h') {
        _printHelp();
        return;
      } else if (arg == '--entry' ||
          arg == '--web-dir' ||
          arg == '--out' ||
          arg == '--pages-config' ||
          arg == '--page' ||
          arg == '--port') {
        Log.debug('Missing value for $arg');
        _printHelp();
        exit(1);
      } else {
        Log.debug('Unknown option: $arg');
        _printHelp();
        exit(1);
      }
    }

    final build = FlintWebUiBuilder.resolve(
      entryArg: entryArg,
      webDirArg: webDirArg,
      outArg: outArg,
    );

    if (build == null) {
      if (entryArg != null) {
        Log.debug('Entry file not found: $entryArg');
      } else if (webDirArg != null) {
        Log.debug('Web directory not found: $webDirArg');
      } else {
        Log.debug('No Flint Web UI entry point found.');
        Log.debug('Or provide one with --entry <path>');
      }
      exit(1);
    }

    if (sharedRuntime) {
      Log.info('Building Flint UI...');
      await FlintWebUiBuilder.compileSharedRuntimeBundle(
        build,
        configPath: pagesConfigArg,
      );
      Log.info('Done building Flint UI.');
    } else if (pageArg != null) {
      Log.info('Building Flint UI...');
      await FlintWebUiBuilder.compilePageBundles(
        build,
        configPath: pagesConfigArg,
        onlyPage: pageArg,
      );
      Log.info('Done building Flint UI.');
    } else {
      Log.info('Building Flint UI...');
      await FlintWebUiBuilder.compile(build);

      if (pageBundles) {
        try {
          await FlintWebUiBuilder.compilePageBundles(
            build,
            configPath: pagesConfigArg,
          );
        } on StateError catch (e) {
          if (pagesConfigArg != null) rethrow;
          Log.debug('Page-level Flint UI bundles skipped: ${e.message}');
        }
      }
      Log.info('Done building Flint UI.');
    }

    if (buildOnly) {
      return;
    }

    await _serve(build.webDir, port);
  }

  Future<void> _serve(Directory webDir, int port) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final url = 'http://localhost:${server.port}';

    Log.debug('Serving Flint Web UI from: ${webDir.path}');
    Log.debug('Open: $url');
    Log.debug('Press Ctrl+C to stop.');

    ProcessSignal.sigint.watch().listen((_) async {
      Log.debug('\n[FLINT] Stopping web server...');
      await server.close(force: true);
      exit(0);
    });

    await for (final request in server) {
      await _handleRequest(request, webDir);
    }
  }

  Future<void> _handleRequest(HttpRequest request, Directory webDir) async {
    final requestPath = Uri.decodeComponent(
        request.uri.path == '/' ? '/index.html' : request.uri.path);
    final relativePath = requestPath.replaceFirst(RegExp(r'^/+'), '');
    final file = File(path.join(webDir.path, relativePath));

    if (!_isInside(webDir, file) || !file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found');
      await request.response.close();
      return;
    }

    request.response.headers.contentType = ContentType.parse(
        lookupMimeType(file.path) ?? 'application/octet-stream');
    await file.openRead().pipe(request.response);
  }

  bool _isInside(Directory root, File file) {
    final rootPath = path.normalize(path.absolute(root.path));
    final filePath = path.normalize(path.absolute(file.path));
    return path.isWithin(rootPath, filePath) || rootPath == filePath;
  }

  void _printHelp() {
    Log.debug('''
Usage: flint web [options]

Options:
  --entry <path>       Dart web entry file (default: lib/ui/main.dart or flint_ui/main.dart)
  --web-dir <path>     Static web directory (default: sibling web/ directory)
  --out <path>         JavaScript output path (default: public/assets/js/flint-ui/main.dart.js for lib/ui)
  --shared-runtime     Compile one shared runtime with deferred page chunks (default)
  --page-bundles       Compile page-level bundles from component_registry.dart or flint_ui.yaml
  --no-page-bundles    Compile only the single global JavaScript bundle
  --no-shared-runtime  Disable shared runtime mode
  --pages-config <path> Page bundle config path (default: auto-detect, then flint_ui.yaml)
  --page <name>        Compile one page-level bundle by component name
  --port <number>      Local server port (default: 8080)
  --build-only         Compile JavaScript without starting the server
  --help, -h           Show this help

Examples:
  flint web
  flint web --port 3000
  flint web --entry lib/ui/main.dart --web-dir public
  flint web --entry flint_ui/main.dart --web-dir web
  flint web --build-only
  flint web --build-only --page-bundles
  flint web --build-only --no-page-bundles
  flint web --build-only --page Home
''');
  }
}
