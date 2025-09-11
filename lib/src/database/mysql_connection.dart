// mysql_connection.dart
import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:mysql_dart/mysql_dart.dart';

class MySqlConnectionWrapper implements DBWrapper {
  late MySQLConnection _conn;

  Future<void> connect({
    required String host,
    required int port,
    required String db,
    required String user,
    required String password,
  }) async {
    _conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      databaseName: db,
      userName: user,
      password: password,
    );
    await _conn.connect();
    print("✅ MySQL connected to $db@$host:$port");
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final stmt = await _conn.prepare(sql);
    final result = await stmt.execute(positionalParams ?? []);
    return result.rows.map((r) => r.assoc()).toList();
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final stmt = await _conn.prepare(sql);
    await stmt.execute(positionalParams ?? []);
  }

  @override
  Future<void> close() async => await _conn.close();
}
