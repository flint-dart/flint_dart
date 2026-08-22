import 'db.dart';
import 'db_executor.dart';

/// Backwards-compatible executor used when no transaction is supplied.
final class DefaultDbExecutor implements DbExecutor {
  const DefaultDbExecutor();

  @override
  DBDriver get driver => DB.driver;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) =>
      DB.query(
        sql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );

  @override
  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) =>
      DB.execute(
        sql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );

  @override
  Future<dynamic> getLastInsertId(String tableName, String primaryKey) =>
      DB.getLastInsertId(tableName, primaryKey);
}
