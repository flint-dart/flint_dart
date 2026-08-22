import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/database/db_executor.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';

class DBTransaction implements DbExecutor {
  final DBWrapper _connection;

  DBTransaction(this._connection);

  @override
  DBDriver get driver => DB.driver;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final (normalizedSql, params) = DB.normalizeQuery(
      sql,
      positionalParams: positionalParams,
      namedParams: namedParams,
    );

    return _connection.query(normalizedSql, positionalParams: params);
  }

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    final (normalizedSql, params) = DB.normalizeQuery(
      sql,
      positionalParams: positionalParams,
      namedParams: namedParams,
    );

    await _connection.execute(normalizedSql, positionalParams: params);
  }

  @override
  Future<dynamic> getLastInsertId(String tableName, String primaryKey) async {
    final rows = driver == DBDriver.postgres
        ? await query('SELECT lastval() as id')
        : await query('SELECT LAST_INSERT_ID() as id');
    if (rows.isEmpty) return null;
    final value = rows.first['id'];
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value) ?? value;
    return value;
  }
}
