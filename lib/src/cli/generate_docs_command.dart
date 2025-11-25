// lib/src/cli/commands.dart
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';

/// 📖 Flint Swagger Docs Generator

/// Flint comes with a built-in CLI command to generate Swagger/OpenAPI documentation from your annotated routes.

/// 1. Add Documentation Annotations

/// Inside your route files (e.g., lib/src/routes/user_routes.dart), you can use special /// annotations:

/// /// @summary Get all users
/// /// @auth bearer
/// /// @response 200 Successful response
/// /// @response 401 Unauthorized
/// /// @param id path string required User ID
/// /// @query page integer optional Page number for pagination
/// app.get("/users/:id", (req, res) async {
///   return res.respond({"id": req.params['id'], "name": "Ademola"});
/// }).useMiddleware(AuthMiddleware());

/// Available Annotations

/// @summary → Short description of the endpoint

/// @auth → Security (default: bearer)

/// @response → HTTP response code + description

/// @param name in type required/optional description

/// Example: @param id path string required The user ID

/// @query name type required/optional description

/// Example: @query page integer optional Page number for pagination

/// @body { "field": "type", "field2": "type" }

/// Example: @body {"email":"string","password":"string"}

/// @prefix /api/v1 → Add a prefix to following routes

/// @server http://localhost:3000 → Add server to Swagger

/// 2. Generate Swagger JSON

/// Run the command:

/// dart run flint docs:generate

/// ✅ Output:

/// Swagger docs generated at docs/swagger.json

/// 3. Serve Swagger UI in Flint

/// Add a simple docs route to your main.dart:
class GenerateDocsCommand extends FlintCommand {
  GenerateDocsCommand()
      : super('docs:generate', 'Generate Swagger docs from routes');

  @override
  Future<void> execute(List<String> args) async {
    final routesDir = Directory('lib/src/routes');
    if (!routesDir.existsSync()) {
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

      List<String> docBuffer = [];
      String? currentPrefix;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        if (line.startsWith('///')) {
          docBuffer.add(line.substring(3).trim());
          continue;
        }

        if (line.contains('app.get') ||
            line.contains('app.post') ||
            line.contains('app.put') ||
            line.contains('app.delete') ||
            line.contains('app.patch')) {
          final docs = _parseDocs(docBuffer);

          // Prefix
          if (docs.containsKey('prefix')) {
            currentPrefix = docs['prefix'];
          }

          // Servers
          if (docs.containsKey('servers')) {
            for (var s in docs['servers']) {
              if (!servers.any((srv) => srv['url'] == s)) {
                servers.add({"url": s});
                print("✅ Added server: $s");
              }
            }
          }

          final routeInfo = _parseRoute(line);
          if (routeInfo != null) {
            var fullPath = routeInfo['path'];

            if (currentPrefix != null) {
              // Ensure prefix starts with /
              var prefix = currentPrefix.startsWith('/')
                  ? currentPrefix
                  : '/$currentPrefix';
              // Remove trailing slash from prefix if present
              if (prefix.endsWith('/') && prefix != '/') {
                prefix = prefix.substring(0, prefix.length - 1);
              }

              // Normalize route path: if root '/', treat as empty; remove leading slash otherwise
              var path = fullPath == '/'
                  ? ''
                  : fullPath.startsWith('/')
                      ? fullPath.substring(1)
                      : fullPath;

              // Combine
              fullPath = '$prefix${path.isNotEmpty ? '/$path' : ''}';
            }

            paths.putIfAbsent(fullPath, () => {});

            final operation = <String, dynamic>{
              "summary": docs['summary'] ?? '',
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

            // Auto-generate path params
            final autoPathParams = _extractPathParams(fullPath);
            allParameters.addAll(autoPathParams);

            // Add query parameters
            if (docs.containsKey('queryParameters')) {
              allParameters.addAll(docs['queryParameters']);
            }

            // Add manually defined parameters
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
                {authType: []} // e.g., {"bearer": []} or {"basicAuth": []}
              ];
            }

            paths[fullPath][routeInfo['method']] = operation;
          }

          docBuffer = [];
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
    if (!docsDir.existsSync()) docsDir.createSync(recursive: true);

    final outFile = File('${docsDir.path}/swagger.json');
    outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(swagger));
    print('✅ Swagger docs generated at ${outFile.path}');
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
      } else if (line.startsWith('@prefix')) {
        result['prefix'] = line.replaceFirst('@prefix', '').trim();
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
