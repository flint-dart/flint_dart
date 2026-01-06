/// Generates Swagger/OpenAPI specification
class SwaggerGenerator {
  final paths = <String, dynamic>{};
  final servers = <Map<String, dynamic>>[];

  void addRoute(
    String fullPath,
    String method,
    Map<String, dynamic> operation,
    List<String> routeServers,
  ) {
    // Initialize path if not exists
    paths.putIfAbsent(fullPath, () => {});
    paths[fullPath][method] = operation;

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
  }) {
    final operation = <String, dynamic>{
      "summary": summary,
      "tags": tags,
      "responses": responses,
    };

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
      "components": {
        "securitySchemes": {
          "bearer": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"},
          "basicAuth": {"type": "http", "scheme": "basic"}
        }
      }
    };
  }
}
