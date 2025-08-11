import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';

class MakeMiddlewareCommand extends FlintCommand {
  MakeMiddlewareCommand()
      : super('make:middleware', 'Creates a new middleware class');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      print('❌ Please provide a middleware name.');
      return;
    }

    final name = args[0];
    final className = _capitalize(name);
    final fileName = _toSnakeCase(name);

    final content = _generateMiddlewareTemplate(className);

    final dir = Directory('lib/src/middlewares');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/$fileName.dart');
    if (await file.exists()) {
      print('⚠️ Middleware $fileName.dart already exists.');
      return;
    }

    await file.writeAsString(content);
    print('✅ Middleware created: lib/src/middlewares/$fileName.dart');
  }

  String _capitalize(String str) =>
      str.isEmpty ? str : '${str[0].toUpperCase()}${str.substring(1)}';

  String _toSnakeCase(String input) =>
      input.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
        return '${match.group(1)}_${match.group(2)}';
      }).toLowerCase();

  String _generateMiddlewareTemplate(String className) {
    return '''
import 'package:flint_dart/flint_dart.dart';

class $className extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      final token = req.bearerToken;
      if (token == null || token != "expected_token") {
        res.status(401).send("Unauthorized");
        return;
      }
      await next(req, res);
    };
  }
}
''';
  }
}
