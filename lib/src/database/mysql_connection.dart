// mysql_connection.dart
import 'dart:async';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:mysql_dart/mysql_dart.dart';

class MySqlConnectionWrapper implements DBWrapper {
  MySQLConnection? _conn;
  bool _connected = false;
  String? _lastError;
  Future<void>? _reconnectFuture;
  Timer? _keepAliveTimer;

  // Persist config so dropped connections can be re-established automatically.
  String? _host;
  int? _port;
  String? _db;
  String? _user;
  String? _password;
  bool _isSecure = false;
  int _timeoutSeconds = 30;
  int _keepAliveSeconds = 120;

  Future<void> connect({
    required String host,
    required int port,
    required String db,
    required String user,
    required String password,
    bool isSecure = false,
    int timeoutSeconds = 30,
    int keepAliveSeconds = 120,
  }) async {
    _host = host;
    _port = port;
    _db = db;
    _user = user;
    _password = password;
    _isSecure = isSecure;
    _timeoutSeconds = timeoutSeconds;
    _keepAliveSeconds = keepAliveSeconds;

    _keepAliveTimer?.cancel();

    try {
      await _openConnection();
      _connected = true;
      _lastError = null;
      _startKeepAliveTimer();
      Log.debug('[DB] MySQL connected to $db@$host:$port');
    } catch (e) {
      _connected = false;
      _lastError = e.toString();
      rethrow;
    }
  }

  @override
  bool get isConnected => _connected && (_conn?.connected ?? false);

  String? get lastError => _lastError;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final (finalSql, finalParams) =
        _processParameters(sql, positionalParams, namedParams);

    return _runWithReconnect(() async {
      final result = finalParams.isEmpty
          ? await _conn!.execute(finalSql)
          : await _conn!.execute(finalSql, finalParams);
      return result.rows.map((r) => r.assoc()).toList();
    });
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    await _runWithReconnect(() async {
      final (finalSql, finalParams) =
          _processParameters(sql, positionalParams, namedParams);
      if (finalParams.isEmpty) {
        await _conn!.execute(finalSql);
      } else {
        await _conn!.execute(finalSql, finalParams);
      }
    });
  }

  /// Process parameters and convert named parameters to positional if needed
  (String, List<dynamic>) _processParameters(
    String sql,
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  ) {
    if (namedParams != null && namedParams.isNotEmpty) {
      final paramList = <dynamic>[];

      final processedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
        final paramName = match.group(1)!;
        if (!namedParams.containsKey(paramName)) {
          throw ArgumentError('Named parameter :$paramName not provided');
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
    await _runWithReconnect(() async {
      for (final sql in sqlCommands) {
        await _conn!.execute(sql);
      }
    });
  }

  /// Check if a table exists in the database
  Future<bool> tableExists(String tableName) async {
    if (!isConnected) {
      throw Exception('MySQL not connected. Last error: $_lastError');
    }

    try {
      final result = await query(
        'SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
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
      throw Exception('MySQL not connected. Last error: $_lastError');
    }

    try {
      final versionResult = await query('SELECT VERSION() as version');
      final databaseResult = await query('SELECT DATABASE() as database_name');

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
      throw Exception('MySQL not connected. Last error: $_lastError');
    }

    try {
      await execute('START TRANSACTION');
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Commit a transaction
  @override
  Future<void> commit() async {
    if (!isConnected) {
      throw Exception('MySQL not connected. Last error: $_lastError');
    }

    try {
      await execute('COMMIT');
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Rollback a transaction
  @override
  Future<void> rollback() async {
    if (!isConnected) {
      throw Exception('MySQL not connected. Last error: $_lastError');
    }

    try {
      await execute('ROLLBACK');
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Execute within a transaction
  Future<void> transaction(Future<void> Function() action) async {
    if (!isConnected) {
      throw Exception('MySQL not connected. Last error: $_lastError');
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
      _keepAliveTimer?.cancel();
      await _conn?.close();
      _conn = null;
      _connected = false;
      Log.debug('[DB] MySQL connection closed');
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Ping the database to check connection health
  Future<bool> ping() async {
    try {
      if (!_connected) return false;
      if (_conn == null || !_conn!.connected) return false;
      await _conn!.execute('SELECT 1');
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
    bool isSecure = false,
    int timeoutSeconds = 30,
    int keepAliveSeconds = 120,
  }) async {
    _host = host;
    _port = port;
    _db = db;
    _user = user;
    _password = password;
    _isSecure = isSecure;
    _timeoutSeconds = timeoutSeconds;
    _keepAliveSeconds = keepAliveSeconds;
    await _reconnect();
  }

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    if (_keepAliveSeconds <= 0) return;

    _keepAliveTimer = Timer.periodic(
      Duration(seconds: _keepAliveSeconds),
      (_) async {
        if (_reconnectFuture != null) return;

        if (!isConnected) {
          try {
            await _reconnect();
          } catch (_) {}
          return;
        }

        await ping();
      },
    );
  }

  Future<void> _openConnection() async {
    _conn = await MySQLConnection.createConnection(
      host: _host!,
      port: _port!,
      databaseName: _db!,
      userName: _user!,
      password: _password!,
      secure: _isSecure,
    );

    await _conn!.connect(timeoutMs: _timeoutSeconds * 1000);
  }

  Future<void> _ensureConnected() async {
    if (isConnected) return;
    await _reconnect();
  }

  Future<void> _reconnect() {
    final existing = _reconnectFuture;
    if (existing != null) return existing;

    final future = () async {
      if (_host == null ||
          _port == null ||
          _db == null ||
          _user == null ||
          _password == null) {
        throw Exception(
            'MySQL reconnect failed: connection config is missing.');
      }

      await _conn?.close();
      _conn = null;

      await _openConnection();
      _connected = true;
      _lastError = null;
      _startKeepAliveTimer();
      Log.debug('[DB] MySQL reconnected to $_db@$_host:$_port');
    }();

    _reconnectFuture = future.whenComplete(() => _reconnectFuture = null);
    return _reconnectFuture!;
  }

  Future<T> _runWithReconnect<T>(Future<T> Function() operation) async {
    await _ensureConnected();

    try {
      final result = await operation();
      _connected = true;
      _lastError = null;
      return result;
    } catch (e) {
      _connected = isConnected;
      _lastError = e.toString();

      if (!_shouldReconnectOnError(e)) {
        Log.debug('', error: e);
        rethrow;
      }

      try {
        await _reconnect();
        final retried = await operation();
        _connected = true;
        _lastError = null;
        return retried;
      } catch (retryError) {
        _connected = isConnected;
        _lastError = retryError.toString();
        Log.debug('', error: retryError);
        rethrow;
      }
    }
  }

  bool _shouldReconnectOnError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('connection closed') ||
        msg.contains('server has gone away') ||
        msg.contains('lost connection') ||
        msg.contains('broken pipe') ||
        msg.contains('eof') ||
        msg.contains('can not prepare stmt');
  }
}
