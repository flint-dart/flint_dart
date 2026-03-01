// pg_connection.dart
import 'dart:async';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:postgres/postgres.dart';

class PgConnectionWrapper implements DBWrapper {
  Connection? _connection;
  bool _connected = false;
  String? _lastError;
  Future<void>? _reconnectFuture;
  Timer? _keepAliveTimer;

  // Persist connection config so dropped connections can be recovered.
  String? _host;
  int? _port;
  String? _database;
  String? _username;
  String? _password;
  Duration _connectionTimeout = const Duration(seconds: 30);
  String? _applicationName;
  int _keepAliveSeconds = 120;

  Future<void> connect({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    Duration connectionTimeout = const Duration(seconds: 30),
    String? applicationName,
    int keepAliveSeconds = 120,
  }) async {
    _host = host;
    _port = port;
    _database = database;
    _username = username;
    _password = password;
    _connectionTimeout = connectionTimeout;
    _applicationName = applicationName;
    _keepAliveSeconds = keepAliveSeconds;

    _keepAliveTimer?.cancel();

    try {
      await _openConnection();
      _connected = true;
      _lastError = null;
      _startKeepAliveTimer();
      Log.debug('[DB] PostgreSQL connected to $database@$host:$port');
    } catch (e) {
      _connected = false;
      _lastError = e.toString();
      rethrow;
    }
  }

  @override
  bool get isConnected => _connected && _connection != null;

  String? get lastError => _lastError;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    return _runWithReconnect(() async {
      final (finalSql, finalParams) =
          _processParameters(sql, positionalParams, namedParams);

      final result = await _connection!.execute(
        finalSql,
        parameters: finalParams,
      );

      return result.map((row) => row.toColumnMap()).toList();
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

      await _connection!.execute(
        finalSql,
        parameters: finalParams,
      );
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
      var paramIndex = 1;

      final processedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
        final paramName = match.group(1)!;
        if (!namedParams.containsKey(paramName)) {
          throw ArgumentError('Named parameter :$paramName not provided');
        }
        paramList.add(namedParams[paramName]);
        return '\$${paramIndex++}';
      });

      return (processedSql, paramList);
    }

    return (sql, positionalParams ?? []);
  }

  /// Execute a batch of SQL commands
  Future<void> executeBatch(List<String> sqlCommands) async {
    await _runWithReconnect(() async {
      for (final sql in sqlCommands) {
        await _connection!.execute(sql);
      }
    });
  }

  /// Execute a query with a returning clause (useful for INSERT/UPDATE)
  Future<List<Map<String, dynamic>>> executeWithReturning(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    return _runWithReconnect(() async {
      final (finalSql, finalParams) =
          _processParameters(sql, positionalParams, namedParams);

      final result = await _connection!.execute(
        finalSql,
        parameters: finalParams,
      );

      return result.map((row) => row.toColumnMap()).toList();
    });
  }

  /// Check if a table exists in the database
  Future<bool> tableExists(String tableName) async {
    if (!isConnected) {
      throw Exception('PostgreSQL not connected. Last error: $_lastError');
    }

    try {
      final result = await query(
        'SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = :table)',
        namedParams: {'table': tableName},
      );

      return result.first['exists'] as bool;
    } catch (e) {
      return false;
    }
  }

  /// Get database metadata
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    if (!isConnected) {
      throw Exception('PostgreSQL not connected. Last error: $_lastError');
    }

    try {
      final versionResult = await query('SELECT version() as version');
      final databaseResult =
          await query('SELECT current_database() as database_name');

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
      throw Exception('PostgreSQL not connected. Last error: $_lastError');
    }

    try {
      await execute('BEGIN');
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Commit a transaction
  @override
  Future<void> commit() async {
    if (!isConnected) {
      throw Exception('PostgreSQL not connected. Last error: $_lastError');
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
      throw Exception('PostgreSQL not connected. Last error: $_lastError');
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
      throw Exception('PostgreSQL not connected. Last error: $_lastError');
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
      await _connection?.close();
      _connected = false;
      _connection = null;
      Log.debug('[DB] PostgreSQL connection closed');
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Ping the database to check connection health
  Future<bool> ping() async {
    try {
      if (!isConnected) return false;
      await _connection!.execute('SELECT 1');
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
    required String database,
    required String username,
    required String password,
    Duration connectionTimeout = const Duration(seconds: 30),
    String? applicationName,
    int keepAliveSeconds = 120,
  }) async {
    _host = host;
    _port = port;
    _database = database;
    _username = username;
    _password = password;
    _connectionTimeout = connectionTimeout;
    _applicationName = applicationName;
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
    final endpoint = Endpoint(
      host: _host!,
      port: _port!,
      database: _database!,
      username: _username!,
      password: _password!,
    );

    _connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(
        applicationName: _applicationName,
        sslMode: SslMode.disable,
      ),
    ).timeout(_connectionTimeout);
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
          _database == null ||
          _username == null ||
          _password == null) {
        throw Exception(
          'PostgreSQL reconnect failed: connection config is missing.',
        );
      }

      await _connection?.close();
      _connection = null;

      await _openConnection();
      _connected = true;
      _lastError = null;
      _startKeepAliveTimer();
      Log.debug('[DB] PostgreSQL reconnected to $_database@$_host:$_port');
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
      _connected = false;
      _lastError = e.toString();

      if (!_shouldReconnectOnError(e)) {
        rethrow;
      }

      try {
        await _reconnect();
        final retried = await operation();
        _connected = true;
        _lastError = null;
        return retried;
      } catch (retryError) {
        _connected = false;
        _lastError = retryError.toString();
        rethrow;
      }
    }
  }

  bool _shouldReconnectOnError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('connection') ||
        msg.contains('closed') ||
        msg.contains('terminating') ||
        msg.contains('broken pipe') ||
        msg.contains('eof') ||
        msg.contains('reset by peer');
  }
}
