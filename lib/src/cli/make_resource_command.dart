import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class MakeResourceCommand extends FlintCommand {
  MakeResourceCommand()
      : super('--make-resource',
            '  Creates controller, routes and registers them');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      Log.debug('❌ Please provide a resource name.');
      return;
    }

    final name = args[0];

    await _createController(name);
    await _createRoutes(name);
    await _registerRoute(name);

    Log.info('🚀 API Resource "$name" created successfully.');
  }

  // ---------------- HELPERS ----------------

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _snake(String input) =>
      input.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) {
        return '${m.group(1)}_${m.group(2)}';
      }).toLowerCase();

  // ---------------- CREATE CONTROLLER ----------------

  Future<void> _createController(String name) async {
    final className = '${_capitalize(name)}Controller';
    final fileName = '${_snake(name)}_controller.dart';

    final dir = Directory('lib/controllers');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return;

    await file.writeAsString('''
import 'package:flint_dart/flint_dart.dart';

class $className {
  Future<Response> index(Request req, Response res) async {
    return res.send('Listing $name');
  }

  Future<Response> show(Request req, Response res) async {
    return res.send('Showing $name \${req.params['id']}');
  }

  Future<Response> create(Request req, Response res) async {
    return res.send('Creating $name');
  }

  Future<Response> update(Request req, Response res) async {
    return res.send('Updating $name \${req.params['id']}');
  }

  Future<Response> delete(Request req, Response res) async {
    return res.send('Deleting $name \${req.params['id']}');
  }
}
''');
  }

  // ---------------- CREATE ROUTES ----------------

  Future<void> _createRoutes(String name) async {
    final className = '${_capitalize(name)}Routes';
    final controllerName = '${_capitalize(name)}Controller';
    final fileName = '${_snake(name)}_routes.dart';

    final dir = Directory('lib/routes');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return;

    await file.writeAsString('''
import 'package:flint_dart/flint_dart.dart';
import '../controllers/${_snake(name)}_controller.dart';

/// $name API routes
/// @prefix /api/$name
class $className extends RouteGroup {
  @override
  String get prefix => '/$name';

  @override
  String get tag => "${_capitalize(name)}";

  @override
  void register(Flint app) {
    final controller = $controllerName();

    app.get('/', controller.index);
    app.post('/', controller.create);
    app.get('/:id', controller.show);
    app.put('/:id', controller.update);
    app.delete('/:id', controller.delete);
  }
}
''');
  }

  // ---------------- REGISTER IN app_routes.dart ----------------

  Future<void> _registerRoute(String name) async {
    final file = File('lib/routes/app_routes.dart');
    if (!await file.exists()) {
      Log.debug('⚠️ app_routes.dart not found, skipping auto-registration.');
      return;
    }

    final content = await file.readAsString();

    final routeClass = '${_capitalize(name)}Routes';
    final importLine =
        "import 'package:eucloudhost_backend/routes/${_snake(name)}_routes.dart';";

    if (content.contains(importLine)) return;

    final updated = content
        .replaceFirst(RegExp(r"(import 'package:flint_dart/flint_dart.dart';)"),
            "$importLine\n\\1")
        .replaceFirst(
          RegExp(r"(void register\(Flint app\) \{)"),
          "\\1\n    app.routes($routeClass());",
        );

    await file.writeAsString(updated);
  }
}
