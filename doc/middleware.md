# Middleware

Middleware is Flint's request pipeline layer. Use it for behavior that should
wrap a route instead of living inside one controller action: authentication,
authorization, tenant lookup, CORS, logging, cache headers, upload guards,
security checks, and exception handling.

Before coding middleware in an app, inspect:

- `lib/main.dart` for global `app.use(...)` calls.
- `lib/routes/` for route groups and `.useMiddleware(...)`.
- `lib/middlewares/` for app-specific middleware.
- `docs/authentication.md` when the middleware checks users, roles, tokens, OTP flows, or sessions.
- `docs/routing.md` when the middleware is attached to `RouteGroup` or `app.controller(...)` routes.
- `docs/websockets.md` when the middleware can run for WebSocket routes.

Framework source to inspect when behavior is unclear:

- `lib/src/middleware/middleware.dart`
- `lib/src/app.dart`
- `lib/src/routing/route_builder.dart`
- `lib/src/routing/route_group.dart`
- `lib/src/routing/router.dart`
- `lib/src/websocket/ws_router.dart`
- `lib/middlewares.dart`

## Core Shape

Middleware is implemented by `lib/src/middleware/middleware.dart`:

```dart
abstract class Middleware {
  Handler handle(Handler next);
}
```

`Handler` is the unified HTTP and WebSocket signature:

```dart
typedef Handler = FutureOr<Object?> Function(Context ctx);
```

That means middleware receives the same `Context` that route handlers and
controllers receive.

- `ctx.req` is always available.
- `ctx.res` is available for HTTP requests.
- `ctx.socket` is available for WebSocket connections.
- `ctx.isHttp` and `ctx.isWebSocket` tell you which kind of request is running.
- `ctx.write<T>(value)` stores typed request data for later middleware, routes, or controllers.
- `ctx.read<T>()` reads typed request data that was stored earlier.

`Response` methods are instance methods. Get the response from `ctx.res` or a
controller's bound `res`, then call `res.send(...)`, `res.json(...)`,
`res.status(...).json(...)`, `res.redirect(...)`, and similar helpers.

## One Middleware Per File

Keep each middleware class in its own file:

```text
lib/middlewares/
  auth_middleware.dart
  role_middleware.dart
  api_key_middleware.dart
  tenant_middleware.dart
```

Do not stack unrelated middleware classes in one file. Do not hide meaningful
middleware behavior inside private helper methods.
If a guard, parser, role check, or reusable helper becomes important enough to
name, put it in a standalone file so the next developer can find it.

## Writing Middleware

Every middleware returns a new handler. That handler decides whether to:

- continue the pipeline with `return await next(ctx);`
- stop the pipeline by returning a response
- write data into `Context` for later code
- run code before and after `next(ctx)`

Pass-through middleware:

```dart
import 'package:flint_dart/flint_dart.dart';

class RequestLogMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      Log.debug('[${ctx.req.method}] ${ctx.req.path}');
      return await next(ctx);
    };
  }
}
```

Auth middleware:

```dart
import 'package:flint_dart/flint_dart.dart';

class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) {
        return await next(ctx);
      }

      final user = await ctx.req.user;
      if (user == null) {
        return await res.status(401).json({
          'status': false,
          'message': 'Unauthorized',
        });
      }

      ctx.write<Map<String, dynamic>>(user);
      return await next(ctx);
    };
  }
}
```

Later, a controller can read the authenticated user:

```dart
class ProfileController extends Controller {
  Future<Response> show() async {
    final user = read<Map<String, dynamic>>();
    return res.json({'user': user});
  }
}
```

API key middleware:

```dart
import 'package:flint_dart/flint_dart.dart';

class ApiKeyMiddleware extends Middleware {
  ApiKeyMiddleware(this.expectedKey);

  final String expectedKey;

  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) {
        return await next(ctx);
      }

      final key = ctx.req.headers['x-api-key'];
      if (key != expectedKey) {
        return await res.status(401).json({
          'status': false,
          'message': 'Missing or invalid API key',
        });
      }

      return await next(ctx);
    };
  }
}
```

## Attaching Middleware

Global middleware runs for all HTTP requests and WebSocket routes:

```dart
final app = Flint();

app.use(CorsMiddleware());
app.use(LoggerMiddleware());
app.use(SecurityMiddleware());
```

Route middleware is attached with `.useMiddleware(...)`:

```dart
app
    .get('/profile', (Context ctx) {
      return ctx.res?.json({'message': 'Profile'});
    })
    .useMiddleware(AuthMiddleware());
```

Route group middleware belongs on the `RouteGroup`:

```dart
class AdminRoutes extends RouteGroup {
  @override
  String get prefix => '/admin';

  @override
  List<Middleware> get middlewares => [
        AuthMiddleware(),
        RoleMiddleware('admin'),
      ];

  @override
  void register(Flint app) {
    final dashboard = app.controller(AdminDashboardController.new);
    dashboard.get('/dashboard', (controller) => controller.index());
  }
}
```

WebSocket routes can receive middleware through the `middlewares` argument:

```dart
app.websocket(
  '/chat',
  (Context ctx) {
    final socket = ctx.socket;
    if (socket == null) return;

    socket.on('message', (data) {
      socket.emitToAll('message', data);
    });
  },
  middlewares: [ChatSocketAuthMiddleware()],
);
```

## Middleware Order

Flint composes middleware as wrappers around the route handler. In the current
implementation, a middleware list behaves like a stack: the last middleware in
the list runs first on the way in, then completes last on the way out.

```dart
middlewares: [
  FirstMiddleware(),
  SecondMiddleware(),
]
```

Execution order:

```text
SecondMiddleware before next
FirstMiddleware before next
route handler
FirstMiddleware after next
SecondMiddleware after next
```

Global middleware wraps the matched route pipeline, so a global middleware sees
the request before route or group middleware. Within each list, remember that
the last item is the outermost wrapper.

## HTTP And WebSocket Safety

Global middleware can run for HTTP and WebSocket contexts. If middleware only
knows how to work with HTTP responses, pass WebSocket contexts through:

```dart
final res = ctx.res;
if (res == null) {
  return await next(ctx);
}
```

For WebSocket-specific auth, use `ctx.socket` and stop before registering route
listeners if the client is not allowed:

```dart
import 'package:flint_dart/flint_dart.dart';

class ChatSocketAuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final socket = ctx.socket;
      if (socket == null) {
        return await next(ctx);
      }

      final token = ctx.req.query['token'];
      if (token == null || token.isEmpty) {
        socket.emit('auth:error', {
          'message': 'Missing socket token',
        });
        await socket.close();
        return null;
      }

      return await next(ctx);
    };
  }
}
```

When a route must reject before the WebSocket upgrade happens, do that with an
HTTP auth route or token issuing flow before the client connects.

## Built-In Middleware

The export file `lib/middlewares.dart` exposes:

- `ExceptionMiddleware`
- `CookieSessionMiddleware`
- `StaticFileMiddleware`
- `CorsMiddleware`
- `LoggerMiddleware`
- `CacheMiddleware`
- `ETagMiddleware`
- `AntiSqlInjectionMiddleware`
- `RichTextUpload`
- `SecurityMiddleware`

`Flint` installs `ExceptionMiddleware`, `CookieSessionMiddleware`, and
`StaticFileMiddleware` by default. If `withDefaultMiddleware: false`,
`CookieSessionMiddleware` is still installed so cookies and sessions can be
initialized for HTTP requests.

`LoggerMiddleware` is not installed by default. Add it explicitly when the app
needs request logs, and read `docs/logging.md` before changing what request
data gets logged.

## Exception Middleware

`ExceptionMiddleware` catches known exceptions and converts them to JSON
responses when `ctx.res` exists.

`ValidationException` returns the exception status code, usually `422`:

```json
{"status": false, "errors": {"field": ["message"]}}
```

`AuthException` returns `401`:

```json
{"status": false, "error": "Unauthorized", "message": "..."}
```

`BaseException` uses the exception's `code`. Format, timeout, argument, and
database exceptions become JSON error payloads when the route is HTTP. If the
context is WebSocket-only, known exceptions are rethrown and logged by the
WebSocket handler layer.

Database column-check errors containing `unknown column`, `does not exist`, or
`42703` are treated specially and may retry `next(ctx)`. Keep this in mind if a
handler appears to run more than once during schema checks.

## Cookie And Session Middleware

`CookieSessionMiddleware` initializes cookies and sessions for HTTP requests:

```dart
CookieService.init(ctx.req, res);
SessionService.init(ctx.req, res);
```

It checks `ctx.res` first. WebSocket contexts pass through without cookie or
session initialization, but the WebSocket handshake `Request` can still read
headers, query parameters, and cookies that were present during upgrade.

Read `docs/sessions-and-cookies.md` before changing session drivers, auth
cookies, flash messages, `CookieService`, or `SessionService`.

## Static Files

`StaticFileMiddleware` serves files from `public` for `GET` and `HEAD`.
It skips known dynamic prefixes such as `/api`, `/ws`, `/docs`, `/swagger`,
`/.well-known`, `/admin`, `/graphql`, and `/graphiql`.

It supports:

- `/` fallback to `public/index.html`
- MIME detection
- `ETag` and `Last-Modified`
- single byte range requests
- gzip compression
- precompressed `.gz` and `.br` files
- security headers such as `X-Content-Type-Options`, `X-Frame-Options`, and `Referrer-Policy`
- immutable cache headers for fingerprinted or query-versioned assets
- no-store cache behavior while `FLINT_HOT=1`

## CORS

Use `CorsMiddleware` globally when the app serves browsers from another origin:

```dart
app.use(CorsMiddleware(
  allowedOrigins: ['https://app.example.com'],
  allowedMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'QUERY', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
));
```

For `OPTIONS` preflight requests, `CorsMiddleware` writes a `204` response and
stops the pipeline.

## Logger Middleware

`LoggerMiddleware` writes a sanitized request log line after a handler
completes:

```dart
app.use(LoggerMiddleware());
```

It records the method, path, status, duration, and client IP. It does not log
cookies, authorization headers, raw request bodies, OTP values, passwords,
tokens, or session IDs.

Use `Log.debug(...)`, `Log.info(...)`, `Log.warning(...)`, `Log.error(...)`,
and `Log.critical(...)` for custom middleware logs instead of `print(...)`.
Read `docs/logging.md` for log levels, production settings, job logs, and error
logging.

## Cache And ETag

`CacheMiddleware` applies response cache headers for `GET`, `HEAD`, and `QUERY`:

```dart
app
    .get('/assets/config.json', (Context ctx) {
      return {'theme': 'light'};
    })
    .useMiddleware(CacheMiddleware.public(const Duration(minutes: 5)));
```

`ETagMiddleware` can return `304 Not Modified` when `If-None-Match` matches:

```dart
app
    .get('/catalog', (Context ctx) => Catalog().all())
    .useMiddleware(ETagMiddleware((ctx) => 'catalog-v1'));
```

Read `docs/cache.md` before using `CacheMiddleware`, `ETagMiddleware`, response
cache helpers, or app data cache stores.

## Security Middleware

`SecurityMiddleware` watches suspicious paths and can temporarily block IPs that
generate too many `404` responses.

```dart
app.use(SecurityMiddleware(
  config: SecurityConfig.production(
    suspiciousPathPrefixes: ['/wp-admin', '/phpmyadmin'],
    excludedPrefixes: ['/health'],
  ),
  onSecurityEvent: (event) {
    Log.warning(event.toString());
  },
));
```

Use `SecurityConfig.monitorOnly(...)` when you want visibility without automatic
blocking.

## Anti-SQL Injection Middleware

`AntiSqlInjectionMiddleware` scans route params, query values, and safe request
body types for high-confidence SQL injection probes. It is a defense-in-depth
tripwire. It does not replace parameterized queries, model query APIs,
validation, or authorization.

```dart
app.use(AntiSqlInjectionMiddleware(
  ignoredPathPrefixes: ['/webhooks/provider'],
  scanHeaders: false,
));
```

## Upload Middleware

`RichTextUpload` handles `POST /api/content-media/upload` for rich text editor
assets. It can require an authenticated user, validates the filename and
extension, stores a base64 upload under `public/uploads/content`, and returns
the public asset URL.

```dart
app.use(RichTextUpload(
  uploadPath: 'public/uploads/content',
  urlPrefix: '/uploads/content',
  requireAuth: true,
));
```

## CLI

Generate a middleware file with:

```bash
dart run flint_dart:flint --make-middleware AuthMiddleware
```

The older `make:middleware` alias is deprecated and will be removed in Flint
Dart `1.5.0`; use `--make-middleware` in new examples and generated guidance.

The generated file belongs in `lib/middlewares/`. After generating it, replace
placeholder token checks with the real app rule: JWT/session auth, role lookup,
tenant lookup, signed webhook validation, rate limiting, or whatever the
feature needs.

## Common Mistakes

- Do not call `res.send(...)`, `res.json(...)`, or `res.close()` and then call `next(ctx)`.
- Do not assume `ctx.res` exists inside global middleware; WebSocket contexts have `ctx.socket` instead.
- Do not create a new `Request` or `Response`; use `ctx.req` and `ctx.res`.
- Do not attach route middleware with `.use(...)`; use `.useMiddleware(...)`.
- Do not rely on `ctx.req.isAuthenticated` before `await ctx.req.user` has populated the request cache.
- Do not put multiple middleware classes in one file.
- Do not put app-specific secrets directly in middleware source; read from environment or config.
