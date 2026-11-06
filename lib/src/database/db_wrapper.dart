// db_wrapper.dart
import 'db_driver.dart';

abstract class DBWrapper {
  DBDriver get driver;

  Future<void> beginTransaction();
  Future<void> commit();
  Future<void> rollback();
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

  Future<void> close();
  bool get isConnected;
}
