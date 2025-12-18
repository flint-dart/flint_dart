import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';

/// 📖 Flint Swagger Docs Generator
class GenerateDocsCommand extends FlintCommand {
  GenerateDocsCommand()
      : super('docs:generate', 'Generate Swagger docs from routes');

  @override
  Future<void> execute(List<String> args) async {
    final routesDir = Directory('lib/src/routes');
    if (!(await routesDir.exists())) {
      print('[FLINT] ❌ No routes directory found at lib/src/routes');
      return;
    }

    final files = routesDir
        .listSync(recursive: true)
        .where((f) => f.path.endsWith('.dart'));

    final paths = <String, dynamic>{};
    final servers = <Map<String, dynamic>>[];

    for (var file in files) {
      final lines = File(file.path).readAsLinesSync();

      // Attempt to detect RouteGroup prefix & tag from class
      String? groupPrefix;
      String? groupTag;

      final classPrefixReg =
          RegExp(r'''String\s+get\s+prefix\s*=>\s*['"]([^'"]+)['"]''');
      final classTagReg =
          RegExp(r'''String\s+get\s+tag\s*=>\s*['"]([^'"]+)['"]''');

      for (var line in lines) {
        final prefixMatch = classPrefixReg.firstMatch(line);
        if (prefixMatch != null) groupPrefix = prefixMatch.group(1);
        final tagMatch = classTagReg.firstMatch(line);
        if (tagMatch != null) groupTag = tagMatch.group(1);
      }

      List<String> docBuffer = [];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        if (line.startsWith('///')) {
          docBuffer.add(line.substring(3).trim());
          continue;
        }

        final routeInfo = _parseRoute(line);
        if (routeInfo != null) {
          final docs = _parseDocs(docBuffer);

          // Use RouteGroup prefix if exists
          final currentPrefix = groupPrefix ?? docs['prefix'];
          var fullPath = _parseRoute(line)?['path'] ?? '';

          if (currentPrefix != null) {
            var prefix = currentPrefix.startsWith('/')
                ? currentPrefix
                : '/$currentPrefix';

            if (prefix.endsWith('/') && prefix != '/') {
              prefix = prefix.substring(0, prefix.length - 1);
            }

            var path = fullPath == '/'
                ? ''
                : fullPath.startsWith('/')
                    ? fullPath.substring(1)
                    : fullPath;

            fullPath = '$prefix${path.isNotEmpty ? '/$path' : ''}';
          }

          paths.putIfAbsent(fullPath, () => {});

          final operation = <String, dynamic>{
            "summary": docs['summary'] ?? '',
            "tags": [groupTag ?? 'Default'], // Use RouteGroup tag if available
            "responses": docs['responses'] ??
                {
                  "200": {"description": "OK"}
                }
          };

          // Attach requestBody
          if (docs.containsKey('requestBody')) {
            operation['requestBody'] = docs['requestBody'];
          }

          // Combine parameters: path params + query params + manual params
          final allParameters = <Map<String, dynamic>>[];
          final autoPathParams = _extractPathParams(fullPath);
          allParameters.addAll(autoPathParams);

          if (docs.containsKey('queryParameters')) {
            allParameters.addAll(docs['queryParameters']);
          }
          if (docs.containsKey('parameters')) {
            allParameters.addAll(docs['parameters']);
          }

          if (allParameters.isNotEmpty) {
            operation['parameters'] = allParameters;
          }

          // Auth/Security
          if (docs.containsKey('auth')) {
            final authType = docs['auth'];
            operation['security'] = [
              {authType: []}
            ];
          }

          final method = _parseRoute(line)?['method'] ?? 'get';
          paths[fullPath][method] = operation;

          docBuffer = [];
        }
      }

      final docServers = _parseDocs(docBuffer)['servers'] ?? [];
      for (var s in docServers) {
        if (!servers.any((srv) => srv['url'] == s)) {
          servers.add({'url': s});
        }
      }
    }

    final swagger = {
      "openapi": "3.0.0",
      "info": {"title": "Flint API", "version": "1.0.0"},
      if (servers.isNotEmpty) "servers": servers,
      "paths": paths,
      "components": {
        "securitySchemes": {
          "bearer": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"},
          "basicAuth": {"type": "http", "scheme": "basic"}
        }
      }
    };

    final docsDir = Directory('docs');
    if (!(await docsDir.exists())) docsDir.createSync(recursive: true);

    final outFile = File('${docsDir.path}/swagger.json');
    outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(swagger));
    // print('✅ Swagger docs generated at ${outFile.path}');
  }

  Map<String, dynamic>? _parseRoute(String line) {
    final regex = RegExp(
      r'''(app|router|flint)\.(get|post|put|delete|patch|options|head)\(\s*['\"]([^'\"]+)['\"]''',
      caseSensitive: false,
    );

    final match = regex.firstMatch(line);
    if (match != null) {
      final method = match.group(2);
      var path = match.group(3);
      if (method != null && path != null) {
        path = path.replaceAllMapped(RegExp(r':(\w+)'), (m) => '{${m[1]}}');
        return {"method": method.toLowerCase(), "path": path};
      }
    }
    return null;
  }

  Map<String, dynamic> _parseDocs(List<String> docs) {
    final result = <String, dynamic>{};
    final responses = <String, dynamic>{};
    final parameters = <Map<String, dynamic>>[];
    final queryParameters = <Map<String, dynamic>>[];
    final servers = <String>[];

    for (var line in docs) {
      if (line.startsWith('@auth')) {
        final value = line.replaceFirst('@auth', '').trim();
        result['auth'] = value.isEmpty ? 'bearer' : value;
      } else if (line.startsWith('@server')) {
        servers.add(line.replaceFirst('@server', '').trim());
      } else if (line.startsWith('@summary')) {
        result['summary'] = line.replaceFirst('@summary', '').trim();
      } else if (line.startsWith('@response')) {
        final parts = line.split(' ');
        if (parts.length >= 3) {
          responses[parts[1]] = {"description": parts.sublist(2).join(' ')};
        }
      } else if (line.startsWith('@param')) {
        final parts = line.split(' ');
        if (parts.length >= 5) {
          final name = parts[1];
          final location = parts[2];
          final type = parts[3];
          final required = parts[4].toLowerCase() == "required";
          final description = parts.sublist(5).join(' ');
          parameters.add({
            "name": name,
            "in": location,
            "schema": {"type": type},
            "required": location == "path" ? true : required,
            "description": description
          });
        }
      } else if (line.startsWith('@query')) {
        final parts = line.split(' ');
        if (parts.length >= 4) {
          final name = parts[1];
          final type = parts[2];
          final required = parts[3].toLowerCase() == "required";
          final description = parts.sublist(4).join(' ');
          queryParameters.add({
            "name": name,
            "in": "query",
            "schema": {"type": type},
            "required": required,
            "description": description
          });
        }
      } else if (line.startsWith('@body')) {
        final jsonStr = line.replaceFirst('@body', '').trim();
        try {
          final Map<String, dynamic> bodySchema =
              jsonDecode(jsonStr) as Map<String, dynamic>;
          result['requestBody'] = {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties":
                      bodySchema.map((k, v) => MapEntry(k, {"type": v}))
                }
              }
            }
          };
        } catch (e) {
          print("[FLINT] ⚠️ Invalid @body JSON: $jsonStr ($e)");
        }
      }
    }

    if (responses.isNotEmpty) result['responses'] = responses;
    if (parameters.isNotEmpty) result['parameters'] = parameters;
    if (queryParameters.isNotEmpty) result['queryParameters'] = queryParameters;
    if (servers.isNotEmpty) result['servers'] = servers;

    return result;
  }

  List<Map<String, dynamic>> _extractPathParams(String path) {
    final params = <Map<String, dynamic>>[];
    final exp = RegExp(r'\{(\w+)\}');
    for (final match in exp.allMatches(path)) {
      final paramName = match.group(1)!;
      params.add({
        "name": paramName,
        "in": "path",
        "required": true,
        "schema": {"type": "string"},
        "description": "Path parameter: $paramName"
      });
    }
    return params;
  }
}
