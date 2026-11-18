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

class $className extends Controller {
  Future<Response> index() async {
    return res.send('Listing $name');
  }

  Future<Response> show() async {
    return res.send('Showing $name \${req.params['id']}');
  }

  Future<Response> create() async {
    return res.send('Creating $name');
  }

  Future<Response> update() async {
    return res.send('Updating $name \${req.params['id']}');
  }

  Future<Response> delete() async {
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

/// ${_capitalize(name)} API routes.
class $className extends RouteGroup {
  @override
  String get prefix => '/$name';

  @override
  String get tag => "${_capitalize(name)}";

  @override
  void register(Flint app) {
    final routes = app.controller($controllerName.new);

    /// @summary List ${_capitalize(name)}
    /// @query page integer optional Page number
    /// @query perPage integer optional Items per page
    /// @response 200 ${_capitalize(name)} list loaded
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    routes.get('/', (controller) => controller.index());

    /// @summary Create ${_capitalize(name)}
    /// @response 201 ${_capitalize(name)} created
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 422 Validation failed
    /// @response 500 Internal server error
    /// @body {"name": "string"}
    routes.post('/', (controller) => controller.create());

    /// @summary Show ${_capitalize(name)}
    /// @param id path string required ${_capitalize(name)} ID
    /// @response 200 ${_capitalize(name)} loaded
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 404 ${_capitalize(name)} not found
    /// @response 500 Internal server error
    routes.get('/:id', (controller) => controller.show());

    /// @summary Update ${_capitalize(name)}
    /// @param id path string required ${_capitalize(name)} ID
    /// @response 200 ${_capitalize(name)} updated
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 404 ${_capitalize(name)} not found
    /// @response 422 Validation failed
    /// @response 500 Internal server error
    /// @body {"name": "string"}
    routes.put('/:id', (controller) => controller.update());

    /// @summary Delete ${_capitalize(name)}
    /// @param id path string required ${_capitalize(name)} ID
    /// @response 200 ${_capitalize(name)} deleted
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 404 ${_capitalize(name)} not found
    /// @response 500 Internal server error
    routes.delete('/:id', (controller) => controller.delete());
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
    final importLine = "import '${_snake(name)}_routes.dart';";

    if (content.contains(importLine)) return;

    final updated = content
        .replaceFirstMapped(
          RegExp(r"(import 'package:flint_dart/flint_dart.dart';)"),
          (match) => '$importLine\n${match.group(1)}',
        )
        .replaceFirstMapped(
          RegExp(r"(void register\(Flint app\) \{)"),
          (match) => '${match.group(1)}\n    app.routes($routeClass());',
        );

    await file.writeAsString(updated);
  }
}
