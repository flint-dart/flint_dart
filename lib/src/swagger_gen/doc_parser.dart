import 'dart:convert';

/// Parses documentation annotations
class DocParser {
  Map<String, dynamic> parse(List<String> docs) {
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
        _parseParameter(line, parameters);
      } else if (line.startsWith('@query')) {
        _parseQueryParameter(line, queryParameters);
      } else if (line.startsWith('@body')) {
        _parseRequestBody(line, result);
      }
    }

    // Add collections only if not empty
    if (responses.isNotEmpty) result['responses'] = responses;
    if (parameters.isNotEmpty) result['parameters'] = parameters;
    if (queryParameters.isNotEmpty) result['queryParameters'] = queryParameters;
    if (servers.isNotEmpty) result['servers'] = servers;

    return result;
  }

  void _parseParameter(String line, List<Map<String, dynamic>> parameters) {
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
  }

  void _parseQueryParameter(
      String line, List<Map<String, dynamic>> queryParameters) {
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
  }

  void _parseRequestBody(String line, Map<String, dynamic> result) {
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
              "properties": bodySchema.map((k, v) => MapEntry(k, {"type": v}))
            }
          }
        }
      };
    } catch (e) {
      print("[FLINT] ⚠️ Invalid @body JSON: $jsonStr ($e)");
    }
  }
}
