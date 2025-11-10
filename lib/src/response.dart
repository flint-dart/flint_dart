import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/flint_ui.dart';
import 'package:flint_dart/mail.dart';
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
  flint,
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
  Future<Response> json(dynamic data, {int? status}) async {
    try {
      // Await top-level Future
      if (data is Future) {
        data = await data;
      }

      /// Recursively converts data into JSON-serializable form
      Future<dynamic> sanitize(dynamic value) async {
        // Await if value is Future
        if (value is Future) value = await value;

        if (value is DateTime) return value.toIso8601String();
        if (value is Model) return sanitize(value.toMap());
        if (value is List) {
          // Await each item
          final results = await Future.wait(value.map(sanitize));
          return results;
        }
        if (value is Map) {
          final entries = await Future.wait(value.entries.map((e) async {
            final sanitizedValue = await sanitize(e.value);
            return MapEntry(e.key, sanitizedValue);
          }));
          return Map.fromEntries(entries);
        }

        // For custom classes
        try {
          final toMapMethod = (value as dynamic).toMap;
          if (toMapMethod is Function) return sanitize(toMapMethod());

          final toJsonMethod = (value as dynamic).toJson;
          if (toJsonMethod is Function) return sanitize(toJsonMethod());
        } catch (_) {}

        return value; // primitives or unsupported objects
      }

      final safeData = await sanitize(data);
      final encoded = jsonEncode(safeData);

      raw.statusCode = status ?? raw.statusCode;
      raw.headers.contentType = ContentType.json;
      raw.write(encoded);
    } catch (e, stack) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to encode JSON response: ${e.runtimeType}');
      print('[Flint] JSON Error: $e\n$stack');
    }

    await close();
    return this;
  }

  /// Sends a response automatically based on [RespondType] or inferred type.
  ///
  /// - If [type] is provided, it is used directly.
  /// - If not, the type is inferred from [data] (Map/List → JSON, HTML tags → HTML, otherwise plain text).
  Future<Response> respond(
    dynamic data, {
    int? status,
    RespondType? type,
    bool? includePreview,
    String? title,
  }) async {
    try {
      // If data is a Future, await it first
      if (data is Future) {
        data = await data;
      }

      // Determine the type asynchronously
      type ??= await _inferRespondType(data);

      switch (type) {
        case RespondType.json:
          await json(data, status: status);
          break;

        case RespondType.html:
          send(data.toString(), status: status, contentType: 'text/html');
          break;

        case RespondType.plain:
          send(data.toString(), status: status, contentType: 'text/plain');
          break;

        case RespondType.flint:
          if (data is FlintWidget) {
            render(
              data,
              title: title,
              status: status,
              includePreview: includePreview == true,
            );
          } else {
            throw ArgumentError('Data must be a FlintWidget for flint type');
          }
          break;
      }
    } catch (e, stack) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to send response: ${e.runtimeType}');
      print('[Flint] respond() Error: $e\n$stack');
    }

    await close();
    return this;
  }

  /// Attempts to guess the best [RespondType] based on [data].
  ///
  /// - Map/List → JSON
  /// - HTML-like string → HTML
  /// - Otherwise → Plain text
  /// Now includes FlintWidget detection
  Future<RespondType> _inferRespondType(dynamic data) async {
    // Await if it's a Future
    if (data is Future) {
      data = await data;
    }

    if (data is FlintWidget) {
      return RespondType.flint;
    } else if (data is Map || data is List) {
      return RespondType.json;
    } else if (data is Model) {
      return RespondType.json;
    } else if (data is String &&
        (data.contains('<html') || data.contains('<!DOCTYPE html'))) {
      return RespondType.html;
    } else {
      return RespondType.plain;
    }
  }

  Response render(
    FlintWidget widget, {
    String? title,
    int? status,
    bool includePreview = false,
  }) {
    try {
      raw.statusCode = status ?? raw.statusCode;
      raw.headers.contentType = ContentType.html;

      final html = includePreview
          ? _generatePreviewHtml(widget, title ?? 'Flint Render')
          : widget.toHtml();

      raw.write(html);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to render FlintWidget: ${e.runtimeType}');
      print('[Flint] Render Error: $e');
    }
    close();
    return this;
  }

  /// Renders a Mailable email template to HTML preview.
  ///
  /// [mailable] is the Mailable instance to render.
  /// [includePreview] wraps the content in email preview interface if true.
  Response renderEmail(
    Mailable mailable, {
    bool includePreview = true,
  }) {
    try {
      raw.statusCode = 200;
      raw.headers.contentType = ContentType.html;

      final content = mailable.build();
      final html = includePreview
          ? _generatePreviewHtml(content, mailable.subject)
          : content.toHtml();

      raw.write(html);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('❌ Failed to render email: ${e.runtimeType}');
      print('[Flint] Render Email Error: $e');
    }
    close();
    return this;
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

    // Render based on file extension

    String content = await FlintTemplateEngine().render(file.path, data: data);

    raw.statusCode = 200;
    raw.headers.contentType = ContentType.html;
    raw.write(content);
    await raw.close();

    return this;
  }

  /// Generates a preview HTML wrapper for FlintWidget content
  String _generatePreviewHtml(FlintWidget content, String title) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Preview: $title</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            padding: 20px;
        }
        
        .preview-container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .preview-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 12px 12px 0 0;
            margin-bottom: 0;
        }
        
        .preview-header h1 {
            font-size: 24px;
            margin-bottom: 10px;
        }
        
        .device-preview {
            background: white;
            border-radius: 0 0 12px 12px;
            padding: 40px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
        }
        
        .preview-controls {
            margin-top: 20px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .preview-controls button {
            background: rgba(255,255,255,0.2);
            border: 1px solid rgba(255,255,255,0.3);
            color: white;
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            backdrop-filter: blur(10px);
            transition: all 0.2s;
        }
        
        .preview-controls button:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-1px);
        }
        
        .back-link {
            display: inline-block;
            margin-top: 20px;
            color: #007cba;
            text-decoration: none;
            padding: 8px 16px;
            border: 1px solid #007cba;
            border-radius: 6px;
        }
        
        .back-link:hover {
            background: #007cba;
            color: white;
        }
        
        @media (max-width: 768px) {
            .preview-controls {
                flex-direction: column;
            }
            
            .device-preview {
                padding: 20px;
            }
        }
    </style>
</head>
<body>
    <div class="preview-container">
        <div class="preview-header">
            <h1>📧 $title</h1>
            <p>Flint Widget Preview</p>
            <div class="preview-controls">
                <button onclick="copyHtml()">Copy HTML</button>
                <button onclick="showHtml()">Show HTML Source</button>
                <button onclick="showText()">Show Text Version</button>
                <button onclick="showJson()">Show JSON</button>
                <button onclick="downloadHtml()">Download HTML</button>
            </div>
        </div>
        
        <div class="device-preview">
            ${content.toHtml()}
        </div>
        
        <a href="javascript:history.back()" class="back-link">← Back</a>
    </div>

    <script>
        const htmlContent = `${content.toHtml().replaceAll('`', '\\`')}`;
        const textContent = `${content.toText().replaceAll('`', '\\`')}`;
        const jsonContent = ${jsonEncode(content.toJson())};
        
        function copyHtml() {
            navigator.clipboard.writeText(htmlContent).then(() => {
                alert('✅ HTML copied to clipboard!');
            }).catch(err => {
                alert('❌ Failed to copy: ' + err);
            });
        }
        
        function showHtml() {
            const newWindow = window.open('', '_blank');
            newWindow.document.write(
                '<!DOCTYPE html><html><head><title>HTML Source</title><style>body { font-family: monospace; white-space: pre-wrap; padding: 20px; }</style></head><body>' + 
                htmlContent.replace(/</g, '&lt;').replace(/>/g, '&gt;') + 
                '</body></html>'
            );
        }
        
        function showText() {
            const newWindow = window.open('', '_blank');
            newWindow.document.write(
                '<!DOCTYPE html><html><head><title>Text Version</title><style>body { font-family: monospace; white-space: pre-wrap; padding: 20px; }</style></head><body>' + 
                textContent.replace(/</g, '&lt;').replace(/>/g, '&gt;') + 
                '</body></html>'
            );
        }
        
        function showJson() {
            const newWindow = window.open('', '_blank');
            newWindow.document.write(
                '<!DOCTYPE html><html><head><title>JSON Data</title><style>body { font-family: monospace; white-space: pre-wrap; padding: 20px; }</style></head><body>' + 
                JSON.stringify(jsonContent, null, 2).replace(/</g, '&lt;').replace(/>/g, '&gt;') + 
                '</body></html>'
            );
        }
        
        function downloadHtml() {
            const blob = new Blob([htmlContent], { type: 'text/html' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'flint-widget-${DateTime.now().millisecondsSinceEpoch}.html';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        }
    </script>
</body>
</html>
''';
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
