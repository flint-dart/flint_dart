import 'package:flint_dart/schema.dart';
import '../connection.dart';
import 'query_builder.dart';

abstract class Model<T extends Model<T>> {
  /// Table name
  // String get tableName;

  /// Primary key column
  String get primaryKey => 'id';

  /// Convert model to map
  Map<dynamic, dynamic> toMap();

  late Table table;

  /// Convert map to model
  T fromMap(Map<dynamic, dynamic> map);

  /// Refresh the model from DB
  Future<T?> refresh() async {
    final id = toMap()[primaryKey];
    if (id == null) return null;

    final conn = DB.instance;
    final stmt = await conn.prepare(
      'SELECT * FROM ${table.name} WHERE $primaryKey = ? LIMIT 1',
    );
    final result = await stmt.execute([id]);

    if (result.rows.isEmpty) return null;
    return fromMap(result.rows.first.assoc());
  }

  /// Insert new record
  Future<T> create(Map<String, dynamic> map) async {
    final insertMap = Map.of(map)..remove(primaryKey);

    final conn = DB.instance;
    final fields = insertMap.keys.toList();
    final values = insertMap.values.toList();
    final placeholders = List.filled(fields.length, '?').join(', ');

    final sql =
        'INSERT INTO ${table.name} (${fields.join(', ')}) VALUES ($placeholders)';
    final stmt = await conn.prepare(sql);
    final result = await stmt.execute(values);
    await stmt.deallocate();

    final id = result.lastInsertID.toDouble();

    final refreshStmt = await conn.prepare(
      'SELECT * FROM ${table.name} WHERE $primaryKey = ? LIMIT 1',
    );
    final refreshed = await refreshStmt.execute([id]);
    await refreshStmt.deallocate();

    return fromMap(refreshed.rows.first.assoc());
  }

  /// Update existing record
  Future<T> update(dynamic id, Map<String, dynamic> map) async {
    if (id == null) throw Exception("Cannot update: $primaryKey is null");

    map.remove(primaryKey);
    final fields = map.keys.toList();
    final values = map.values.toList();
    final setClause = fields.map((f) => '$f = ?').join(', ');

    final sql = 'UPDATE ${table.name} SET $setClause WHERE $primaryKey = ?';
    final conn = DB.instance;
    final stmt = await conn.prepare(sql);
    await stmt.execute([...values, id]);

    final refreshStmt = await conn.prepare(
      'SELECT * FROM ${table.name} WHERE $primaryKey = ? LIMIT 1',
    );
    final refreshed = await refreshStmt.execute([id]);

    return fromMap(refreshed.rows.first.assoc());
  }

  /// Delete this model
  Future<void> delete() async {
    final id = toMap()[primaryKey];
    if (id == null) return;

    final sql = 'DELETE FROM ${table.name} WHERE $primaryKey = ?';
    final conn = DB.instance;
    final stmt = await conn.prepare(sql);
    await stmt.execute([id]);
  }

  /// Find by ID
  Future<T?> find(dynamic id) async {
    final conn = DB.instance;
    final stmt = await conn.prepare(
      'SELECT * FROM ${table.name} WHERE $primaryKey = ? LIMIT 1',
    );
    final result = await stmt.execute([id]);

    if (result.rows.isEmpty) return null;
    return fromMap(result.rows.first.assoc());
  }

  /// Get all records

  Future<List<T>> all() async {
    final conn = DB.instance;
    final stmt = await conn.prepare('SELECT * FROM ${table.name}');
    final result = await stmt.execute([]);

    final list = result.rows.map((r) => fromMap(r.assoc())).toList();
    return list; // ✅ Now it's returning Future<List<T>> because the function is async
  }

  /// Where clause
  Future<List<T>> where(String field, dynamic value) async {
    final conn = DB.instance;
    final stmt = await conn.prepare(
      'SELECT * FROM ${table.name} WHERE $field = ?',
    );
    final result = await stmt.execute([value]);

    return result.rows.map((r) => fromMap(r.assoc())).toList();
  }

  /// Count all records
  static Future<int> count<T extends Model<T>>(T model) async {
    final conn = DB.instance;
    final stmt =
        await conn.prepare('SELECT COUNT(*) as count FROM ${model.table}');
    final result = await stmt.execute([]);

    return result.rows.first.assoc()['count'];
  }

  /// Truncate table
  Future<void> truncate() async {
    final conn = DB.instance;
    final stmt = await conn.prepare('TRUNCATE TABLE ${table.name}');
    await stmt.execute([]);
  }

  /// Validate input using rules
  // static Map<String, dynamic>? validate(
  //     Map<String, dynamic> input, Map<String, String> rules) {
  //   Validator.validate(input, rules);
  // }

  /// Custom query builder (you’ll implement this)
  QueryBuilder query() {
    return QueryBuilder(table: table.name);
  }
}
