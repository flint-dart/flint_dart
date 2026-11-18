/// Generates Swagger/OpenAPI specification
class SwaggerGenerator {
  final paths = <String, dynamic>{};
  final servers = <Map<String, dynamic>>[];
  final websocketPaths = <String, dynamic>{};
  final queryPaths = <String, dynamic>{};

  void addRoute(String fullPath, String method, Map<String, dynamic> operation,
      List<String> routeServers,
      {bool isWebSocket = false}) {
    final normalizedMethod = method.toLowerCase();

    if (isWebSocket) {
      websocketPaths[fullPath] = operation;
    }

    // Initialize path if not exists
    paths.putIfAbsent(fullPath, () => {});

    if (normalizedMethod == 'query') {
      final queryOperation = {
        ...operation,
        'x-http-method': 'QUERY',
        'x-openapi-operation-key-unavailable': true,
      };
      final existingOperation =
          paths[fullPath]['x-flint-query'] as Map<String, dynamic>?;
      if (existingOperation == null) {
        paths[fullPath]['x-flint-query'] = queryOperation;
        queryPaths[fullPath] = queryOperation;
      } else {
        final merged = _mergeOperations(existingOperation, queryOperation);
        paths[fullPath]['x-flint-query'] = merged;
        queryPaths[fullPath] = merged;
      }
    } else {
      final existingOperation =
          paths[fullPath][normalizedMethod] as Map<String, dynamic>?;
      if (existingOperation == null) {
        paths[fullPath][normalizedMethod] = operation;
      } else {
        paths[fullPath][normalizedMethod] =
            _mergeOperations(existingOperation, operation);
      }
    }

    // Collect unique servers
    for (var server in routeServers) {
      if (!servers.any((srv) => srv['url'] == server)) {
        servers.add({'url': server});
      }
    }
  }

  Map<String, dynamic> createOperation({
    required String summary,
    required List<String> tags,
    required Map<String, dynamic> responses,
    Map<String, dynamic>? requestBody,
    List<Map<String, dynamic>>? queryParameters,
    List<Map<String, dynamic>>? parameters,
    String? auth,
    required String fullPath,
    bool isWebSocket = false,
  }) {
    final normalizedResponses = <String, dynamic>{...responses};
    final operation = <String, dynamic>{
      "summary": summary,
      "tags": tags,
      "responses": normalizedResponses,
    };

    if (isWebSocket) {
      normalizedResponses.putIfAbsent(
        '101',
        () => {"description": "Switching Protocols"},
      );
      operation['x-websocket'] = true;
      operation['x-flint-transport'] = 'websocket';
      operation['x-flint-namespace'] = fullPath;
    }

    // Add requestBody if provided
    if (requestBody != null) {
      operation['requestBody'] = requestBody;
    }

    // 1️⃣ Extract path parameters from the URL
    final pathParams = _extractPathParams(fullPath);

    // 2️⃣ Combine all parameters: path first, then query, then manual
    final allParameters = [
      ...pathParams,
      if (queryParameters != null) ...queryParameters,
      if (parameters != null) ...parameters,
    ];

    // 3️⃣ Make parameters unique by `in:name`
    final uniqueParamsMap = <String, Map<String, dynamic>>{};
    for (var p in allParameters) {
      final key = '${p["in"]}:${p["name"]}';
      uniqueParamsMap[key] = p;
    }

    // 4️⃣ Assign the unique parameters to operation
    if (uniqueParamsMap.isNotEmpty) {
      operation['parameters'] = uniqueParamsMap.values.toList();
    }

    // 5️⃣ Add authentication/security if provided
    if (auth != null) {
      operation['security'] = [
        {auth: []}
      ];
    }

    return operation;
  }

  Map<String, dynamic> _mergeOperations(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = <String, dynamic>{...existing};

    incoming.forEach((key, value) {
      if (key == 'responses' &&
          value is Map<String, dynamic> &&
          existing[key] is Map<String, dynamic>) {
        merged[key] = {
          ...(existing[key] as Map<String, dynamic>),
          ...value,
        };
        return;
      }

      if (key == 'parameters' &&
          value is List &&
          existing[key] is List<Map<String, dynamic>>) {
        final params = <String, Map<String, dynamic>>{};
        for (final parameter
            in (existing[key] as List).cast<Map<String, dynamic>>()) {
          params['${parameter["in"]}:${parameter["name"]}'] = parameter;
        }
        for (final parameter in value.cast<Map<String, dynamic>>()) {
          params['${parameter["in"]}:${parameter["name"]}'] = parameter;
        }
        merged[key] = params.values.toList();
        return;
      }

      merged[key] = value;
    });

    return merged;
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

  Map<String, dynamic> generateSwagger() {
    return {
      "openapi": "3.0.0",
      "info": {"title": "Flint API", "version": "1.0.0"},
      if (servers.isNotEmpty) "servers": servers,
      "paths": paths,
      if (websocketPaths.isNotEmpty) "x-websockets": websocketPaths,
      if (queryPaths.isNotEmpty) "x-flint-query-routes": queryPaths,
      if (queryPaths.isNotEmpty)
        "x-flint-query-openapi-note":
            "OpenAPI 3.0 has no standard QUERY operation key. Flint preserves HTTP QUERY operations with x-http-method: QUERY.",
      "components": {
        "securitySchemes": {
          "bearer": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"},
          "basicAuth": {"type": "http", "scheme": "basic"}
        }
      }
    };
  }
}
