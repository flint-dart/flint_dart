# Project Structure

The framework package is organized around public export files, implementation files under `lib/src`, a CLI under `bin` and `lib/src/cli`, tests, and a sample app.

## Main Package Areas

```text
bin/
  flint_dart.dart        # CLI entrypoint
  hot_reload.dart        # hot reload worker entrypoint
lib/
  flint_dart.dart        # main public framework export
  auth.dart              # auth exports
  db.dart                # DB/query exports
  model.dart             # Model exports
  middlewares.dart       # middleware exports
  schema.dart            # Table/Column schema exports
  websocket.dart         # WebSocket exports
  src/
    app.dart             # Flint app and request loop
    routing/             # Router, RouteBuilder, RouteGroup
    middleware/          # Middleware implementations
    database/            # DB wrappers, ORM, migrations, seeders
    auth/                # Auth facade, config, OAuth providers
    validation/          # Validator
    websocket/           # FlintWebSocket and WebSocketManager
    swagger_gen/         # route-comment parser and OpenAPI generator
    cli/                 # command implementations
example/
  lib/main.dart          # full sample app
  lib/routes/            # RouteGroup examples
  lib/controllers/       # controller examples
  lib/models/            # Model examples
  lib/config/            # table/seeder registries
test/                    # behavior tests for framework pieces
```

## Public API Convention

Most application code imports `package:flint_dart/flint_dart.dart`. That file exports the core app, context, request/response, routing, validation, auth, DB/model helpers, middleware, WebSocket, jobs, mail, cache, storage, and related utilities.

More focused exports also exist:

```dart
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/auth.dart';
import 'package:flint_dart/middlewares.dart';
```

The example models use focused imports:

```dart
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';
```

## Application Layout

Generated and example apps follow this pattern:

```text
lib/
  main.dart
  controllers/
  routes/
  models/
  middlewares/
  config/
    table_registry.dart
    seeder_registry.dart
  views/
docs/
  swagger.json
public/
```

`DBMigrateCommand` looks specifically for `lib/config/table_registry.dart` when no table list is passed directly. `GenerateDocsCommand` looks specifically for Dart files under `lib/routes`.

## Naming Conventions

CLI generators convert class-ish names to snake-case files:

- `make:model BlogPost` creates `lib/models/blog_post.dart`.
- `make:controller BlogPostController` creates `lib/controllers/blog_post_controller.dart`.
- `make:route BlogPost` creates `lib/routes/blog_post_routes.dart` with class `BlogPostRoutes`.

The generated model table name is a simple pluralization of the file stem plus `s`, for example `blog_posts`.

## Important Limits

- The CLI writes files directly and skips creation if the target file already exists.
- The migration command depends on a registry file that can be spawned as an isolate.
- `docs/swagger.json` is generated from source comments, not from live route registration.
- `doc/api` contains generated API docs; do not treat it as the source of behavior.
