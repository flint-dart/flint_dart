import 'dart:io';

import 'package:flint_dart/flint_dart.dart';

/// Blocks requests that contain high-confidence SQL injection payloads.
///
/// This middleware is a defense-in-depth tripwire. It does not replace
/// parameterized queries, ORM bindings, authorization checks, or validation.
class AntiSqlInjectionMiddleware extends Middleware {
  AntiSqlInjectionMiddleware({
    this.enabled = true,
    this.scanBody = true,
    this.scanHeaders = false,
    this.maxBodyBytes = 64 * 1024,
    this.blockedStatusCode = HttpStatus.badRequest,
    this.blockedMessage = 'Potential SQL injection payload detected.',
    List<String>? ignoredPathPrefixes,
    List<RegExp>? extraPatterns,
  })  : ignoredPathPrefixes = ignoredPathPrefixes ?? const [],
        _patterns = [..._defaultPatterns, ...?extraPatterns];

  final bool enabled;
  final bool scanBody;
  final bool scanHeaders;
  final int maxBodyBytes;
  final int blockedStatusCode;
  final String blockedMessage;
  final List<String> ignoredPathPrefixes;
  final List<RegExp> _patterns;

  static final List<RegExp> _defaultPatterns = [
    // ' OR 1=1 --, ") OR "a"="a", etc.
    RegExp(
      r'''(?:'|"|%27|%22|\)|\b)(?:\s|\+)*(?:or|and)(?:\s|\+)+(?:\d+\s*=\s*\d+|['"][^'"]*['"]\s*=\s*['"][^'"]*['"])''',
      caseSensitive: false,
    ),

    // UNION SELECT attacks.
    RegExp(
      r'''(?:union(?:\s|\+|%20)+(?:all(?:\s|\+|%20)+)?select)\b''',
      caseSensitive: false,
    ),

    // Stacked destructive SQL statements.
    RegExp(
      r''';\s*(?:drop|alter|truncate|delete|insert|update|create|replace)\s+(?:table|database|schema|from|into|set|\w+)''',
      caseSensitive: false,
    ),

    // SQL comments commonly used to terminate clauses after injected logic.
    RegExp(
      r'''(?:--|#|/\*)\s*(?:$|(?:select|union|drop|delete|insert|update|or|and)\b)''',
      caseSensitive: false,
    ),

    // Time/error based injection probes.
    RegExp(
      r'''\b(?:sleep|benchmark|pg_sleep|waitfor\s+delay)\s*\(''',
      caseSensitive: false,
    ),

    // Common schema enumeration and SQL Server command shell probes.
    RegExp(
      r'''\b(?:information_schema|sysobjects|syscolumns|xp_cmdshell)\b''',
      caseSensitive: false,
    ),
  ];

  @override
  Handler handle(Handler next) {
    return (ctx) async {
      if (!enabled) return next(ctx);

      final req = ctx.req;
      final res = ctx.res;
      if (_isIgnoredPath(req.path)) return next(ctx);

      final detectedIn = await _detect(req);
      if (detectedIn != null) {
        Log.warning(
          '[Flint][AntiSqlInjection] blocked path=${req.path} source=$detectedIn ip=${req.ipAddress}',
        );

        if (res == null) return null;
        return res.json(
          {
            'status': false,
            'message': blockedMessage,
          },
          status: blockedStatusCode,
        );
      }

      return next(ctx);
    };
  }

  bool _isIgnoredPath(String path) {
    for (final prefix in ignoredPathPrefixes) {
      if (prefix.isNotEmpty && path.startsWith(prefix)) return true;
    }
    return false;
  }

  Future<String?> _detect(Request req) async {
    for (final entry in req.params.entries) {
      if (_looksDangerous(entry.value)) return 'param:${entry.key}';
    }

    for (final entry in req.query.entries) {
      if (_looksDangerous(entry.value)) return 'query:${entry.key}';
    }

    if (scanHeaders) {
      for (final entry in req.headers.entries) {
        if (_looksDangerous(entry.value)) return 'header:${entry.key}';
      }
    }

    if (scanBody && _shouldScanBody(req)) {
      final raw = await req.rawBody();
      if (raw.isNotEmpty && raw.length <= maxBodyBytes) {
        final body = String.fromCharCodes(raw);
        if (_looksDangerous(body)) return 'body';
      }
    }

    return null;
  }

  bool _shouldScanBody(Request req) {
    final method = req.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS') {
      return false;
    }

    final contentType = req.raw.headers.contentType;
    if (contentType == null) return true;

    final mime = contentType.mimeType.toLowerCase();
    if (mime == 'multipart/form-data' || mime == 'application/octet-stream') {
      return false;
    }

    return mime.startsWith('text/') ||
        mime == 'application/json' ||
        mime == 'application/x-www-form-urlencoded';
  }

  bool _looksDangerous(String value) {
    if (value.trim().isEmpty) return false;

    final candidates = <String>{
      value,
      _decodeRepeatedly(value),
    };

    for (final candidate in candidates) {
      final normalized = _normalize(candidate);
      for (final pattern in _patterns) {
        if (pattern.hasMatch(normalized)) return true;
      }
    }

    return false;
  }

  String _decodeRepeatedly(String value) {
    var current = value;
    for (var i = 0; i < 3; i++) {
      late final String decoded;
      try {
        decoded = Uri.decodeComponent(current.replaceAll('+', ' '));
      } on FormatException {
        break;
      }
      if (decoded == current) break;
      current = decoded;
    }
    return current;
  }

  String _normalize(String value) {
    return value
        .replaceAll(RegExp(r'/\*!?\d*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
