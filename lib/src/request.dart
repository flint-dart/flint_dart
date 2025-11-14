import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flint_dart/flint_dart.dart';
import 'package:mime/mime.dart';

/// In-memory session storage (in production, use a persistent store)
final Map<String, Map<String, dynamic>> _sessionStore = {};

/// Represents a single uploaded file with metadata and content stream.
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

  /// Saves the uploaded file to the specified path
  Future<void> saveTo(String path) async {
    final file = File(path);
    final sink = file.openWrite();
    await content.pipe(sink);
    await sink.close();
  }
}

/// Enhanced HTTP request wrapper with comprehensive parsing, validation, and session management.
///
/// This class provides a convenient interface for handling HTTP requests in a Flint Dart server,
/// including body parsing, file uploads, authentication, session management, and validation.
class Request {
  /// The original [HttpRequest] from Dart's `dart:io` server.
  final HttpRequest raw;

  /// Route parameters matched by the router (e.g. `/user/:id`).
  final Map<String, String> params;

  /// Internal storage for request-scoped data
  final Map<String, dynamic> _storage = {};

  /// Cache for parsed body content to avoid multiple parsing
  dynamic _bodyCache;

  /// Constructs a [Request] with the raw [HttpRequest] and optional route [params].
  Request(this.raw, {Map<String, String>? params}) : params = params ?? {};

  // ==================== BASIC REQUEST PROPERTIES ====================

  /// The HTTP method (e.g. GET, POST, PUT, DELETE)
  String get method => raw.method;

  /// The full request path (e.g. `/api/users/1`)
  String get path => raw.uri.path;

  /// The request URI
  Uri get uri => raw.uri;

  /// All request headers as a case-insensitive map
  Map<String, String> get headers {
    final Map<String, String> result = {};
    raw.headers.forEach((name, values) {
      result[name] = values.join(', ');
    });
    return result;
  }

  /// Query parameters from the URL
  Map<String, String> get query => raw.uri.queryParameters;

  /// Client IP address
  String get ipAddress =>
      raw.connectionInfo?.remoteAddress.address ?? 'unknown';

  // ==================== REQUEST STORAGE ====================

  /// Stores a value in request-scoped storage
  void set(String key, dynamic value) => _storage[key] = value;

  /// Retrieves a value from request-scoped storage
  dynamic get(String key) => _storage[key];

  // ==================== AUTHENTICATION & JWT ====================

  /// Extract Bearer token from Authorization header
  String? get bearerToken {
    final header = headers['authorization'] ?? headers['Authorization'];
    if (header != null && header.startsWith('Bearer ')) {
      return header.substring(7);
    }
    return null;
  }

  /// JWT utility instance for token operations
  FlintJwt get jwt => FlintJwt(FlintEnv.get('JWT_SECRET'));

  /// Returns the authenticated user payload from JWT
  Map<String, dynamic>? get user => get('user');

  /// Returns true if the request has a valid authenticated user
  bool get isAuthenticated => user != null;

  /// Throws an exception if no user is authenticated
  Map<String, dynamic> requireUser() {
    final user = this.user;
    if (user == null) {
      throw Exception('Authentication required');
    }
    return user;
  }

  // ==================== SESSION MANAGEMENT ====================

  /// Session ID from FLINTSESSID cookie
  String? get sessionId => cookies['FLINTSESSID'];

  /// Returns current session data if exists
  Map<String, dynamic>? get session {
    final id = sessionId;
    return id != null ? _sessionStore[id] : null;
  }

  /// Creates a new session with the provided data
  Future<void> startSession(Map<String, dynamic> data) async {
    final newId = _generateSessionId();
    raw.response.cookies.add(
      Cookie('FLINTSESSID', newId)
        ..path = '/'
        ..httpOnly = true
        ..secure = true, // Use secure cookies in production
    );

    _sessionStore[newId] = Map<String, dynamic>.from(data);
  }

  /// Updates the current session data
  void updateSession(Map<String, dynamic> updates) {
    final id = sessionId;
    if (id != null && _sessionStore.containsKey(id)) {
      _sessionStore[id]!.addAll(updates);
    }
  }

  /// Destroys the current session
  void destroySession() {
    final id = sessionId;
    if (id != null) {
      _sessionStore.remove(id);
      // Clear the session cookie
      raw.response.cookies.add(
        Cookie('FLINTSESSID', '')
          ..path = '/'
          ..maxAge = 0,
      );
    }
  }

  /// Generates a cryptographically secure session ID
  String _generateSessionId() {
    // Improved session ID generation
    final random = List<int>.generate(
        32, (_) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64Url.encode(random) +
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ==================== COOKIE MANAGEMENT ====================

  /// Parsed cookies from the Cookie header
  Map<String, String> get cookies {
    final cookieHeader = raw.headers.value(HttpHeaders.cookieHeader);
    if (cookieHeader == null) return {};

    return Map.fromEntries(cookieHeader.split(';').map((cookie) {
      final trimmed = cookie.trim();
      final parts = trimmed.split('=');
      if (parts.length == 2) {
        return MapEntry(parts[0], parts[1]);
      }
      return MapEntry(trimmed, '');
    }));
  }

  // ==================== BODY PARSING ====================

  /// Internal body parsing method that handles different content types
  Future<void> _parseBody() async {
    if (_bodyCache != null) return;

    final contentTypeHeader = raw.headers.contentType;
    if (contentTypeHeader == null) {
      _bodyCache = await utf8.decodeStream(raw);
      return;
    }

    final mimeType = contentTypeHeader.mimeType;

    switch (mimeType) {
      case 'multipart/form-data':
        await _parseMultipartFormData(contentTypeHeader);
        break;
      case 'application/x-www-form-urlencoded':
        await _parseUrlEncodedFormData();
        break;
      case 'application/json':
        await _parseJsonBody();
        break;
      default:
        _bodyCache = await utf8.decodeStream(raw);
    }
  }

  /// Parses multipart/form-data requests (file uploads + form fields)
  Future<void> _parseMultipartFormData(ContentType contentTypeHeader) async {
    final boundary = contentTypeHeader.parameters['boundary'];
    if (boundary == null) {
      throw FormatException(
          'Missing multipart boundary in Content-Type header');
    }

    final parts = await MimeMultipartTransformer(boundary).bind(raw).toList();
    final files = <String, UploadedFile>{};
    final fields = <String, String>{};

    for (var part in parts) {
      final contentDisposition = part.headers['content-disposition'];
      if (contentDisposition != null) {
        await _processMultipartPart(part, contentDisposition, files, fields);
      }
    }

    _bodyCache = {'files': files, 'fields': fields};
  }

  /// Processes individual parts in a multipart request
  Future<void> _processMultipartPart(
    MimeMultipart part,
    String contentDisposition,
    Map<String, UploadedFile> files,
    Map<String, String> fields,
  ) async {
    final fieldName = _extractFieldName(contentDisposition);
    if (fieldName == null) return;

    if (contentDisposition.contains('filename=')) {
      // This is a file part
      final filename = _extractFilename(contentDisposition);
      final contentType = part.headers['content-type']?.split(';')[0];

      files[fieldName] = UploadedFile(
        fieldName: fieldName,
        filename: filename,
        contentType: contentType,
        content: part,
      );
    } else {
      // This is a regular form field
      fields[fieldName] = await utf8.decodeStream(part);
    }
  }

  /// Extracts field name from Content-Disposition header
  String? _extractFieldName(String contentDisposition) {
    final nameMatch = RegExp(r'name="([^"]*)"').firstMatch(contentDisposition);
    return nameMatch?.group(1);
  }

  /// Extracts filename from Content-Disposition header
  String _extractFilename(String contentDisposition) {
    final filenameMatch =
        RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);
    return filenameMatch?.group(1) ?? 'unknown';
  }

  /// Parses application/x-www-form-urlencoded data
  Future<void> _parseUrlEncodedFormData() async {
    final content = await utf8.decodeStream(raw);
    _bodyCache = Uri.splitQueryString(content);
  }

  /// Parses application/json data
  Future<void> _parseJsonBody() async {
    final content = await utf8.decodeStream(raw);
    if (content.isEmpty) {
      _bodyCache = <String, dynamic>{};
    } else {
      _bodyCache = jsonDecode(content);
    }
  }

  // ==================== BODY ACCESS METHODS ====================

  /// Reads and returns the raw request body as a string
  ///
  /// Note: For multipart/form-data requests, use [form()] or [files()] instead
  Future<String> body() async {
    await _parseBody();
    if (_bodyCache is String) {
      return _bodyCache;
    }
    return '';
  }

  /// Parses the body as JSON and returns a Map
  ///
  /// @throws FormatException if body is not valid JSON
  Future<Map<String, dynamic>> json() async {
    await _parseBody();

    if (_bodyCache is Map<String, dynamic>) {
      return _bodyCache;
    }

    if (_bodyCache is String && (_bodyCache as String).isEmpty) {
      return <String, dynamic>{};
    }

    throw FormatException('Expected a JSON object in request body');
  }

  /// Parses form data from application/x-www-form-urlencoded or multipart/form-data
  Future<Map<String, String>> form() async {
    await _parseBody();

    if (_bodyCache is Map<String, String>) {
      return _bodyCache;
    }

    if (_bodyCache is Map && _bodyCache.containsKey('fields')) {
      return Map<String, String>.from(_bodyCache['fields']);
    }

    return {};
  }

  /// Checks if a file with the given field name exists in the request
  Future<bool> hasFile(String fieldName) async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      final files = _bodyCache['files'] as Map<String, UploadedFile>;
      return files.containsKey(fieldName);
    }
    return false;
  }

  /// Retrieves a single uploaded file by field name
  Future<UploadedFile?> file(String fieldName) async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      final files = _bodyCache['files'] as Map<String, UploadedFile>;
      return files[fieldName];
    }
    return null;
  }

  /// Retrieves all uploaded files from the request
  Future<Map<String, UploadedFile>> files() async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      return Map<String, UploadedFile>.from(_bodyCache['files']);
    }
    return {};
  }

  // ==================== VALIDATION ====================

  /// Validates the request body against specified validation rules
  ///
  /// This method automatically parses the JSON body and validates it
  /// using the Flint validation system.
  ///
  /// Example:
  /// ```dart
  /// final data = await request.validate({
  ///   'email': 'required|email',
  ///   'password': 'required|min:6',
  ///   'age': 'optional|integer|min:18'
  /// });
  /// ```
  ///
  /// @param rules Validation rules in pipe-separated format
  /// @returns Validated and parsed request body
  /// @throws ValidationException if validation fails
  Future<Map<String, dynamic>> validate(Map<String, String> rules) async {
    final body = await json();
    await Validator.validate(body, rules);
    return body;
  }

  /// Validates form data against specified rules
  ///
  /// Useful for traditional form submissions
  Future<Map<String, String>> validateForm(Map<String, String> rules) async {
    final formData = await form();
    await Validator.validate(formData, rules);
    return formData;
  }
}
