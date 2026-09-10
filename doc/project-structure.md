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
  ai.dart                # AI runtime, providers, stores, env, and AI tables
  cache.dart             # app data cache store exports
  db.dart                # DB/query exports
  db_api.dart            # secure Database API resource exports
  model.dart             # Model exports
  middlewares.dart       # middleware exports
  logs.dart              # Log and LogLevel exports
  schema.dart            # Table/Column schema exports
  storage.dart           # public file storage exports
  security.dart          # hashing, JWT, and security utility exports
  session.dart           # session and cookie service exports
  helper.dart            # Str helper exports
  isolate.dart           # IsolateTask exports
  websocket.dart         # WebSocket exports
  ui.dart                # concise Flint UI browser app entrypoint
  flint_ui.dart          # browser entrypoint APIs
  flint_ui_core.dart     # shared Flint UI primitives
  flint_ui_server.dart   # server-side Flint UI rendering APIs
  src/
    app.dart             # Flint app and request loop
    ai_env.dart          # AI provider and production policy env helpers
    ai_database.dart     # Flint DB-backed AI memory and repository adapters
    ai_tables.dart       # canonical AI table definitions
    routing/             # Router, RouteBuilder, RouteGroup
    middleware/          # Middleware implementations
    logs/                # Log, LogLevel, console output, and optional file logs
    cache/               # CacheStore, MemoryCacheStore, and FileCacheStore
    database/            # DB wrappers, ORM, migrations, seeders, DB API
      api/               # secure Database API resources, policies, and routes
    auth/                # Auth facade, config, OAuth providers
    validation/          # Validator
    websocket/           # FlintWebSocket and WebSocketManager
    jobs/                # QueueJob, worker runtime, schedules, and stores
    isolate/             # IsolateTask and IsolateTaskQueue
    swagger_gen/         # route-comment parser and OpenAPI generator
    cli/                 # command implementations
example/
  lib/main.dart          # full sample app
  lib/routes/            # RouteGroup examples
  lib/controllers/       # controller examples
  lib/models/            # Model examples
  lib/ui/                # Flint UI frontend source
  lib/config/            # table/seeder registries
test/                    # behavior tests for framework pieces
```

## Public API Convention

Most application code imports `package:flint_dart/flint_dart.dart`. That file exports the core app, context, request/response, routing, validation, auth, DB/model helpers, middleware, WebSocket, jobs, mail, cache, storage, and related utilities.

Flint is its own Dart-first, object-oriented framework. Do not treat this
package layout as a copy of another ecosystem. Some ideas such as controllers,
models, and migrations are familiar across web frameworks, but Flint's
`Context`, `RouteGroup`, `app.controller(...)`, model tables, fullstack
`lib/ui`, and CLI generators should be learned from the Flint docs and source.

More focused exports also exist:

```dart
import 'package:flint_dart/ai.dart';
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/db_api.dart';
import 'package:flint_dart/auth.dart';
import 'package:flint_dart/cache.dart';
import 'package:flint_dart/middlewares.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/storage.dart';
import 'package:flint_dart/security.dart';
import 'package:flint_dart/session.dart';
import 'package:flint_dart/helper.dart';
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
  seeders/
  jobs/
  isolate/
    tasks/
  ai/
    agents/
    tools/
    workflows/
  middlewares/
  ui/
    main.dart
    component_registry.dart
    pages/
    components/
    sections/
    helpers/
    styles/
    state/
  config/
    ai.dart
    database_api.dart
    table_registry.dart
    seeder_registry.dart
    jobs_registry.dart
  views/
    layouts/
    partials/
  mail/
    views/
docs/
  swagger.json
public/
  assets/js/flint-ui/    # generated browser JavaScript and manifest
  assets/css/flint-ui/   # generated Flint UI CSS
  flint-sw.js            # generated Flint UI service worker
docker/                  # optional Docker files from --make-docker
build/                   # production output from flint build
test/
  helpers/               # app-local HTTP, storage, job, DB, and UI test helpers
  routes/
  controllers/
  middlewares/
  validators/
  storage/
  jobs/
  seeders/
  ui/
```

`DBMigrateCommand` looks specifically for `lib/config/table_registry.dart` when no table list is passed directly. `GenerateDocsCommand` looks specifically for Dart files under `lib/routes`.

AI source should be organized by responsibility. Put `AiAgent` classes under
`lib/ai/agents`, `AiTool` classes under `lib/ai/tools`, named `AiWorkflow`
classes under `lib/ai/workflows`, and boot wiring in `lib/config/ai.dart`.
Read `docs/ai.md` before changing AI providers, memory stores, run, thread,
trace, or artifact persistence, DB-backed AI tables, or production tool policy.

Flint UI source belongs under `lib/ui`. Treat `public/assets/js/flint-ui/`,
`public/assets/css/flint-ui/`, and `public/flint-sw.js` as generated output.
Read `docs/frontend-ui.md`, `docs/ui-widgets.md`, and
`docs/build-and-rendering.md` before changing pages, components, forms, buttons,
layouts, overlays, tables, charts, storage, navigation, browser entrypoints,
generated bundles, page registry behavior, or SSR. Pages belong in
`lib/ui/pages`, reusable components in `lib/ui/components`, larger page sections
in `lib/ui/sections`, view helper functions in `lib/ui/helpers`, shared styles
in `lib/ui/styles`, and frontend state holders in `lib/ui/state`.

App tests belong under `test/` and should follow the same one-class-per-file
habit as app code. Read `docs/testing.md` before adding route, controller,
middleware, validator, storage, job, seeder, or UI component tests.

Server-rendered HTML templates belong under `lib/views`. Mail templates belong
under `lib/mail/views` and should be owned by `ViewMailable` classes under
`lib/mail`. Read `docs/templates.md` before changing template syntax,
partials, layouts, assets, sessions, or mail HTML.

## Naming Conventions

CLI generators convert class-ish names to snake-case files. Use the `--make-*`
generator commands in new work; the older `make:*` aliases are deprecated and
will be removed in Flint Dart `1.5.0`.

- `--make-model BlogPost` creates `lib/models/blog_post.dart`.
- `--make-seeder RoleSeeder` creates `lib/seeders/role_seeder.dart` and registers it in `lib/config/seeder_registry.dart`.
- `--make-isolate GenerateReport` creates `lib/isolate/tasks/generate_report_task.dart`.
- `--make-controller BlogPostController` creates `lib/controllers/blog_post_controller.dart`.
- `--make-route BlogPost` creates `lib/routes/blog_post_routes.dart` with class `BlogPostRoutes`.
- `--make-ui --page Dashboard` creates `lib/ui/pages/dashboard_page.dart`.
- `--make-ui --component ProjectCard` creates `lib/ui/components/project_card.dart`.
- `--make-ui --section Hero` creates `lib/ui/sections/hero_section.dart`.

The generated model table name is a simple pluralization of the file stem plus `s`, for example `blog_posts`.

Use one file per Dart type and per reusable UI builder. A function or helper that
returns `View`, `Node`, `FlintNode`, or `FlintComponent` should live in its own
file once it is extracted from a component.

## Important Limits

- The CLI writes files directly and skips creation if the target file already exists.
- The migration command depends on a registry file that can be spawned as an isolate.
- `docs/swagger.json` is generated from source comments, not from live route registration.
- `doc/api` contains generated API docs; do not treat it as the source of behavior.
- `public/assets/js/flint-ui/`, `public/assets/css/flint-ui/`, and
  `public/flint-sw.js` are generated by `flint web` or `flint build`.
- `docker/` is generated by `--make-docker` when used.
- `build/` is generated by `flint build`.
