import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/auth/auth.dart';
import 'package:flint_dart/src/session/session.dart';
import 'package:mime/mime.dart';

class UploadedFile {
  final String fieldName;
  final String filename;
  final String? contentType;
  final int? size; // file size in bytes
  final String? extension; // ".png", ".jpg"
  final DateTime uploadedAt; // auto timestamp
  final Stream<List<int>> content;

  UploadedFile({
    required this.fieldName,
    required this.filename,
    this.contentType,
    this.size,
    this.extension,
    DateTime? uploadedAt,
    required this.content,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  Future<void> saveTo(String path) async {
    final file = File(path);
    final sink = file.openWrite();
    await content.pipe(sink);
    await sink.close();
  }
}

/// Enhanced HTTP request wrapper with comprehensive parsing, validation, and session management.
class Request {
  /// The original [HttpRequest] from Dart's `dart:io` server.
  final HttpRequest raw;

  /// Route parameters matched by the router (e.g. `/user/:id`).
  final Map<String, String> params;

  /// Route parameters matched by the router
  /// (e.g. `/user/:id`).
  /// param() returns the value of a route parameter.
  String? param(String key) => params[key];

  String? queryParam(String key) => query[key];

  /// Access route parameters using bracket notation.
  String? operator [](String key) {
    return params[key] ?? query[key];
  }

  String? input(String key) {
    return params[key] ?? query[key];
  }

  /// Internal storage for request-scoped data
  final Map<String, dynamic> _storage = {};

  /// Cache for parsed body content to avoid multiple parsing
  dynamic _bodyCache;

  /// Singleton SessionManager instance (use your existing SessionManager).
  static final sessionManager = SessionManager();

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

  // ---------------- USER ----------------
  /// Returns the authenticated user payload from JWT or session (option C: session shape == JWT payload)
  Future<Map<String, dynamic>?> get user async {
    // 1️⃣ JWT first
    final token = bearerToken;
    if (token != null) {
      try {
        final payload = Auth.verifyToken(token);
        set('user', payload);
        return payload;
      } catch (_) {
        // invalid token → fallback to session
      }
    }

    // 2️⃣ fallback to session (SessionManager returns the session data we stored earlier)
    final s = await session;
    if (s != null) {
      // Option C: session data is the same shape as JWT payload
      set('user', s);
      return s;
    }

    // 3️⃣ no user
    return null;
  }

  /// Returns true if the request has a valid authenticated user (cached in _storage)
  bool get isAuthenticated => _storage.containsKey('user');

  /// Throws an exception if no user is authenticated
  Map<String, dynamic> requireUser() {
    final u = _storage['user'];
    if (u == null) throw Exception('Authentication required');
    return Map<String, dynamic>.from(u as Map);
  }

  // ==================== SESSION MANAGEMENT ====================

  /// Session ID from FLINTSESSID cookie
  String? get sessionId => cookies['FLINTSESSID'];

  /// Returns current session data if exists (delegates to SessionManager)
  Future<Map<String, dynamic>?> get session async {
    return await sessionManager.getSession(sessionId);
  }

  /// Creates a new session with the provided data (delegates to SessionManager)
  /// Returns the generated session id.
  Future<String> startSession(Map<String, dynamic> data,
      {Duration? ttl}) async {
    final id = await sessionManager.createSession(raw.response, data, ttl: ttl);
    // cache user in request storage (session payload is same shape as JWT per option C)
    set('user', data);
    return id;
  }

  /// Merge updates into existing session. NOTE: this implementation will create a NEW session
  /// with merged data and set a new cookie (session id regenerated). If you need to preserve the
  /// old session id, add an update method to SessionManager that writes in-place.
  Future<String?> updateSession(Map<String, dynamic> updates,
      {Duration? ttl}) async {
    final current = await session;
    if (current == null) return null;

    final merged = {...current, ...updates};
    // destroy old session and create a new one (keeps code simple and secure)
    await sessionManager.destroySession(raw.response, sessionId);
    final newId =
        await sessionManager.createSession(raw.response, merged, ttl: ttl);
    set('user', merged);
    return newId;
  }

  /// Destroys the current session (delegates to SessionManager)
  Future<void> destroySession() async {
    await sessionManager.destroySession(raw.response, sessionId);
    _storage.remove('user');
  }

  // ==================== COOKIE MANAGEMENT ====================

  /// Parsed cookies from the Cookie header
  Map<String, String> get cookies {
    final cookieHeader = raw.headers.value(HttpHeaders.cookieHeader);
    if (cookieHeader == null) return {};

    final cookies = <String, String>{};

    for (var cookie in cookieHeader.split(';')) {
      final trimmed = cookie.trim();
      final index = trimmed.indexOf('=');

      if (index == -1) continue; // skip malformed cookies

      final key = trimmed.substring(0, index).trim();
      final value =
          trimmed.substring(index + 1).trim(); // keep all remaining chars

      cookies[key] = value;
    }

    return cookies;
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
      // FILE FIELD
      final filename = _extractFilename(contentDisposition);
      final ext = filename.split('.').last;
      final contentType = part.headers['content-type']?.split(';')[0];

      // Count size while buffering the stream
      int totalBytes = 0;
      final controller = StreamController<List<int>>();

      part.listen((chunk) {
        totalBytes += chunk.length;
        controller.add(chunk);
      }, onDone: () {
        controller.close();
      });

      files[fieldName] = UploadedFile(
        fieldName: fieldName,
        filename: filename,
        contentType: contentType,
        size: totalBytes,
        extension: ext,
        content: controller.stream,
      );
    } else {
      // NORMAL FIELD
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
  /// Note: For multipart/form-data requests, use [form()] or [files()] instead
  Future<String> body() async {
    await _parseBody();
    if (_bodyCache is String) {
      return _bodyCache;
    }
    return '';
  }

  /// Parses the body as JSON and returns a Map
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

  /// Checks if multiple files with the given field name exist in the request
  Future<bool> hasFiles(String fieldName) async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      final files = _bodyCache['files'] as Map<String, UploadedFile>;

      // Check for exact match first
      if (files.containsKey(fieldName)) {
        return true;
      }

      // Check for array-style field names (e.g., "gallery[]", "gallery[0]", etc.)
      final pattern = RegExp('^${RegExp.escape(fieldName)}(\\[\\d*\\])?\$');
      return files.keys.any((key) => pattern.hasMatch(key));
    }
    return false;
  }

  /// Retrieves multiple uploaded files by field name
  Future<List<UploadedFile?>> files(String fieldName) async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      final files = _bodyCache['files'] as Map<String, UploadedFile>;

      final List<UploadedFile?> result = [];

      // Add exact match if exists
      if (files.containsKey(fieldName)) {
        result.add(files[fieldName]);
      }

      // Add array-style matches (e.g., "gallery[]", "gallery[0]", etc.)
      final pattern = RegExp('^${RegExp.escape(fieldName)}(\\[\\d*\\])?\$');
      files.forEach((key, file) {
        if (pattern.hasMatch(key)) {
          result.add(file);
        }
      });

      return result;
    }
    return [];
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
  Future<Map<String, UploadedFile>> allFiles() async {
    await _parseBody();
    if (_bodyCache is Map && _bodyCache.containsKey('files')) {
      return Map<String, UploadedFile>.from(_bodyCache['files']);
    }
    return {};
  }

  // ==================== FILE STORAGE HELPERS ====================

  /// Save a single uploaded file to disk and return the saved path.
  ///
  /// Defaults to `public/uploads` and preserves the original filename.
  /// Returns null if the file field does not exist.
  Future<String?> storeFile(
    String fieldName, {
    String directory = 'public/uploads',
    String? filename,
  }) async {
    final upload = await file(fieldName);
    if (upload == null) return null;

    final safeName = (filename ?? upload.filename).replaceAll('/', '_');
    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final path = '${dir.path}/$safeName';
    await upload.saveTo(path);
    return path;
  }

  /// Save multiple uploaded files to disk and return their saved paths.
  ///
  /// Defaults to `public/uploads` and preserves original filenames.
  Future<List<String>> storeFiles(
    String fieldName, {
    String directory = 'public/uploads',
  }) async {
    final uploads = await files(fieldName);
    if (uploads.isEmpty) return [];

    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final List<String> paths = [];
    for (final upload in uploads) {
      if (upload == null) continue;
      final safeName = upload.filename.replaceAll('/', '_');
      final path = '${dir.path}/$safeName';
      await upload.saveTo(path);
      paths.add(path);
    }

    return paths;
  }

  // ==================== VALIDATION ====================

  /// Validates the request body against specified validation rules
  Future<Map<String, dynamic>> validate(
    Map<String, String> rules, {
    Map<String, String>? messages,
  }) async {
    final body = await json();
    await Validator.validate(body, rules, messages: messages);
    return body;
  }

  /// Validates form data against specified rules
  Future<Map<String, String>> validateForm(
    Map<String, String> rules, {
    Map<String, String>? messages,
  }) async {
    final formData = await form();
    await Validator.validate(formData, rules, messages: messages);
    return formData;
  }
}
