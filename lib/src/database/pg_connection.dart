// pg_connection.dart
import 'dart:async';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:postgres/postgres.dart';

class PgConnectionWrapper implements DBWrapper {
  Connection? _connection;
  bool _connected = false;
  String? _lastError;
  // final Map<String, StreamSubscription<Notification>> _listeners = {};
  Future<void> connect({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    Duration connectionTimeout = const Duration(seconds: 30),
    String? applicationName,
  }) async {
    try {
      final endpoint = Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );

      _connection = await Connection.open(
        endpoint,
        settings: ConnectionSettings(
            applicationName: applicationName, sslMode: SslMode.disable),
      );

      _connected = true;
      _lastError = null;
      Log.debug("✅ PostgreSQL connected to $database@$host:$port");
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
    // if (!isConnected) {
    //   throw Exception("PostgreSQL not connected. Last error: $_lastError");
    // }

    try {
      // Convert named parameters to positional parameters if provided
      final (finalSql, finalParams) =
          _processParameters(sql, positionalParams, namedParams);

      final result = await _connection!.execute(
        finalSql,
        parameters: finalParams,
      );

      // Convert each row into a map {colName: value}
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      _connected = false;
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
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
    }

    try {
      // Convert named parameters to positional parameters if provided
      final (finalSql, finalParams) =
          _processParameters(sql, positionalParams, namedParams);

      await _connection!.execute(
        finalSql,
        parameters: finalParams,
      );
    } catch (e) {
      _connected = false;
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
      // Convert named parameters to positional parameters
      final paramList = <dynamic>[];
      var paramIndex = 1;

      final processedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
        final paramName = match.group(1)!;
        if (!namedParams.containsKey(paramName)) {
          throw ArgumentError("Named parameter :$paramName not provided");
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
    if (!isConnected) {
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
    }

    try {
      for (final sql in sqlCommands) {
        await _connection!.execute(sql);
      }
    } catch (e) {
      _connected = false;
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Execute a query with a returning clause (useful for INSERT/UPDATE)
  Future<List<Map<String, dynamic>>> executeWithReturning(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    if (!isConnected) {
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
    }

    try {
      final (finalSql, finalParams) =
          _processParameters(sql, positionalParams, namedParams);

      final result = await _connection!.execute(
        finalSql,
        parameters: finalParams,
      );

      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      _connected = false;
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Check if a table exists in the database
  Future<bool> tableExists(String tableName) async {
    if (!isConnected) {
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
    }

    try {
      final result = await query(
        "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = :table)",
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
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
    }

    try {
      final versionResult = await query("SELECT version() as version");
      final databaseResult =
          await query("SELECT current_database() as database_name");

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
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
    }

    try {
      await execute("BEGIN");
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Commit a transaction
  @override
  Future<void> commit() async {
    if (!isConnected) {
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
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
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
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
      throw Exception("PostgreSQL not connected. Last error: $_lastError");
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
      await _connection?.close();
      _connected = false;
      _connection = null;
      Log.debug("✅ PostgreSQL connection closed");
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Ping the database to check connection health
  Future<bool> ping() async {
    try {
      if (!isConnected) return false;
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
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      await close();
      await connect(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  // /// Listen for notifications on a channel
  // Future<void> listen(
  //     String channel, void Function(String payload) callback) async {
  //   if (!isConnected) {
  //     throw Exception("PostgreSQL not connected. Last error: $_lastError");
  //   }

  //   try {
  //     // Store the subscription so we can cancel it later if needed
  //     final subscription = _connection!.channels.all.listen(channel, (message) {
  //       callback(message.payload);
  //     });

  //     // You might want to store the subscription in a map if you need to manage multiple listeners
  //     // _listeners[channel] = subscription;
  //   } catch (e) {
  //     _lastError = e.toString();
  //     rethrow;
  //   }
  // }

  // /// Unlisten from a channel
  // Future<void> unlisten(String channel) async {
  //   if (!isConnected) {
  //     throw Exception("PostgreSQL not connected. Last error: $_lastError");
  //   }

  //   try {
  //     await _connection!.channels.all.unlisten(channel);
  //   } catch (e) {
  //     _lastError = e.toString();
  //     rethrow;
  //   }
  // }

  // /// Notify a channel with a payload
  // Future<void> notify(String channel, {String payload = ''}) async {
  //   if (!isConnected) {
  //     throw Exception("PostgreSQL not connected. Last error: $_lastError");
  //   }

  //   try {
  //     await _connection!.channels.all.asBroadcastStream(channel, payload: payload);
  //   } catch (e) {
  //     _lastError = e.toString();
  //     rethrow;
  //   }
  // }
}
