# Getting Started

This guide describes the framework implemented in this repository. The core package is `flint_dart`, with the server entry point in `lib/src/app.dart`, public exports in `lib/flint_dart.dart`, and runnable examples in `example/lib`.

## Minimal App

`Flint` is the application object. It owns the HTTP router, WebSocket route list, middleware stack, optional database bootstrapping, optional mail bootstrapping, and optional Swagger routes.

```dart
import 'package:flint_dart/flint_dart.dart';

void main(List<String> args) {
  final app = Flint(
    autoConnectDb: false,
    enableSwaggerDocs: true,
  );

  app.get('/', (Request req, Response res) {
    return res.json({'message': 'Hello Flint'});
  });

  app.listen(port: 3000, hotReload: true);
}
```

`example/lib/main.dart` uses this shape. It creates `Flint(withDefaultMiddleware: true, enableSwaggerDocs: true, autoConnectDb: false, viewPath: 'lib/views')`, adds `LoggerMiddleware`, serves Flint UI assets with `app.static('/web', 'flint_ui/web')`, registers `RouteGroup` classes, and calls `app.listen(...)`.

## What Happens Internally

When `listen()` runs:

1. It resolves the port from the argument or `PORT`, defaulting to `3001` in `Flint.listen`.
2. Unless disabled, hot reload starts a launcher process using `dart run flint_dart:hot_reload`.
3. The worker process runs `_runServer`, optionally runs migrations and seeders, binds `HttpServer` on `InternetAddress.anyIPv4`, and starts reading requests.
4. Each HTTP request is wrapped in `Request` and `Response`.
5. `Router.match()` finds the route and fills `req.params`.
6. Global middleware is folded around the matched route handler.
7. Returned `Model`, `toMap()`, or `toJson()` values are serialized with `res.json`; other values go through `res.respond`.

## Default Middleware

By default, `Flint` adds:

```dart
ExceptionMiddleware()
CookieSessionMiddleware()
StaticFileMiddleware()
```

If `withDefaultMiddleware: false`, `CookieSessionMiddleware` is still added by the constructor. This matters because `CookieService` and `SessionService` are initialized there for HTTP requests.

## Running Commands

The CLI executable is registered in `pubspec.yaml`:

```yaml
executables:
 flint: flint_dart
 hot_reload: hot_reload
```

Use the package commands from an app/package root:

```bash
dart run flint_dart:flint run --port=3000
dart run flint_dart:flint docs:generate
dart run flint_dart:flint migrate --no-interaction
```

The command registry is in `lib/src/cli/commands.dart`.

## Important Limits

- `Flint.listen()` uses hot reload by default. Set `hotReload: false` or `FLINT_HOT=0` when you want a single process.
- Database auto-connect defaults to `true`; examples often use `autoConnectDb: false` so routes can run without a configured database.
- Static file middleware only serves from `public` by default. `app.static('/web', 'flint_ui/web')` is a separate route registration.
- The repository contains multiple sibling projects; this documentation targets the `flint/flint_dart` framework package.
