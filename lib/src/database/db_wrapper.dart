// db_wrapper.dart
abstract class DBWrapper {
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

  Future<void> close();
  bool get isConnected;
}
