import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/template_engine/template.dart';
import 'package:path/path.dart' as p;

import '../flint_dart.dart';

/// Supported response types for automatic content handling.
enum RespondType {
  /// JSON data (application/json)
  json,

  /// HTML content (text/html)
  html,

  /// Plain text (text/plain)
  plain,
}

/// A wrapper around [HttpResponse] for sending HTTP responses in Flint Dart.
///
/// The [Response] class provides helper methods to:
/// - Send plain text, HTML, or JSON responses
/// - Stream files
/// - Set HTTP status codes
/// - Automatically determine response types
///
/// Example:
/// ```dart
/// app.get('/hello', (req, res) {
///   res.send('Hello World!');
/// });
///
/// app.get('/user', (req, res) {
///   res.json({'name': 'John'});
/// });
/// ```
class Response {
  /// The underlying raw [HttpResponse] object.
  final HttpResponse raw;
  bool _closed = false;

  /// Creates a new [Response] instance with the given [HttpResponse].
  Response(this.raw);
  bool get isClosed => _closed;

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await raw.close();
    }
  }

  /// Sends a plain text or custom content response.
  ///
  /// [body] is the content to send.
  /// [status] is the optional HTTP status code.
  /// [contentType] defaults to `text/plain`.
  Response send(
    String body, {
    int? status,
    String contentType = 'text/plain',
  }) {
    try {
      raw.statusCode = status ?? raw.statusCode;
      raw.headers.contentType = ContentType.parse(contentType);
      raw.write(body);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to send response: Invalid content.');
    }
    close();
    return this; // ✅ return Response
  }

  /// Sends a JSON response with a [Map] or [List].
  ///
  /// Automatically sets the `Content-Type` header to `application/json`.
  /// [status] can be provided to override the HTTP status code.
  Response json(dynamic data, {int? status}) {
    try {
      final encoded = jsonEncode(data);
      raw.statusCode = status ?? raw.statusCode;
      raw.headers.contentType = ContentType.json;
      raw.write(encoded);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to encode JSON response: ${e.runtimeType}');
      print('[Flint] JSON Error: $e');
    }
    close();
    return this; // ✅ return Response
  }

  /// Sends a response automatically based on [RespondType] or inferred type.
  ///
  /// - If [type] is provided, it is used directly.
  /// - If not, the type is inferred from [data] (Map/List → JSON, HTML tags → HTML, otherwise plain text).
  Response respond(
    dynamic data, {
    int? status,
    RespondType? type,
  }) {
    try {
      type ??= _inferRespondType(data);

      switch (type) {
        case RespondType.json:
          json(data, status: status);
          break;
        case RespondType.html:
          send(data.toString(), status: status, contentType: 'text/html');
          break;
        case RespondType.plain:
          send(data.toString(), status: status, contentType: 'text/plain');
      }
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to send response: ${e.runtimeType}');
      print('[Flint] respond() Error: $e');
    }
    close();
    return this; // ✅ return Response
  }

  /// Attempts to guess the best [RespondType] based on [data].
  ///
  /// - Map/List → JSON
  /// - HTML-like string → HTML
  /// - Otherwise → Plain text
  RespondType _inferRespondType(dynamic data) {
    if (data is Map || data is List) {
      return RespondType.json;
    } else if (data is String &&
        (data.contains('<html') || data.contains('<!DOCTYPE html'))) {
      return RespondType.html;
    } else {
      return RespondType.plain;
    }
  }

  /// Sets the HTTP status code for the response without sending content.
  ///
  /// Can be chained with other calls:
  /// ```dart
  /// res.status(404).send('Not Found');
  /// ```
  Response status(int code) {
    raw.statusCode = code;
    return this;
  }

  /// Streams the contents of a [File] directly to the response body.
  ///
  /// Does not set the content type automatically — you should set it before calling.
  Future<void> streamFile(File file) async {
    await raw.addStream(file.openRead());
  }

  /// Redirects the client to a different [location] (URL or path).
  ///
  /// [status] defaults to `302` (Found). You can use:
  /// - `301` → Permanent Redirect
  /// - `302` → Temporary Redirect
  ///
  /// Example:
  /// ```dart
  /// res.redirect('/login');
  /// res.redirect('https://example.com', status: 301);
  /// ```
  Response redirect(String location, {int status = HttpStatus.found}) {
    try {
      raw.statusCode = status;
      raw.headers.set(HttpHeaders.locationHeader, location);
      raw.write(
          '<html><body><a href="$location">Redirecting to $location...</a></body></html>');
    } catch (e) {
      raw.statusCode = 500;
      raw.write('❌ Redirect failed: ${e.runtimeType}');
      print('[Flint] Redirect Error: $e');
    }
    close();
    return this;
  }

  /// Sends a predefined HTTP status message and closes the response.
  ///
  /// Example:
  /// ```dart
  /// res.sendStatus(404); // Sends "Not Found"
  /// ```
  Response sendStatus(int code) {
    final message = _statusMessages[code] ?? 'Status';
    raw.statusCode = code;
    return send(message);
  }

  /// Renders an HTML view from a file.
  ///
  /// [filePath] can be absolute or relative to your project's `views` directory.
  /// Optionally, you can pass [data] for simple variable replacement in the template.
  Future<Response> view(String filePath, {Map<String, dynamic>? data}) async {
    // Resolve possible view file paths
    final base = p.join(Flint.viewPath, filePath);

    final flintPath = base.endsWith('.flint.html') ? base : '$base.flint.html';
    final htmlPath = base.endsWith('.html') ? base : '$base.html';

    File? file;

    if (await File(flintPath).exists()) {
      file = File(flintPath);
    } else if (await File(htmlPath).exists()) {
      file = File(htmlPath);
    }

    if (file == null) {
      raw.statusCode = 404;
      raw.write('❌ View not found: $flintPath');
      await raw.close();
      return this;
    }

    String content;

    // Render based on file extension
    if (file.path.endsWith('.flint.html')) {
      content = await TemplateEngine().render(file.path, data: data);
    } else {
      content = await file.readAsString();
    }

    raw.statusCode = 200;
    raw.headers.contentType = ContentType.html;
    raw.write(content);
    await raw.close();

    return this;
  }
}

/// Common HTTP status codes and their default messages.
const Map<int, String> _statusMessages = {
  200: 'OK',
  201: 'Created',
  202: 'Accepted',
  204: 'No Content',
  301: 'Moved Permanently',
  302: 'Found',
  304: 'Not Modified',
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  409: 'Conflict',
  422: 'Unprocessable Entity',
  500: 'Internal Server Error',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
};
