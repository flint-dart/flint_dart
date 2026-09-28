import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class MakeRouteCommand extends FlintCommand {
  MakeRouteCommand() : super('--make-route', '  Creates a new RouteGroup');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      Log.debug('❌ Please provide a route name.');
      return;
    }

    final name = args[0];
    final className = '${_capitalize(name)}Routes';
    final controllerName = '${_capitalize(name)}Controller';
    final fileName = _toSnakeCase(name);

    final content = _generateRouteTemplate(
      name,
      className,
      controllerName,
    );

    final dir = Directory('lib/routes');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/${fileName}_routes.dart');
    if (await file.exists()) {
      Log.debug('⚠️ Route file ${fileName}_routes.dart already exists.');
      return;
    }

    await file.writeAsString(content);
    Log.info('✅ Route created: lib/routes/${fileName}_routes.dart');
  }

  String _capitalize(String str) =>
      str.isEmpty ? str : '${str[0].toUpperCase()}${str.substring(1)}';

  String _toSnakeCase(String input) =>
      input.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) {
        return '${m.group(1)}_${m.group(2)}';
      }).toLowerCase();

  String _generateRouteTemplate(
    String name,
    String className,
    String controllerName,
  ) {
    return '''
import 'package:flint_dart/flint_dart.dart';
import '../controllers/${_toSnakeCase(name)}_controller.dart';

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
''';
  }
}
