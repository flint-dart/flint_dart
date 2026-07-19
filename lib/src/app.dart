import 'dart:io';
import 'package:flint_dart/ai.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/mail.dart';
import 'package:flint_dart/middlewares.dart';
import 'package:flint_dart/model.dart';
import 'package:flint_dart/src/controller.dart' as controller_api;
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/database/migrations.dart';
import 'package:flint_dart/src/database/orm/global_table_registry.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/jobs/flint_job_models.dart';
import 'package:flint_dart/src/jobs/flint_jobs.dart';
import 'package:flint_dart/src/jobs/jobs_registry.dart';
import 'package:flint_dart/src/routing/route_builder.dart';
import 'package:flint_dart/src/routing/route_group.dart';
import 'package:flint_dart/schema.dart' as schema;

import 'context.dart';
import 'package:flint_dart/src/websocket/ws_manager_instance.dart';
import 'package:mime/mime.dart';
import 'request.dart';
import 'response.dart';
import 'routing/router.dart';
import 'websocket/websocket.dart'; // FlintWebSocket and wsManager
import 'websocket/ws_router.dart'; // WsRoute
import 'package:path/path.dart' as path;
import 'package:package_config/package_config.dart';

Future<String?> _getFlintDartLibPath() async {
  try {
    final packageConfig = await findPackageConfig(Directory.current);
    if (packageConfig == null) {
      return null;
    }

    final flintPackage = packageConfig['flint_dart'];
    if (flintPackage == null) {
      return null;
    }

    return path.join(
        flintPackage.root.toFilePath(windows: Platform.isWindows), 'lib');
  } catch (e) {
    Log.debug('[FLINT] Swagger package path resolution failed: $e');
    return null;
  }
}

class ControllerRouteBuilder<T extends controller_api.Controller> {
  final Flint _app;
  final controller_api.ControllerFactory<T> _factory;

  ControllerRouteBuilder(this._app, this._factory);

  RouteBuilder get(
    String path,
    controller_api.ControllerCallback<T> action,
  ) {
    return _app.get(path, controller_api.controller(_factory, action));
  }

  RouteBuilder post(
    String path,
    controller_api.ControllerCallback<T> action,
  ) {
    return _app.post(path, controller_api.controller(_factory, action));
  }

  RouteBuilder put(
    String path,
    controller_api.ControllerCallback<T> action,
  ) {
    return _app.put(path, controller_api.controller(_factory, action));
  }

  RouteBuilder patch(
    String path,
    controller_api.ControllerCallback<T> action,
  ) {
    return _app.patch(path, controller_api.controller(_factory, action));
  }

  RouteBuilder query(
    String path,
    controller_api.ControllerCallback<T> action,
  ) {
    return _app.query(path, controller_api.controller(_factory, action));
  }

  RouteBuilder delete(
    String path,
    controller_api.ControllerCallback<T> action,
  ) {
    return _app.delete(path, controller_api.controller(_factory, action));
  }

  RouteBuilder route(
    String method,
    String path,
    controller_api.ControllerCallback<T> action,
  ) {
    return _app.route(
        method, path, controller_api.controller(_factory, action));
  }

  void websocket(
    String path,
    void Function(T controller) action, {
    List<Middleware> middlewares = const [],
  }) {
    _app.websocket(
      path,
      controller_api.controllerVoid(_factory, action),
      middlewares: middlewares,
    );
  }
}

//  void _registerSwaggerDocs() async {
//    // Resolve flint_dart's lib path
//    final flintLibPath = await _getFlintDartLibPath();
//    final swaggerDir = Directory(path.join(flintLibPath, 'swagger', 'swagger-ui'));
//    Log.debug('[DEBUG] Swagger UI directory: ${swaggerDir.absolute.path}');

//    // Serve swagger.json from sample project
//    get('/swagger.json', (req, res) async {
//      final file = File(path.join(Directory.current.path, 'docs', 'swagger.json'));
//      Log.debug('[DEBUG] Checking for swagger.json at: ${file.absolute.path}');
//      if (await file.exists()) {
//        Log.debug('[DEBUG] swagger.json found');
//        final bytes = await file.readAsBytes();
//        res.raw.headers.contentType = ContentType.json;
//        await res.raw.addStream(Stream.fromIterable([bytes]));
//        await res.raw.close();
//      } else {
//        Log.debug('[DEBUG] swagger.json not found');
//        res.raw.statusCode = 404;
//        res.raw.write('swagger.json not found');
//        await res.raw.close();
//      }
//    });

//    // Check if swagger-ui directory exists
//    if (!await swaggerDir.exists()) {
//      Log.debug('[FLINT] ⚠️ Warning: Static directory not found: ${swaggerDir.absolute.path}');
//      return;
//    }

//    // Serve static Swagger UI files
//    static('/swagger-ui', swaggerDir.path);

//    // Serve /docs
//    get('/docs', (req, res) async {
//      final file = File(path.join(swaggerDir.path, 'index.html'));
//      Log.debug('[DEBUG] Checking for index.html at: ${file.absolute.path}');
//      if (await file.exists()) {
//        Log.debug('[DEBUG] index.html found');
//        final bytes = await file.readAsBytes();
//        res.raw.headers.contentType = ContentType.html;
//        await res.raw.addStream(Stream.fromIterable([bytes]));
//        await res.raw.close();
//      } else {
//        Log.debug('[DEBUG] index.html not found');
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
/// - WebSocket routing
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
  final bool autoConnectMail;
  final bool? autoMigrate;
  final bool autoMigrateDefault;
  final bool autoMigrateCreateDatabase;
  final bool autoMigrateDuringHotReload;
  final bool autoMigrateVerbose;
  final TableRegistry? tableRegistry;
  final JobsRegistry? jobsRegistry;
  final bool autoRegisterJobs;
  final bool includeJobTablesInMigrations;
  final FlintPageServerRenderer? _flintPageServerRenderer;
  final bool _serverRenderFlintPages;
  bool _jobSchedulesRegistered = false;

  /// Creates a new Flint application instance.
  ///
  /// [rootPath] is used for resolving hot reload entry points
  /// and mounted sub-apps.
  Flint(
      {this.rootPath = "lib",
      String? viewPath,
      FlintPageServerRenderer? flintPageServerRenderer,
      bool serverRenderFlintPages = false,
      this.autoConnectDb = true,
      this.autoConnectMail = true,
      this.autoMigrate,
      this.autoMigrateDefault = false,
      this.autoMigrateCreateDatabase = false,
      this.autoMigrateDuringHotReload = false,
      this.autoMigrateVerbose = false,
      this.tableRegistry,
      this.jobsRegistry,
      this.autoRegisterJobs = true,
      this.includeJobTablesInMigrations = true,
      this.withDefaultMiddleware = true,
      this.enableSwaggerDocs = false})
      : _flintPageServerRenderer = flintPageServerRenderer,
        _serverRenderFlintPages = serverRenderFlintPages {
    DB.setLazyAutoConnect(autoConnectDb);
    if (autoRegisterJobs) {
      jobsRegistry?.registerJobs();
    }
    Response.flintPageServerRenderer = flintPageServerRenderer;
    Response.flintPageServerRenderingEnabled = serverRenderFlintPages;

    if (withDefaultMiddleware) {
      _middlewares.add(ExceptionMiddleware());
      _middlewares.add(CookieSessionMiddleware());
      _middlewares.add(StaticFileMiddleware());
    } else {
      _middlewares.add(CookieSessionMiddleware());
    }
    if (enableSwaggerDocs) {
      _registerSwaggerDocs();
    }

    if (viewPath != null) {
      Flint.viewPath = viewPath;
    }
  }

  void _registerSwaggerDocs() async {
    // Always register swagger.json so apps can serve API spec even without UI assets.
    get('/swagger.json', (req, res) async {
      final candidates = <File>[
        File(path.join(Directory.current.path, 'docs', 'swagger.json')),
        File(path.join(Directory.current.path, 'swagger.json')),
      ];

      for (final file in candidates) {
        Log.debug(
            '[DEBUG] Checking for swagger.json at: ${file.absolute.path}');
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          res.raw.headers.contentType = ContentType.json;
          await res.raw.addStream(Stream.fromIterable([bytes]));
          await res.raw.close();
          return;
        }
      }

      res.raw.statusCode = 404;
      res.raw.write('swagger.json not found');
      await res.raw.close();
      return;
    });

    try {
      final swaggerDir = await _resolveSwaggerUiDir();
      if (swaggerDir == null) {
        Log.debug(
            '[FLINT] ⚠️ Warning: Swagger UI directory not found. /swagger.json remains available.');
        get('/docs', (req, res) async {
          res.raw.statusCode = 404;
          res.raw.write(
              'Swagger UI not found. Use /swagger.json or provide swagger-ui assets.');
          await res.raw.close();
          return;
        });
        return;
      }

      Log.debug('[DEBUG] Swagger UI directory: ${swaggerDir.absolute.path}');
      static('/swagger-ui', swaggerDir.path);

      get('/docs', (req, res) async {
        final file = File(path.join(swaggerDir.path, 'index.html'));
        if (await file.exists()) {
          var content = await file.readAsString();
          content = content.replaceAll('href="./', 'href="/swagger-ui/');
          content = content.replaceAll('src="./', 'src="/swagger-ui/');
          content = content.replaceAll(
              'href="index.css"', 'href="/swagger-ui/index.css"');

          res.raw.headers.contentType = ContentType.html;
          res.raw.write(content);
        } else {
          res.raw.statusCode = 404;
          res.raw.write('Swagger UI not found');
        }
        await res.raw.close();
        return;
      });
    } catch (e) {
      Log.debug(
          '[FLINT] ⚠️ Swagger docs bootstrap failed: $e. /swagger.json may still be available.');
    }
  }

  Future<Directory?> _resolveSwaggerUiDir() async {
    final candidates = <String>[];
    final explicitDir = Platform.environment['FLINT_SWAGGER_UI_DIR'];
    if (explicitDir != null && explicitDir.trim().isNotEmpty) {
      candidates.add(explicitDir.trim());
    }

    // Prefer project-local UI assets first (dev/build output).
    candidates.add(path.join(Directory.current.path, 'swagger-ui'));
    candidates.add(path.join(Directory.current.path, 'build', 'swagger-ui'));
    candidates.add(path.join(Directory.current.path, '..', 'swagger-ui'));
    candidates
        .add(path.join(Directory.current.path, 'lib', 'swagger', 'swagger-ui'));
    candidates.add(path.join(
        Directory.current.path, 'flint_dart', 'lib', 'swagger', 'swagger-ui'));
    candidates.add(path.join(Directory.current.path, '..', 'flint_dart', 'lib',
        'swagger', 'swagger-ui'));

    // Final fallback: framework-bundled assets from package cache.
    final flintLibPath = await _getFlintDartLibPath();
    if (flintLibPath != null) {
      candidates.add(path.join(flintLibPath, 'swagger', 'swagger-ui'));
    }

    for (final dirPath in candidates) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        return dir;
      }
    }
    return null;
  }

  final Router _router = Router();
  final List<Middleware> _middlewares = [];
  final FlintAi _ai = FlintAi(
    memoryStore: FlintAutoAiMemoryStore(),
    repository: FlintAutoAiRepository(),
  );

  bool _dbInitialized = false;

  /// Returns `true` if the database connection has been established.
  bool get isDatabaseConnected => _dbInitialized;

  FlintAi get ai => _ai;

  ControllerRouteBuilder<T> controller<T extends controller_api.Controller>(
    controller_api.ControllerFactory<T> factory,
  ) {
    return ControllerRouteBuilder<T>(this, factory);
  }

  // ===== HTTP ROUTES =====
  /// Registers a **GET** HTTP route on the application.
  ///
  /// This method maps an incoming HTTP GET request at the given [path]
  /// to the provided [handler]. The handler will be executed when a
  /// request with method `GET` matches the path.
  ///
  /// Internally, this creates a [RouteBuilder], registers the route
  /// with the application's router, and returns the builder for
  /// further configuration such as attaching middleware.
  ///
  /// ### Example
  /// ```dart
  /// app.get('/users', (req, res) async {
  ///   return res.json({'message': 'All users'});
  /// });
  /// ```
  ///
  /// ### Chaining middleware
  /// ```dart
  /// app.get('/profile', handler)
  ///    .use(AuthMiddleware());
  /// ```
  ///
  /// ### Parameters
  /// - [path]: The URL path to match (e.g. `/`, `/users`, `/posts/:id`)
  /// - [handler]: The function that handles the request
  ///
  /// ### Returns
  /// A [RouteBuilder] instance that can be used to attach
  /// route-specific middleware or additional configuration.
  RouteBuilder get(String path, Object handler) {
    final rb = RouteBuilder(_router, 'GET', path, _coerceHttpHandler(handler));
    rb.register();
    return rb;
  }

  /// Registers a **POST** HTTP route on the application.
  ///
  /// This method maps an incoming HTTP POST request at the given [path]
  /// to the provided [handler]. The handler is typically used to process
  /// request bodies such as form data or JSON payloads.
  ///
  /// Internally, this creates a [RouteBuilder], registers the route
  /// with the application's router, and returns the builder to allow
  /// further configuration such as attaching route-specific middleware.
  ///
  /// ### Example
  /// ```dart
  /// app.post('/users', (req, res) async {
  ///   final data = await req.json();
  ///   return res.json({
  ///     'success': true,
  ///     'user': data,
  ///   });
  /// });
  /// ```
  ///
  /// ### Chaining middleware
  /// ```dart
  /// app.post('/login', handler)
  ///    .use(ValidateBodyMiddleware())
  ///    .use(AuthMiddleware());
  /// ```
  ///
  /// ### Parameters
  /// - [path]: The URL path to match (e.g. `/users`, `/login`)
  /// - [handler]: The function that handles the incoming request
  ///
  /// ### Returns
  /// A [RouteBuilder] instance for attaching middleware or
  /// performing additional route configuration.
  RouteBuilder post(String path, Object handler) {
    final rb = RouteBuilder(_router, 'POST', path, _coerceHttpHandler(handler));
    rb.register();
    return rb;
  }

  /// Registers a **PUT** HTTP route on the application.
  ///
  /// This method maps an incoming HTTP PUT request at the given [path]
  /// to the provided [handler]. PUT requests are typically used to
  /// **update or replace** an existing resource.
  ///
  /// Internally, this creates a [RouteBuilder], registers the route
  /// with the application's router, and returns the builder to allow
  /// further configuration such as attaching route-specific middleware.
  ///
  /// ### Example
  /// ```dart
  /// app.put('/users/:id', (req, res) async {
  ///   final id = req.params['id'];
  ///   final data = await req.json();
  ///
  ///   return res.json({
  ///     'updated': true,
  ///     'id': id,
  ///     'data': data,
  ///   });
  /// });
  /// ```
  ///
  /// ### Chaining middleware
  /// ```dart
  /// app.put('/profile/:id', handler)
  ///    .use(AuthMiddleware());
  /// ```
  ///
  /// ### Parameters
  /// - [path]: The URL path to match (e.g. `/users/:id`)
  /// - [handler]: The function that handles the incoming request
  ///
  /// ### Returns
  /// A [RouteBuilder] instance for attaching middleware or
  /// performing additional route configuration.
  RouteBuilder put(String path, Object handler) {
    final rb = RouteBuilder(_router, 'PUT', path, _coerceHttpHandler(handler));
    rb.register();
    return rb;
  }

  /// Registers a **DELETE** HTTP route on the application.
  ///
  /// This method maps an incoming HTTP DELETE request at the given [path]
  /// to the provided [handler]. DELETE routes are typically used to
  /// **remove a resource** identified by the request path.
  ///
  /// Internally, this creates a [RouteBuilder], registers the route
  /// with the application's router, and returns the builder to allow
  /// further configuration such as attaching route-specific middleware.
  ///
  /// ### Example
  /// ```dart
  /// app.delete('/users/:id', (req, res) async {
  ///   final id = req.params['id'];
  ///
  ///   return res.json({
  ///     'deleted': true,
  ///     'id': id,
  ///   });
  /// });
  /// ```
  ///
  /// ### Chaining middleware
  /// ```dart
  /// app.delete('/posts/:id', handler)
  ///    .use(AuthMiddleware());
  /// ```
  ///
  /// ### Parameters
  /// - [path]: The URL path to match (e.g. `/users/:id`)
  /// - [handler]: The function that handles the incoming request
  ///
  /// ### Returns
  /// A [RouteBuilder] instance for attaching middleware or
  /// performing additional route configuration.
  RouteBuilder delete(String path, Object handler) {
    final rb =
        RouteBuilder(_router, 'DELETE', path, _coerceHttpHandler(handler));
    rb.register();
    return rb;
  }

  /// Registers a **PATCH** HTTP route on the application.
  ///
  /// This method maps an incoming HTTP PATCH request at the given [path]
  /// to the provided [handler]. PATCH routes are typically used to
  /// **partially update** an existing resource.
  ///
  /// Internally, this creates a [RouteBuilder], registers the route
  /// with the application's router, and returns the builder to allow
  /// further configuration such as attaching route-specific middleware.
  ///
  /// ### Example
  /// ```dart
  /// app.patch('/users/:id', (req, res) async {
  ///   final id = req.params['id'];
  ///   final updates = await req.json();
  ///
  ///   return res.json({
  ///     'patched': true,
  ///     'id': id,
  ///     'updates': updates,
  ///   });
  /// });
  /// ```
  ///
  /// ### Chaining middleware
  /// ```dart
  /// app.patch('/settings', handler)
  ///    .use(AuthMiddleware());
  /// ```
  ///
  /// ### Parameters
  /// - [path]: The URL path to match (e.g. `/users/:id`)
  /// - [handler]: The function that handles the incoming request
  ///
  /// ### Returns
  /// A [RouteBuilder] instance for attaching middleware or
  /// performing additional route configuration.
  RouteBuilder patch(String path, Object handler) {
    final rb =
        RouteBuilder(_router, 'PATCH', path, _coerceHttpHandler(handler));
    rb.register();
    return rb;
  }

  /// Registers a **QUERY** HTTP route on the application.
  ///
  /// QUERY requests are safe and idempotent like GET, but can carry request
  /// content like POST. This is useful for complex search/filter operations
  /// where the query expression belongs in the request body.
  RouteBuilder query(String path, Object handler) {
    final rb =
        RouteBuilder(_router, 'QUERY', path, _coerceHttpHandler(handler));
    rb.register();
    return rb;
  }

  /// Registers a route for a **custom HTTP method** on the application.
  ///
  /// This method allows you to define routes using HTTP methods that are
  /// not covered by the standard helpers (`get`, `post`, `put`, etc.),
  /// such as `OPTIONS`, `HEAD`, or any custom or extension method.
  ///
  /// Internally, this creates a [RouteBuilder], registers the route
  /// with the application's router, and returns the builder to allow
  /// further configuration such as attaching route-specific middleware.
  ///
  /// ### Example
  /// ```dart
  /// app.route('OPTIONS', '/users', (req, res) async {
  ///   res.raw.headers.add('Allow', 'GET, POST, PUT, DELETE');
  ///   return res.send('');
  /// });
  /// ```
  ///
  /// ### Chaining middleware
  /// ```dart
  /// app.route('HEAD', '/health', handler)
  ///    .use(AuthMiddleware());
  /// ```
  ///
  /// ### Parameters
  /// - [method]: The HTTP method to match (e.g. `OPTIONS`, `HEAD`)
  /// - [path]: The URL path to match
  /// - [handler]: The function that handles the incoming request
  ///
  /// ### Returns
  /// A [RouteBuilder] instance for attaching middleware or
  /// performing additional route configuration.
  RouteBuilder route(String method, String path, Object handler) {
    final rb = RouteBuilder(_router, method, path, _coerceHttpHandler(handler));
    rb.register();
    return rb;
  }
  // ===== WEBSOCKET ROUTES =====

  final List<WsRoute> _wsRoutes = [];

  /// Registers a WebSocket route.
  ///
  /// [path] is the WebSocket endpoint (e.g. `/chat`).
  /// [handler] is the callback for connected clients and receives
  /// the [Request] built from the upgrade handshake.
  void websocket(
    String path,
    Object handler, {
    List<Middleware> middlewares = const [],
  }) {
    _wsRoutes.add(
      WsRoute(path, _coerceWebSocketHandler(handler), middlewares),
    );
  }

  // ===== STATIC FILES =====

  /// Serves static files from [directoryPath] at [urlPrefix].
  ///
  /// Example:
  /// ```dart
  /// app.static('/public', 'public');
  /// ```
  void static(String urlPrefix, String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      Log.debug(
          '[FLINT] ⚠️ Warning: Static directory not found: $directoryPath');
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

  /// Adds a global [middleware] to the application.
  ///
  /// Middlewares registered with this method are executed for **every
  /// incoming HTTP request**, in the exact order they are added.
  /// Each middleware can inspect, modify, or short-circuit the request
  /// and response lifecycle.
  ///
  /// Middlewares are typically used for:
  /// - Authentication and authorization
  /// - Logging and request tracing
  /// - Error handling
  /// - Request/response transformation
  ///
  /// ### Execution order
  /// ```
  /// Global middlewares (registered via use())
  /// → RouteGroup middlewares
  /// → Route-specific middlewares
  /// → Route handler
  /// ```
  ///
  /// ### Example
  /// ```dart
  /// app.use(LoggerMiddleware());
  /// app.use(AuthMiddleware());
  /// ```
  ///
  /// ### Notes
  /// - Middleware order matters; earlier middlewares wrap later ones.
  /// - Use route-specific middleware when logic should not apply globally.
  ///
  /// ### Parameters
  /// - [middleware]: The middleware to register globally.
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

    // Normalize prefix: ensure it starts with "/" and remove trailing slash
    String cleanPrefix = prefix;
    if (!cleanPrefix.startsWith('/')) {
      cleanPrefix = '/$cleanPrefix';
    }
    if (cleanPrefix != '/' && cleanPrefix.endsWith('/')) {
      cleanPrefix = cleanPrefix.substring(0, cleanPrefix.length - 1);
    }

    for (final route in subApp._router.routes) {
      // Normalize route path
      String cleanPath = route.path;

      // Fix missing leading slash
      if (!cleanPath.startsWith('/')) {
        cleanPath = '/$cleanPath';
      }

      // Remove duplicate "/" when combining
      final fullPath = cleanPath == '/'
          ? cleanPrefix
          : cleanPrefix == '/'
              ? cleanPath
              : '$cleanPrefix$cleanPath';

      // Merge middlewares
      final allMiddleware = [...middlewares, ...route.middlewares];

      final handlerWithMiddlewares = allMiddleware.fold<Handler>(
        route.handler,
        (prev, middleware) => middleware.handle(prev),
      );

      _router.add(
        route.method,
        fullPath,
        handlerWithMiddlewares,
      );
    }

    // Normalize websocket paths too
    for (final wsRoute in subApp._wsRoutes) {
      String cleanWsPath = wsRoute.path;

      if (!cleanWsPath.startsWith('/')) {
        cleanWsPath = '/$cleanWsPath';
      }

      final fullWsPath =
          cleanPrefix == '/' ? cleanWsPath : '$cleanPrefix$cleanWsPath';

      _wsRoutes.add(
        WsRoute(fullWsPath, wsRoute.handler, wsRoute.middlewares),
      );
    }
  }

  /// Registers a [RouteGroup] and its optional child groups into the Flint app.
  ///
  /// This method allows you to organize routes into hierarchical, reusable groups
  /// with automatic URL prefixing and middleware composition. It supports **nested
  /// route groups**, making it easy to build modular and maintainable applications.
  ///
  /// ### How it works
  /// 1. If the parent [group] has an empty prefix (`''`), its routes are registered
  ///    directly on the current app instance.
  /// 2. Child groups (if any) are recursively registered at the same level.
  /// 3. If the parent [group] has a prefix, it is mounted using [Flint.mount].
  ///    - Parent routes are registered inside the mounted sub-app.
  ///    - Child groups are recursively registered inside the sub-app.
  /// 4. Middlewares defined on the parent [group] are applied to all its routes
  ///    and automatically inherited by child groups.
  ///
  /// ### Example: Simple registration
  /// ```dart
  /// app.routes(ApiRoute());
  /// ```
  ///
  /// ### Example: Nested route groups
  /// ```dart
  /// app.routes(
  ///   ApiRoute(),
  ///   children: [
  ///     SchoolRoutes(),
  ///     AIRoutes(),
  ///   ],
  /// );
  /// ```
  ///
  /// This automatically composes prefixes and middleware:
  /// - `/api` -> ApiRoute
  /// - `/api/schools` -> SchoolRoutes
  /// - `/api/ai` -> AIRoutes
  ///
  /// ### Middleware order
  /// ```
// — Global middlewares
// — Parent RouteGroup middlewares
// — Child RouteGroup middlewares
// — Route-specific middlewares
  /// ```
  ///
  /// ### Parameters
  /// - [group]: The [RouteGroup] to register. Can define a prefix and middlewares.
  /// - [children]: Optional list of [RouteGroup] instances nested inside [group].
  ///
  /// ### Notes
  /// - Child groups inherit the parent group's prefix and middleware.
  /// - Supports deep nesting of route groups for modular API design.
  /// - Recommended for organizing large applications with multiple logical route sections.
  void routes(
    RouteGroup group, {
    List<RouteGroup> children = const [],
  }) {
    // Normalize prefix: empty string or "/" is treated the same
    String cleanPrefix = group.prefix.isEmpty ? '/' : group.prefix;

    mount(
      cleanPrefix,
      (subApp) {
        // Register this group's routes in the sub-app
        group.register(subApp);

        // Recursively register child groups in the sub-app
        for (final child in children) {
          subApp.routes(child);
        }
      },
      middlewares: group.middlewares,
    );
  }

  void _registerFlintTemReload() {
    websocket('/flint_reload', (Request req, FlintWebSocket client) {
      // client.onClose(() {
      //   connectedClients.remove(client.id);
      //   Log.debug('[FLINT] Client disconnected: ${client.id}');
      // });
    });
  }

  void _registerHotReloadEndpoint() {
    // Endpoint for hot reload process to notify about template changes
    post('/_flint/internal/hot-reload', (req, res) async {
      try {
        final body = await req.json();
        final templateName = body['template'] as String?;
        final htmlContent = body['html']?.toString() ?? '';
        final source = body['source']?.toString();
        final event = body['event']?.toString() ?? 'flint:reload';
        final message = body['message']?.toString();

        if (templateName == null) {
          return res.status(400).json(
              {'success': false, 'error': 'Missing template in request body'});
        }

        // Emit to all WebSocket clients in THIS process
        wsManager.emitToAll(event, {
          'template': templateName,
          'html': htmlContent,
          if (message != null) 'message': message,
        });

        return res.json({
          'success': true,
          'message': 'Hot reload event sent',
          'source': source,
          'clients': wsManager.clients.length,
          'timestamp': DateTime.now().toIso8601String()
        });
      } catch (e) {
        return res
            .status(500)
            .json({'success': false, 'error': 'Internal server error: $e'});
      }
    });
  }

  /// Starts the HTTP & WebSocket server.
  ///
  /// - Attempts to auto-connect to the database via `.env` unless already connected.
  /// - Runs with hot reload during development unless hotReload is set to true in listen.
  /// - Handles both HTTP and WebSocket upgrade requests.
  ///
  /// If [port] is not provided, it will use `env('PORT', 3001)`.
  Future<void> listen({int? port, bool hotReload = true}) async {
    final resolvedPort = port ?? (env('PORT', 3001) as int);
    final hotFlag = env('FLINT_HOT', '').toString().toLowerCase().trim();
    final hotReloadDisabled = hotFlag == '0' || hotFlag == 'false';
    final isHotReloadWorker = hotFlag == '1';
    final shouldUseHotReload = hotReload && !hotReloadDisabled;

    // 1. Register hot reload websocket route if enabled
    if (shouldUseHotReload) {
      _registerFlintTemReload();
      _registerHotReloadEndpoint();
    }

    // 2. THE LAUNCHER CHECK
    // If we are in the Parent Process, start the watcher and STOP here.
    if (shouldUseHotReload && !isHotReloadWorker) {
      await _startHotReloadLauncher(resolvedPort);
      return; // CRITICAL: Parent process returns here and never runs the server.
    }

    // 3. THE ACTUAL SERVER (Worker Process)
    // If we reach here, we are either in the child process or hot reload is off.
    await _runServer(resolvedPort);
  }

  /// Handles the Process forking for hot reload
  Future<void> _startHotReloadLauncher(int port) async {
    final debugVmService =
        Platform.environment['FLINT_DEBUG_VM_SERVICE']?.toLowerCase().trim();
    final enableVmService = debugVmService == '1' ||
        debugVmService == 'true' ||
        debugVmService == 'yes';

    final child = await Process.start(
      'dart',
      [
        if (enableVmService) '--enable-vm-service',
        'run',
        'flint_dart:hot_reload',
        rootPath,
        '--port=$port'
      ],
      environment: {'FLINT_HOT': '1'},
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );

    ProcessSignal.sigint.watch().listen((_) async {
      Log.debug('\n[FLINT] Shutting down launcher and child...');
      child.kill(ProcessSignal.sigint);
      await child.exitCode;
      exit(0);
    });
  }

  /// Binds the server and starts the request loop
  Future<void> _runServer(int port) async {
    HttpServer? server;
    try {
      await _ensureMigrationsIfEnabled();
      await _registerJobSchedulesIfConfigured();
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      Log.debug(
          '[FLINT] Server Worker running on http://localhost:$port (PID: $pid)');

      if (autoConnectDb) _connectDatabaseInBackground();
      if (autoConnectMail) MailConfig.load();
    } on SocketException catch (e) {
      Log.debug('[FLINT] ❌ ERROR: Could not bind to port $port: ${e.message}');
      exit(1);
    }

    // Handle graceful shutdown for the worker process
    ProcessSignal.sigint.watch().listen((_) async {
      Log.debug('\n[FLINT] Worker shutting down...');
      await server?.close(force: true);
      exit(0);
    });

    await for (var req in server) {
      _handleIncomingRequest(req);
    }
  }

  Future<void> _ensureMigrationsIfEnabled() async {
    final enabled = autoMigrate ??
        FlintMigrations.enabledFromEnv(
            'FLINT_AUTO_MIGRATE', autoMigrateDefault);
    if (!enabled) return;

    final hotFlag = env('FLINT_HOT', '').toString().toLowerCase().trim();
    final isHotReloadWorker = hotFlag == '1';
    if (isHotReloadWorker && !autoMigrateDuringHotReload) {
      Log.debug('[FLINT] Auto migration skipped during hot reload worker.');
      return;
    }

    await FlintMigrations.ensure(
      enabled: true,
      createDatabase:
          autoMigrateCreateDatabase || FlintMigrations.createDatabaseFromEnv(),
      verbose: autoMigrateVerbose || FlintMigrations.verboseFromEnv(),
      tables: _migrationTables(),
    );
  }

  Future<void> _registerJobSchedulesIfConfigured() async {
    if (_jobSchedulesRegistered) return;
    final registry = jobsRegistry;
    if (registry == null) return;
    await registry.registerSchedules();
    _jobSchedulesRegistered = true;
  }

  /// Runs this app's configured migrations before `listen()`.
  ///
  /// This uses [tableRegistry] and automatically adds Flint job tables when
  /// [jobsRegistry] is configured. Calling this is useful when the app needs
  /// database tables before registering routes or running bootstraps.
  Future<void> ensureMigrations() async {
    await _ensureMigrationsIfEnabled();
    await _registerJobSchedulesIfConfigured();
  }

  Future<void> startJobs({
    String queue = 'default',
    int limit = 20,
    int scheduleLimit = 100,
    String? workerId,
    Duration pollInterval = const Duration(minutes: 1),
    Duration staleRunningAfter = const Duration(minutes: 15),
    bool runImmediately = true,
  }) async {
    await _registerJobSchedulesIfConfigured();
    FlintJobs.startRuntime(
      queue: queue,
      limit: limit,
      scheduleLimit: scheduleLimit,
      workerId: workerId,
      pollInterval: pollInterval,
      staleRunningAfter: staleRunningAfter,
      runImmediately: runImmediately,
    );
  }

  void stopJobs() {
    FlintJobs.stopRuntime();
  }

  List<schema.Table>? _migrationTables() {
    final tables = <schema.Table>[];
    final tableRegistryTables = tableRegistry?.tables;
    if (tableRegistryTables != null) {
      tables.addAll(tableRegistryTables);
    }

    if (includeJobTablesInMigrations && jobsRegistry != null) {
      final names = tables.map((table) => table.name).toSet();
      for (final table in flintJobTables()) {
        if (names.add(table.name)) {
          tables.add(table);
        }
      }
    }

    return tables.isEmpty ? null : tables;
  }

  /// Dispatches requests to WebSockets or HTTP Routes
  Future<void> _handleIncomingRequest(HttpRequest req) async {
    // ===== WebSocket check =====
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      await _handleWebSocketUpgrade(req);
      return;
    }

    // ===== HTTP Request handling =====
    final request = Request(req);
    final response = Response(
      req.response,
      request: request,
      flintPageServerRenderer: _flintPageServerRenderer,
      serverRenderFlintPages: _serverRenderFlintPages,
    );

    final normalizedPath = normalizePath(request.path);

    final handler =
        _router.match(request.method, normalizedPath, request.params);

    final pipeline = _middlewares.fold<Handler>(
      handler ??
          ((ctx) async {
            final res = ctx.res;
            if (res == null) return null;
            return res.send('404 Not Found', status: 404);
          }),
      (prev, middleware) => middleware.handle(prev),
    );

    final ctx = Context(req: request, res: response);
    ctx.write<FlintAi>(_ai);

    try {
      final result = await pipeline(ctx);
      if (!response.isClosed && result != null) {
        await _applyHandlerResult(result, response);
      }
      if (!response.isClosed) {
        await response.close();
      }
    } catch (e, st) {
      if (!response.isClosed) {
        try {
          response.raw.statusCode = HttpStatus.internalServerError;
          response.raw.write('Internal Server Error: $e');
        } on StateError {
          // Headers were already sent; best effort is to close the response.
        }
        try {
          await response.close();
        } on StateError {
          // Underlying response was already closed externally.
        }
      }
      Log.debug('[FLINT] ❌ Handler error: $e\n$st');
    }
  }

  /// Handles a single request through the full Flint pipeline.
  /// Intended for testing and internal tooling.
  Future<void> handleRequest(HttpRequest req) async {
    await _handleIncomingRequest(req);
  }

  String normalizePath(String path) {
    // Collapse multiple slashes: /// → /
    path = path.replaceAll(RegExp(r'/+'), '/');

    // Remove trailing slash (except root)
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return path;
  }

  /// Specialized handler for WebSocket Upgrades
  Future<void> _handleWebSocketUpgrade(HttpRequest req) async {
    bool matched = false;

    for (final route in _wsRoutes) {
      final params = route.match(req.uri.path);
      if (params != null) {
        matched = true;

        final wsRequest = Request(req, params: params);

        final socket = await WebSocketTransformer.upgrade(req);
        final clientId = DateTime.now().microsecondsSinceEpoch.toString();
        final namespace = normalizePath(req.uri.path);

        // This is now guaranteed to be in the same process as the server
        final client = FlintWebSocket(socket, clientId, namespace: namespace);

        final handlerWithRouteMiddleware = route.middlewares.fold<Handler>(
          route.handler,
          (prev, middleware) => middleware.handle(prev),
        );

        final pipeline = _middlewares.fold<Handler>(
          handlerWithRouteMiddleware,
          (prev, middleware) => middleware.handle(prev),
        );

        try {
          final ctx = Context(req: wsRequest, socket: client);
          ctx.write<FlintAi>(_ai);
          await pipeline(ctx);
        } catch (e, st) {
          Log.debug('[FLINT] ❌ WebSocket handler error: $e\n$st');
        }
        return;
      }
    }

    if (!matched) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  }

  Future<void> _connectDatabaseInBackground() async {
    try {
      await DB.autoConnect();
      _dbInitialized = true;
      Log.debug('[FLINT] Database auto-connected via .env');
    } catch (e) {
      Log.debug(
        '[FLINT] Database auto-connect failed: $e\n'
        '[FLINT] Tip: set autoConnectDb: false and call DB.connect(...) inside try/catch.',
      );
      Future.delayed(const Duration(seconds: 10), _connectDatabaseInBackground);
    }
  }

  Future<void> _applyHandlerResult(Object result, Response res) async {
    if (result is Response) return;
    if (result is Model || _hasToMapOrToJson(result)) {
      await res.json(result);
      return;
    }
    await res.respond(result);
  }

  bool _hasToMapOrToJson(Object value) {
    try {
      final dynamic dyn = value;
      final toMapMethod = dyn.toMap;
      if (toMapMethod is Function) return true;
      final toJsonMethod = dyn.toJson;
      if (toJsonMethod is Function) return true;
    } catch (_) {}
    return false;
  }

  Handler _coerceHttpHandler(Object handler) {
    if (handler is Handler) return handler;
    if (handler is LegacyHandler) return adaptHttp(handler);
    if (handler is Function) {
      return (ctx) async {
        final res = ctx.res;
        if (res == null) return null;
        final result = Function.apply(handler, [ctx.req, res]);
        if (result is Future) {
          return await result;
        }
        return result;
      };
    }
    throw ArgumentError(
      'HTTP handler must be a Handler or LegacyHandler',
    );
  }

  Handler _coerceWebSocketHandler(Object handler) {
    if (handler is Handler) return handler;
    if (handler is WsHandler) return adaptWebSocket(handler);
    throw ArgumentError(
      'WebSocket handler must be a Handler or WsHandler',
    );
  }
}
