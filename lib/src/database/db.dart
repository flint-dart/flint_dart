import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'mysql_connection.dart';
import 'pg_connection.dart';
import 'dart:convert';

/// Supported database drivers
enum DBDriver { mysql, postgres }

/// Database manager for Flint Dart
///
/// - Automatically connects on first use (lazy init).
/// - Reads connection info from `.env`
///   (`DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SECURE`).
/// - Supports MySQL & PostgreSQL with query normalization.
/// - Provides retry logic if the database is not reachable.
///
/// Example:
/// ```dart
/// final users = await DB.query("SELECT * FROM users WHERE id = ?", positionalParams: [1]);
/// final lastId = await DB.getLastInsertId("users", "id");
/// ```
class DB {
  static DBDriver? _driver;
  static MySqlConnectionWrapper? _mysql;
  static PgConnectionWrapper? _pg;
  static bool _isConnected = false;
  static bool _isConnecting = false;

  /// Ensure the database is connected before running any command.
  static Future<void> _ensureConnected() async {
    if (_isConnected) return;
    if (_isConnecting) {
      // Wait if another call is already connecting
      while (_isConnecting) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return;
    }
    _isConnecting = true;
    try {
      await tryAutoConnect();
    } finally {
      _isConnecting = false;
    }
  }

  /// Connect to the database using environment variables.
  static Future<void> autoConnect() async {
    final driver = FlintEnv.get('DB_CONNECTION', 'mysql');

    if (driver == 'postgres') {
      _driver = DBDriver.postgres;
      _pg = PgConnectionWrapper();
      await _pg!.connect(
        host: FlintEnv.get('DB_HOST', 'localhost'),
        port: FlintEnv.getInt('DB_PORT', 5432),
        database: FlintEnv.get('DB_NAME', 'postgres'),
        username: FlintEnv.get('DB_USER', 'postgres'),
        password: FlintEnv.get('DB_PASSWORD', ''),
      );
    } else {
      _driver = DBDriver.mysql;
      _mysql = MySqlConnectionWrapper();
      await _mysql!.connect(
        host: FlintEnv.get('DB_HOST', 'localhost'),
        port: FlintEnv.getInt('DB_PORT', 3306),
        db: FlintEnv.get('DB_NAME', ''),
        user: FlintEnv.get('DB_USER', 'root'),
        isSecure: FlintEnv.getBool("DB_SECURE", false),
        password: FlintEnv.get('DB_PASSWORD', ''),
      );
    }
    _isConnected = true;
  }

  /// Manual connect for dynamic tenant switching.
  static Future<void> connect({
    required String database,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? isSecure,
  }) async {
    _isConnected = false;

    final driver = FlintEnv.get('DB_CONNECTION', 'mysql');

    if (driver == 'postgres') {
      _driver = DBDriver.postgres;
      _pg = PgConnectionWrapper();
      await _pg!.connect(
        host: host ?? FlintEnv.get('DB_HOST', 'localhost'),
        port: port ?? FlintEnv.getInt('DB_PORT', 5432),
        database: database,
        username: username ?? FlintEnv.get('DB_USER', 'postgres'),
        password: password ?? FlintEnv.get('DB_PASSWORD', ''),
      );
    } else {
      _driver = DBDriver.mysql;
      _mysql = MySqlConnectionWrapper();
      await _mysql!.connect(
        host: host ?? FlintEnv.get('DB_HOST', 'localhost'),
        port: port ?? FlintEnv.getInt('DB_PORT', 3306),
        db: database,
        user: username ?? FlintEnv.get('DB_USER', 'root'),
        password: password ?? FlintEnv.get('DB_PASSWORD', ''),
        isSecure: isSecure ?? FlintEnv.getBool('DB_SECURE', false),
      );
    }

    _isConnected = true;
  }

  /// Attempt auto-connect with retries.
  static Future<void> tryAutoConnect(
      {int retries = 5, int delaySeconds = 3}) async {
    for (int i = 1; i <= retries; i++) {
      try {
        await autoConnect();
        return;
      } catch (e) {
        if (i == retries) {
          throw Exception(
              "❌ Could not connect to DB after $retries attempts: $e");
        }
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  static void overrideConnection(DBWrapper connection) {
    _mysql = connection is MySqlConnectionWrapper ? connection : null;
    _pg = connection is PgConnectionWrapper ? connection : null;
    _isConnected = true;
  }

  /// Returns whether the database is currently connected.
  static bool get isConnected =>
      _isConnected && (_mysql?.isConnected == true || _pg?.isConnected == true);

  /// Current driver in use.
  static DBDriver get driver {
    _ensureConnected();
    if (_driver == null) {
      throw Exception("Database not initialized.");
    }
    return _driver!;
  }

  static MySqlConnectionWrapper get mysql {
    _ensureConnected();
    if (_mysql == null || !_mysql!.isConnected) {
      throw Exception("MySQL not connected or connection lost.");
    }
    return _mysql!;
  }

  static PgConnectionWrapper get pg {
    if (_pg == null || !_pg!.isConnected) {
      throw Exception("PostgreSQL not connected or connection lost.");
    }
    return _pg!;
  }

  /// Returns the active connection (MySQL or PostgreSQL).
  static DBWrapper get instance {
    _ensureConnected();
    if (_driver == null) {
      throw Exception("Database not initialized.");
    }
    return _driver == DBDriver.mysql ? _mysql! : _pg!;
  }

  /// Normalize SQL and parameters for the active driver.
  static (String, List<dynamic>) normalizeQuery(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) {
    _ensureConnected();
    if (_driver == DBDriver.mysql) {
      return _normalizeMySQL(sql, positionalParams, namedParams);
    } else {
      return _normalizePostgreSQL(sql, positionalParams, namedParams);
    }
  }

  static (String, List<dynamic>) _normalizeMySQL(
    String sql,
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  ) {
    if (namedParams != null && namedParams.isNotEmpty) {
      final paramList = <dynamic>[];
      final normalizedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
        final paramName = match.group(1)!;
        if (!namedParams.containsKey(paramName)) {
          throw ArgumentError("Named parameter :$paramName not provided");
        }
        paramList
            .add(_normalizeValueForDb(namedParams[paramName])); // ✅ normalize
        return '?';
      });
      return (normalizedSql, paramList);
    } else {
      final params = (positionalParams ?? [])
          .map(_normalizeValueForDb)
          .toList(); // ✅ normalize

      return (sql, params);
    }
  }

  static (String, List<dynamic>) _normalizePostgreSQL(
    String sql,
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  ) {
    if (namedParams != null && namedParams.isNotEmpty) {
      // Convert named parameters to $1, $2, ...
      final paramList = <dynamic>[];
      var paramIndex = 1;

      final normalizedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
        final paramName = match.group(1)!;
        if (!namedParams.containsKey(paramName)) {
          throw ArgumentError("Named parameter :$paramName not provided");
        }
        paramList
            .add(_normalizeValueForDb(namedParams[paramName])); // ✅ normalize
        return '\$${paramIndex++}';
      });

      return (normalizedSql, paramList);
    } else {
      // Convert ? to $1, $2, ...
      var paramIndex = 1;
      final normalizedSql =
          sql.replaceAllMapped(RegExp(r'\?'), (_) => '\$${paramIndex++}');
      final params =
          (positionalParams ?? []).map(_normalizeValueForDb).toList(); // ✅ norm
      return (normalizedSql, params);
    }
  }

  /// Execute a query with parameters.
  static Future<List<Map<dynamic, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    await _ensureConnected();

    final (normalizedSql, params) = normalizeQuery(
      sql,
      positionalParams: positionalParams,
      namedParams: namedParams,
    );

    return await instance.query(normalizedSql, positionalParams: params);
  }

  /// Execute a command (INSERT, UPDATE, DELETE).
  static Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    await _ensureConnected();

    final (normalizedSql, params) = normalizeQuery(
      sql,
      positionalParams: positionalParams,
      namedParams: namedParams,
    );

    return await instance.execute(normalizedSql, positionalParams: params);
  }

  /// Get the last inserted ID (DB-specific).
  static Future<dynamic> getLastInsertId(
      String tableName, String primaryKey) async {
    await _ensureConnected();

    if (_driver == DBDriver.postgres) {
      final result = await query("SELECT lastval() as id");
      return _convertDatabaseId(result.first['id']);
    } else {
      final result = await query("SELECT LAST_INSERT_ID() as id");
      return _convertDatabaseId(result.first['id']);
    }
  }

  static dynamic _convertDatabaseId(dynamic id) {
    if (id is String) return int.tryParse(id) ?? id;
    if (id is BigInt) return id.toInt();
    return id;
  }

  /// Check if a table exists.
  /// Check if a table exists.
  static Future<bool> tableExists(String tableName) async {
    await _ensureConnected();

    try {
      final String sql;
      final Map<String, dynamic> params = {'table': tableName};

      if (_driver == DBDriver.postgres) {
        sql = '''
        SELECT COUNT(*) > 0 AS exists
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = :table
      ''';
      } else {
        sql = '''
        SELECT COUNT(*) > 0 AS `exists_flag`
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
        AND table_name = ?
      ''';
      }

      final result = await query(
        sql,
        positionalParams: _driver == DBDriver.mysql ? [tableName] : null,
        namedParams: _driver == DBDriver.postgres ? params : null,
      );

      final exists = result.first['exists'] ?? result.first['exists_flag'];
      if (exists is bool) return exists;
      if (exists is int) return exists > 0;
      if (exists is BigInt) return exists > BigInt.zero;
      if (exists is String) {
        return exists == '1' || exists.toLowerCase() == 'true';
      }
      return false;
    } catch (e) {
      print('⚠️ tableExists() failed: $e');
      return false;
    }
  }

  /// Build a LIMIT/OFFSET clause.
  static String buildLimitClause(int limit, [int? offset]) {
    if (_driver == DBDriver.postgres) {
      return offset != null ? 'LIMIT $limit OFFSET $offset' : 'LIMIT $limit';
    } else {
      return offset != null ? 'LIMIT $offset, $limit' : 'LIMIT $limit';
    }
  }

  /// Close active connection.
  static Future<void> close() async {
    await _mysql?.close();
    await _pg?.close();
    _driver = null;
    _isConnected = false;
    _mysql = null;
    _pg = null;
  }

  /// Convert Dart types to DB-compatible types.
  /// This function now automatically handles:
  /// - List → JSON string
  /// - Map → JSON string
  /// - Object with toJson() → JSON string
  /// - Object with toMap() → JSON string
  /// - DateTime → ISO8601
  /// - bool → 1/0 for MySQL
  static dynamic _normalizeValueForDb(dynamic value) {
    // Null stays null
    if (value == null) return null;

    // DateTime → ISO8601 text (works for MySQL & Postgres)
    if (value is DateTime) return value.toIso8601String();

    // Enums → store enum name
    if (value is Enum) return value.name;

    // Bool (MySQL expects 0/1, Postgres accepts bool directly)
    if (_driver == DBDriver.mysql && value is bool) {
      return value ? 1 : 0;
    }

    // List → jsonEncode()
    if (value is List) {
      return jsonEncode(value);
    }

    // Map → jsonEncode()
    if (value is Map) {
      return jsonEncode(value);
    }

    // Object with toJson() → jsonEncode()
    final toJson = _getToJson(value);
    if (toJson != null) {
      return jsonEncode(toJson());
    }

    // Object with toMap() → jsonEncode()
    final toMap = _getToMap(value);
    if (toMap != null) {
      return jsonEncode(toMap());
    }

    // Default → return as-is
    return value;
  }

  static MapFn? _getToMap(dynamic obj) {
    try {
      final candidate = obj.toMap;
      if (candidate is MapFn) return candidate;
    } catch (_) {}
    return null;
  }

  static JsonFn? _getToJson(dynamic obj) {
    try {
      final candidate = obj.toJson;
      if (candidate is JsonFn) return candidate;
    } catch (_) {}
    return null;
  }
}

typedef JsonMap = Map<String, dynamic>;
typedef MapFn = JsonMap Function();
typedef JsonFn = JsonMap Function();
