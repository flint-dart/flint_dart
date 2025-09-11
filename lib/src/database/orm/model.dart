import 'package:flint_dart/schema.dart';
import '../connection.dart';
import 'query_builder.dart';

abstract class Model<T extends Model<T>> {
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

    final result = await DB.instance.query(
      'SELECT * FROM ${table.name} WHERE $primaryKey = @id LIMIT 1',
      namedParams: {'id': id},
    );

    if (result.isEmpty) return null;
    return fromMap(result.first);
  }

  /// Insert new record
  Future<T> create(Map<String, dynamic> map) async {
    final insertMap = Map.of(map)..remove(primaryKey);

    final fields = insertMap.keys.join(', ');
    final params = insertMap.keys.map((k) => '@$k').join(', ');

    final sql = 'INSERT INTO ${table.name} ($fields) VALUES ($params)';

    await DB.instance.query(sql, namedParams: insertMap);

    // fetch the latest record (works for Postgres & MySQL if PK is serial/auto-increment)
    final refreshed = await DB.instance.query(
      'SELECT * FROM ${table.name} ORDER BY $primaryKey DESC LIMIT 1',
    );

    return fromMap(refreshed.first);
  }

  /// Update existing record
  Future<T> update(dynamic id, Map<String, dynamic> map) async {
    if (id == null) throw Exception("Cannot update: $primaryKey is null");

    map.remove(primaryKey);
    final setClause = map.keys.map((k) => '$k = @$k').join(', ');

    final sql = 'UPDATE ${table.name} SET $setClause WHERE $primaryKey = @id';

    final params = {...map, 'id': id};

    await DB.instance.query(sql, namedParams: params);

    final refreshed = await DB.instance.query(
      'SELECT * FROM ${table.name} WHERE $primaryKey = @id LIMIT 1',
      namedParams: {'id': id},
    );

    return fromMap(refreshed.first);
  }

  /// Delete this model
  Future<void> delete() async {
    final id = toMap()[primaryKey];
    if (id == null) return;

    await DB.instance.query(
      'DELETE FROM ${table.name} WHERE $primaryKey = @id',
      namedParams: {'id': id},
    );
  }

  /// Find by ID
  Future<T?> find(dynamic id) async {
    final result = await DB.instance.query(
      'SELECT * FROM ${table.name} WHERE $primaryKey = @id LIMIT 1',
      namedParams: {'id': id},
    );

    return result.isNotEmpty ? fromMap(result.first) : null;
  }

  /// Get all records
  Future<List<T>> all() async {
    final result = await DB.instance.query('SELECT * FROM ${table.name}');
    return result.map(fromMap).toList();
  }

  /// Where clause
  Future<List<T>> where(String field, dynamic value) async {
    final result = await DB.instance.query(
      'SELECT * FROM ${table.name} WHERE $field = @value',
      namedParams: {'value': value},
    );

    return result.map(fromMap).toList();
  }

  /// Count all records
  static Future<int> count<T extends Model<T>>(T model) async {
    final result = await DB.instance.query(
      'SELECT COUNT(*) as count FROM ${model.table.name}',
    );

    return result.first['count'] as int;
  }

  /// Truncate table
  Future<void> truncate() async {
    await DB.instance.query('TRUNCATE TABLE ${table.name}');
  }

  /// Custom query builder
  QueryBuilder query() {
    return QueryBuilder(table: table.name);
  }
}
