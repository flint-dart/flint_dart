import 'dart:io';
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/mail/mail_config.dart';
import 'package:flint_dart/src/route_builder.dart';
import 'package:flint_dart/src/websocket/websocket_manager.dart';
import 'package:flint_dart/src/websocket/ws_helper.dart';
import 'package:mime/mime.dart';
import 'middleware.dart';
import 'request.dart';
import 'response.dart';
import 'router.dart';
import 'websocket/websocket.dart'; // FlintWebSocket and wsManager
import 'websocket/ws_router.dart'; // _WsRoute, WsHandler, WsAuthMiddleware typedefs
import 'package:path/path.dart' as path;
import 'package:package_config/package_config.dart';

Future<String> _getFlintDartLibPath() async {
  // Load the package configuration from the sample project
  final packageConfig = await findPackageConfig(Directory.current);
  if (packageConfig == null) {
    throw Exception(
        'Could not find package configuration in ${Directory.current.path}');
  }

  // Find the flint_dart package
  final flintPackage = packageConfig['flint_dart'];
  if (flintPackage == null) {
    throw Exception('flint_dart package not found in dependencies');
  }

  // Return the path to flint_dart's lib folder
  return path.join(
      flintPackage.root.toFilePath(windows: Platform.isWindows), 'lib');
}

//  void _registerSwaggerDocs() async {
//    // Resolve flint_dart's lib path
//    final flintLibPath = await _getFlintDartLibPath();
//    final swaggerDir = Directory(path.join(flintLibPath, 'swagger', 'swagger-ui'));
//    print('[DEBUG] Swagger UI directory: ${swaggerDir.absolute.path}');

//    // Serve swagger.json from sample project
//    get('/swagger.json', (req, res) async {
//      final file = File(path.join(Directory.current.path, 'docs', 'swagger.json'));
//      print('[DEBUG] Checking for swagger.json at: ${file.absolute.path}');
//      if (await file.exists()) {
//        print('[DEBUG] swagger.json found');
//        final bytes = await file.readAsBytes();
//        res.raw.headers.contentType = ContentType.json;
//        await res.raw.addStream(Stream.fromIterable([bytes]));
//        await res.raw.close();
//      } else {
//        print('[DEBUG] swagger.json not found');
//        res.raw.statusCode = 404;
//        res.raw.write('swagger.json not found');
//        await res.raw.close();
//      }
//    });

//    // Check if swagger-ui directory exists
//    if (!await swaggerDir.exists()) {
//      print('[FLINT] ⚠️ Warning: Static directory not found: ${swaggerDir.absolute.path}');
//      return;
//    }

//    // Serve static Swagger UI files
//    static('/swagger-ui', swaggerDir.path);

//    // Serve /docs
//    get('/docs', (req, res) async {
//      final file = File(path.join(swaggerDir.path, 'index.html'));
//      print('[DEBUG] Checking for index.html at: ${file.absolute.path}');
//      if (await file.exists()) {
//        print('[DEBUG] index.html found');
//        final bytes = await file.readAsBytes();
//        res.raw.headers.contentType = ContentType.html;
//        await res.raw.addStream(Stream.fromIterable([bytes]));
//        await res.raw.close();
//      } else {
//        print('[DEBUG] index.html not found');
//        res.raw.statusCode = 404;
//        res.raw.write('Swagger UI not found in the framework');
//        await res.raw.close();
//      }
//    });
//  }
/// The core application class for the Flint Dart framework.
///
/// Provides:
/// - HTTP route handling (`get`, `post`, `put`, etc.)
/// - WebSocket routing with optional authentication
/// - Static file serving
/// - Middleware support
/// - Mounting of sub-applications
/// - Automatic database connection (via `.env`)
/// - Hot reload support during development
class Flint {
  /// The root path of your Flint project (defaults to `"lib"`).
  final String rootPath;
  static String viewPath = ""; // 👈 default

  /// Whether to automatically connect to the database when [listen] is called.
  ///
  /// - If `true` (default), Flint will attempt to initialize the database
  ///   connection in the background as soon as the server starts.
  /// - If `false`, Flint will not auto-connect, and you must manually call
  ///   `DB.connect()` before using any database features.
  final bool autoConnectDb;

  /// Whether to include Flint’s default middleware stack.
  ///
  /// - If `true` (default), Flint automatically registers useful middleware
  ///   such as [ExceptionMiddleware] for error handling.
  /// - If `false`, no middleware is added — you must register your own with [use()].
  ///   This is useful for very minimal or fully customized setups.
  final bool withDefaultMiddleware;
  final bool enableSwaggerDocs;

  /// Creates a new Flint application instance.
  ///
  /// [rootPath] is used for resolving hot reload entry points
  /// and mounted sub-apps.
  Flint(
      {this.rootPath = "lib",
      String? viewPath,
      this.autoConnectDb = true,
      this.withDefaultMiddleware = true,
      this.enableSwaggerDocs = false}) {
    if (withDefaultMiddleware) {
      _middlewares.add(ExceptionMiddleware());
    }
    if (enableSwaggerDocs) {
      _registerSwaggerDocs();
    }

    if (viewPath != null) {
      Flint.viewPath = viewPath;
    }
  }

  void _registerSwaggerDocs() async {
    // Resolve flint_dart's lib path
    final flintLibPath = await _getFlintDartLibPath();
    final swaggerDir =
        Directory(path.join(flintLibPath, 'swagger', 'swagger-ui'));
    print('[DEBUG] Swagger UI directory: ${swaggerDir.absolute.path}');

    // Serve swagger.json from sample project
    get('/swagger.json', (req, res) async {
      final file =
          File(path.join(Directory.current.path, 'docs', 'swagger.json'));
      print('[DEBUG] Checking for swagger.json at: ${file.absolute.path}');
      if (await file.exists()) {
        print('[DEBUG] swagger.json found');
        final bytes = await file.readAsBytes();
        res.raw.headers.contentType = ContentType.json;
        await res.raw.addStream(Stream.fromIterable([bytes]));
        await res.raw.close();
      } else {
        print('[DEBUG] swagger.json not found');
        res.raw.statusCode = 404;
        res.raw.write('swagger.json not found');
        await res.raw.close();
      }
      return;
    });

    // Check if swagger-ui directory exists
    if (!await swaggerDir.exists()) {
      print(
          '[FLINT] ⚠️ Warning: Static directory not found: ${swaggerDir.absolute.path}');
      return;
    }

    // Serve static Swagger UI files
    static('/swagger-ui', swaggerDir.path);

    // Serve /docs
    get('/docs', (req, res) async {
      final file = File(path.join(swaggerDir.path, 'index.html'));
      if (await file.exists()) {
        var content = await file.readAsString();

        // Rewrite asset paths so they load correctly
        content = content.replaceAll('href="./', 'href="/swagger-ui/');
        content = content.replaceAll('src="./', 'src="/swagger-ui/');
        // Replace default Petstore spec with /swagger.json

        res.raw.headers.contentType = ContentType.html;
        res.raw.write(content);
        return;
      } else {
        res.raw.statusCode = 404;
        res.raw.write('Swagger UI not found');
      }
      await res.raw.close();
      return;
    });
  }

  final Router _router = Router();
  final List<Middleware> _middlewares = [];

  bool _dbInitialized = false;

  /// Returns `true` if the database connection has been established.
  bool get isDatabaseConnected => _dbInitialized;

  // ===== HTTP ROUTES =====

  /// Registers a GET route.
  RouteBuilder get(String path, Handler handler) {
    final rb = RouteBuilder(_router, 'GET', path, handler);
    rb.register();
    return rb;
  }

  /// Registers a POST route.
  RouteBuilder post(String path, Handler handler) {
    final rb = RouteBuilder(_router, 'POST', path, handler);
    rb.register();
    return rb;
  }

  /// Registers a PUT route.
  RouteBuilder put(String path, Handler handler) {
    final rb = RouteBuilder(_router, 'PUT', path, handler);
    rb.register();
    return rb;
  }

  /// Registers a DELETE route.
  RouteBuilder delete(String path, Handler handler) {
    final rb = RouteBuilder(_router, 'DELETE', path, handler);
    rb.register();
    return rb;
  }

  /// Registers a PATCH route.
  RouteBuilder patch(String path, Handler handler) {
    final rb = RouteBuilder(_router, 'PUT', path, handler);
    rb.register();
    return rb;
  }

  /// Registers a route for a custom HTTP method.
  RouteBuilder route(String method, String path, Handler handler) {
    final rb = RouteBuilder(_router, method, path, handler);
    rb.register();
    return rb;
  }
  // ===== WEBSOCKET ROUTES =====

  final List<WsRoute> _wsRoutes = [];

  /// Registers a WebSocket route.
  ///
  /// [path] is the WebSocket endpoint (e.g. `/chat`).
  /// [handler] is the callback for connected clients.
  /// [auth] is an optional authentication middleware that runs
  /// before upgrading the connection.
  void websocket(String path, WsHandler handler, {WsAuthMiddleware? auth}) {
    _wsRoutes.add(WsRoute(path, handler, auth));
  }

  // ===== STATIC FILES =====

  /// Serves static files from [directoryPath] at [urlPrefix].
  ///
  /// Example:
  /// ```dart
  /// app.static('/public', 'public');
  /// ```
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
        return res; // ✅ always return
      } else {
        return res.status(404).send('Not Found'); // ✅ return
      }
    });
  }

  // ===== MIDDLEWARE =====

  /// Adds a [middleware] to the application.
  ///
  /// Middlewares run for every incoming request in the order
  /// they are registered.
  void use(Middleware middleware) => _middlewares.add(middleware);

  // ===== MOUNTING =====

  /// Mounts a sub-application under [prefix].
  ///
  /// Useful for modular route organization.
  /// You can also pass specific [middlewares] for the mounted app.
  void mount(String prefix, void Function(Flint subApp) callback,
      {List<Middleware> middlewares = const []}) {
    final subApp = Flint(rootPath: rootPath);
    callback(subApp);

    for (final route in subApp._router.routes) {
      var allMiddleware = [...middlewares, ...route.middlewares];

      var handlerWithMiddlewares = allMiddleware.fold<Handler>(
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

  /// Starts the HTTP & WebSocket server on [port].
  ///
  /// - Attempts to auto-connect to the database via `.env` unless already connected.
  /// - Runs with hot reload during development unless `FLINT_HOT` is set.
  /// - Handles both HTTP and WebSocket upgrade requests.
  Future<void> listen(int port) async {
    if (autoConnectDb) {
      _connectDatabaseInBackground();
    }
    MailConfig.load();
    // Hot reload parent process
    if (Platform.environment['FLINT_HOT'] != '1') {
      print('[FLINT] Starting with hot reload...');
      final child = await Process.start('dart',
          ['--enable-vm-service', 'run', 'flint_dart:hot_reload', rootPath],
          environment: {'FLINT_HOT': '1'},
          mode: ProcessStartMode.inheritStdio,
          runInShell: true);

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

      // await pipeline(request, response);

      try {
        await pipeline(request, response);

        // ✅ Only close once
        if (!response.isClosed) {
          await response.close();
          await req.response.close();
        }
      } catch (e, st) {
        if (!response.isClosed) {
          response.raw.statusCode = 500;
          response.raw.write('Internal Server Error: $e');
          await response.close();
        }
        print('[FLINT] ❌ Handler error: $e\n$st');
      }
    }
  }

  void _connectDatabaseInBackground() async {
    try {
      await DB.autoConnect();
      _dbInitialized = true;
      print('[FLINT] Database auto-connected via .env');
    } catch (e) {
      print('[FLINT] ⚠️ Could not auto-connect to database: $e');
      // retry later if you want
      Future.delayed(const Duration(seconds: 10), _connectDatabaseInBackground);
    }
  }
}
