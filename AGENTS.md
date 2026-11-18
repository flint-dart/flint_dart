# AGENTS.md

This file teaches AI coding agents how to work in the `flint_dart` framework repository.

## Scope

The framework package is `D:\eulogia-tech\flint\flint_dart`. Work from this directory unless the user explicitly asks about another sibling project.

## Architecture To Respect

- `lib/src/app.dart` owns `Flint`, route registration, middleware pipeline execution, hot reload startup, Swagger serving, database bootstrapping, WebSocket upgrades, jobs startup, and result serialization.
- `lib/src/routing/` owns route matching and route groups. Do not replace it with a third-party router.
- `lib/src/context.dart` defines the unified `Handler` API for HTTP and WebSocket routes.
- `lib/src/request.dart` and `lib/src/response.dart` are the public request/response wrappers. Preserve their compatibility with legacy `(Request, Response)` handlers.
- `lib/src/middleware/` contains the middleware contract and default middleware. Global middleware must tolerate WebSocket contexts where `ctx.res == null`.
- `lib/src/database/` contains DB wrappers, ORM query builder, models, migrations, transactions, seeders, and relations. Keep MySQL and PostgreSQL behavior in sync.
- `lib/src/auth/` is a static facade around auth config, login/register, OAuth, reset/verification tokens, refresh tokens, and TOTP.
- `lib/src/swagger_gen/` is a source parser for route files. It is not runtime introspection.
- `lib/src/cli/commands.dart` is the CLI command registry and alias map.
- `example/lib` and `test` are the best places to find real usage.

## Files To Inspect Before Changes

- Routing changes: `lib/src/app.dart`, `lib/src/routing/router.dart`, `lib/src/routing/route_builder.dart`, `lib/src/routing/route_group.dart`, `test/app_test.dart`, `test/controller_test.dart`.
- Middleware changes: `lib/src/context.dart`, `lib/src/middleware/middleware.dart`, the specific middleware file, `test/middleware_test.dart`.
- Request/response changes: `lib/src/request.dart`, `lib/src/response.dart`, `test/request_response_test.dart`.
- Model/DB changes: `lib/src/database/db.dart`, `lib/src/database/orm/query_builder.dart`, `lib/src/database/model/model.dart`, `lib/src/database/model/model_crud.dart`, `lib/src/database/model/model_query.dart`, `lib/src/database/migrations.dart`, related tests.
- Auth changes: `lib/src/auth/auth.dart`, `lib/src/auth/auth_config.dart`, `lib/src/auth/auth_service.dart`, `lib/src/security/jwt.dart`, `test/auth_test.dart`.
- Validation changes: `lib/src/validation/validator.dart`, `lib/src/error/validation_exception.dart`, `test/validator_test.dart`.
- WebSocket changes: `lib/src/websocket/websocket.dart`, `lib/src/websocket/websocket_manager.dart`, `lib/src/websocket/ws_router.dart`, `test/websocket_test.dart`.
- Swagger changes: `lib/src/swagger_gen/*`, `lib/src/cli/generate_docs_command.dart`, `test/swagger_generator_test.dart`.
- CLI changes: `bin/flint_dart.dart`, `lib/src/cli/commands.dart`, the specific command file, CLI tests.
- Agent-doc generation changes: `lib/src/cli/agent_docs_command.dart`, `bin/flint_dart.dart`, and `lib/src/cli/create_project_command.dart`.

## Preferred Patterns

- Keep public imports stable. App code should usually import `package:flint_dart/flint_dart.dart` or focused exports like `model.dart`, `schema.dart`, and `auth.dart`.
- Preserve both handler styles: unified `Handler(Context ctx)` and legacy `(Request req, Response res)` callbacks.
- Preserve controller binding semantics: `controllerAction()` creates and binds a controller per request, then unbinds it in `finally`.
- For new routes in examples or generated code, use `RouteGroup` classes with `prefix`, optional `tag`, and `register(Flint app)`.
- For route middleware, use `.useMiddleware(...)`; there is no verified `.use(...)` route-builder alias.
- For models, prefer `getAttribute<T>()`, `setAttribute()`, `toMap()`, and `Table` schema definitions. Keep `conceal` behavior intact.
- For SQL, use `DB.query/execute` parameters or `QueryBuilder`. Do not interpolate request input.
- For migrations, remember `Table` auto-adds `id`, and migrations inject timestamps and may drop undeclared columns.
- For validation, keep unknown-field rejection unless changing tests and docs intentionally.
- For WebSockets, keep room names namespace-scoped.
- For docs generation, update parser tests whenever changing recognized comment tags or route syntax.
- For app AI guidance, keep `flint agent` safe for existing projects: skip files by default and require `--force` to overwrite.

## Do Not Replace Or Rewrite

- Do not replace the custom `Flint` request loop with shelf, express-style adapters, or another web framework.
- Do not replace the custom ORM/query builder with an external ORM.
- Do not remove support for MySQL or PostgreSQL normalization.
- Do not remove legacy handler compatibility.
- Do not rewrite generated `doc/api` files when changing source behavior.
- Do not assume many-to-many relation loading is implemented; `belongsToMany` and `hasManyThrough` currently return empty lists.
- Do not make Swagger claims that are not supported by `RouteParser` and `SwaggerGenerator`.
- Do not bypass `apply_patch` for manual file edits.

## Verification

Run focused tests after changes:

```bash
dart test test/app_test.dart
dart test test/controller_test.dart
dart test test/middleware_test.dart
dart test test/validator_test.dart
dart test test/websocket_test.dart
dart test test/swagger_generator_test.dart
```

Use the actual existing test names; if a listed file changes or is removed, inspect `test/` and choose the nearest focused test. For broad framework changes, run:

```bash
dart test
```
