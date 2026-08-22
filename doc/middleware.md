# Middleware

Middleware is implemented by `lib/src/middleware/middleware.dart`.

```dart
abstract class Middleware {
  Handler handle(Handler next);
}
```

`Handler` is the unified HTTP/WebSocket signature:

```dart
typedef Handler = FutureOr<Object?> Function(Context ctx);
```

## Writing Middleware

Use `Context` to access `req`, `res`, `socket`, and typed extras.

```dart
import 'package:flint_dart/flint_dart.dart';

class RequireHeaderMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final res = ctx.res;
      if (res == null) return next(ctx);

      if (ctx.req.headers['x-api-key'] == null) {
        return res.status(401).json({'message': 'Missing API key'});
      }

      return next(ctx);
    };
  }
}
```

Add it globally:

```dart
app.use(RequireHeaderMiddleware());
```

Or per route:

```dart
app.get('/profile', profile).useMiddleware(AuthMiddleware());
```

## Built-In Middleware

The export file `lib/middlewares.dart` exposes:

- `ExceptionMiddleware`
- `CookieSessionMiddleware`
- `StaticFileMiddleware`
- `CorsMiddleware`
- `LoggerMiddleware`
- `CacheMiddleware`
- `AntiSqlInjectionMiddleware`
- `RichTextUploadMiddleware`

`Flint` installs `ExceptionMiddleware`, `CookieSessionMiddleware`, and `StaticFileMiddleware` by default.

## Exception Middleware

`ExceptionMiddleware` catches known exceptions and converts them to JSON responses. For example, `ValidationException` becomes:

```json
{"status": false, "errors": {"field": ["message"]}}
```

with the exception's status code, usually `422`.

`AuthException` becomes a `401` response with:

```json
{"status": false, "error": "Unauthorized", "message": "..."}
```

It also catches database column-check errors containing `unknown column`, `does not exist`, or `42703` and retries `next(ctx)`. That behavior is part of the current implementation and should be considered when debugging repeated handler execution.

## Static Files

`StaticFileMiddleware` serves from `public` for `GET` and `HEAD`. It skips known dynamic prefixes such as `/api`, `/ws`, `/docs`, `/swagger`, `/admin`, and `/graphql`. It supports:

- root `/` fallback to `public/index.html`
- MIME detection
- `ETag` and `Last-Modified`
- range requests for a single byte range
- gzip compression and precompressed `.gz` or `.br` files
- security headers such as `X-Content-Type-Options`

## Cookie and Session Initialization

`CookieSessionMiddleware` calls:

```dart
CookieService.init(ctx.req, res);
SessionService.init(ctx.req, res);
```

This only happens for HTTP contexts. WebSocket middleware receives a context with `socket` and no `res`.

## Important Limits

- Middleware must handle both HTTP and WebSocket contexts if it is global; `ctx.res` can be null.
- `Response.send()` and `Response.json()` close the response. Middleware after a closed response should not try to write headers.
- `StaticFileMiddleware` is path-based and does not sanitize a custom `app.static()` file path beyond the route prefix logic.
