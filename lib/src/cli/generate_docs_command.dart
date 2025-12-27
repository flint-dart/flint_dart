import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/cli/commands.dart';

/// 📖 Flint Swagger Docs Generator
class GenerateDocsCommand extends FlintCommand {
  GenerateDocsCommand()
      : super('docs:generate', 'Generate Swagger docs from routes');

  @override
  Future<void> execute(List<String> args) async {
    final routesDir = Directory('lib/routes');
    if (!(await routesDir.exists())) {
      return;
    }

    final files = routesDir
        .listSync(recursive: true)
        .where((f) => f.path.endsWith('.dart'));

    final paths = <String, dynamic>{};
    final servers = <Map<String, dynamic>>[];

    for (var file in files) {
      final lines = File(file.path).readAsLinesSync();

      // Buffers for documentation
      List<String> docBuffer = [];

      // State tracking
      String? currentClassPrefixFromDocs;
      String? currentGroupPrefix;
      String? currentGroupTag;
      bool insideRouteGroupClass = false;

      // Regex patterns
      final classPrefixReg =
          RegExp(r'''String\s+get\s+prefix\s*=>\s*['"]([^'"]+)['"]''');
      final classTagReg =
          RegExp(r'''String\s+get\s+tag\s*=>\s*['"]([^'"]+)['"]''');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Track if we're inside a RouteGroup class
        if (line.contains('class ') && line.contains('RouteGroup')) {
          insideRouteGroupClass = true;
          currentClassPrefixFromDocs = null;
          currentGroupPrefix = null;
          currentGroupTag = null;
        }

        // Collect doc comments
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('///')) {
          docBuffer.add(trimmedLine.substring(3).trim());
          continue;
        }

        // Check for class definition - parse its docs
        if (insideRouteGroupClass && trimmedLine.contains('class ')) {
          final classDocs = _parseDocs(docBuffer);
          currentClassPrefixFromDocs = classDocs['prefix'];
          docBuffer.clear();
        }

        // Extract RouteGroup prefix/tag getters
        if (insideRouteGroupClass) {
          final prefixMatch = classPrefixReg.firstMatch(line);
          if (prefixMatch != null) {
            currentGroupPrefix = prefixMatch.group(1);
          }

          final tagMatch = classTagReg.firstMatch(line);
          if (tagMatch != null) {
            currentGroupTag = tagMatch.group(1);
          }
        }

        // Process route definitions
        final routeInfo = _parseRoute(line);
        if (routeInfo != null && insideRouteGroupClass) {
          final routeDocs = _parseDocs(docBuffer);

          // Priority: route @prefix -> class @prefix -> RouteGroup prefix
          String? effectivePrefix;

          if (routeDocs.containsKey('prefix')) {
            effectivePrefix = routeDocs['prefix'];
          } else if (currentClassPrefixFromDocs != null) {
            effectivePrefix = currentClassPrefixFromDocs;
          } else if (currentGroupPrefix != null) {
            effectivePrefix = currentGroupPrefix;
          }

          var fullPath = routeInfo['path'] ?? '';

          // Apply prefix if available
          if (effectivePrefix != null && effectivePrefix.isNotEmpty) {
            // Clean the prefix
            var prefix = effectivePrefix;
            if (!prefix.startsWith('/')) {
              prefix = '/$prefix';
            }
            if (prefix.endsWith('/') && prefix != '/') {
              prefix = prefix.substring(0, prefix.length - 1);
            }

            // Clean the route path
            var routePath = fullPath;
            if (routePath == '/') {
              routePath = '';
            } else if (routePath.startsWith('/')) {
              routePath = routePath.substring(1);
            }

            // Combine
            if (routePath.isNotEmpty) {
              fullPath = '$prefix/$routePath';
            } else {
              fullPath = prefix;
            }
          } else {}

          // Initialize path if not exists
          paths.putIfAbsent(fullPath, () => {});

          // Build operation object
          final operation = <String, dynamic>{
            "summary": routeDocs['summary'] ?? '',
            "tags": [currentGroupTag ?? 'Default'],
            "responses": routeDocs['responses'] ??
                {
                  "200": {"description": "OK"}
                }
          };

          // Add requestBody if defined
          if (routeDocs.containsKey('requestBody')) {
            operation['requestBody'] = routeDocs['requestBody'];
          }

          // Combine all parameter types
          final allParameters = <Map<String, dynamic>>[];

          // Auto-extract path parameters
          final autoPathParams = _extractPathParams(fullPath);
          allParameters.addAll(autoPathParams);

          // Add query parameters from @query
          if (routeDocs.containsKey('queryParameters')) {
            allParameters.addAll(routeDocs['queryParameters']);
          }

          // Add manual parameters from @param
          if (routeDocs.containsKey('parameters')) {
            allParameters.addAll(routeDocs['parameters']);
          }

          if (allParameters.isNotEmpty) {
            operation['parameters'] = allParameters;
          }

          // Add authentication/security
          if (routeDocs.containsKey('auth')) {
            final authType = routeDocs['auth'];
            operation['security'] = [
              {authType: []}
            ];
          }

          // Add operation to the path
          final method = routeInfo['method'] ?? 'get';
          paths[fullPath][method] = operation;

          // Collect servers
          final routeServers = routeDocs['servers'] ?? [];
          for (var server in routeServers) {
            if (!servers.any((srv) => srv['url'] == server)) {
              servers.add({'url': server});
            }
          }

          // Reset doc buffer
          docBuffer.clear();
        } else if (trimmedLine.isNotEmpty && !trimmedLine.startsWith('///')) {
          // If we hit non-doc, non-route code, clear buffer
          docBuffer.clear();
        }

        // Check if we're leaving the class (end of class or new class)
        if (trimmedLine.contains('}') && insideRouteGroupClass) {
          // Simple check: if we see a closing brace at the start of line
          // This might need refinement for complex cases
          insideRouteGroupClass = false;
        }
      }
    }

    // Build the final Swagger/OpenAPI specification
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

    // Write to file
    final docsDir = Directory('docs');
    if (!(await docsDir.exists())) {
      docsDir.createSync(recursive: true);
    }

    final outFile = File('${docsDir.path}/swagger.json');
    outFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(swagger));
  }

  /// Parse route information from a line
  Map<String, dynamic>? _parseRoute(String line) {
    // Look for patterns like: app.get('/', ...), router.post('/login', ...), etc.
    final regex = RegExp(
      r'''(app|router|flint)\.(get|post|put|delete|patch|options|head)\(\s*['\"]([^'\"]+)['\"]''',
      caseSensitive: false,
    );

    final match = regex.firstMatch(line);
    if (match != null) {
      final method = match.group(2);
      var path = match.group(3);
      if (method != null && path != null) {
        // Convert :param to {param} format for OpenAPI
        path = path.replaceAllMapped(RegExp(r':(\w+)'), (m) => '{${m[1]}}');
        return {"method": method.toLowerCase(), "path": path};
      }
    }
    return null;
  }

  /// Parse documentation annotations
  Map<String, dynamic> _parseDocs(List<String> docs) {
    final result = <String, dynamic>{};
    final responses = <String, dynamic>{};
    final parameters = <Map<String, dynamic>>[];
    final queryParameters = <Map<String, dynamic>>[];
    final servers = <String>[];

    for (var line in docs) {
      if (line.startsWith('@prefix')) {
        result['prefix'] = line.replaceFirst('@prefix', '').trim();
      } else if (line.startsWith('@auth')) {
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

    // Only add non-empty collections
    if (responses.isNotEmpty) result['responses'] = responses;
    if (parameters.isNotEmpty) result['parameters'] = parameters;
    if (queryParameters.isNotEmpty) result['queryParameters'] = queryParameters;
    if (servers.isNotEmpty) result['servers'] = servers;

    return result;
  }

  /// Extract path parameters from a route path
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
