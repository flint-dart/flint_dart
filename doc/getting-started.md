# Getting Started

Flint is a fullstack Dart framework. Server code is built around `Flint`,
`Context`, `Request`, `Response`, `RouteGroup`, middleware, controllers, models,
mail, jobs, and WebSockets. Frontend code lives in `lib/ui` and uses
`package:flint_dart/ui.dart`.

For server code, import:

```dart
import 'package:flint_dart/flint_dart.dart';
```

That public entrypoint exports the app object, routing, `Context`, controllers,
request/response helpers, auth, database/model helpers, middleware, mail, cache,
storage, jobs, WebSockets, and related utilities.

## Minimal App

`Flint` is the application object. The object you create from `Flint(...)` owns
the HTTP router, WebSocket route list, middleware stack, optional database
bootstrapping, optional mail bootstrapping, optional job registration, optional
Flint UI server rendering, and optional Swagger docs routes.

```dart
import 'package:flint_dart/flint_dart.dart';

void main(List<String> args) {
  final app = Flint(
    autoConnectDb: false,
    enableSwaggerDocs: true,
  );

  app.get('/', (Context ctx) {
    return ctx.res?.json({'message': 'Hello Flint'});
  });

  app.listen(port: 3000, hotReload: true);
}
```

`example/lib/main.dart` uses this shape. It creates `Flint(...)`, adds
middleware, serves assets, registers `RouteGroup` classes, and calls
`app.listen(...)`.

## Creating The App

Common constructor options:

- `rootPath`: app source root used by hot reload and mounted apps. Defaults to `lib`.
- `viewPath`: template directory for `res.view(...)`.
- `withDefaultMiddleware`: adds `ExceptionMiddleware`, `CookieSessionMiddleware`, and `StaticFileMiddleware`. Defaults to `true`.
- `enableSwaggerDocs`: registers `/swagger.json`, `/docs`, and `/swagger-ui/*`.
- `autoConnectDb`: lazily connects the database when needed. Defaults to `true`.
- `autoConnectMail`: prepares mail configuration from `.env`. Defaults to `true`.
- `autoMigrate`: overrides whether migrations run during startup.
- `autoMigrateDefault`: default startup migration behavior when `autoMigrate` is not set.
- `autoMigrateCreateDatabase`: lets startup migrations create the configured database.
- `autoMigrateDuringHotReload`: controls whether the hot reload worker runs migrations.
- `autoMigrateVerbose`: logs migration detail during startup.
- `tableRegistry`: in-memory table registry used by auto migrations.
- `seederRegistry`: seed registry used by `seed()` or startup seeding.
- `autoSeed`: runs seeders during startup.
- `closeSeederConnection`: closes the DB connection after seeding when requested.
- `jobsRegistry`: job definitions available to the app.
- `autoRegisterJobs`: registers queue job definitions from `jobsRegistry`. Defaults to `true`.
- `includeJobTablesInMigrations`: includes Flint job tables in migration runs. Defaults to `true`.
- `flintPageServerRenderer`: renderer used by `res.page(...)` when server rendering Flint UI.
- `serverRenderFlintPages`: enables server rendering for Flint UI pages.

Runtime helpers:

- `app.ai`: the app-level Flint AI service.
- `app.isDatabaseConnected`: `true` after the database connection is established.

See `docs/seeders.md` before enabling `autoSeed`; seeders should be registered
through `SeederRegistry` and should be safe to run more than once.

See `docs/jobs-and-workers.md` before adding background jobs. New jobs should
extend `QueueJob`; the old `FlintJob` base class is deprecated compatibility.

See `docs/isolate-tasks.md` before moving work into Dart isolates. Isolate tasks
are for CPU-heavy or blocking work; they are not a durable job queue.

See `docs/storage.md` before saving uploads with `Storage`, and see
`docs/security-and-utilities.md` before hashing passwords, creating JWTs,
adding rate limits, throwing framework exceptions, or using `Str` helpers.

See `docs/sessions-and-cookies.md` before adding server sessions, login
cookies, flash messages, or browser-side auth session storage.

See `docs/templates.md` before changing server-rendered HTML templates,
`{{ }}` syntax, includes, layouts, sections, control flow, assets, session
helpers, or mail template syntax.

See `docs/cache.md` before adding `CacheStore`, response cache headers, ETags,
or cached app data.

See `docs/logging.md` before adding `LoggerMiddleware`, production log settings,
job logs, error logs, or committed log calls.

See `docs/testing.md` before adding route, controller, middleware, validator,
storage, job, seeder, or UI component tests.

See `docs/ai.md` before configuring AI providers, agents, tools, workflows,
memory stores, run, thread, trace, artifact persistence, AI table migrations,
or production tool policy.

See `docs/build-and-rendering.md` before changing `flint build`, `flint web`,
browser entrypoints, generated UI bundles, page registry behavior, or Flint UI
server rendering.

See `docs/frontend-ui.md` and `docs/ui-widgets.md` before adding Flint UI
pages, components, forms, buttons, layouts, overlays, tables, charts, browser
storage, navigation, or `StateSignal` state.

See `docs/deployment.md` before changing Docker files, production startup,
environment variables, static file deploys, migration steps, or jobs worker
processes.

See `docs/database-api.md` before exposing models through `FlintDatabaseApi`.
The normal model layer is for backend workflows; the Database API is for
intentional, policy-protected resource access.

## Routes On The App Object

The `app` object exposes route methods for HTTP and WebSocket work:

```dart
app.get('/courses', (Context ctx) async {});
app.post('/courses', (Context ctx) async {});
app.put('/courses/:id', (Context ctx) async {});
app.patch('/courses/:id', (Context ctx) async {});
app.delete('/courses/:id', (Context ctx) async {});
app.query('/courses/search', (Context ctx) async {});
app.route('HEAD', '/health', (Context ctx) async {});
app.route('OPTIONS', '/courses', (Context ctx) async {});
app.websocket('/chat', (Context ctx) {});
```

Use:

- `get` to read a resource.
- `post` to create a resource or perform an action.
- `put` to replace or update a full resource.
- `patch` to update part of a resource.
- `delete` to remove a resource.
- `query` for safe/idempotent reads that need a request body, such as advanced search filters.
- `route` for custom HTTP methods such as `HEAD`, `OPTIONS`, or extension methods.
- `websocket` for real-time connections.

All HTTP route methods return a `RouteBuilder`. Attach route-specific middleware
with `.useMiddleware(...)`:

```dart
app
    .post('/courses', (Context ctx) async {
      final data = await ctx.req.validate({
        'title': 'required|string|min:3',
      });

      return ctx.res?.status(201).json({'data': data});
    })
    .useMiddleware(AuthMiddleware());
```

Path parameters use `:name`:

```dart
app.get('/courses/:id', (Context ctx) {
  final id = ctx.req.param('id');
  return ctx.res?.json({'id': id});
});
```

## Context, Request, Response, And Socket

New Flint code should use `Context`. A context unifies HTTP routes, WebSocket
routes, middleware, and controller actions behind one object:

```dart
typedef Handler = FutureOr<Object?> Function(Context ctx);
```

`Context` contains:

- `ctx.req`: the current `Request`.
- `ctx.res`: the current `Response?`; it is available for HTTP and null for WebSocket handlers.
- `ctx.socket`: the current `FlintWebSocket?`; it is available for WebSocket handlers and null for HTTP handlers.
- `ctx.isHttp`: true when a response exists.
- `ctx.isWebSocket`: true when a socket exists.
- `ctx.read<T>()` and `ctx.write<T>(value)`: typed request-scoped storage.
- `ctx.getExtra<T>(key)` and `ctx.setExtra(key, value)`: keyed request-scoped storage.
- `ctx.ai`: request-aware access to the app AI service when attached.

This is why middleware and handlers should accept `Context ctx`: the same shape
works for HTTP and sockets. You do not need one handler object for HTTP and a
different handler object for WebSocket work.

Useful `Request` properties and methods:

```dart
ctx.req.method;
ctx.req.path;
ctx.req.uri;
ctx.req.headers;
ctx.req.query;
ctx.req.params;
ctx.req.param('id');
ctx.req.queryParam('search');
ctx.req['id'];
await ctx.req.input('email');
await ctx.req.json();
await ctx.req.form();
await ctx.req.body();
await ctx.req.rawBody();
await ctx.req.allInput();
await ctx.req.validate({'email': 'required|email'});
await ctx.req.hasFile('avatar');
await ctx.req.file('avatar');
await ctx.req.files('attachments');
await ctx.req.storeFile('avatar', directory: 'public/uploads');
ctx.req.cookies;
ctx.req.bearerToken;
ctx.req.authToken;
await ctx.req.user;
ctx.req.isAuthenticated;
ctx.req.requireUser();
ctx.req.clientIpAddress;
```

Useful `Response` properties and methods:

```dart
ctx.res?.status(201).json({'ok': true});
ctx.res?.json({'ok': true});
ctx.res?.respond({'ok': true});
ctx.res?.send('hello');
ctx.res?.header('X-App', 'Flint');
ctx.res?.setCookie('name', 'value', httpOnly: true);
ctx.res?.clearCookie('name');
ctx.res?.redirect('/login');
ctx.res?.back(fallback: '/');
ctx.res?.view('emails.welcome', data: {'name': 'Ada'});
ctx.res?.page('Dashboard', props: {'title': 'Dashboard'});
ctx.res?.renderEmail(WelcomeMail());
ctx.res?.streamFile(file);
ctx.res?.cachePublic(const Duration(minutes: 5));
ctx.res?.cachePrivate(const Duration(minutes: 5));
ctx.res?.noStore();
ctx.res?.etag('version-1');
ctx.res?.lastModified(DateTime.now());
await ctx.res?.close();
```

Because `ctx.res` is nullable, global middleware and WebSocket handlers should
check it before writing an HTTP response.

## Middleware

Middleware wraps handlers. It can inspect the request, add context data,
short-circuit the response, or continue to the next handler.

```dart
class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) return next(ctx);

      final user = await ctx.req.user;
      if (user == null) {
        return res.status(401).json({'message': 'Unauthorized'});
      }

      ctx.write<Map<String, dynamic>>(user);
      return next(ctx);
    };
  }
}
```

Add global middleware with `app.use(...)`:

```dart
app.use(LoggerMiddleware());
app.use(AuthMiddleware());
```

Add route middleware with `.useMiddleware(...)`:

```dart
app
    .get('/profile', (Context ctx) => ctx.res?.json({'ok': true}))
    .useMiddleware(AuthMiddleware());
```

Add group middleware with a `RouteGroup`:

```dart
class ApiRoutes extends RouteGroup {
  @override
  String get prefix => '/api';

  @override
  List<Middleware> get middlewares => [AuthMiddleware()];

  @override
  void register(Flint app) {
    app.get('/me', (Context ctx) {
      final user = ctx.read<Map<String, dynamic>>();
      return ctx.res?.json({'user': user});
    });
  }
}
```

Middleware order is:

```text
global middleware
route group middleware
route-specific middleware
handler
```

## What Happens Internally

When `listen()` runs:

1. It resolves the port from the argument or `PORT`, defaulting to `3001` in `Flint.listen`.
2. Unless disabled, hot reload starts a launcher process using `dart run flint_dart:hot_reload`.
3. The worker process runs `_runServer`, optionally runs migrations and seeders, binds `HttpServer` on `InternetAddress.anyIPv4`, and starts reading requests.
4. Each HTTP request is wrapped in `Request` and `Response`.
5. Flint creates `Context(req: request, res: response)`.
6. `Router.match()` finds the route and fills `ctx.req.params`.
7. Global middleware is folded around the matched route handler.
8. The handler receives `Context`.
9. Returned `Model`, `toMap()`, or `toJson()` values are serialized with `res.json`; other values go through `res.respond`.

## Default Middleware

By default, `Flint` adds:

```dart
ExceptionMiddleware()
CookieSessionMiddleware()
StaticFileMiddleware()
```

If `withDefaultMiddleware: false`, `CookieSessionMiddleware` is still added by the constructor. This matters because `CookieService` and `SessionService` are initialized there for HTTP requests.

## Controllers

For feature code, prefer request-scoped controllers:

```dart
class CourseController extends Controller {
  Future<Response> index() async {
    final courses = await Course().get();
    return res.json({'data': courses});
  }
}
```

`Controller` receives the same `Context` that route handlers receive. Inside a
controller:

- `context` is the bound request context.
- `req` is `context.req`.
- `res` is `context.res`, and throws if the action is running as WebSocket code.
- `socket` is `context.socket`, and throws if the action is running as HTTP code.

For route groups and advanced apps, use `app.controller(...)`:

```dart
class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';

  @override
  void register(Flint app) {
    final courses = app.controller(CourseController.new);

    courses.get('/', (controller) => controller.index());
  }
}
```

If you are not using `app.controller(...)`, still wrap controller actions so
Flint can bind and unbind the context for each request:

```dart
app.get('/courses', controller(CourseController.new, (c) => c.index()));

app.get('/courses/featured',
    useController(CourseController.new, (c) => c.featured()));
```

Do not instantiate a controller once and pass method references directly for
feature routes. Use `app.controller(...)`, `controller(...)`, or
`useController(...)` so the controller receives the current `Context`.

## WebSockets Use Context Too

WebSocket routes should also use `Context`:

```dart
app.websocket('/chat', (Context ctx) {
  final socket = ctx.socket;
  if (socket == null) return;

  socket.emit('connected', {'clientId': socket.id});

  socket.on('send_message', (payload) {
    socket.emitToRoom('general', 'new_message', payload);
  });

  socket.join('general');
});
```

For WebSocket routes, `ctx.req` is the upgrade request and `ctx.socket` is the
connected `FlintWebSocket`. `ctx.res` is null because the HTTP response has
become a socket connection.

Controller-backed WebSockets use the same `app.controller(...)` idea:

```dart
class ChatSocketController extends Controller {
  void connect() {
    socket.emit('connected', {'clientId': socket.id});
  }
}

final chat = app.controller(ChatSocketController.new);
chat.websocket('/chat', (controller) => controller.connect());
```

## Static Files, Route Groups, And Mounting

Serve static files:

```dart
app.static('/assets', 'public/assets');
```

Register route groups:

```dart
app.routes(ApiRoutes());
```

Register nested groups:

```dart
app.routes(
  ApiRoutes(),
  children: [
    CourseRoutes(),
    AuthRoutes(),
  ],
);
```

Mount a group of routes manually when you need a small local module:

```dart
app.mount('/admin', (admin) {
  admin.get('/health', (Context ctx) {
    return ctx.res?.json({'ok': true});
  });
}, middlewares: [
  AuthMiddleware(),
]);
```

Start the server:

```dart
await app.listen(port: 3000, hotReload: true);
```

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
dart run flint_dart:flint --docs-generate
dart run flint_dart:flint migrate --no-interaction
```

The command registry is in `lib/src/cli/commands.dart`.

## Important Limits

- `Flint.listen()` uses hot reload by default. Set `hotReload: false` or `FLINT_HOT=0` when you want a single process.
- Database auto-connect defaults to `true`; examples often use `autoConnectDb: false` so routes can run without a configured database.
- Static file middleware only serves from `public` by default. `app.static('/web', 'flint_ui/web')` is a separate route registration.
- HTTP handlers should use `Context ctx`; the older two-argument handler shape exists for compatibility.
- WebSocket handlers should use `Context ctx`; `ctx.socket` holds the connected `FlintWebSocket`.
- Controller actions should be registered with `app.controller(...)`, `controller(...)`, or `useController(...)` so Flint can bind `context`.
- The repository contains multiple sibling projects; this documentation targets the `flint/flint_dart` framework package.
