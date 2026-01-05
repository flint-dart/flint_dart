import 'dart:io';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/cli/commands.dart';

class MakeRouteCommand extends FlintCommand {
  MakeRouteCommand() : super('make:route', '  Creates a new RouteGroup');

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
import '../controllers/${_toSnakeCase(name)}.dart';

/// ${_capitalize(name)} API routes
/// @prefix /api/$name
class $className extends RouteGroup {
  @override
  String get prefix => '/$name';

  @override
  String get tag => "${_capitalize(name)}";

  @override
  void register(Flint app) {
    final controller = $controllerName();

    /// @summary Get  $name
    /// @response 200 Success response description
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    app.get('/', controller.index);

    /// @summary create $name by id
    /// @response 200 Success response description
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    /// @body {"name": "string","email": "string","password": "string"}
    app.post('/', controller.create);

    /// @summary Get  $name by id
    /// @response 200 Success response description
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    app.get('/:id', controller.show);
  
    /// @summary update  $name by id
    /// @response 200 Success response description
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    /// @body {"name": "string","email": "string","password": "string"}
    app.put('/:id', controller.update);

     /// @summary delete  $name by id
    /// @response 200 Success response description
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    app.delete('/:id', controller.delete);
  }
}
''';
  }
}
