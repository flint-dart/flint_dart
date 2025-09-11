import 'package:flint_dart/src/database/db_wrapper.dart';
import 'package:postgres/postgres.dart';

class PgConnectionWrapper implements DBWrapper {
  Connection? _connection;

  Future<void> connect({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    _connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
    );
    print("✅ PostgreSQL connected to $database@$host:$port");
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    if (_connection == null) throw Exception("PostgreSQL not connected.");

    final result = await _connection!.execute(
      sql,
      parameters: positionalParams ?? [],
    );

    // Convert each row into a map {colName: value}
    return result.map((row) => row.toColumnMap()).toList();
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    if (_connection == null) throw Exception("PostgreSQL not connected.");
    await _connection!.execute(sql, parameters: positionalParams ?? []);
  }

  @override
  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}
