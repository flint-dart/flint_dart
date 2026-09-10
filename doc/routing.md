# Routing

Routing is the layer that maps an incoming HTTP request or WebSocket upgrade to
the Dart code that should handle it. In Flint, routing is built from `Flint`,
`Router`, `RouteBuilder`, `RouteGroup`, `Context`, and `Request`.

Before coding routes in a developer app, inspect:

- `lib/main.dart` for `Flint(...)`, global middleware, `app.routes(...)`, `app.mount(...)`, `app.static(...)`, and `app.listen(...)`.
- `lib/routes/` for `RouteGroup` classes.
- `lib/controllers/` for controller actions.
- `lib/middlewares/` for auth, role, tenant, CORS, or other route guards.
- `lib/models/` when a route reads or writes database records.
- `docs/authentication.md` before adding auth, login, session, token, send OTP, verify OTP, or resend OTP routes.
- `docs/middleware.md` before adding route-specific or group middleware.
- `docs/validation.md` before validating route input.
- `docs/websockets.md` before adding WebSocket routes.

Framework source to inspect when behavior is unclear:

- `lib/src/app.dart`
- `lib/src/context.dart`
- `lib/src/request.dart`
- `lib/src/response.dart`
- `lib/src/controller.dart`
- `lib/src/routing/router.dart`
- `lib/src/routing/route_builder.dart`
- `lib/src/routing/route_group.dart`
- `lib/src/websocket/ws_router.dart`

## The Mental Model

New Flint route handlers should receive `Context`:

```dart
app.get('/health', (Context ctx) {
  return ctx.res?.json({'ok': true});
});
```

`Context` is the single object that unifies HTTP routes, WebSocket routes,
middleware, and controllers.

- `ctx.req` is the `Request`.
- `ctx.res` is the `Response?`; it exists for HTTP routes.
- `ctx.socket` is the `FlintWebSocket?`; it exists for WebSocket routes.
- `ctx.isHttp` is true when `ctx.res` exists.
- `ctx.isWebSocket` is true when `ctx.socket` exists.
- `ctx.write<T>(value)` stores typed data for later middleware, routes, or controllers.
- `ctx.read<T>()` reads typed data from the context.

Use `ctx.req` for incoming data. Use `ctx.res` for outgoing HTTP responses. Use
`ctx.socket` for WebSocket events.

The older two-argument HTTP handler style is still adapted for compatibility,
but new and advanced apps should teach and write `Context` routes.

## Route Methods On `Flint`

`Flint` exposes these HTTP route methods:

```dart
app.get(path, handler);
app.post(path, handler);
app.put(path, handler);
app.patch(path, handler);
app.delete(path, handler);
app.query(path, handler);
app.route(method, path, handler);
```

Each route method returns a `RouteBuilder`, so middleware can be attached with
`.useMiddleware(...)`.

```dart
app
    .get('/profile', (Context ctx) async {
      final user = await ctx.req.user;
      return ctx.res?.json({'user': user});
    })
    .useMiddleware(AuthMiddleware());
```

### `get`

Use `GET` for reads that do not change server state.

```dart
app.get('/courses', (Context ctx) async {
  final courses = await Course().orderBy('created_at', desc: true).get();
  return ctx.res?.json({'data': courses});
});
```

### `post`

Use `POST` for creation, login, OTP sends, webhook receives, and other actions
that submit a body.

```dart
app.post('/auth/send-otp', (Context ctx) async {
  final data = await ctx.req.validate({
    'email': 'required|email',
  });

  final email = data['email'].toString().trim().toLowerCase();
  final otp = await Auth.generateNumericVerificationCode(email);
  await SendAuthOtpAction().call(email: email, otp: otp);

  return ctx.res?.json({'message': 'OTP sent'});
});
```

`SendAuthOtpAction` is application code. See `docs/authentication.md` and
`docs/mail.md` before wiring OTP routes.

### `put`

Use `PUT` when replacing or updating a resource by id.

```dart
app.put('/courses/:id', (Context ctx) async {
  final input = await ctx.req.validate({
    'id': 'required|string',
    'title': 'required|string|min:3',
  });

  final course = await Course().update(
    id: input['id'],
    data: {'title': input['title']},
  );
  return ctx.res?.json({'data': course});
});
```

### `patch`

Use `PATCH` for partial updates.

```dart
app.patch('/courses/:id/status', (Context ctx) async {
  final input = await ctx.req.validate({
    'id': 'required|string',
    'status': 'required|in:draft,published',
  });

  final course = await Course().update(id: input['id'], data: {
    'status': input['status'],
  });
  return ctx.res?.json({'data': course});
});
```

### `delete`

Use `DELETE` for removing a resource.

```dart
app.delete('/courses/:id', (Context ctx) async {
  await Course().delete(ctx.req.param('id'));
  return ctx.res?.status(204).send('');
});
```

### `query`

`QUERY` is supported by Flint for safe, idempotent reads that need a request
body. Use it for complex searches and filters that are too large or structured
for URL query parameters.

```dart
app.query('/courses/search', (Context ctx) async {
  final body = await ctx.req.json();
  final courses = await CourseSearch().call(body);
  return ctx.res?.json({'data': courses});
});
```

`QUERY` is part of Flint routing and response handling, but it is not a standard
OpenAPI operation key. The Swagger generator documents it with Flint-specific
metadata.

### `route`

Use `route(...)` for custom or less common methods such as `OPTIONS`, `HEAD`, or
provider-specific extension methods.

```dart
app.route('OPTIONS', '/courses', (Context ctx) {
  final res = ctx.res;
  if (res == null) return null;

  res.raw.headers.set('Allow', 'GET, POST, QUERY, OPTIONS');
  return res.status(204).send('');
});
```

### `websocket`

Use `app.websocket(...)` for realtime features. WebSocket handlers should also
receive `Context`.

```dart
app.websocket('/chat', (Context ctx) {
  final socket = ctx.socket;
  if (socket == null) return;

  socket.on('message', (data) {
    socket.emitToAll('message', data);
  });
});
```

WebSocket route middleware is passed with the `middlewares` argument:

```dart
app.websocket(
  '/chat',
  (Context ctx) {
    ctx.socket?.emit('ready', {'ok': true});
  },
  middlewares: [ChatSocketAuthMiddleware()],
);
```

## Route Paths

Route paths should start with `/`. `RouteBuilder.normalizedPath` adds the leading
slash when missing and removes a trailing slash except for `/`.

```dart
app.get('/courses', handler);
app.get('/courses/:id', handler);
app.get('/files/*', handler);
```

Incoming paths are normalized by `Flint.normalizePath()` so duplicate slashes are
collapsed and a trailing slash is removed except for the root path.

## Route Parameters

Use `:name` to capture a path segment.

```dart
app.get('/courses/:id', (Context ctx) {
  final id = ctx.req.params['id'];
  return ctx.res?.json({'id': id});
});
```

The shortcut `req.param(name)` reads from `req.params`:

```dart
final id = ctx.req.param('id');
```

Parameter regex segments are supported:

```dart
app.get('/users/:id(\\d+)', (Context ctx) {
  return ctx.res?.json({'id': ctx.req.param('id')});
});
```

Wildcards only match route paths ending in `/*`.

```dart
app.get('/assets/*', (Context ctx) {
  return ctx.res?.send('asset route');
});
```

## Route Matching

`Router.match()` resolves routes in this order:

1. Exact and parameter matches for the request method.
2. Wildcard routes ending in `/*`.
3. `HEAD` fallback to a matching `GET` route.
4. Automatic `OPTIONS` response when the path exists for another method.
5. Automatic `405 Method Not Allowed` when the path exists but the method is not allowed.
6. The app-level `404 Not Found` handler when no route matches.

The automatic `Allow` header includes `HEAD` when `GET` exists and includes
`OPTIONS` when any method exists for that path.

## Returning From Handlers

A route can write to `ctx.res` directly:

```dart
app.get('/plain', (Context ctx) {
  return ctx.res?.send('hello');
});
```

A route can also return data and let Flint serialize it:

```dart
app.get('/health', (Context ctx) {
  return {'ok': true};
});
```

Returned `Response` values are already handled. Returned `Model` instances and
objects with `toMap()` or `toJson()` are sent with `res.json(...)`. Other values
are sent with `res.respond(...)`, which infers JSON, HTML, or plain text.

If you use `ctx.res?.json(...)`, `ctx.res?.send(...)`, or another response
method that closes the response, return it and do not write again later.

## Route Groups

Use `RouteGroup` to keep related routes together.

```dart
class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';

  @override
  String get tag => 'Courses';

  @override
  void register(Flint app) {
    app.get('/', (Context ctx) => Course().all());
    app.get('/:id', (Context ctx) => Course().find(ctx.req.param('id')));
  }
}
```

Register the group in `lib/main.dart`:

```dart
app.routes(CourseRoutes());
```

`RouteGroup` provides:

```dart
abstract class RouteGroup {
  String get prefix => '';
  String get tag => '';
  List<Middleware> get middlewares => const [];
  void register(Flint app);
}
```

`prefix` is added to every route inside the group. `tag` is useful for
documentation and tooling. `middlewares` applies to every route in the group.

## Nested Route Groups

`app.routes(group, children: [...])` registers a parent group and child groups
under the same mounted tree.

```dart
app.routes(
  ApiRoutes(),
  children: [
    CourseRoutes(),
    UserRoutes(),
  ],
);
```

If `ApiRoutes.prefix` is `/api`, `CourseRoutes.prefix` is `/courses`, and
`UserRoutes.prefix` is `/users`, the final route paths become:

```text
/api/courses
/api/users
```

Child groups inherit the parent prefix and middleware through mounting.

## Mounting

`app.mount(prefix, callback, middlewares: [...])` creates a sub-`Flint`, lets the
callback register routes on it, then copies those routes into the parent app
under the prefix.

```dart
app.mount('/api', (api) {
  api.get('/health', (Context ctx) => {'ok': true});
}, middlewares: [
  ApiMiddleware(),
]);
```

Use `RouteGroup` for normal app features. Use `mount(...)` when you need to
compose a small sub-application or register a package/module under a prefix.

## Route Middleware

Route-specific middleware uses `.useMiddleware(...)`.

```dart
app
    .post('/courses', (Context ctx) async {
      final data = await ctx.req.validate({'title': 'required|string'});
      return Course().create(data);
    })
    .useMiddleware(AuthMiddleware());
```

Group middleware is declared on the `RouteGroup`:

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
    app.get('/dashboard', (Context ctx) => {'ok': true});
  }
}
```

Global middleware is registered in `lib/main.dart`:

```dart
app.use(CorsMiddleware());
app.use(LoggerMiddleware());
```

The important practical rule: `app.use(...)` is for global middleware.
`.useMiddleware(...)` is for a specific route. There is no `.use(...)` alias on
`RouteBuilder`.

Middleware lists behave like a wrapper stack. The last middleware in a list runs
first on the way in and finishes last on the way out. See
`docs/middleware.md` before changing middleware order. See `docs/logging.md`
before changing request logging, log levels, or error log behavior.

## Controllers

For feature code, prefer request-scoped controllers that extend `Controller`.
Register them through `app.controller(...)`.

```dart
class CourseController extends Controller {
  Future<Response> index() async {
    final courses = await Course().all();
    return res.json({'data': courses});
  }

  Future<Response> show() async {
    final course = await Course().find(req.param('id'));
    if (course == null) {
      return res.status(404).json({'message': 'Course not found'});
    }
    return res.json({'data': course});
  }
}
```

Route group:

```dart
class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';

  @override
  void register(Flint app) {
    final courses = app.controller(CourseController.new);

    courses.get('/', (controller) => controller.index());
    courses.get('/:id', (controller) => controller.show());
  }
}
```

`app.controller(CourseController.new)` creates a route builder that constructs a
fresh controller per request, binds the current `Context`, runs the action, and
unbinds the controller afterwards.

Inside a controller:

- `context` is the bound `Context`.
- `req` is `context.req`.
- `res` is `context.res`, and throws if the action is running in a WebSocket context.
- `socket` is `context.socket`, and throws if the action is running in an HTTP context.
- `read<T>()` and `write<T>(value)` proxy to `context.read<T>()` and `context.write<T>()`.

If a controller action is not registered through `app.controller(...)`, wrap it
with `controller(...)` or `useController(...)` so Flint binds the current
`Context`.

```dart
app.get('/profile', controller(ProfileController.new, (c) => c.show()));

app.get(
  '/profile/settings',
  useController(ProfileController.new, (c) => c.settings()),
);
```

## Request Reference

`Request` is Flint's wrapper around Dart's `HttpRequest`. You normally access it
as `ctx.req` or as `req` inside a `Controller`.

```dart
app.post('/courses/:id', (Context ctx) async {
  final req = ctx.req;
  final id = req.param('id');
  final data = await req.json();
  return ctx.res?.json({'id': id, 'data': data});
});
```

### Raw Request

```dart
final raw = req.raw;
```

`raw` is the original `HttpRequest` from `dart:io`. Use it only when Flint's
helpers do not expose what you need.

### Basic Properties

```dart
req.method;
req.path;
req.uri;
req.headers;
req.query;
req.ipAddress;
req.clientIpAddress;
```

- `method` is the incoming HTTP method, such as `GET`, `POST`, `QUERY`, or `DELETE`.
- `path` is the URL path without the query string.
- `uri` is the full `Uri`.
- `headers` returns request headers as a `Map<String, String>`.
- `query` returns URL query parameters as a `Map<String, String>`.
- `ipAddress` uses the direct socket address.
- `clientIpAddress` checks common proxy headers such as Cloudflare, `X-Forwarded-For`, and `X-Real-IP` before falling back to `ipAddress`.

When exact header behavior matters, inspect `req.raw.headers` because header
names can vary by client, proxy, and server.

### Route Params And Query Params

```dart
final id = req.params['id'];
final sameId = req.param('id');
final page = req.query['page'];
final samePage = req.queryParam('page');
final routeOrQuery = req['id'];
```

- `params` contains route params captured from path segments such as `:id`.
- `param(key)` reads one route param.
- `query` contains URL query parameters.
- `queryParam(key)` reads one query param.
- `operator [](key)` checks `params` first, then `query`.

`req['name']` does not read JSON or form body fields. Use `await req.input(...)`
or `await req.allInput()` when you want normalized request input.

### Normalized Input

```dart
final value = await req.input('email');
final input = await req.allInput();
```

`input(key)` returns one value from `allInput()`.

`allInput()` merges request data in this precedence order:

```text
query < body/form fields < uploaded files < route params
```

That means a route param wins over a body field with the same key, and an
uploaded file wins over a normal form field with the same key.

Use `allInput()` in validators, filters, and controller actions where the source
can be query string, JSON, form data, file upload, or route param.

### Request-Scoped Storage

```dart
req.set('tenant_id', 'school_123');
final tenantId = req.get('tenant_id');
```

`req.set(...)` and `req.get(...)` are request-local storage helpers. They are
not database methods and `req.get(...)` is not an HTTP `GET` helper.

Prefer `ctx.write<T>(value)` and `ctx.read<T>()` when middleware needs to pass
typed objects to later middleware, routes, or controllers.

### Cookies

```dart
final cookies = req.cookies;
final sessionId = req.sessionId;
```

`cookies` parses the `Cookie` header into a `Map<String, String>`.
`sessionId` reads the `FLINTSESSID` cookie.

Use response cookie helpers such as `res.setCookie(...)` and
`res.clearCookie(...)` when writing cookies.

### Auth And JWT

```dart
final bearer = req.bearerToken;
final token = req.authToken;
final jwt = req.jwt;
final user = await req.user;
final authenticated = req.isAuthenticated;
final requiredUser = req.requireUser();
```

- `bearerToken` reads `Authorization: Bearer <token>`.
- `authToken` prefers the bearer token, then checks auth cookies.
- `jwt` creates a `FlintJwt` helper using `JWT_SECRET`.
- `user` tries to verify the auth token, then falls back to session data.
- `isAuthenticated` checks whether `user` has already been cached on the request.
- `requireUser()` returns the cached user or throws `AuthException`.

Important: call `await req.user` before relying on `req.isAuthenticated` or
`req.requireUser()`. `isAuthenticated` is a cache check; it does not perform the
lookup by itself.

Middleware can load and store the user once:

```dart
class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) return await next(ctx);

      final user = await ctx.req.user;
      if (user == null) {
        return res.status(401).json({'message': 'Unauthorized'});
      }

      ctx.write<Map<String, dynamic>>(user);
      return await next(ctx);
    };
  }
}
```

Then a controller can read it:

```dart
final user = read<Map<String, dynamic>>();
```

### Sessions

```dart
final current = await req.session;
final newSessionId = await req.startSession({'id': user.id});
final rotatedSessionId = await req.updateSession({'role': 'admin'});
await req.destroySession();
```

- `session` reads current session data through `SessionManager`.
- `startSession(data, ttl: ...)` creates a session, sets the session cookie, and caches `user` in request storage.
- `updateSession(updates, ttl: ...)` merges updates, destroys the old session, creates a new session, and caches the merged data.
- `destroySession()` destroys the current session and removes cached `user`.

Session helpers need access to the underlying HTTP response because they write
cookies. In normal routes and controllers this is already available.

Read `docs/sessions-and-cookies.md` for session drivers, cookie options, flash
messages, browser auth session storage, and logout guidance.

### Body Parsing

```dart
final text = await req.body();
final bytes = await req.rawBody();
final json = await req.json();
final form = await req.form();
```

- `body()` returns the raw request body decoded as UTF-8 text.
- `rawBody()` returns the exact request body bytes and caches them.
- `json()` parses `application/json` and expects a JSON object.
- `form()` parses `application/x-www-form-urlencoded` and multipart form fields.

Body parsing is cached. Calling `rawBody()`, `json()`, `form()`, `allInput()`,
or validation helpers does not permanently consume the body for later Flint
parsers.

`json()` returns an empty map for an empty JSON body. It throws
`FormatException` when the body is not a JSON object.

### File Uploads

Multipart uploads are represented by `UploadedFile`.

```dart
final hasAvatar = await req.hasFile('avatar');
final avatar = await req.file('avatar');
final gallery = await req.files('gallery');
final allFiles = await req.allFiles();
```

File helpers:

- `hasFile(fieldName)` checks whether a single file field exists.
- `hasFiles(fieldName)` checks exact and array-style file fields such as `gallery[]` or `gallery[0]`.
- `file(fieldName)` returns one `UploadedFile?`.
- `files(fieldName)` returns uploaded files for exact and array-style field names.
- `allFiles()` returns every uploaded file by field name.

`UploadedFile` exposes:

```dart
upload.fieldName;
upload.filename;
upload.contentType;
upload.size;
upload.extension;
upload.uploadedAt;
upload.content;
await upload.saveTo('public/uploads/avatar.png');
```

Convenience storage helpers:

```dart
final path = await req.storeFile(
  'avatar',
  directory: 'public/uploads/avatars',
  filename: 'user-${req.param('id')}.png',
);

final paths = await req.storeFiles(
  'gallery',
  directory: 'public/uploads/gallery',
);
```

- `storeFile(...)` saves one uploaded file and returns the saved path.
- `storeFiles(...)` saves multiple uploaded files and returns their saved paths.

Always validate file type, size, and authorization before trusting uploads.

### Validation

```dart
final data = await req.validate({
  'email': 'required|email',
  'password': 'required|string|min:8|confirmed',
});
```

`validate(...)` reads normalized input from query, body, form fields, uploaded
files, and route params. It returns the validated data or throws a validation
exception that `ExceptionMiddleware` can turn into a JSON response.

Custom messages:

```dart
final data = await req.validate(
  {'email': 'required|email'},
  messages: {
    'email.required': 'Email is required.',
  },
);
```

`validateForm(...)` still exists but is deprecated. Use `validate(...)`.

## Request Examples In Routes

Create with JSON:

```dart
app.post('/courses', (Context ctx) async {
  final data = await ctx.req.validate({
    'title': 'required|string|min:3',
    'status': 'in:draft,published',
  });

  final course = await Course().create(data);
  return ctx.res?.status(201).json({'data': course});
});
```

Search with query string:

```dart
app.get('/courses', (Context ctx) async {
  final page = int.tryParse(ctx.req.queryParam('page') ?? '1') ?? 1;
  final status = ctx.req.queryParam('status');

  final query = Course().orderBy('created_at', desc: true);
  if (status != null) {
    query.where('status', status);
  }

  final courses = await query.paginate(page);
  return ctx.res?.json({'data': courses});
});
```

Upload a file:

```dart
app.post('/profile/avatar', (Context ctx) async {
  final user = await ctx.req.user;
  if (user == null) {
    return ctx.res?.status(401).json({'message': 'Unauthorized'});
  }

  if (!await ctx.req.hasFile('avatar')) {
    return ctx.res?.status(422).json({'message': 'Avatar is required'});
  }

  final path = await ctx.req.storeFile(
    'avatar',
    directory: 'public/uploads/avatars',
  );

  return ctx.res?.json({'path': path});
});
```

Read a signed webhook raw body:

```dart
app.post('/webhooks/provider', (Context ctx) async {
  final signature = ctx.req.headers['x-provider-signature'];
  final rawBody = await ctx.req.rawBody();

  await VerifyWebhookSignatureAction().call(signature, rawBody);
  await ProcessWebhookAction().call(rawBody);

  return ctx.res?.json({'received': true});
});
```

## Static Files

For normal public assets, Flint installs `StaticFileMiddleware` by default and
serves from `public`.

You can also register a static route manually:

```dart
app.static('/assets', 'public/assets');
```

Static files are route-adjacent, but most app features should use normal routes,
controllers, and middleware instead of custom static handlers.

## Common Mistakes

- Do not teach new code to use legacy two-argument HTTP handlers when `Context ctx` works.
- Do not call `req.get('id')` expecting query data; `req.get(...)` reads request-scoped storage.
- Do not use `req['field']` for JSON or form fields; use `await req.input('field')`.
- Do not rely on `req.isAuthenticated` before `await req.user`.
- Do not attach route middleware with `.use(...)`; use `.useMiddleware(...)`.
- Do not create one route file with many unrelated classes. Keep each `RouteGroup`, controller, middleware, service, action, and reusable frontend component in its own file.
- Do not put business workflows inside route closures. For real features, route to a controller, and extract workflows to service/action classes.
- Do not use `QUERY` as if every external tool understands it; document it clearly for clients and API docs.
- Do not read a WebSocket response from `ctx.res`; WebSocket routes use `ctx.socket`.
- Do not create a new `Request` or `Response` inside route code; use `ctx.req` and `ctx.res`.
