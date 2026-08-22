import 'package:flint_client/flint_client.dart';
import 'package:universal_web/web.dart' as web;

/// Browser API client with Flint-style route grouping.
class ClientRouter {
  /// Creates a client router using the current browser origin by default.
  ClientRouter({
    String? baseUrl,
    this.prefix = '',
    Map<String, String> headers = const {},
    Map<String, dynamic> query = const {},
    Duration timeout = const Duration(seconds: 30),
    bool debug = false,
    bool throwIfError = false,
    bool withCredentials = true,
    ErrorHandler? onError,
    RequestDoneCallback? onDone,
    StatusCodeConfig statusCodeConfig = const StatusCodeConfig(),
  }) : client = FlintClient(
         baseUrl: baseUrl ?? _browserOrigin(),
         headers: headers,
         defaultQueryParameters: query,
         timeout: timeout,
         debug: debug,
         throwIfError: throwIfError,
         withCredentials: withCredentials,
         onError: onError,
         onDone: onDone,
         statusCodeConfig: statusCodeConfig,
       );

  /// Creates a router around an existing [FlintClient].
  ClientRouter.fromClient(this.client, {this.prefix = ''});

  /// The underlying Flint HTTP client.
  final FlintClient client;

  /// Route prefix applied to relative request paths.
  final String prefix;

  /// Returns a new router with [prefix] appended to this router's prefix.
  ClientRouter group(String prefix) {
    return ClientRouter.fromClient(client, prefix: _join(this.prefix, prefix));
  }

  /// Sends a GET request to [path].
  Future<FlintResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? timeout,
  }) {
    return client.get<T>(
      _path(path),
      queryParameters: query,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: timeout,
    );
  }

  /// Sends a POST request to [path].
  Future<FlintResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? timeout,
  }) {
    return client.post<T>(
      _path(path),
      body: body,
      queryParameters: query,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: timeout,
    );
  }

  /// Sends a QUERY request to [path].
  Future<FlintResponse<T>> query<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? timeout,
  }) {
    return client.query<T>(
      _path(path),
      body: body,
      queryParameters: query,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: timeout,
    );
  }

  /// Sends a PUT request to [path].
  Future<FlintResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? timeout,
  }) {
    return client.put<T>(
      _path(path),
      body: body,
      queryParameters: query,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: timeout,
    );
  }

  /// Sends a PATCH request to [path].
  Future<FlintResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? timeout,
  }) {
    return client.patch<T>(
      _path(path),
      body: body,
      queryParameters: query,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: timeout,
    );
  }

  /// Sends a DELETE request to [path].
  Future<FlintResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? timeout,
  }) {
    return client.delete<T>(
      _path(path),
      queryParameters: query,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: timeout,
    );
  }

  /// Sends a request using [method] and dispatches to the matching verb helper.
  Future<FlintResponse<T>> request<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? timeout,
  }) {
    return switch (method.toUpperCase()) {
      'GET' => get<T>(
        path,
        query: query,
        headers: headers,
        parser: parser,
        onError: onError,
        onDone: onDone,
        timeout: timeout,
      ),
      'POST' => post<T>(
        path,
        body: body,
        query: query,
        headers: headers,
        parser: parser,
        onError: onError,
        onDone: onDone,
        timeout: timeout,
      ),
      'QUERY' => this.query<T>(
        path,
        body: body,
        query: query,
        headers: headers,
        parser: parser,
        onError: onError,
        onDone: onDone,
        timeout: timeout,
      ),
      'PUT' => put<T>(
        path,
        body: body,
        query: query,
        headers: headers,
        parser: parser,
        onError: onError,
        onDone: onDone,
        timeout: timeout,
      ),
      'PATCH' => patch<T>(
        path,
        body: body,
        query: query,
        headers: headers,
        parser: parser,
        onError: onError,
        onDone: onDone,
        timeout: timeout,
      ),
      'DELETE' => delete<T>(
        path,
        query: query,
        headers: headers,
        parser: parser,
        onError: onError,
        onDone: onDone,
        timeout: timeout,
      ),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };
  }

  String _path(String path) {
    final value = path.trim();
    if (_isFullUrl(value)) return value;
    return _join(prefix, value);
  }

  bool _isFullUrl(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  String _join(String left, String right) {
    final a = left.trim();
    final b = right.trim();

    if (a.isEmpty) return b.isEmpty ? '/' : _withLeadingSlash(b);
    if (b.isEmpty || b == '/') return _withLeadingSlash(a);

    final cleanLeft = _withLeadingSlash(a).replaceFirst(RegExp(r'/+$'), '');
    final cleanRight = b.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanLeft/$cleanRight';
  }

  String _withLeadingSlash(String path) {
    return path.startsWith('/') ? path : '/$path';
  }
}

/// Shared browser API router using the current origin.
final clientRouter = ClientRouter();

String _browserOrigin() {
  final location = web.window.location;
  final origin = location.origin;

  if (origin.isNotEmpty) return origin;

  final protocol = location.protocol;
  final host = location.host;

  if (protocol.isNotEmpty && host.isNotEmpty) return '$protocol//$host';

  return 'http://localhost';
}
