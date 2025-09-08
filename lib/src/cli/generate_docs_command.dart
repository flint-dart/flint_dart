// lib/src/cli/commands.dart
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';

class GenerateDocsCommand extends FlintCommand {
  GenerateDocsCommand()
      : super('docs:generate', 'Generate Swagger docs from routes');

  @override
  Future<void> execute(List<String> args) async {
    final routesDir = Directory('bin/routes');
    if (!routesDir.existsSync()) {
      print('[FLINT] ❌ No routes directory found at bin/routes');
      return;
    }

    final files = routesDir
        .listSync(recursive: true)
        .where((f) => f.path.endsWith('.dart'));

    final paths = <String, dynamic>{};

    for (var file in files) {
      final lines = File(file.path).readAsLinesSync();

      List<String> docBuffer = [];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        if (line.startsWith('///')) {
          docBuffer.add(line.substring(3).trim());
          continue;
        }

        if (line.startsWith('app.get') ||
            line.startsWith('app.post') ||
            line.startsWith('app.put') ||
            line.startsWith('app.delete')) {
          final docs = _parseDocs(docBuffer);
          final routeInfo = _parseRoute(line);
          if (routeInfo != null) {
            paths.putIfAbsent(routeInfo['path'], () => {});
            paths[routeInfo['path']][routeInfo['method']] = {
              "summary": docs['summary'] ?? '',
              "responses": docs['responses'] ??
                  {
                    "200": {"description": "OK"}
                  }
            };
          }
          docBuffer = [];
        } else {
          docBuffer = [];
        }
      }
    }

    final swagger = {
      "openapi": "3.0.0",
      "info": {"title": "Flint API", "version": "1.0.0"},
      "paths": paths
    };

    final outFile = File('swagger.json');
    outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(swagger));
    print('✅ Swagger docs generated at swagger.json');
  }

  Map<String, dynamic> _parseDocs(List<String> docs) {
    final result = <String, dynamic>{};
    final responses = <String, dynamic>{};

    for (var line in docs) {
      if (line.startsWith('@summary')) {
        result['summary'] = line.replaceFirst('@summary', '').trim();
      } else if (line.startsWith('@response')) {
        final parts = line.split(' ');
        if (parts.length >= 3) {
          responses[parts[1]] = {"description": parts.sublist(2).join(' ')};
        }
      }
    }

    if (responses.isNotEmpty) result['responses'] = responses;
    return result;
  }

  Map<String, dynamic>? _parseRoute(String line) {
    // Handle multiple patterns for different syntax variations
    // final patterns = [
    //   'app\.(get|post|put|delete|patch|options|head|all)\(\s*["\']([^"\']+)["\']',
    //   // ... other patterns
    // ];
    // for (final pattern in patterns) {
    //   final match = RegExp(pattern, caseSensitive: false).firstMatch(line);
    //   if (match != null) {
    //     final method = match.group(1);
    //     final path = match.group(2);
    //     if (method != null && path != null) {
    //       return {
    //         "method": method.toUpperCase(),
    //         "path": path,
    //       };
    //     }
    //   }
    // }
    return null;
  }
}
