// mysql_connection.dart
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:mysql_dart/mysql_dart.dart';

class MySqlConnectionWrapper implements DBWrapper {
  late MySQLConnection _conn;
  bool _connected = false;
  String? _lastError;

  Future<void> connect({
    required String host,
    required int port,
    required String db,
    required String user,
    required String password,
    bool isSecure = false,
    int timeoutSeconds = 30,
  }) async {
    try {
      _conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        databaseName: db,
        userName: user,
        password: password,
        secure: isSecure,
      );

      await _conn.connect();
      _connected = true;
      _lastError = null;
      Log.debug("✅ MySQL connected to $db@$host:$port");
    } catch (e) {
      _connected = false;
      _lastError = e.toString();
      rethrow;
    }
  }

  @override
  bool get isConnected => _connected && _conn.connected;

  String? get lastError => _lastError;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    // if (!isConnected) {
    //   throw Exception("MySQL not connected. Last error: $_lastError");
    // }

    // Convert named parameters to positional parameters for MySQL
    final (finalSql, finalParams) =
        _processParameters(sql, positionalParams, namedParams);

    try {
      final stmt = await _conn.prepare(finalSql);
      final result = await stmt.execute(finalParams);
      return result.rows.map((r) => r.assoc()).toList();
    } catch (e) {
      Log.debug("", error: e);
      _connected = _conn.connected;
      _lastError = e.toString();
      rethrow;
    }
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    if (positionalParams == null || positionalParams.isEmpty) {
      await _conn.execute(sql);
      return;
    }

    // Convert named parameters to positional parameters for MySQL
    final (finalSql, finalParams) =
        _processParameters(sql, positionalParams, namedParams);

    try {
      final stmt = await _conn.prepare(finalSql);
      await stmt.execute(finalParams);
    } catch (e) {
      Log.debug("", error: e);

      _connected = _conn.connected;
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Process parameters and convert named parameters to positional if needed
  (String, List<dynamic>) _processParameters(
    String sql,
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  ) {
    if (namedParams != null && namedParams.isNotEmpty) {
      // Convert named parameters to positional parameters for MySQL
      final paramList = <dynamic>[];

      // Simple conversion: replace :param with ? and collect values in order
      // This is a basic implementation - you might need a more robust one
      final processedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
        final paramName = match.group(1)!;
        if (!namedParams.containsKey(paramName)) {
          throw ArgumentError("Named parameter :$paramName not provided");
        }
        paramList.add(namedParams[paramName]);
        return '?';
      });

      return (processedSql, paramList);
    }

    return (sql, positionalParams ?? []);
  }

  /// Execute a batch of SQL commands
  Future<void> executeBatch(List<String> sqlCommands) async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    try {
      for (final sql in sqlCommands) {
        final stmt = await _conn.prepare(sql);
        await stmt.execute([]);
      }
    } catch (e) {
      _connected = _conn.connected;
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Check if a table exists in the database
  Future<bool> tableExists(String tableName) async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    try {
      final result = await query(
        "SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?",
        positionalParams: [tableName],
      );

      final count = result.first['count'];
      if (count is int) return count > 0;
      if (count is String) return int.parse(count) > 0;
      if (count is BigInt) return count > BigInt.zero;
      return (count as num) > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get database metadata
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    try {
      final versionResult = await query("SELECT VERSION() as version");
      final databaseResult = await query("SELECT DATABASE() as database_name");

      return {
        'version': versionResult.first['version'],
        'database': databaseResult.first['database_name'],
        'connected': isConnected,
      };
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Start a transaction
  @override
  Future<void> beginTransaction() async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    try {
      await execute("START TRANSACTION");
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Commit a transaction
  @override
  Future<void> commit() async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    try {
      await execute("COMMIT");
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Rollback a transaction
  @override
  Future<void> rollback() async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    try {
      await execute("ROLLBACK");
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Execute within a transaction
  Future<void> transaction(Future<void> Function() action) async {
    if (!isConnected) {
      throw Exception("MySQL not connected. Last error: $_lastError");
    }

    try {
      await beginTransaction();
      await action();
      await commit();
    } catch (e) {
      await rollback();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    try {
      await _conn.close();
      _connected = false;
      Log.debug("✅ MySQL connection closed");
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Ping the database to check connection health
  Future<bool> ping() async {
    try {
      if (!_connected) return false;
      await query("SELECT 1");
      return true;
    } catch (e) {
      _connected = false;
      _lastError = e.toString();
      return false;
    }
  }

  /// Reconnect if connection is lost
  Future<void> reconnect({
    required String host,
    required int port,
    required String db,
    required String user,
    required String password,
  }) async {
    try {
      await close();
      await connect(
        host: host,
        port: port,
        db: db,
        user: user,
        password: password,
      );
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }
}
