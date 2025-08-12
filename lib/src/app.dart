import 'dart:io';

import 'package:flint_dart/src/database/connection.dart';
import 'package:mime/mime.dart';

import 'middleware.dart';
import 'request.dart';
import 'response.dart';
import 'router.dart';
import 'websocket.dart'; // FlintWebSocket and wsManager
import 'ws_router.dart'; // _WsRoute, WsHandler, WsAuthMiddleware typedefs

class Flint {
  final String rootPath;
  Flint({this.rootPath = "lib"});

  final Router _router = Router();
  final List<Middleware> _middlewares = [];

  bool _dbInitialized = false;
  bool get isDatabaseConnected => _dbInitialized;

  // ===== HTTP ROUTES =====
  void get(String path, Handler handler) => _router.add('GET', path, handler);
  void post(String path, Handler handler) => _router.add('POST', path, handler);
  void put(String path, Handler handler) => _router.add('PUT', path, handler);
  void patch(String path, Handler handler) =>
      _router.add('PATCH', path, handler);
  void delete(String path, Handler handler) =>
      _router.add('DELETE', path, handler);
  void route(String method, String path, Handler handler) =>
      _router.add(method.toUpperCase(), path, handler);

  // ===== WEBSOCKET ROUTES =====
  final List<WsRoute> _wsRoutes = [];

  void websocket(String path, WsHandler handler, {WsAuthMiddleware? auth}) {
    _wsRoutes.add(WsRoute(path, handler, auth));
  }

  // ===== STATIC FILES =====
  void static(String urlPrefix, String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      print('[FLINT] ⚠️ Warning: Static directory not found: $directoryPath');
      return;
    }

    _router.add('GET', '$urlPrefix/*', (req, res) async {
      final filePath = req.path.substring(urlPrefix.length);
      final file = File('$directoryPath$filePath');

      if (await file.exists()) {
        final mimeType = lookupMimeType(file.path);
        if (mimeType != null) {
          res.raw.headers.contentType = ContentType.parse(mimeType);
        }
        await res.streamFile(file);
      } else {
        res.status(404).send('Not Found');
      }
    });
  }

  // ===== MIDDLEWARE =====
  void use(Middleware middleware) => _middlewares.add(middleware);

  // ===== MOUNTING =====
  void mount(String prefix, void Function(Flint subApp) callback,
      {List<Middleware> middlewares = const []}) {
    final subApp = Flint(rootPath: rootPath);
    callback(subApp);

    for (final route in subApp._router.routes) {
      final handlerWithMiddlewares = middlewares.fold<Handler>(
        route.handler,
        (prev, middleware) => middleware.handle(prev),
      );

      _router.add(
        route.method,
        '$prefix${route.path == '/' ? '' : route.path}',
        handlerWithMiddlewares,
      );
    }

    for (final wsRoute in subApp._wsRoutes) {
      _wsRoutes.add(
          WsRoute('$prefix${wsRoute.path}', wsRoute.handler, wsRoute.auth));
    }
  }

  // ===== START SERVER =====
  Future<void> listen(int port) async {
    if (!_dbInitialized) {
      try {
        await DB.autoConnect();
        _dbInitialized = true;
        print('[FLINT] Database auto-connected via .env');
      } catch (e) {
        print('[FLINT] ⚠️ Could not auto-connect to database: $e');
      }
    }

    // Hot reload parent process
    if (Platform.environment['FLINT_HOT'] != '1') {
      print('[FLINT] Starting with hot reload...');
      final child = await Process.start(
        'dart',
        ['--enable-vm-service', 'run', 'flint_dart:hot_reload', rootPath],
        environment: {'FLINT_HOT': '1'},
        mode: ProcessStartMode.inheritStdio,
      );

      ProcessSignal.sigint.watch().listen((_) async {
        print('\n[FLINT] Shutting down...');
        child.kill(ProcessSignal.sigint);
        child.kill();
        await child.exitCode;
        exit(0);
      });

      return;
    }

    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Server running on http://localhost:$port');
    } on SocketException catch (e) {
      print('[FLINT] ❌ ERROR: Could not bind to port $port. Is it in use?');
      print('[FLINT] 🔎 Details: ${e.message}');
      await Future.delayed(const Duration(seconds: 1));
      exit(1);
    }

    ProcessSignal.sigint.watch().listen((_) async {
      print('\n[FLINT] Server shutting down...');
      await server?.close(force: true);
      exit(0);
    });

    await for (var req in server) {
      // ===== WebSocket check =====
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        bool matched = false;

        for (final route in _wsRoutes) {
          final params = route.match(req.uri.path);
          if (params != null) {
            matched = true;

            if (route.auth != null) {
              final allowed = await route.auth!(req);
              if (!allowed) {
                req.response.statusCode = HttpStatus.unauthorized;
                await req.response.close();
                break;
              }
            }

            final socket = await WebSocketTransformer.upgrade(req);
            final clientId = DateTime.now().microsecondsSinceEpoch.toString();
            final client = FlintWebSocket(socket, clientId);
            wsManager.addClient(clientId, client);

            route.handler(client, params);
            break;
          }
        }

        if (!matched) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
        continue;
      }

      // ===== HTTP Request handling =====
      final request = Request(req);
      final response = Response(req.response);
      final handler =
          _router.match(request.method, request.path, request.params);

      final pipeline = _middlewares.fold<Handler>(
        handler ?? ((req, res) async => res.send('404 Not Found', status: 404)),
        (prev, middleware) => middleware.handle(prev),
      );

      await pipeline(request, response);
      await req.response.close();
    }
  }
}
