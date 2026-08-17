import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class AgentDocsCommand extends FlintCommand {
  AgentDocsCommand()
      : super('agent', 'Creates Flint AI agent docs in an existing app');

  static const _docFileNames = [
    'getting-started.md',
    'project-structure.md',
    'routing.md',
    'middleware.md',
    'models-and-database.md',
    'authentication.md',
    'validation.md',
    'websockets.md',
    'swagger-and-api-docs.md',
    'cli.md',
    'building-a-feature.md',
    'common-patterns.md',
  ];

  @override
  Future<void> execute(List<String> args) async {
    final force = args.contains('--force') || args.contains('-f');
    final projectName = await _projectName();

    if (!await File('pubspec.yaml').exists()) {
      Log.debug(
        'No pubspec.yaml found. Run `flint agent` from a Flint app root.',
      );
      return;
    }

    final docsDir = Directory('docs');
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }

    var written = 0;
    var skipped = 0;

    final files = {
      'AGENTS.md': _agentsTemplate(projectName),
      for (final name in _docFileNames) 'docs/$name': _docTemplate(name),
    };

    for (final entry in files.entries) {
      final file = File(entry.key);
      if (await file.exists() && !force) {
        skipped++;
        Log.debug('Skipped existing ${entry.key}. Use --force to overwrite.');
        continue;
      }

      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      written++;
      Log.info('Created ${entry.key}');
    }

    Log.info(
      'Flint agent docs ready. Written: $written, skipped: $skipped.',
    );
  }

  Future<String> _projectName() async {
    final pubspec = File('pubspec.yaml');
    if (!await pubspec.exists()) return 'this_app';

    final lines = await pubspec.readAsLines();
    for (final line in lines) {
      final match = RegExp(r'^name:\s*(.+)$').firstMatch(line.trim());
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return 'this_app';
  }

  String _agentsTemplate(String projectName) {
    return '''
# AGENTS.md

This is a Flint Dart application named `$projectName`.

AI coding agents should use the local app structure first, then inspect the installed `flint_dart` package only when framework behavior is unclear.

## Inspect First

- `pubspec.yaml` for package name and dependencies.
- `lib/main.dart` for `Flint(...)`, global middleware, route registration, static assets, database flags, and `listen(...)`.
- `lib/routes/` for `RouteGroup` classes.
- `lib/controllers/` for request handlers.
- `lib/models/` for `Model<T>` classes and `Table` schemas.
- `lib/middlewares/` for app-specific middleware.
- `lib/config/table_registry.dart` before changing models or migrations.
- `lib/config/seeder_registry.dart` before changing seed data.
- `docs/swagger.json` as generated output only.

## Use Flint Patterns

- Import `package:flint_dart/flint_dart.dart` for app code.
- Organize routes with `RouteGroup`, `prefix`, optional `tag`, and `register(Flint app)`.
- Attach route middleware with `.useMiddleware(...)`.
- Use `(Request req, Response res)` handlers or controllers extending `Controller`.
- Validate input with `await req.validate({...})`.
- Respond with `res.json(...)`, `res.respond(...)`, `res.status(...).json(...)`, `res.view(...)`, or `res.page(...)`.
- Define persistence with `Model<T>` and `Table`.
- Register tables in `lib/config/table_registry.dart`.
- Use `DB.query(...)` parameters, `QueryBuilder`, or model methods. Do not interpolate request input into SQL.
- Use `app.websocket(...)` and `FlintWebSocket` for realtime features.

## Commands

```bash
dart run flint_dart:flint run --port=3000
dart run flint_dart:flint migrate --no-interaction
dart run flint_dart:flint seed
dart run flint_dart:flint docs:generate
dart run flint_dart:flint agent
dart test
```

## Do Not Replace

- Do not replace Flint with another server framework.
- Do not rewrite the app around another ORM.
- Do not edit generated static assets by hand when source UI files exist.
- Do not treat `docs/swagger.json` as the source of routes.
- Do not remove table columns casually; Flint migrations can drop undeclared columns.

## Framework Source

When needed, resolve the installed `flint_dart` package through `.dart_tool/package_config.json` and inspect:

- `lib/src/app.dart`
- `lib/src/routing/`
- `lib/src/request.dart`
- `lib/src/response.dart`
- `lib/src/middleware/`
- `lib/src/database/`
- `lib/src/auth/`
- `lib/src/validation/validator.dart`
- `lib/src/websocket/`
- `lib/src/swagger_gen/`
- `lib/src/cli/`
''';
  }

  String _docTemplate(String fileName) {
    final title = fileName
        .replaceAll('.md', '')
        .split('-')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    return '''
# $title

This file is generated by `flint agent` for an existing Flint Dart app. It gives AI coding agents and developers a local checklist for working with this topic. Verify details against the actual app files before changing code.

## Inspect

- `lib/main.dart`
- `lib/routes/`
- `lib/controllers/`
- `lib/models/`
- `lib/middlewares/`
- `lib/config/`
- The installed `flint_dart` package source when framework behavior matters.

## Flint APIs To Prefer

- `Flint`
- `RouteGroup`
- `Request`
- `Response`
- `Middleware`
- `Controller`
- `Validator` and `Request.validate`
- `Model<T>`, `Table`, `Column`, `DB`, and `QueryBuilder`
- `FlintWebSocket`

## Working Pattern

1. Read the local implementation first.
2. Follow existing naming and folder conventions.
3. Keep changes scoped to routes, controllers, models, middleware, or config.
4. Add or update route comments before running `flint docs:generate`.
5. Run focused tests or `dart analyze` after changes.

## Example

```dart
app.get('/health', (Request req, Response res) {
  return res.json({'ok': true});
});
```

For feature work, prefer this flow:

```text
model -> table_registry -> migrate -> controller -> route group -> validation -> docs
```

## Limits

- Do not document APIs that are not present in the installed `flint_dart` package.
- Do not overwrite unrelated app code.
- Do not assume generated output is the source of truth.
''';
  }
}
