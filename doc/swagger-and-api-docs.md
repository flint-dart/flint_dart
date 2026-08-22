# Swagger And API Docs

Swagger/OpenAPI support has two pieces:

- Runtime serving in `Flint(enableSwaggerDocs: true)`.
- Source generation in `GenerateDocsCommand`, `RouteParser`, `RouteExtractor`, `DocParser`, and `SwaggerGenerator`.

## Serving Docs

Enable routes in the app:

```dart
final app = Flint(enableSwaggerDocs: true);
```

This registers:

- `GET /swagger.json`, serving `docs/swagger.json` or `swagger.json`.
- `GET /docs`, serving bundled Swagger UI if assets can be found.
- `GET /swagger-ui/*`, serving static Swagger UI assets.

Swagger UI lookup checks `FLINT_SWAGGER_UI_DIR`, project-local locations, and finally the package's `lib/swagger/swagger-ui`.

## Generating `docs/swagger.json`

Run:

```bash
dart run flint_dart:flint docs:generate
```

`GenerateDocsCommand` reads every `.dart` file under `lib/routes`, parses route groups and route comments, creates the OpenAPI object, and writes `docs/swagger.json`.

## Route Comments

The sample `example/lib/routes/user_routes.dart` uses comments that the parser understands:

```dart
/// @summary Create a new user
/// @response 200 User registered successfully
/// @response 404 User not found
/// @body {"email": "string", "password": "string"}
app.post('/', controller.create);
```

`RouteParser` also reads:

```dart
String get prefix => '/users';
String get tag => 'Users';
```

If no tag is set, the generated tag is `Default`.

## Path Handling

The generator builds full paths from the `RouteGroup.prefix` and the route path. `RouteExtractor` converts Flint route parameters such as `:id` to OpenAPI-style `{id}`, and `SwaggerGenerator` then extracts those `{name}` segments into path parameters.

## Flint Extensions

`SwaggerGenerator` handles framework-specific routes:

- WebSocket routes get `x-websocket: true`, `x-flint-transport: websocket`, and `x-flint-namespace`.
- `QUERY` routes are stored under `x-flint-query` on the path and collected in `x-flint-query-routes`.

OpenAPI 3.0 has no standard `query` operation key, so this is intentionally custom.

## Important Limits

- Generation is based on source parsing, not the live `Flint` router.
- Only route files under `lib/routes` are parsed.
- The parser expects `RouteGroup` classes and recognizable route-call syntax such as `app.get(...)`, `app.post(...)`, or `app.websocket(...)`.
- Runtime `/swagger.json` does not generate docs; it only serves an existing file.
