import 'db_driver.dart';

/// Executes database work for a [QueryBuilder].
///
/// The default executor delegates to the global [DB] connection. A
/// [DBTransaction] implements the same contract so every query in a model
/// chain can remain on the request's transaction connection.
abstract interface class DbExecutor {
  DBDriver get driver;

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  });

  Future<void> execute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  });

  Future<dynamic> getLastInsertId(String tableName, String primaryKey);
}
