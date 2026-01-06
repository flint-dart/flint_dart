import "dart:convert";

import "package:flint_dart/logs.dart";

class DocParser {
  Map<String, dynamic> parse(List<String> docs) {
    final result = <String, dynamic>{};
    final responses = <String, dynamic>{};
    final parameters = <Map<String, dynamic>>[];
    final queryParameters = <Map<String, dynamic>>[];
    final servers = <String>[];

    for (int i = 0; i < docs.length; i++) {
      final trimmedLine = docs[i].trim();

      if (trimmedLine.startsWith('@prefix')) {
        result['prefix'] = _extractValue(trimmedLine, '@prefix');
      } else if (trimmedLine.startsWith('@auth')) {
        result['auth'] =
            _extractValue(trimmedLine, '@auth', defaultValue: 'bearer');
      } else if (trimmedLine.startsWith('@server')) {
        servers.add(_extractValue(trimmedLine, '@server'));
      } else if (trimmedLine.startsWith('@summary')) {
        result['summary'] = _extractValue(trimmedLine, '@summary');
      } else if (trimmedLine.startsWith('@response')) {
        final value = _extractValue(trimmedLine, '@response');
        final parts = value.split(' ');
        final code = parts[0];
        final description =
            parts.length > 1 ? parts.sublist(1).join(' ') : 'No description';

        responses[code] = {"description": description};
      } else if (trimmedLine.startsWith('@param')) {
        _parseParameter(trimmedLine, parameters);
      } else if (trimmedLine.startsWith('@query')) {
        _parseQueryParameter(trimmedLine, queryParameters);
      } else if (trimmedLine.startsWith('@body')) {
        final buffer = StringBuffer();
        var bodyLine = trimmedLine.substring(5).trim();

        int braceCount = 0;

        // First line
        if (bodyLine.isNotEmpty) {
          buffer.writeln(bodyLine);
          braceCount += _countBraces(bodyLine);
        }

        // Read until braces are balanced
        while (braceCount > 0 && i + 1 < docs.length) {
          i++;
          final next = docs[i].replaceAll('///', '').trim();
          buffer.writeln(next);
          braceCount += _countBraces(next);
        }

        final json = buffer.toString().trim();

        if (json.startsWith('{') && json.endsWith('}')) {
          _parseRequestBody(json, result);
        } else {
          Log.error('[FLINT] ⚠️ Incomplete @body JSON:\n$json');
        }
      }
    }

    if (responses.isNotEmpty) result['responses'] = responses;
    if (parameters.isNotEmpty) result['parameters'] = parameters;
    if (queryParameters.isNotEmpty) result['queryParameters'] = queryParameters;
    if (servers.isNotEmpty) result['servers'] = servers;

    return result;
  }

  int _countBraces(String line) {
    return '{'.allMatches(line).length - '}'.allMatches(line).length;
  }

  String _extractValue(String line, String annotation,
      {String defaultValue = ''}) {
    // Remove the annotation and trim
    final value = line.substring(annotation.length).trim();
    return value.isEmpty ? defaultValue : value;
  }

  void _parseParameter(String line, List<Map<String, dynamic>> parameters) {
    // Remove @param and split by whitespace
    final content = line.substring(6).trim();
    final parts = content.split(' ');

    if (parts.length >= 4) {
      final name = parts[0];
      final location = parts[1]; // "path", "query", etc.
      final type = parts[2];
      final required = parts[3].toLowerCase() == "required";
      final description = parts.length > 4 ? parts.sublist(4).join(' ') : '';

      // Create the parameter object
      final param = {
        "name": name,
        "in": location,
        "schema": {"type": type},
        "required": location == "path" ? true : required,
        "description": description
      };

      // Check if a parameter with the same "in:name" already exists
      final existingIndex = parameters.indexWhere(
        (p) => p["name"] == name && p["in"] == location,
      );

      if (existingIndex >= 0) {
        // Overwrite the existing one (user-defined takes priority)
        parameters[existingIndex] = param;
      } else {
        parameters.add(param);
      }
    }
  }

  void _parseQueryParameter(
      String line, List<Map<String, dynamic>> queryParameters) {
    // Remove @query and split by whitespace
    final content = line.substring(6).trim();
    final parts = content.split(' ');

    if (parts.length >= 3) {
      final name = parts[0];
      final type = parts[1];
      final required = parts[2].toLowerCase() == "required";
      final description = parts.length > 3 ? parts.sublist(3).join(' ') : '';

      queryParameters.add({
        "name": name,
        "in": "query",
        "schema": {"type": type},
        "required": required,
        "description": description
      });
    }
  }

  void _parseRequestBody(String jsonStr, Map<String, dynamic> result) {
    try {
      // Log.info(jsonStr);

      final Map<String, dynamic> bodySchema = jsonDecode(jsonStr);

      result['requestBody'] = {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "type": "object",
              "properties": bodySchema.map(
                (k, v) => MapEntry(k, _dartValueToSwaggerSchema(v)),
              )
            }
          }
        }
      };
      // Log.debug("${bodySchema.map(
      //   (k, v) => MapEntry(k, {"type": v}),
      // )}");
      // Log.info("$bodySchema");
    } catch (e) {
      Log.error(
        "[FLINT] ⚠️ Invalid @body JSON: $jsonStr",
        error: e,
      );
    }
  }

  Map<String, dynamic> _dartValueToSwaggerSchema(dynamic v) {
    // 1️⃣ User explicitly defined type
    if (v is String) {
      final typeStr = v.toLowerCase().trim();

      // Handle array types like "string[]" or "integer[]"
      final arrayMatch = RegExp(r'^(\w+)\[\]$').firstMatch(typeStr);
      if (arrayMatch != null) {
        return {
          "type": "array",
          "items": {"type": arrayMatch.group(1)}
        };
      }

      // Known OpenAPI types
      const openApiTypes = [
        'string',
        'integer',
        'number',
        'boolean',
        'object',
        'array'
      ];
      if (openApiTypes.contains(typeStr)) {
        return {"type": typeStr};
      }
    }

    // 2️⃣ Null
    if (v == null) return {"type": "string", "nullable": true};

    // 3️⃣ Runtime inference for actual values
    if (v is int) return {"type": "integer"};
    if (v is double) return {"type": "number"};
    if (v is bool) return {"type": "boolean"};
    if (v is List && v.isNotEmpty) {
      return {"type": "array", "items": _dartValueToSwaggerSchema(v.first)};
    }
    if (v is List) return {"type": "array", "items": {}};
    if (v is Map<String, dynamic>) {
      return {
        "type": "object",
        "properties":
            v.map((k, val) => MapEntry(k, _dartValueToSwaggerSchema(val)))
      };
    }

    // 4️⃣ Fallback
    return {"type": "string"};
  }
}
