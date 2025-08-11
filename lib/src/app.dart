import 'dart:io';

import 'package:flint_dart/src/database/connection.dart';
import 'package:mime/mime.dart';

import 'middleware.dart';
import 'request.dart';
import 'response.dart';
import 'router.dart';

/// The core application class for the Flint Dart framework.
///
/// Use [Flint] to define routes, mount sub-apps, register middlewares,
/// and start the HTTP server.
///
/// Example usage:
/// ```dart
/// final app = Flint();
///
/// app.get('/', (req, res) async {
///   res.send('Hello, world!');
/// });
///
/// await app.listen(3000);
/// ```
class Flint {
  /// The root path of the app, typically where your entry file (`bin/main.dart`) is located.
  ///
  /// This is used internally to assist with hot reload and runtime configuration.
  final String rootPath;

  /// Creates a new instance of [Flint].
  ///
  /// The optional [rootPath] defaults to `'lib'` and is mainly for internal hot reload behavior.
  Flint({this.rootPath = "lib"});

  final Router _router = Router();
  final List<Middleware> _middlewares = [];
  bool _dbInitialized = false;

  /// Whether the database connection was initialized.
  ///
  /// Used to warn if the developer forgets to initialize the database.
  bool get isDatabaseConnected => _dbInitialized;

  /// Register a route handler for `GET` requests.
  void get(String path, Handler handler) => _router.add('GET', path, handler);

  /// Register a route handler for `POST` requests.
  void post(String path, Handler handler) => _router.add('POST', path, handler);

  /// Register a route handler for `PUT` requests.
  void put(String path, Handler handler) => _router.add('PUT', path, handler);

  /// Register a route handler for `PATCH` requests.
  void patch(String path, Handler handler) =>
      _router.add('PATCH', path, handler);

  /// Register a route handler for `DELETE` requests.
  void delete(String path, Handler handler) =>
      _router.add('DELETE', path, handler);

  // Inside your App class
// ... existing methods ...

  /// Serves static files from a [directoryPath] at a given [urlPrefix].
  ///
  /// This is used to make files in a local directory (e.g., 'public/assets')
  /// accessible via a URL path (e.g., '/assets').
  void static(String urlPrefix, String directoryPath) {
    // Ensure the directory exists to avoid runtime errors.
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      print('[FLINT] ⚠️ Warning: Static directory not found: $directoryPath');
      return;
    }

    // Register a GET route for all paths under the prefix.
    _router.add('GET', '$urlPrefix/*', (req, res) async {
      // Get the path of the file requested by the client.
      final filePath = req.path.substring(urlPrefix.length);
      final file = File('$directoryPath$filePath');

      if (await file.exists()) {
        // Set the content type based on the file extension.
        final mimeType = lookupMimeType(file.path);
        if (mimeType != null) {
          res.raw.headers.contentType = ContentType.parse(mimeType);
        }

        // Stream the file's contents to the response.
        await res.streamFile(file);
      } else {
        // If the file doesn't exist, send a 404 Not Found response.
        res.status(404).send('Not Found');
      }
    });
  }

  /// Register a route handler with a custom HTTP [method].
  void route(String method, String path, Handler handler) =>
      _router.add(method.toUpperCase(), path, handler);

  /// Register a global [middleware] to apply to all routes.
  ///
  /// Middleware can be used to handle logging, authentication, etc.
  void use(Middleware middleware) => _middlewares.add(middleware);

  /// Mounts a sub-application under the given [prefix].
  ///
  /// This is useful for organizing your app into modules.
  ///
  /// Example:
  /// ```dart
  /// app.mount('/api', (api) {
  ///   api.get('/users', getUsersHandler);
  /// });
  /// ```
  void mount(String prefix, void Function(Flint subApp) callback,
      {List<Middleware> middlewares = const []}) {
    final subApp = Flint(rootPath: rootPath);
    callback(subApp);

    for (final route in subApp._router.routes) {
      // Chain route.handler through the provided middlewares
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
  }

  /// Starts the HTTP server on the given [port].
  ///
  /// If hot reload is not enabled, it automatically spawns a hot reload
  /// process using the `flintdart:hot_reload` entry point.
  ///
  /// Logs a warning if the database has not been initialized.
  ///
  /// Example:
  /// ```dart
  /// await app.listen(8080);
  /// ```
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

    // Spawn hot reload child process
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

      return; // Parent process stops here
    }

    HttpServer? server;

    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Server running on http://localhost:$port');
    } on SocketException catch (e) {
      print('[FLINT] ❌ ERROR: Could not bind to port $port. Is it in use?');
      print('[FLINT] 🔎 Details: ${e.message}');
      await Future.delayed(
          const Duration(seconds: 1)); // Give a moment before exit
      exit(1); // Exi
    }

    // Handle Ctrl+C directly on the server process
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n[FLINT] Server shutting down...');
      await server?.close(force: true);
      exit(0);
    });

    await for (var req in server) {
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
