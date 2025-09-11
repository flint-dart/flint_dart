import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'mysql_connection.dart';
import 'pg_connection.dart';

enum DBDriver { mysql, postgres }

class DB {
  static DBDriver? _driver;
  static MySqlConnectionWrapper? _mysql;
  static PgConnectionWrapper? _pg;

  /// Connect to the database using environment variables
  static Future<void> autoConnect() async {
    await FlintEnv.load();
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
        password: FlintEnv.get('DB_PASSWORD', ''),
      );
    }
  }

  static Future<void> tryAutoConnect({int retries = 5}) async {
    for (int i = 1; i <= retries; i++) {
      try {
        await autoConnect();
        return;
      } catch (e) {
        print("⏳ Retry $i/$retries in 3s...");
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    print("❌ Could not connect to DB after $retries attempts.");
  }

  static DBDriver get driver {
    if (_driver == null) {
      throw Exception(
          "Database not initialized. Call DB.connectFromEnv() first.");
    }
    return _driver!;
  }

  static MySqlConnectionWrapper get mysql {
    if (_mysql == null) throw Exception("MySQL not connected.");
    return _mysql!;
  }

  static PgConnectionWrapper get pg {
    if (_pg == null) throw Exception("PostgreSQL not connected.");
    return _pg!;
  }

  /// Returns the raw instance (mysql or pg)
  static DBWrapper get instance {
    if (_driver == null) {
      throw Exception(
          "Database not initialized. Call DB.connectFromEnv() first.");
    }
    return _driver == DBDriver.mysql ? _mysql! : _pg!;
  }

  /// Normalize placeholder style depending on driver
  /// - MySQL -> ?
  /// - Postgres -> $1, $2, ...
  static String normalizePlaceholders(String sql, List<dynamic> params) {
    if (_driver == DBDriver.mysql) return sql;

    // Replace each "?" with $1, $2, ...
    var i = 0;
    return sql.replaceAllMapped(RegExp(r'\?'), (_) => '\$${++i}');
  }

  /// Execute query for SELECT/INSERT/UPDATE/DELETE
  static Future<dynamic> execute(String sql,
      [List<dynamic> params = const []]) async {
    if (_driver == DBDriver.mysql) {
      final stmt = await _mysql!.query(sql);
      return stmt;
    } else {
      final normalized = normalizePlaceholders(sql, params);
      return await _pg!.query(
        normalized,
      );
    }
  }

  /// Close active connection
  static Future<void> close() async {
    await _mysql?.close();
    await _pg?.close();
    _driver = null;
  }
}
