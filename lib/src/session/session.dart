import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flint_dart/flint_dart.dart';

class SessionManager {
  // Singleton instance
  static final SessionManager instance = SessionManager._internal();

  // Constructor
  late final String driver;
  late final File? sessionFile;
  late final String dbTable;
  final Duration defaultTtl;

  // Memory store
  final Map<String, Map<String, dynamic>> _memoryStore = {};

  factory SessionManager() => instance;
  SessionManager._internal()
      : defaultTtl = _parseTtl(FlintEnv.get('SESSION_TTL', '7d')) {
    driver = FlintEnv.get('SESSION_DRIVER', 'memory');
    dbTable = FlintEnv.get('SESSION_DB_TABLE', 'sessions');
    // ---------------- FILE DRIVER SETUP ----------------
    if (driver == 'file') {
      sessionFile = File(FlintEnv.get('SESSION_FILE', 'sessions.json'));

      if (!sessionFile!.existsSync()) {
        sessionFile!.createSync(recursive: true);
        sessionFile!.writeAsStringSync('{}');
      }
    } else {
      sessionFile = null;
    }

    // ---------------- DB DRIVER SETUP ----------------
    if (driver == 'db') {
      Future.microtask(() => _ensureDbTable());
    }
  }

  bool isReady() => driver.isNotEmpty;

  // ===================================================
  // CREATE SESSION
  // ===================================================
  Future<String> createSession(
    HttpResponse response,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    final id = _generateSessionId();
    final expiresAt = DateTime.now().add(ttl ?? defaultTtl);

    switch (driver) {
      case 'memory':
        _memoryStore[id] = {
          ...data,
          'expires_at': expiresAt.toIso8601String(),
        };
        break;

      case 'file':
        final sessions = await _readSessions();
        sessions[id] = {
          ...data,
          'expires_at': expiresAt.toIso8601String(),
        };
        await _writeSessions(sessions);
        break;

      case 'db':
        await DB.query(
          'INSERT INTO $dbTable (id, user_id, data, expires_at) VALUES (?, ?, ?, ?)',
          positionalParams: [
            id,
            data['id'],
            jsonEncode(data),
            expiresAt.toIso8601String(),
          ],
        );
        break;

      default:
        throw Exception('Unknown SESSION_DRIVER: $driver');
    }

    _setSessionCookie(response, id);

    return id;
  }

  // ===================================================
  // GET SESSION
  // ===================================================
  Future<Map<String, dynamic>?> getSession(String? sessionId) async {
    if (sessionId == null) return null;
    switch (driver) {
      case 'memory':
        final s = _memoryStore[sessionId];
        if (s == null || _isExpired(s['expires_at'])) {
          _memoryStore.remove(sessionId);
          return null;
        }
        return s;

      case 'file':
        final sessions = await _readSessions();
        final s = sessions[sessionId];
        if (s == null) return null;

        if (_isExpired(s['expires_at'])) {
          sessions.remove(sessionId);
          await _writeSessions(sessions);
          return null;
        }
        return s;

      case 'db':
        final result = await DB.query(
          'SELECT data, expires_at FROM $dbTable WHERE id = ?',
          positionalParams: [sessionId],
        );
        if (result.isEmpty) return null;

        final row = result.first;
        final expiresAt = DateTime.parse(row['expires_at']);

        if (expiresAt.isBefore(DateTime.now())) {
          await DB.query('DELETE FROM $dbTable WHERE id = ?',
              positionalParams: [sessionId]);
          return null;
        }

        return jsonDecode(row['data']);

      default:
        throw Exception('Unknown SESSION_DRIVER: $driver');
    }
  }

  // ===================================================
  // DESTROY SESSION
  // ===================================================
  Future<void> destroySession(HttpResponse response, String? sessionId) async {
    if (sessionId == null) return;

    switch (driver) {
      case 'memory':
        _memoryStore.remove(sessionId);
        break;

      case 'file':
        final sessions = await _readSessions();
        sessions.remove(sessionId);
        await _writeSessions(sessions);
        break;

      case 'db':
        await DB.query(
          'DELETE FROM $dbTable WHERE id = ?',
          positionalParams: [sessionId],
        );
        break;
    }

    _clearSessionCookie(response);
  }

  // ===================================================
  // FILE DRIVER HELPERS
  // ===================================================
  Future<Map<String, Map<String, dynamic>>> _readSessions() async {
    final content = await sessionFile!.readAsString();
    if (content.trim().isEmpty) return {};

    try {
      return Map<String, Map<String, dynamic>>.from(jsonDecode(content));
    } catch (_) {
      return {}; // corrupted file fallback
    }
  }

  Future<void> _writeSessions(
    Map<String, Map<String, dynamic>> sessions,
  ) async {
    await sessionFile!.writeAsString(jsonEncode(sessions));
  }

  // ===================================================
  // DB DRIVER TABLE CREATION
  // ===================================================
  void _ensureDbTable() async {
    final isPostgres = FlintEnv.get('DB_CONNECTION', 'mysql') == 'postgres';

    final jsonType = isPostgres ? 'JSONB' : 'JSON';

    await DB.query('''
      CREATE TABLE IF NOT EXISTS $dbTable (
        id VARCHAR(128) PRIMARY KEY,
        user_id VARCHAR(128),
        data $jsonType NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP
      )
    ''');
  }

  // ===================================================
  // UTILITIES
  // ===================================================
  bool _isExpired(String iso) => DateTime.parse(iso).isBefore(DateTime.now());

  String _generateSessionId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  static Duration _parseTtl(String ttl) {
    if (ttl.endsWith('d')) {
      return Duration(days: int.parse(ttl.replaceAll('d', '')));
    }
    if (ttl.endsWith('h')) {
      return Duration(hours: int.parse(ttl.replaceAll('h', '')));
    }
    return Duration(days: 7);
  }

  void _setSessionCookie(HttpResponse response, String sessionId) {
    final appEnv = FlintEnv.get('APP_ENV', 'development').toLowerCase();
    final secureDefault = appEnv == 'production';
    final secure = FlintEnv.getBool('SESSION_COOKIE_SECURE', secureDefault);
    final httpOnly = FlintEnv.getBool('SESSION_COOKIE_HTTP_ONLY', true);
    final sameSite = FlintEnv.get('SESSION_COOKIE_SAMESITE', 'Lax');
    final path = FlintEnv.get('SESSION_COOKIE_PATH', '/');

    final cookie = StringBuffer()..write('FLINTSESSID=$sessionId; Path=$path;');
    if (httpOnly) cookie.write(' HttpOnly;');
    if (secure) cookie.write(' Secure;');
    if (sameSite.isNotEmpty) cookie.write(' SameSite=$sameSite;');
    response.headers.add('Set-Cookie', cookie.toString());
  }

  void _clearSessionCookie(HttpResponse response) {
    final path = FlintEnv.get('SESSION_COOKIE_PATH', '/');
    response.headers.add(
      'Set-Cookie',
      'FLINTSESSID=; Path=$path; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=0;',
    );
  }
}
