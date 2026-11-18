# Swagger And API Docs

Flint API docs are generated from route source comments. The route file is the
source of truth; `docs/swagger.json` is generated output.

Use this guide when adding, reviewing, or fixing API documentation in a Flint
app. Anyone should be able to read a route group, document the route
comments, run the generator, and know what Swagger UI will show.

Before documenting an app, inspect:

- `lib/main.dart` for `Flint(enableSwaggerDocs: true)`, registered route groups, and mounted modules.
- `lib/routes/` for the `RouteGroup` classes the generator will parse.
- `lib/controllers/` for the real request behavior.
- `lib/middlewares/` for auth, role, tenant, or rate-limit middleware that must be reflected with `@auth` or response codes.
- `lib/models/` and resource/presenter classes for response shapes.
- `docs/authentication.md` before documenting auth, password reset, send OTP, verify OTP, resend OTP, refresh token, or OAuth routes.
- `docs/routing.md` before documenting route params, `QUERY`, WebSockets, route groups, or controller routes.
- `docs/validation.md` before documenting request bodies and validation failures.

Framework source to inspect when behavior is unclear:

- `lib/src/cli/generate_docs_command.dart`
- `lib/src/swagger_gen/route_parser.dart`
- `lib/src/swagger_gen/route_extractor.dart`
- `lib/src/swagger_gen/doc_parser.dart`
- `lib/src/swagger_gen/swagger_generator.dart`
- `lib/src/app.dart`

## The Workflow

1. Put routes in `lib/routes/<feature>_routes.dart`.
2. Use one `RouteGroup` class per route file.
3. Set `String get prefix => '/feature';`.
4. Set `String get tag => 'Feature';`.
5. Put `///` docs directly above each route call.
6. Run `dart run flint_dart:flint --docs-generate`.
7. Commit route source comments and generated `docs/swagger.json` when the app wants generated docs tracked.
8. Serve docs with `Flint(enableSwaggerDocs: true)`.

Do not hand-edit `docs/swagger.json` as the primary fix. Update route comments,
then regenerate.

## Serving Swagger UI

Enable docs routes in the app:

```dart
final app = Flint(enableSwaggerDocs: true);
```

This registers:

- `GET /swagger.json`, serving `docs/swagger.json` first, then `swagger.json`.
- `GET /docs`, serving bundled Swagger UI when assets can be found.
- `GET /swagger-ui/*`, serving static Swagger UI assets.

Swagger UI lookup checks:

- `FLINT_SWAGGER_UI_DIR`
- project-local `swagger-ui`
- project-local `build/swagger-ui`
- project-local `lib/swagger/swagger-ui`
- framework/package Swagger UI asset locations

Runtime `/swagger.json` does not generate docs. It only serves an existing
Swagger file. Run `--docs-generate` first.

## Generating `docs/swagger.json`

Run:

```bash
dart run flint_dart:flint --docs-generate
```

`GenerateDocsCommand` reads every `.dart` file under `lib/routes` recursively.
It parses route groups, route paths, route comments, request bodies, parameters,
responses, auth markers, servers, WebSocket routes, and Flint `QUERY` routes.
It then writes:

```text
docs/swagger.json
```

The generated object uses OpenAPI `3.0.0`, the default title `Flint API`, and
the default version `1.0.0`.

## What The Generator Parses

The generator parses route calls inside classes that extend `RouteGroup`.

Recognized route calls:

```dart
app.get('/path', handler);
app.post('/path', handler);
app.put('/path', handler);
app.patch('/path', handler);
app.delete('/path', handler);
app.query('/path', handler);
app.websocket('/path', handler);
routes.get('/path', (controller) => controller.index());
routes.post('/path', (controller) => controller.store());
```

The parser also recognizes route calls split across chains when the route
variable and method are easy to see:

```dart
routes
    .post('/', (controller) => controller.store())
    .useMiddleware(AuthMiddleware());
```

Prefer keeping the route method visible as `routes.post(...)`,
`courses.get(...)`, or `app.websocket(...)`. Do not hide route registration
behind helper methods if you expect `--docs-generate` to find it.

Current parser limits:

- It only parses files under `lib/routes`.
- It only records routes found inside `RouteGroup` classes.
- It does not inspect controller methods.
- It does not infer auth from middleware; use `@auth`.
- It does not infer request bodies from `req.validate(...)`; use `@body`.
- It does not infer query parameters from `req.queryParam(...)`; use `@query`.
- It does not parse arbitrary `app.route('METHOD', ...)` calls yet.
- It creates JSON request bodies only; multipart upload schemas need generator work before they can be represented precisely.

## RouteGroup Prefix And Tag

Use the `RouteGroup` getters for normal docs:

```dart
class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';

  @override
  String get tag => 'Courses';

  @override
  void register(Flint app) {
    final courses = app.controller(CourseController.new);

    /// @summary List courses
    /// @response 200 Courses loaded
    courses.get('/', (controller) => controller.index());
  }
}
```

Swagger will see:

```json
{
  "paths": {
    "/courses": {
      "get": {
        "summary": "List courses",
        "tags": ["Courses"],
        "responses": {
          "200": {"description": "Courses loaded"}
        }
      }
    }
  }
}
```

If no `tag` getter is found, the operation tag becomes `Default`.

`@prefix` also exists, but use it carefully. It overrides the prefix used by the
docs generator. If `@prefix` does not match the real `RouteGroup.prefix`, Swagger
will show a different path from the runtime app.

Prefer this:

```dart
String get prefix => '/courses';
```

Avoid this unless you intentionally need a docs-only override:

```dart
/// @prefix /api/courses
class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';
}
```

## Route Comment Placement

Put route comments immediately above the route call they describe.

```dart
/// @summary Create course
/// @response 201 Course created
/// @response 422 Validation failed
/// @body {"title": "string", "status": "string"}
courses.post('/', (controller) => controller.store());
```

Do not put route docs only above the controller method. The generator reads
`lib/routes`, not controller action bodies.

Good:

```dart
/// @summary Show course
/// @param id path string required Course ID
/// @response 200 Course loaded
/// @response 404 Course not found
courses.get('/:id', (controller) => controller.show());
```

Not enough for Swagger generation:

```dart
class CourseController extends Controller {
  /// @summary Show course
  Future<Response> show() async {
    return res.json({'data': await Course().find(req.param('id'))});
  }
}
```

## Supported Annotations

### `@summary`

Sets the operation summary.

```dart
/// @summary Register a new user
auth.post('/register', (controller) => controller.register());
```

Swagger will see:

```json
{"summary": "Register a new user"}
```

Keep summaries short and action-based: `List courses`, `Create course`,
`Verify email OTP`, `Refresh access token`.

### `@response`

Adds a response status code and description.

```dart
/// @response 200 User loaded
/// @response 401 Unauthorized
/// @response 404 User not found
users.get('/:id', (controller) => controller.show());
```

The first token after `@response` is the status code. Everything after it is the
description.

Swagger will see:

```json
{
  "responses": {
    "200": {"description": "User loaded"},
    "401": {"description": "Unauthorized"},
    "404": {"description": "User not found"}
  }
}
```

If a route has no `@response`, Flint generates:

```json
{"200": {"description": "OK"}}
```

Common response codes:

- `200` for successful reads and updates.
- `201` for created resources.
- `202` for accepted background work.
- `204` for successful empty responses.
- `400` for malformed input.
- `401` for unauthenticated requests.
- `403` for authenticated users without permission.
- `404` for missing resources.
- `409` for conflicts.
- `422` for validation failures.
- `429` for rate limits.
- `500` for unexpected server errors.

### `@param`

Documents a parameter in `path`, `query`, `header`, or another OpenAPI parameter
location.

Format:

```text
@param <name> <location> <type> <required|optional> <description>
```

Example:

```dart
/// @summary Show course
/// @param id path string required Course ID
/// @response 200 Course loaded
/// @response 404 Course not found
courses.get('/:id', (controller) => controller.show());
```

Flint automatically converts `:id` in the route path to `{id}` and creates a
string path parameter. Use `@param` when you want a better type or description.

Swagger will see:

```json
{
  "paths": {
    "/courses/{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "string"},
            "description": "Course ID"
          }
        ]
      }
    }
  }
}
```

Path parameters are always marked required, even if the annotation says
`optional`, because OpenAPI requires path params to be required.

### `@query`

Documents a query-string parameter.

Format:

```text
@query <name> <type> <required|optional> <description>
```

Example:

```dart
/// @summary List courses
/// @query page integer optional Page number
/// @query perPage integer optional Items per page
/// @query status string optional Filter by course status
/// @response 200 Courses loaded
courses.get('/', (controller) => controller.index());
```

Swagger will see query parameters on the operation:

```json
{
  "parameters": [
    {
      "name": "page",
      "in": "query",
      "schema": {"type": "integer"},
      "required": false,
      "description": "Page number"
    }
  ]
}
```

Use OpenAPI type names such as `string`, `integer`, `number`, `boolean`,
`array`, and `object`.

### `@body`

Documents a JSON request body.

Example:

```dart
/// @summary Create course
/// @response 201 Course created
/// @response 422 Validation failed
/// @body {"title": "string", "price": "number", "published": "boolean"}
courses.post('/', (controller) => controller.store());
```

Swagger will see:

```json
{
  "requestBody": {
    "required": true,
    "content": {
      "application/json": {
        "schema": {
          "type": "object",
          "properties": {
            "title": {"type": "string"},
            "price": {"type": "number"},
            "published": {"type": "boolean"}
          }
        }
      }
    }
  }
}
```

`@body` accepts balanced JSON across multiple doc lines:

```dart
/// @body {
///   "email": "string",
///   "password": "string",
///   "profile": {
///     "firstName": "string",
///     "lastName": "string"
///   },
///   "roles": "string[]"
/// }
auth.post('/register', (controller) => controller.register());
```

Supported type hints inside `@body`:

- `"string"`
- `"integer"`
- `"number"`
- `"boolean"`
- `"object"`
- `"array"`
- `"string[]"`, `"integer[]"`, `"number[]"`, or `"boolean[]"`
- example values such as `1`, `1.5`, `true`, `null`, nested objects, and arrays

Current `@body` generation does not mark individual properties as required.
Document validation failures with `@response 422 Validation failed` and keep the
real validation rules in the controller or validator class.

### `@auth`

Adds OpenAPI security to the operation.

```dart
/// @summary Current user
/// @auth bearer
/// @response 200 Current user loaded
/// @response 401 Unauthorized
auth.get('/me', (controller) => controller.me())
    .useMiddleware(AuthMiddleware());
```

Swagger will see:

```json
{
  "security": [
    {"bearer": []}
  ]
}
```

If `@auth` has no value, Flint uses `bearer`.

```dart
/// @auth
```

Built-in security schemes in generated Swagger:

```json
{
  "bearer": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"},
  "basicAuth": {"type": "http", "scheme": "basic"}
}
```

Use `@auth bearer` for JWT and token-protected routes. Use `@auth basicAuth`
only when the route actually uses HTTP Basic auth. If a route has auth
middleware but no `@auth`, Swagger will look public.

### `@server`

Adds a server URL to the generated top-level `servers` list.

```dart
/// @summary List public courses
/// @server https://api.example.com
/// @server http://localhost:3000
/// @response 200 Courses loaded
courses.get('/', (controller) => controller.index());
```

Swagger will see:

```json
{
  "servers": [
    {"url": "https://api.example.com"},
    {"url": "http://localhost:3000"}
  ]
}
```

Servers are collected globally and deduplicated. They are not stored only on
that one route.

### `@prefix`

Overrides the route-group prefix for generated docs.

```dart
/// @prefix /api/courses
```

Use the `RouteGroup.prefix` getter for normal app code. Use `@prefix` only when
the source parser cannot see the actual prefix or when you intentionally need a
docs-only prefix. A wrong `@prefix` makes Swagger paths differ from runtime
paths.

## Complete CRUD Example

File: `lib/routes/course_routes.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../controllers/course_controller.dart';
import '../middlewares/auth_middleware.dart';

class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';

  @override
  String get tag => 'Courses';

  @override
  void register(Flint app) {
    final courses = app.controller(CourseController.new);

    /// @summary List courses
    /// @query page integer optional Page number
    /// @query perPage integer optional Items per page
    /// @query status string optional Filter by status
    /// @response 200 Courses loaded
    courses.get('/', (controller) => controller.index());

    /// @summary Create course
    /// @auth bearer
    /// @response 201 Course created
    /// @response 401 Unauthorized
    /// @response 422 Validation failed
    /// @body {"title": "string", "status": "string"}
    courses.post('/', (controller) => controller.store())
        .useMiddleware(AuthMiddleware());

    /// @summary Show course
    /// @param id path string required Course ID
    /// @response 200 Course loaded
    /// @response 404 Course not found
    courses.get('/:id', (controller) => controller.show());

    /// @summary Update course
    /// @auth bearer
    /// @param id path string required Course ID
    /// @response 200 Course updated
    /// @response 401 Unauthorized
    /// @response 404 Course not found
    /// @response 422 Validation failed
    /// @body {"title": "string", "status": "string"}
    courses.patch('/:id', (controller) => controller.update())
        .useMiddleware(AuthMiddleware());

    /// @summary Delete course
    /// @auth bearer
    /// @param id path string required Course ID
    /// @response 204 Course deleted
    /// @response 401 Unauthorized
    /// @response 404 Course not found
    courses.delete('/:id', (controller) => controller.destroy())
        .useMiddleware(AuthMiddleware());
  }
}
```

Swagger will see:

- `/courses` with `get` and `post`.
- `/courses/{id}` with `get`, `patch`, and `delete`.
- tag `Courses` on every operation.
- bearer security only on routes that have `@auth bearer`.
- path parameter `id` on ID routes.
- query parameters on the list route.
- JSON request bodies on create and update routes.

## Auth And OTP Routes

Auth routes should be documented carefully because clients need to know which
routes are public, which route sends an OTP, and which route verifies one.

Example:

```dart
class AuthRoutes extends RouteGroup {
  @override
  String get prefix => '/auth';

  @override
  String get tag => 'Auth';

  @override
  void register(Flint app) {
    final auth = app.controller(AuthController.new);

    /// @summary Register account
    /// @response 201 Account registered
    /// @response 409 Email already exists
    /// @response 422 Validation failed
    /// @body {"email": "string", "password": "string", "name": "string"}
    auth.post('/register', (controller) => controller.register());

    /// @summary Send email verification OTP
    /// @response 200 OTP sent
    /// @response 404 Account not found
    /// @response 422 Validation failed
    /// @body {"email": "string"}
    auth.post('/send-otp', (controller) => controller.sendOtp());

    /// @summary Verify email OTP
    /// @response 200 Email verified
    /// @response 400 Invalid or expired OTP
    /// @response 422 Validation failed
    /// @body {"email": "string", "otp": "string"}
    auth.post('/verify-otp', (controller) => controller.verifyOtp());

    /// @summary Resend email verification OTP
    /// @response 200 OTP resent
    /// @response 404 Account not found
    /// @response 429 Too many requests
    /// @response 422 Validation failed
    /// @body {"email": "string"}
    auth.post('/resend-otp', (controller) => controller.resendOtp());

    /// @summary Current user
    /// @auth bearer
    /// @response 200 Current user loaded
    /// @response 401 Unauthorized
    auth.get('/me', (controller) => controller.me())
        .useMiddleware(AuthMiddleware());
  }
}
```

Do not mark public login, register, send OTP, verify OTP, or forgot-password
routes with `@auth bearer` unless they truly require an existing token. Do mark
current-user, logout, token refresh, and protected account routes when they need
auth.

## `QUERY` Routes

Flint supports HTTP `QUERY` for safe, idempotent reads with a request body.
OpenAPI 3.0 has no standard `query` operation key, so Flint stores it as a
vendor extension.

Route:

```dart
/// @summary Search courses
/// @query page integer optional Page number
/// @response 200 Search results loaded
/// @body {"q": "string", "status": "string"}
courses.query('/search', (controller) => controller.search());
```

Swagger will see:

```json
{
  "paths": {
    "/courses/search": {
      "x-flint-query": {
        "x-http-method": "QUERY",
        "x-openapi-operation-key-unavailable": true,
        "summary": "Search courses"
      }
    }
  },
  "x-flint-query-routes": {
    "/courses/search": {
      "x-http-method": "QUERY"
    }
  },
  "x-flint-query-openapi-note": "OpenAPI 3.0 has no standard QUERY operation key. Flint preserves HTTP QUERY operations with x-http-method: QUERY."
}
```

Swagger UI may not display `QUERY` like standard `GET` or `POST` operations.
Clients should read the Flint extension fields.

## WebSocket Routes

Document the WebSocket handshake route where the client connects.

Route:

```dart
class ChatRoutes extends RouteGroup {
  @override
  String get prefix => '/ws';

  @override
  String get tag => 'Chat';

  @override
  void register(Flint app) {
    /// @summary Chat websocket handshake
    /// @param room path string required Chat room
    /// @response 101 Switching Protocols
    app.websocket('/chat/:room', (Context ctx) {
      ctx.socket?.emit('ready', {'ok': true});
    });
  }
}
```

Swagger will see a `GET` operation with WebSocket extensions:

```json
{
  "paths": {
    "/ws/chat/{room}": {
      "get": {
        "summary": "Chat websocket handshake",
        "x-websocket": true,
        "x-flint-transport": "websocket",
        "x-flint-namespace": "/ws/chat/{room}",
        "responses": {
          "101": {"description": "Switching Protocols"}
        }
      }
    }
  },
  "x-websockets": {
    "/ws/chat/{room}": {
      "x-websocket": true,
      "x-flint-transport": "websocket"
    }
  }
}
```

Document event names, payloads, and room behavior in `docs/websockets.md` or a
feature-specific markdown file. Swagger describes only the connection endpoint.

## File Upload Routes

The current generator creates `application/json` request bodies from `@body`.
It does not yet create precise `multipart/form-data` schemas.

For upload routes, document what the route does, auth, status codes, and the
file field name in the summary or body description until multipart support is
added.

Example:

```dart
/// @summary Upload profile avatar using multipart field "avatar"
/// @auth bearer
/// @response 200 Avatar uploaded
/// @response 401 Unauthorized
/// @response 422 Avatar file is required or invalid
profile.post('/avatar', (controller) => controller.uploadAvatar())
    .useMiddleware(AuthMiddleware());
```

## What To Document On Every Route

For each route, include:

- `@summary` with a short action phrase.
- `@response` for success.
- `@response` for validation, auth, not-found, conflict, and rate-limit outcomes that can happen.
- `@param` for every meaningful path parameter.
- `@query` for every supported query-string parameter.
- `@body` for JSON payloads on create, update, login, OTP, and search routes.
- `@auth bearer` or `@auth basicAuth` when middleware or controller behavior requires auth.

A protected mutation should usually have:

```dart
/// @summary Publish course
/// @auth bearer
/// @param id path string required Course ID
/// @response 200 Course published
/// @response 401 Unauthorized
/// @response 403 Forbidden
/// @response 404 Course not found
/// @response 422 Validation failed
courses.post('/:id/publish', (controller) => controller.publish())
    .useMiddleware(AuthMiddleware());
```

## Good Documentation Style

Prefer specific language:

- `Create course`
- `Verify email OTP`
- `Refresh access token`
- `Upload profile avatar`
- `List published courses`

Avoid vague language:

- `Get data`
- `Do request`
- `User API`
- `Success response description`
- `Create item by id` for a route that does not use an ID

Keep route comments close to route behavior. If the controller changes from
`200` to `201`, update the route comments before regenerating docs.

## Generated Output Shape

The generated Swagger file has this shape:

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "Flint API",
    "version": "1.0.0"
  },
  "servers": [],
  "paths": {},
  "x-websockets": {},
  "x-flint-query-routes": {},
  "components": {
    "securitySchemes": {
      "bearer": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT"
      },
      "basicAuth": {
        "type": "http",
        "scheme": "basic"
      }
    }
  }
}
```

Empty extension fields are omitted. `servers` is omitted when no `@server`
annotation is present.

## Common Mistakes

- Do not document only controller methods; document the route calls in `lib/routes`.
- Do not hand-edit `docs/swagger.json` instead of fixing route comments.
- Do not use `@prefix` unless it matches runtime routing or you intentionally need a docs-only override.
- Do not forget `@auth` on protected routes; middleware is not inferred.
- Do not put fake `401` responses on public routes unless the route can actually return `401`.
- Do not add `@body` to every route; use it for routes that read JSON bodies.
- Do not rely on the generator to infer `req.validate(...)`; write `@body`, `@query`, and `@param`.
- Do not split route registration through custom helper methods if the generator needs to see it.
- Do not expect `app.route('OPTIONS', ...)` to be parsed until route-extractor support is added.
- Do not treat `QUERY` as a standard OpenAPI method; Flint stores it in extension fields.
- Do not expect Swagger to describe WebSocket event payloads; document those in `docs/websockets.md`.

## Review Checklist

Before running `--docs-generate`, check:

1. Every public API route lives in `lib/routes`.
2. Every route group has a real `prefix` and useful `tag`.
3. Every route has a specific `@summary`.
4. Every route has realistic success and error `@response` entries.
5. Every `:id` or path variable has a matching `@param` when type or description matters.
6. Every query filter, pagination value, or search option has `@query`.
7. Every JSON body has `@body`.
8. Every protected route has `@auth`.
9. Auth and OTP routes were checked against `docs/authentication.md`.
10. WebSocket routes were checked against `docs/websockets.md`.
11. `docs/swagger.json` was regenerated after route comments changed.
