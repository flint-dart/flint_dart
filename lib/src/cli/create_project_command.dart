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
- `lib/routes/` for `RouteGroup` classes.
- `lib/controllers/` for request handlers.
- `lib/models/` for `Model<T>` classes and `Table` schemas.
- `lib/middlewares/` for app-specific middleware.
- `lib/config/table_registry.dart` before changing database tables or migrations.
- `lib/config/seeder_registry.dart` before changing seed data.
- `docs/swagger.json` only as generated output; route comments in `lib/routes/` are the source.

## Flint Patterns To Use

- Create the app with `Flint` from `package:flint_dart/flint_dart.dart`.
- Organize routes with `RouteGroup`, `prefix`, optional `tag`, and `register(Flint app)`.
- Add route middleware with `.useMiddleware(...)`.
- Use handlers with `(Request req, Response res)` or request-scoped controllers extending `Controller`.
- Validate input with `await req.validate({...})` before writing to models.
- Return `res.json(...)`, `res.respond(...)`, `res.status(...).json(...)`, `res.view(...)`, or `res.page(...)`.
- Define database models with `Model<T>` and `Table(name: ..., columns: [...])`.
- Register tables in `lib/config/table_registry.dart` so `flint migrate` can see them.
- Use `DB.query(...)` parameters or `QueryBuilder` instead of interpolating request input into SQL.
- Use `app.websocket(...)` and `FlintWebSocket` for WebSocket features.

## Common Commands

```bash
dart run flint_dart:flint run --port=3000
dart run flint_dart:flint migrate --no-interaction
dart run flint_dart:flint seed
dart run flint_dart:flint docs:generate
dart test
```

Generator commands:

```bash
dart run flint_dart:flint make:model Course
dart run flint_dart:flint make:controller CourseController
dart run flint_dart:flint make:route Course
dart run flint_dart:flint make:middleware AuthMiddleware
dart run flint_dart:flint make:seeder CourseSeeder
```

## Do Not Replace

- Do not replace `Flint`, `RouteGroup`, `Request`, `Response`, middleware, or the Flint model/database layer with unrelated frameworks.
- Do not edit generated static assets in `public/assets/js/flint-ui/` by hand when there is source UI code.
- Do not treat `docs/swagger.json` as the source of routes; update route files and regenerate docs.
- Do not remove columns from model `Table` definitions casually; migrations may drop undeclared columns.
- Do not assume many-to-many relation loading is available unless the installed `flint_dart` implementation supports it.

## Package Docs

If deeper framework behavior is needed, inspect the installed `flint_dart` package source through `.dart_tool/package_config.json`, especially:

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
}
