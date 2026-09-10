# AGENTS.md

This is a Flint Dart application named `{{project_name}}`.

AI coding agents should use the local app structure first, then inspect the installed `flint_dart` package only when framework behavior is unclear.

## Docs First

Before coding, read the local Flint docs for the topic you are changing. These files are copied into the developer app by `flint agent`, so prefer them over guessing from memory.

- New app setup or boot flow: `docs/getting-started.md`
- Folder layout and source ownership: `docs/project-structure.md`
- Routes, `RouteGroup`, handlers, controllers, `Request` helpers, and route middleware: `docs/routing.md`
- Middleware, guards, request pipeline behavior, CORS, and auth checks: `docs/middleware.md`
- Logging, log levels, request logs, job logs, and error logs: `docs/logging.md`
- Testing routes, controllers, middleware, validators, storage, jobs, seeders,
  and UI components: `docs/testing.md`
- Cache stores, response cache headers, ETags, and response-vs-app-data caching: `docs/cache.md`
- AI runtime, providers, tools, workflows, memory stores, run, thread, trace, artifact persistence, and DB-backed AI tables: `docs/ai.md`
- Build output, `flint build`, `flint web`, browser entrypoints, generated bundles, page registry, and SSR: `docs/build-and-rendering.md`
- Deployment, Docker generation, production server process, env variables, static files, migrations, and jobs workers: `docs/deployment.md`
- Models, tables, migrations, queries, and database changes: `docs/models-and-database.md`
- Secure Database API resources, resource policies, protocol queries, and client data access: `docs/database-api.md`
- Seeders, seeder registries, `autoSeed`, and fixture data: `docs/seeders.md`
- Queue jobs, background workers, schedules, and isolate-vs-job decisions: `docs/jobs-and-workers.md`
- Isolate tasks, CPU-heavy work, and `IsolateTask.perform(...)`: `docs/isolate-tasks.md`
- Login, registration, current user, JWT, refresh tokens, OAuth, password reset, and OTP verification: `docs/authentication.md`
- Server sessions, cookies, flash messages, and browser auth session storage: `docs/sessions-and-cookies.md`
- Mail config, `ViewMailable`, email templates, OTP mail delivery, and queued sends: `docs/mail.md`
- HTML templates, `{{ }}`, variables, includes, layouts, sections, control flow,
  assets, sessions, comments, and mail templates: `docs/templates.md`
- Public file uploads, `Storage`, and upload safety: `docs/storage.md`
- `Hashing`, JWT helpers, security middleware, rate-limit guidance, exceptions, and `Str`: `docs/security-and-utilities.md`
- Flint UI pages, component structure, frontend source layout, and reusable UI files: `docs/frontend-ui.md`
- Flint UI widgets, `FlintComponent`, `StatefulComponent`, `StatelessComponent`, `FlintNode`, `View`, `style` maps, `DartStyle`, `StateSignal`, forms, buttons, layouts, overlays, tables, charts, browser storage, and navigation: `docs/ui-widgets.md`
- Flint UI build output, browser entrypoints, generated bundles, page registry behavior, and SSR: `docs/build-and-rendering.md`
- Request validation rules and error handling: `docs/validation.md`
- WebSocket routes, rooms, and realtime handlers: `docs/websockets.md`
- Swagger comments, OpenAPI generation, and `docs/swagger.json`: `docs/swagger-and-api-docs.md`
- CLI commands and generators: `docs/cli.md`
- Building a complete feature end to end: `docs/building-a-feature.md`
- Reusable Flint conventions and common implementation patterns: `docs/common-patterns.md`

For example, if the task is "add an auth check", read `docs/authentication.md`, `docs/middleware.md`, and `docs/sessions-and-cookies.md` first, then inspect the app's auth middleware, routes, controllers, and user model before editing code. If the task sends or verifies an OTP, also read `docs/mail.md` and `docs/templates.md`, then inspect the app's mail class and template.

## Inspect First

- `pubspec.yaml` for package name and dependencies.
- `lib/main.dart` for `Flint(...)`, global middleware, route registration, static assets, database flags, and `listen(...)`.
- `test/` for existing app testing style, helpers, fakes, and coverage.
- `lib/routes/` for `RouteGroup` classes.
- `lib/controllers/` for request handlers.
- `lib/models/` for `Model<T>` classes and `Table` schemas.
- `lib/config/database_api.dart` before exposing models through the Database API, when present.
- `lib/config/ai.dart`, `lib/ai/`, and `docs/ai.md` before changing AI providers, agents, tools, workflows, memory, or persistence.
- `lib/seeders/` for `Seeder` classes.
- `lib/jobs/` for `QueueJob` classes.
- `lib/isolate/` for `IsolateTask` classes.
- `lib/middlewares/` for app-specific middleware.
- `lib/views/` for server-rendered HTML templates.
- `lib/mail/` and `lib/mail/views/` for mailable classes and mail templates.
- `lib/ui/` for Flint UI frontend source, including pages, components, sections, and registries.
- `docs/frontend-ui.md` and `docs/ui-widgets.md` before changing Flint UI pages, components, forms, buttons, layouts, overlays, tables, charts, browser storage, navigation, or state.
- `docs/logging.md` before changing request logs, job logs, error logs, or replacing `print(...)`.
- `docs/testing.md` before adding or fixing tests for routes, controllers,
  middleware, validators, storage, jobs, seeders, or UI components.
- `docs/templates.md` before changing server-rendered HTML, `{{ }}`,
  includes, layouts, sections, control flow, assets, session helpers, or mail
  template syntax.
- `public/` before changing public file upload behavior.
- `docs/deployment.md` before changing Docker, production startup, environment variables, deploy scripts, or worker process setup.
- `lib/config/table_registry.dart` before changing models or migrations.
- `lib/config/seeder_registry.dart` before changing seed data.
- `lib/config/jobs_registry.dart` before changing background jobs or schedules.
- `docs/swagger.json` as generated output only.
- `docs/*.md` for Flint framework guidance copied from the installed package.

## Use Flint Patterns

- Import `package:flint_dart/flint_dart.dart` for app code.
- Import `package:flint_dart/ui.dart` for frontend code in `lib/ui`.
- Import `package:flint_dart/ai.dart` when code names `FlintAi`, providers, `AiAgent`, `AiTool`, `AiWorkflow`, AI stores, or `flintAiTables`.
- Configure AI once through `app.ai` during boot and use `ctx.ai` or controller `context.ai` in request code. Do not create a new `FlintAi()` inside each request.
- Read `docs/ui-widgets.md` before adding or changing `FlintComponent`, `StatefulComponent`, `StatelessComponent`, `FlintNode`, `View`, `DartStyle`, `StateSignal`, forms, buttons, layouts, overlays, tables, charts, storage, or navigation.
- Treat Flint as its own Dart-first, object-oriented framework. Do not assume
  Laravel-style behavior from familiar words such as controller, route, model,
  migration, or middleware.
- Put every class, backend object, frontend component, page, section, state holder, and reusable helper in its own Dart file. Do not add a second class or component to an existing file because it is small.
- Do not hide feature, business, or UI behavior in private `_someThing()` helper methods. Extract a named class, component, or top-level helper in its own file.
- Any extracted frontend method or function that returns `FlintComponent`, `FlintNode`, `Node`, or `View` should live in its own file under `lib/ui/components`, `lib/ui/sections`, or another clear `lib/ui` folder.
- Organize routes with `RouteGroup`, `prefix`, optional `tag`, and `register(Flint app)`.
- Attach route middleware with `.useMiddleware(...)`.
- For feature controllers, extend `Controller`, use the bound `context` plus the `req`/`res` shortcuts, and register actions through `app.controller(YourController.new)`.
- If a controller action is not registered through `app.controller(...)`, wrap it with `controller(...)` or `useController(...)` so Flint binds the current `Context`.
- Use direct `Context ctx` route handlers for small inline routes.
- Validate input with `await req.validate({...})`; on routes with path params such as `/:id`, include those params in the rule map because `validate(...)` reads normalized request input.
- Respond with `res.json(...)`, `res.respond(...)`, `res.status(...).json(...)`, `res.view(...)`, or `res.page(...)`.
- Use `res.page(...)` with names registered in `PageRegistry`; read `docs/build-and-rendering.md` before changing browser entrypoints, generated bundles, or SSR.
- Define persistence with `Model<T>` and `Table`.
- Register tables in `lib/config/table_registry.dart`.
- Register `...flintAiTables` in `lib/config/table_registry.dart` and run migrations before relying on durable AI runs, memory, traces, threads, or artifacts.
- Expose models through `FlintDatabaseApi` only when the resource contract, allowed operations, fields, and policies are intentional. Read `docs/database-api.md` first.
- Put seed data in `Seeder` subclasses under `lib/seeders` and register them in `lib/config/seeder_registry.dart`.
- Put background work in `QueueJob` subclasses under `lib/jobs` and register them in `lib/config/jobs_registry.dart`. `FlintJob` is deprecated compatibility; do not use it in new code.
- Put CPU-heavy or blocking helper work in `IsolateTask` subclasses under `lib/isolate/tasks`; implement `performTask()` and call `perform(...)`.
- Use `Storage` for public uploaded files and validate upload authorization, size, extension, and MIME type before saving.
- Use `req.startSession(...)`, `req.session`, `req.updateSession(...)`, and `req.destroySession()` for server sessions. Use `res.setCookie(...)` and `res.clearCookie(...)` for explicit cookies. Read `docs/sessions-and-cookies.md` before adding login cookies, flash messages, or browser auth session storage.
- Use `res.view(...)` for server-rendered HTML templates and `ViewMailable`
  for mail templates. Read `docs/templates.md` before changing `{{ }}`,
  includes, layouts, sections, control flow, assets, session helpers, or mail
  template syntax.
- Use `CacheStore` for app data caching. Use `CacheMiddleware`, `ETagMiddleware`, and `res.cachePublic(...)`/`res.cachePrivate(...)`/`res.noStore()` for HTTP response caching. Read `docs/cache.md` before adding cache behavior.
- Use `Log.debug(...)`, `Log.info(...)`, `Log.warning(...)`, `Log.error(...)`, and `Log.critical(...)` instead of committed `print(...)` calls. Do not log cookies, tokens, OTPs, passwords, raw request bodies, or authorization headers.
- Read `docs/testing.md` before adding tests. Use app-local HTTP fakes, bind
  controllers with `Context`, reset `FlintJobs` global state in job tests, use
  temporary directories for storage tests, and choose `flint_ui_core.dart` or
  `flint_ui_server.dart` for UI tests based on what is being verified.
- For AI tools, use `ProductionAiToolPolicy` or `app.ai.useProductionToolPolicyFromEnv()` in production. Bind runs to `userId`, `tenantId`, `threadId`, roles, and capabilities before allowing tools that read or change data.
- Use `Hashing(algorithm: HashingAlgorithm.bcrypt)` for passwords, `FlintJwt` only for lower-level JWT work, and `Str` for simple random/string helpers.
- Use `DB.query(...)` parameters, `QueryBuilder`, or model methods. Do not interpolate request input into SQL.
- Use `app.websocket(...)` with `Context ctx` and `ctx.socket` for realtime features; attach socket guards through the WebSocket `middlewares:` argument.

## Commands

```bash
dart run flint_dart:flint run --port=3000
dart run flint_dart:flint migrate --no-interaction
dart run flint_dart:flint seed
dart run flint_dart:flint --make-docker
dart run flint_dart:flint build --linux
dart run flint_dart:flint jobs-work
dart run flint_dart:flint --docs-generate
dart run flint_dart:flint agent
dart test
```

Use `--make-*` generator commands for new work. The older `make:*` aliases are
deprecated and will be removed in Flint Dart `1.5.0`.

## Do Not Replace

- Do not replace Flint with another server framework.
- Do not rewrite the app around another ORM.
- Do not describe Flint as a Laravel clone or copy Laravel command and folder
  assumptions into this app.
- Do not edit generated static assets by hand when source UI files exist.
- Do not treat `docs/swagger.json` as the source of routes.
- Do not remove table columns casually; Flint migrations can drop undeclared columns.

## Framework Source

When needed, resolve the installed `flint_dart` package through `.dart_tool/package_config.json` and inspect:

- `lib/src/app.dart`
- `lib/ai.dart`
- `lib/src/ai_env.dart`
- `lib/src/ai_database.dart`
- `lib/src/ai_tables.dart`
- `lib/src/routing/`
- `lib/src/request.dart`
- `lib/src/response.dart`
- `lib/src/middleware/`
- `lib/src/logs/`
- `lib/src/cache/`
- `lib/src/template_engine/`
- `lib/src/database/`
- `lib/src/database/api/`
- `lib/src/auth/`
- `lib/src/session/`
- `lib/src/security/`
- `lib/src/storage/`
- `lib/src/helpers/`
- `lib/src/validation/validator.dart`
- `lib/src/websocket/`
- `lib/src/jobs/`
- `lib/src/isolate/`
- `lib/src/swagger_gen/`
- `lib/src/cli/`
- `test/`
