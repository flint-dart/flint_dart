// lib/cli/make_controller_command.dart
import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';

class MakeControllerCommand extends FlintCommand {
  MakeControllerCommand()
      : super('make:controller', '  Creates a new controller class');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      print('❌ Please provide a controller name.');
      return;
    }

    final name = args[0];
    final className = _capitalize(name);
    final fileName = _toSnakeCase(name);

    final content = _generateControllerTemplate(
      className,
    );

    final dir = Directory('lib/controllers');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/$fileName.dart');
    if (await file.exists()) {
      print('⚠️ controllers $fileName.dart already exists.');
      return;
    }

    await file.writeAsString(content);
    print('✅ controller created: lib/controllers/$fileName.dart');
  }

  String _capitalize(String str) =>
      str.isEmpty ? str : '${str[0].toUpperCase()}${str.substring(1)}';

  String _toSnakeCase(String input) =>
      input.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
        return '${match.group(1)}_${match.group(2)}';
      }).toLowerCase();

  String _generateControllerTemplate(String className) {
    return '''
import 'package:flint_dart/flint_dart.dart';

class $className {
  Future<void> index(Request req, Response res) async {
    res.send('Listing all items...');
  }

  Future<void> show(Request req, Response res) async {
    res.send('Showing item \${req.params['id']}');
  }

  Future<void> create(Request req, Response res) async {
    res.send('Creating item...');
  }

  Future<void> update(Request req, Response res) async {
    res.send('Updating item \${req.params['id']}');
  }

  Future<void> delete(Request req, Response res) async {
    res.send('Deleting item \${req.params['id']}');
  }
}
''';
  }
}
