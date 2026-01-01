import "dart:convert";

import "package:flint_dart/logs.dart";

class DocParser {
  Map<String, dynamic> parse(List<String> docs) {
    final result = <String, dynamic>{};
    final responses = <String, dynamic>{};
    final parameters = <Map<String, dynamic>>[];
    final queryParameters = <Map<String, dynamic>>[];
    final servers = <String>[];

    for (var line in docs) {
      final trimmedLine = line.trim();

      // Handle @prefix
      if (trimmedLine.startsWith('@prefix')) {
        result['prefix'] = _extractValue(trimmedLine, '@prefix');
      }
      // Handle @auth
      else if (trimmedLine.startsWith('@auth')) {
        result['auth'] =
            _extractValue(trimmedLine, '@auth', defaultValue: 'bearer');
      }
      // Handle @server
      else if (trimmedLine.startsWith('@server')) {
        servers.add(_extractValue(trimmedLine, '@server'));
      }
      // Handle @summary
      else if (trimmedLine.startsWith('@summary')) {
        result['summary'] = _extractValue(trimmedLine, '@summary');
      }
      // Handle @response
      else if (trimmedLine.startsWith('@response')) {
        final value = _extractValue(trimmedLine, '@response');
        final parts = value.split(' ');
        if (parts.isNotEmpty) {
          final code = parts[0];
          final description =
              parts.length > 1 ? parts.sublist(1).join(' ') : 'No description';
          responses[code] = {"description": description};
        }
      }
      // Handle @param
      else if (trimmedLine.startsWith('@param')) {
        _parseParameter(trimmedLine, parameters);
      }
      // Handle @query
      else if (trimmedLine.startsWith('@query')) {
        _parseQueryParameter(trimmedLine, queryParameters);
      }
      // Handle @body
      else if (trimmedLine.startsWith('@body')) {
        _parseRequestBody(trimmedLine, result);
      }
    }

    // Add collections only if not empty
    if (responses.isNotEmpty) result['responses'] = responses;
    if (parameters.isNotEmpty) result['parameters'] = parameters;
    if (queryParameters.isNotEmpty) result['queryParameters'] = queryParameters;
    if (servers.isNotEmpty) result['servers'] = servers;

    return result;
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
      final location = parts[1];
      final type = parts[2];
      final required = parts[3].toLowerCase() == "required";
      final description = parts.length > 4 ? parts.sublist(4).join(' ') : '';

      parameters.add({
        "name": name,
        "in": location,
        "schema": {"type": type},
        "required": location == "path" ? true : required,
        "description": description
      });
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

  void _parseRequestBody(String line, Map<String, dynamic> result) {
    try {
      final jsonStr = line.substring(5).trim(); // Remove @body
      if (jsonStr.isNotEmpty) {
        final Map<String, dynamic> bodySchema =
            jsonDecode(jsonStr) as Map<String, dynamic>;
        result['requestBody'] = {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": bodySchema.map((k, v) => MapEntry(k, {"type": v}))
              }
            }
          }
        };
      }
    } catch (e) {
      Log.error(
          "[FLINT] ⚠️ Invalid @body JSON: ${line.substring(5).trim()} ($e)",
          error: e);
    }
  }
}
