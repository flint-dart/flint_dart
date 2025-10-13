import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flint_dart/src/validation/validator.dart';
import 'package:mime/mime.dart';

/// Represents a single uploaded file.
class UploadedFile {
  final String fieldName;
  final String filename;
  final String? contentType;
  final Stream<List<int>> content;

  UploadedFile({
    required this.fieldName,
    required this.filename,
    this.contentType,
    required this.content,
  });
}

/// Represents an HTTP request with convenient accessors for
/// method, headers, parameters, body, and other common features.
class Request {
  /// The original [HttpRequest] from Dart's `dart:io` server.
  final HttpRequest raw;

  /// Route parameters matched by the router (e.g. `/user/:id`).
  final Map<String, String> params;

  /// A cache for the parsed body content.
  dynamic _bodyCache;

  /// Constructs a [Request] with the raw [HttpRequest] and optional route [params].
  Request(this.raw, {Map<String, String>? params}) : params = params ?? {};

  /// The HTTP method (e.g. GET, POST, PUT).
  String get method => raw.method;

  /// The full request path (e.g. `/api/users/1`).
  String get path => raw.uri.path;

  /// All request headers as a [Map<String, String>].
  /// If a header has multiple values, they are joined with commas.
  Map<String, String> get headers {
    final Map<String, String> result = {};
    raw.headers.forEach((name, values) {
      result[name] = values.join(', ');
    });
    return result;
  }

  /// Query parameters from the URL as a [Map<String, String>].
  Map<String, String> get query => raw.uri.queryParameters;

  /// Parses the request body and caches the result.
  Future<void> _parseBody() async {
    if (_bodyCache != null) return;

    final contentTypeHeader = raw.headers.contentType;
    if (contentTypeHeader == null) {
      _bodyCache = await utf8.decodeStream(raw);
      return;
    }

    final mimeType = contentTypeHeader.mimeType;

    if (mimeType == 'multipart/form-data') {
      final boundary = contentTypeHeader.parameters['boundary'];
      if (boundary == null) {
        throw FormatException('Missing multipart boundary.');
      }
      final parts = await MimeMultipartTransformer(boundary).bind(raw).toList();
      final files = <String, UploadedFile>{};
      final fields = <String, String>{};

      for (var part in parts) {
        final contentDisposition = part.headers['content-disposition'];
        if (contentDisposition != null) {
          final isFile = contentDisposition.contains('filename=');
          final fieldName = contentDisposition
              .split('name=')[1]
              .split(';')[0]
              .replaceAll('"', '');

          if (isFile) {
            final filename =
                contentDisposition.split('filename=')[1].replaceAll('"', '');
            final contentType = part.headers['content-type']?.split(';')[0];
            final file = UploadedFile(
              fieldName: fieldName,
              filename: filename,
              contentType: contentType,
              content: part,
            );
            files[fieldName] = file;
          } else {
            fields[fieldName] = await utf8.decodeStream(part);
          }
        }
      }
      _bodyCache = {'files': files, 'fields': fields};
    } else if (mimeType == 'application/x-www-form-urlencoded') {
      final content = await utf8.decodeStream(raw);
      _bodyCache = Uri.splitQueryString(content);
    } else {
      _bodyCache = await utf8.decodeStream(raw);
    }
  }

  /// Reads and returns the raw request body as a [String].
  /// Note: This will not work for `multipart/form-data` requests.
  Future<String> body() async {
    await _parseBody();
    if (_bodyCache is String) {
      return _bodyCache;
    }
    return '';
  }

  /// Parses the body as JSON and returns a [Map<String, dynamic>].
  /// Throws if the body is not valid JSON.
  Future<Map<String, dynamic>> json() async {
    final content = await body();
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw FormatException('Expected a JSON object');
  }

  /// Parses the request body and returns a [Map] of form fields.
  ///
  /// This method handles two types of form data:
  /// 1. `application/x-www-form-urlencoded`: Returns the key-value pairs directly.
  /// 2. `multipart/form-data`: Extracts and returns the non-file fields.
  ///
  /// Use this method to access form data, especially when handling file uploads
  /// where the other fields (e.g., user name, file description) are sent
  /// alongside the file.
  ///
  /// @returns A [Future] that completes with a [Map<String, String>] of the form fields.
  Future<Map<String, String>> form() async {
    await _parseBody();
    if (_bodyCache is Map<String, String>) {
      return _bodyCache;
    }
    if (_bodyCache is Map && _bodyCache.containsKey('fields')) {
      return _bodyCache['fields'] as Map<String, String>;
    }
    return {};
  }

  /// Checks if a file with the given name exists in the request.
  /// @param name The name of the file field.
  /// Returns `true` if a file is uploaded with the given `field`.
  /// Returns `false` otherwise.
  Future<bool> hasFile(String name) async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      final files = _bodyCache['files'] as Map<String, UploadedFile>;
      return files.containsKey(name);
    }
    return false;
  }

  /// Retrieves a single uploaded file by its field name.
  /// @param name The name of the file field.
  /// @returns An [UploadedFile] object or `null` if not found.
  Future<UploadedFile?> file(String name) async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      final files = _bodyCache['files'] as Map<String, UploadedFile>;
      return files[name];
    }
    return null;
  }

  /// Retrieves all uploaded files from the request.
  /// @returns A [Map] of all uploaded files, keyed by field name.
  Future<Map<String, UploadedFile>> files() async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      return _bodyCache['files'] as Map<String, UploadedFile>;
    }
    return {};
  }

  // --- Other existing methods ---

  /// Returns the bearer token from the `Authorization` header if present.
  String? get bearerToken {
    final auth = headers['authorization'];
    if (auth != null && auth.startsWith('Bearer ')) {
      return auth.substring(7);
    }
    return null;
  }

  /// Parses cookies from the `Cookie` header into a [Map<String, String>].
  Map<String, String> get cookies {
    final cookieHeader = raw.headers.value(HttpHeaders.cookieHeader);
    if (cookieHeader == null) return {};
    return Map.fromEntries(cookieHeader.split(';').map((cookie) {
      final parts = cookie.trim().split('=');
      return MapEntry(parts[0], parts[1]);
    }));
  }

  /// 📘 **Validate Request Body**
  ///
  /// This method parses and validates the incoming JSON request body
  /// against the specified validation [rules].
  ///
  /// ---
  /// ### ✅ **Usage Example**
  ///
  /// ```dart
  /// // Inside a controller method
  /// Future<Response> register(Request req) async {
  ///   final data = await req.validate({
  ///     'name': 'required|string',
  ///     'email': 'required|string|email',
  ///     'password': 'required|string|confirmed|min:6',
  ///   });
  ///
  ///   // Safe to use: all fields are validated
  ///   return Response.json({'user': data});
  /// }
  /// ```
  ///
  /// ---
  /// ### 🧠 **Behavior**
  /// - Reads the request body as JSON.
  /// - Validates all keys using the [Validator.validate] method.
  /// - Throws a `ValidationException` if any rule fails.
  /// - Returns the parsed request body (`Map<String, dynamic>`) if validation passes.
  ///
  /// ---
  /// ### ⚙️ **Supported Validation Rules**
  /// - `required` — Field must not be null or empty.
  /// - `string` — Must be a string.
  /// - `email` — Must be a valid email format.
  /// - `numeric` — Must be a number.
  /// - `min:<n>` — Minimum string length or numeric value.
  /// - `max:<n>` — Maximum string length or numeric value.
  /// - `confirmed` — Field must have a matching confirmation field (`confirm_field` or `field_confirmation`).
  /// - `boolean` — Must be `true` or `false`.
  /// - `date` — Must be a valid date string or `DateTime`.
  /// - `in:<a,b,c>` — Value must be one of the listed items.
  ///
  /// ---
  /// ### ⚠️ **Throws**
  /// - `ValidationException` — when one or more rules fail.
  ///
  /// ---
  /// ### 📤 **Returns**
  /// - A `Map<String, dynamic>` representing the validated request body.
  ///
  Future<Map<String, dynamic>> validate(Map<String, String> rules) async {
    final body = await json();
    await Validator.validate(body, rules);
    return body;
  }
}
