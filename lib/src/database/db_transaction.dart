import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/database/db_wrapper.dart';

class DBTransaction {
  final DBWrapper _connection;

  DBTransaction(this._connection);

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
}
