import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class CreateProjectCommand extends FlintCommand {
  CreateProjectCommand() : super('create', 'Creates a new Flint Dart project');

  @override
  Future<void> execute(List<String> args) async {
    // 🟦 1. Get project name (prompt if missing)
    String projectName =
        args.isNotEmpty ? args.first.trim() : await _promptProjectName();

    if (projectName.isEmpty) {
      Log.debug('❌ Project name cannot be empty.');
      return;
    }

    final dir = Directory(projectName);
    if (await dir.exists()) {
      Log.debug('❌ Error: Directory "$projectName" already exists.');
      return;
    }

    // 🟦 2. Clone template
    Log.debug('🚀 Creating project "$projectName"...');
    final result = await Process.run(
      'git',
      [
        'clone',
        '--depth',
        '1',
        'https://github.com/flint-dart/flint-dart-sample.git',
        projectName
      ],
    );

    if (result.exitCode != 0) {
      Log.debug('❌ Failed to clone template:\n${result.stderr}');
      return;
    }

    // 🟦 3. Clean up .git folder
    final gitDir = Directory('${dir.path}/.git');
    if (await gitDir.exists()) await gitDir.delete(recursive: true);

    // 🟦 4. Update pubspec name
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (await pubspecFile.exists()) {
      var content = await pubspecFile.readAsString();
      content = content.replaceFirst(
          RegExp(r'^name:\s*.*', multiLine: true), 'name: $projectName');
      await pubspecFile.writeAsString(content);
    }

    // 🟦 5. Update internal imports
    await _updatePackageImports(dir.path, 'sample', projectName);
    await _writeAgentGuide(dir.path, projectName);

    // 🟦 6. Run pub get
    Log.debug('⚙️ Running `dart pub get`...');
    final pubGet =
        await Process.start('dart', ['pub', 'get'], workingDirectory: dir.path);
    await stdout.addStream(pubGet.stdout);
    await stderr.addStream(pubGet.stderr);
    final exitCode = await pubGet.exitCode;

    if (exitCode != 0) {
      Log.debug('❌ Failed to install dependencies.');
      return;
    }

    // 🟦 7. Success message
    Log.info('\n✅ Project "$projectName" created successfully!');
    Log.info('📂 Location: ${dir.absolute.path}');
    Log.info('\nTo get started:');
    Log.info('  cd $projectName');
    Log.info('  flint run');
  }

  /// Prompts the user for a project name.
  Future<String> _promptProjectName() async {
    stdout.write('👉 What is your project name? ');
    return stdin.readLineSync()?.trim() ?? '';
  }

  /// Updates all Dart imports to reflect the new package name.
  Future<void> _updatePackageImports(
      String root, String oldName, String newName) async {
    final dir = Directory(root);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        var content = await entity.readAsString();
        if (content.contains('package:$oldName/')) {
          content =
              content.replaceAll('package:$oldName/', 'package:$newName/');
          await entity.writeAsString(content);
        }
      }
    }
  }

  Future<void> _writeAgentGuide(String root, String projectName) async {
    final file = File('$root/AGENTS.md');
    if (await file.exists()) {
      Log.debug('AGENTS.md already exists, keeping template version.');
      return;
    }

    await file.writeAsString(_agentGuideTemplate(projectName));
    Log.debug('AI agent guide created: AGENTS.md');
  }

  String _agentGuideTemplate(String projectName) {
    return '''
# AGENTS.md

This is a Flint Dart application named `$projectName`.

Use this file to help AI coding agents work correctly in this app. The app depends on the `flint_dart` package, so agents should follow Flint conventions instead of replacing the framework with another server stack.

## Files To Inspect First

- `pubspec.yaml` for the app package name and `flint_dart` dependency.
- `lib/main.dart` for `Flint(...)`, middleware, routes, static assets, database settings, and `listen(...)`.
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
- `lib/ui/` for Flint UI frontend source: pages, components, sections, helpers, styles, state, and the component registry.
- `docs/frontend-ui.md` and `docs/ui-widgets.md` before changing Flint UI pages, components, forms, buttons, layouts, overlays, tables, charts, browser storage, navigation, or state.
- `docs/logging.md` before changing request logs, job logs, error logs, or replacing `print(...)`.
- `docs/testing.md` before adding or fixing tests for routes, controllers, middleware, validators, storage, jobs, seeders, or UI components.
- `docs/build-and-rendering.md` before changing `flint build`, `flint web`, browser entrypoints, generated bundles, page registry behavior, or SSR.
- `docs/deployment.md` before changing Docker, production startup, environment variables, deploy scripts, or worker process setup.
- `public/` before changing public file upload behavior.
- `lib/config/table_registry.dart` before changing database tables or migrations.
- `docs/database-api.md` before exposing models through the secure Database API resource layer.
- `lib/config/seeder_registry.dart` before changing seed data.
- `lib/config/jobs_registry.dart` before changing background jobs or schedules.
- `docs/seeders.md` when adding seeders, fixture data, or startup seeding.
- `docs/jobs-and-workers.md` when adding queue jobs, job workers, schedules, or isolate-backed background work.
- `docs/isolate-tasks.md` when moving CPU-heavy or blocking work into Dart isolates.
- `docs/sessions-and-cookies.md` when adding server sessions, login cookies, flash messages, or browser auth session storage.
- `docs/mail.md` when adding `ViewMailable` classes, OTP mail, queued sends, or mail previews.
- `docs/cache.md` when adding app data caching, response cache headers, or ETags.
- `docs/templates.md` before changing server-rendered HTML, `{{ }}`, includes, layouts, sections, control flow, assets, session helpers, or mail template syntax.
- `docs/storage.md` when adding public uploads or deleting/replacing stored files.
- `docs/security-and-utilities.md` when hashing passwords, creating JWTs, adding rate limits, throwing framework exceptions, or using helpers.
- `docs/swagger.json` only as generated output; route comments in `lib/routes/` are the source.

## Flint Patterns To Use

- Create the app with `Flint` from `package:flint_dart/flint_dart.dart`.
- Use `package:flint_dart/ui.dart` for frontend code in `lib/ui`.
- Import `package:flint_dart/ai.dart` when code names `FlintAi`, providers, `AiAgent`, `AiTool`, `AiWorkflow`, AI stores, or `flintAiTables`.
- Configure AI once through `app.ai` during boot and use `ctx.ai` or controller `context.ai` in request code. Do not create a new `FlintAi()` inside each request.
- Read `docs/ui-widgets.md` before adding or changing `FlintComponent`, `StatefulComponent`, `StatelessComponent`, `FlintNode`, `View`, `DartStyle`, `StateSignal`, forms, buttons, layouts, overlays, tables, charts, storage, or navigation.
- Treat Flint as its own Dart-first, object-oriented framework. Do not assume
  Laravel-style behavior from familiar words such as controller, route, model,
  migration, or middleware.
- Put every class, backend object, frontend component, page, section, state holder, and reusable helper in its own Dart file.
- Any extracted frontend method or function that returns `FlintComponent`, `FlintNode`, `Node`, or `View` should live in its own file under `lib/ui/components`, `lib/ui/sections`, or another clear `lib/ui` folder.
- Do not hide feature, business, or UI behavior in private `_someThing()` helper methods. Extract a named class, component, or top-level helper in its own file.
- Organize routes with `RouteGroup`, `prefix`, optional `tag`, and `register(Flint app)`.
- Add route middleware with `.useMiddleware(...)`.
- Use direct `Context ctx` route handlers for small inline routes.
- For feature controllers, extend `Controller`, use the bound `context` plus `req`/`res`, and register actions through `app.controller(YourController.new)`.
- If a controller action is not registered through `app.controller(...)`, wrap it with `controller(...)` or `useController(...)` so Flint binds the current `Context`.
- Validate input with `await req.validate({...})` before writing to models.
- Return `res.json(...)`, `res.respond(...)`, `res.status(...).json(...)`, `res.view(...)`, or `res.page(...)`.
- Use `res.page(...)` with names registered in `PageRegistry`; read `docs/build-and-rendering.md` before changing browser entrypoints, generated bundles, or SSR.
- Define database models with `Model<T>` and `Table(name: ..., columns: [...])`.
- Register tables in `lib/config/table_registry.dart` so `flint migrate` can see them.
- Register `...flintAiTables` in `lib/config/table_registry.dart` and run migrations before relying on durable AI runs, memory, traces, threads, or artifacts.
- Expose models through `FlintDatabaseApi` only when the resource contract, allowed operations, fields, and policies are intentional.
- Put seed data in `Seeder` subclasses under `lib/seeders` and register them in `lib/config/seeder_registry.dart`.
- Put durable background work in `QueueJob` subclasses under `lib/jobs` and register them in `lib/config/jobs_registry.dart`. `FlintJob` is deprecated compatibility; do not use it in new code.
- Put CPU-heavy or blocking helper work in `IsolateTask` subclasses under `lib/isolate/tasks`; implement `performTask()` and call `perform(...)`.
- Use `req.startSession(...)`, `req.session`, `req.updateSession(...)`, and `req.destroySession()` for server sessions. Use `res.setCookie(...)` and `res.clearCookie(...)` for explicit cookies.
- Use `res.view(...)` for server-rendered HTML templates and `ViewMailable` for mail templates. Read `docs/templates.md` before changing `{{ }}`, includes, layouts, sections, control flow, assets, session helpers, or mail template syntax.
- Use `CacheStore` for app data caching. Use `CacheMiddleware`, `ETagMiddleware`, and response cache helpers for HTTP response caching.
- Use `Log.debug(...)`, `Log.info(...)`, `Log.warning(...)`, `Log.error(...)`, and `Log.critical(...)` instead of committed `print(...)` calls. Do not log cookies, tokens, OTPs, passwords, raw request bodies, or authorization headers.
- Read `docs/testing.md` before adding tests. Use app-local HTTP fakes, bind controllers with `Context`, reset `FlintJobs` global state in job tests, use temporary directories for storage tests, and choose `flint_ui_core.dart` or `flint_ui_server.dart` for UI tests based on what is being verified.
- For AI tools, use `ProductionAiToolPolicy` or `app.ai.useProductionToolPolicyFromEnv()` in production. Bind runs to `userId`, `tenantId`, `threadId`, roles, and capabilities before allowing tools that read or change data.
- Use `Storage` for public uploaded files and validate upload authorization, size, extension, and MIME type before saving.
- Use `Hashing(algorithm: HashingAlgorithm.bcrypt)` for passwords, `FlintJwt` only for lower-level JWT work, and `Str` for simple random/string helpers.
- Use `DB.query(...)` parameters or `QueryBuilder` instead of interpolating request input into SQL.
- Use `app.websocket(...)` with `Context ctx` and `ctx.socket` for WebSocket features; attach socket guards through the WebSocket `middlewares:` argument.
- Do not use `deploy-globe`, `globe.yaml`, or `globe_cli`; Globe deployment is no longer supported.

## Common Commands

```bash
dart run flint_dart:flint run --port=3000
dart run flint_dart:flint migrate --no-interaction
dart run flint_dart:flint seed
dart run flint_dart:flint --make-docker
dart run flint_dart:flint build --linux
dart run flint_dart:flint jobs-work
dart run flint_dart:flint --docs-generate
dart test
```

Generator commands:

```bash
dart run flint_dart:flint --make-model Course
dart run flint_dart:flint --make-controller CourseController
dart run flint_dart:flint --make-route Course
dart run flint_dart:flint --make-middleware AuthMiddleware
dart run flint_dart:flint --make-seeder CourseSeeder
```

The older `make:*` aliases are deprecated and will be removed in Flint Dart
`1.5.0`. Use the `--make-*` generator commands in new work.

## Do Not Replace

- Do not replace `Flint`, `RouteGroup`, `Request`, `Response`, middleware, or the Flint model/database layer with unrelated frameworks.
- Do not describe Flint as a Laravel clone or copy Laravel command and folder
  assumptions into this app.
- Do not edit generated static assets in `public/assets/js/flint-ui/` by hand when there is source UI code.
- Do not treat `docs/swagger.json` as the source of routes; update route files and regenerate docs.
- Do not remove columns from model `Table` definitions casually; migrations may drop undeclared columns.
- Do not assume many-to-many relation loading is available unless the installed `flint_dart` implementation supports it.

## Package Docs

If deeper framework behavior is needed, inspect the installed `flint_dart` package source through `.dart_tool/package_config.json`, especially:

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
''';
  }
}
