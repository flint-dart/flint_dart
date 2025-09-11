import 'db.dart';

class DBUtils {
  /// Get all column names from a table
  static Future<List<String>> getColumns(String tableName) async {
    final conn = DB.instance;

    final result = await conn.query(
      '''
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = @tableName
      ''',
      namedParams: {'tableName': tableName},
    );

    return result.map((row) => row['column_name'] as String).toList();
  }

  /// Check if a column exists in a table
  static Future<bool> columnExists(String tableName, String columnName) async {
    final columns = await getColumns(tableName);
    return columns.contains(columnName);
  }

  /// Checks if a given table exists in the database.
  static Future<bool> tableExists(String tableName) async {
    final conn = DB.instance;

    final result = await conn.query(
      '''
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = @tableName
      ) AS exists
      ''',
      namedParams: {'tableName': tableName},
    );

    return result.isNotEmpty && result.first['exists'] == true;
  }
}
