import 'dart:convert';
import 'dart:io';

/// Supported response types
enum RespondType {
  json,
  html,
  plain,
}

class Response {
  final HttpResponse raw;

  Response(this.raw);

  /// Sends a plain text or custom content response.
  void send(
    String body, {
    int? status,
    String contentType = 'text/plain',
  }) {
    try {
      raw.statusCode = status ?? raw.statusCode; // ✅ use existing if set
      raw.headers.contentType = ContentType.parse(contentType);
      raw.write(body);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to send response: Invalid content.');
    }
  }

  /// Sends a JSON response with a map or list.
  void json(dynamic data, {int? status}) {
    try {
      final encoded = jsonEncode(data);
      raw.statusCode = status ?? raw.statusCode; // ✅ use existing if set
      raw.headers.contentType = ContentType.json;
      raw.write(encoded);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to encode JSON response: ${e.runtimeType}');
      print('[Flint] JSON Error: $e');
    }
  }

  /// Automatically responds based on [RespondType] or inferred type.
  void respond(
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
  }

  /// Infers response type from data.
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

  /// Sets the status code of the response without sending data.
  Response status(int code) {
    raw.statusCode = code;
    return this;
  }

  /// Streams the contents of a [file] directly to the response body.
  ///
  /// @param file The [File] to be served.
  Future<void> streamFile(File file) async {
    await raw.addStream(file.openRead());
  }

  /// Sends a predefined status message and closes the response.
  void sendStatus(int code) {
    final message = _statusMessages[code] ?? 'Status';
    raw.statusCode = code;
    send(message);
    raw.close();
  }
}

/// Common HTTP status codes and their default messages
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
