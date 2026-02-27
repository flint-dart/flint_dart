import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';
import 'package:flint_dart/src/swagger_gen/route_parser.dart';
import 'package:flint_dart/src/swagger_gen/swagger_generator.dart';

/// 📖 Flint Swagger Docs Generator
class GenerateDocsCommand extends FlintCommand {
  GenerateDocsCommand()
      : super('--docs-generate', 'Generate Swagger docs from routes');

  @override
  Future<void> execute(List<String> args) async {
    final routesDir = Directory('lib/routes');
    if (!(await routesDir.exists())) {
      return;
    }

    final files = routesDir
        .listSync(recursive: true)
        .where((f) => f.path.endsWith('.dart'));

    final parser = RouteParser();
    final docsGenerator = SwaggerGenerator();

    for (var file in files) {
      final lines = File(file.path).readAsLinesSync();
      parser.parseFile(lines, docsGenerator);
    }

    // Generate and write the Swagger JSON
    final swagger = docsGenerator.generateSwagger();
    final docsDir = Directory('docs');
    if (!(await docsDir.exists())) {
      docsDir.createSync(recursive: true);
    }

    final outFile = File('${docsDir.path}/swagger.json');
    outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(swagger));
  }
}
