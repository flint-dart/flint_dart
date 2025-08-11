import 'connection.dart';

class DBUtils {
  /// Get all column names from a table
  static Future<List<String>> getColumns(String tableName) async {
    final conn = await DB.autoConnect();
    final result = await conn.execute("SHOW COLUMNS FROM `$tableName`");

    return result.rows.map((row) => row.colByName('Field') as String).toList();
  }

  /// Check if a column exists in a table
  static Future<bool> columnExists(String tableName, String columnName) async {
    final columns = await getColumns(tableName);
    return columns.contains(columnName);
  }

  /// Checks if a given table exists in the database.
  static Future<bool> tableExists(String tableName) async {
    final conn = await DB.autoConnect();
    final result = await conn.execute(
      "SHOW TABLES LIKE :tableName",
      {'tableName': tableName},
    );
    return result.rows.isNotEmpty;
  }
}
