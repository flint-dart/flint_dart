import 'package:flint_dart/src/database/connection.dart';

/// A simple SQL query builder for MySQL/PostgreSQL in Flint Dart.
///
/// `QueryBuilder` provides a fluent API for constructing and executing
/// common SQL operations such as:
/// - `SELECT` (with optional `WHERE` and `LIMIT`)
/// - `INSERT`
/// - `UPDATE`
/// - `DELETE`
///
/// Queries are built safely using prepared statements and bound parameters
/// to avoid SQL injection.
///
/// ### Example
/// ```dart
/// // Select example
/// final users = await QueryBuilder(table: 'users')
///   .select(['id', 'name'])
///   .where('status', '=', 'active')
///   .limit(10)
///   .get();
///
/// // Insert example
/// await QueryBuilder(table: 'users').insert({
///   'name': 'John Doe',
///   'email': 'john@example.com',
/// });
///
/// // Update example
/// await QueryBuilder(table: 'users')
///   .where('id', '=', 1)
///   .update({'name': 'Jane Doe'});
///
/// // Delete example
/// await QueryBuilder(table: 'users')
///   .where('id', '=', 1)
///   .delete();
/// ```
class QueryBuilder {
  /// The name of the table to run queries against.
  final String table;

  final List<String> _selects = [];
  final List<String> _wheres = [];
  final List<dynamic> _bindings = [];
  int? _limit;

  /// Creates a new [QueryBuilder] for the given [table].
  QueryBuilder({required this.table});

  /// Adds selected fields to the query.
  ///
  /// If [fields] is `null` or empty, all columns (`*`) are selected.
  ///
  /// Returns the current [QueryBuilder] instance for chaining.
  QueryBuilder select([List<String>? fields]) {
    if (fields != null && fields.isNotEmpty) {
      _selects.addAll(fields);
    }
    return this;
  }

  /// Adds a `WHERE` condition to the query.
  ///
  /// [field] is the column name.
  /// [operator] is the SQL operator (e.g., `"="`, `">"`, `"<"`, `"LIKE"`).
  /// [value] is the value to bind.
  ///
  /// Returns the current [QueryBuilder] instance for chaining.
  QueryBuilder where(String field, String operator, dynamic value) {
    _wheres.add('$field $operator ?');
    _bindings.add(value);
    return this;
  }

  /// Adds a `LIMIT` clause to the query.
  ///
  /// [value] is the maximum number of rows to return.
  ///
  /// Returns the current [QueryBuilder] instance for chaining.
  QueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  /// Builds the SQL `SELECT` query string.
  ///
  /// Used internally by [get] and [first].
  String _buildSelectQuery() {
    final select = _selects.isEmpty ? '*' : _selects.join(', ');
    final whereClause =
        _wheres.isNotEmpty ? ' WHERE ${_wheres.join(' AND ')}' : '';
    final limitClause = _limit != null ? ' LIMIT $_limit' : '';
    return 'SELECT $select FROM $table$whereClause$limitClause';
  }

  /// Executes the query and returns all matching rows.
  ///
  /// Returns a list of maps where each map represents a row:
  /// - Keys are column names
  /// - Values are column values
  Future<List<Map<String, dynamic>>> get() async {
    final conn = DB.instance;
    final sql = _buildSelectQuery();
    final stmt = await conn.prepare(sql);
    final result = await stmt.execute(_bindings);
    return result.rows.map((row) => row.assoc()).toList();
  }

  /// Executes the query and returns the first matching row.
  ///
  /// Returns:
  /// - A map representing the row, or
  /// - `null` if no rows are found.
  Future<Map<String, dynamic>?> first() async {
    limit(1);
    final rows = await get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Inserts a new record into the table.
  ///
  /// [data] is a map where:
  /// - Keys are column names
  /// - Values are the values to insert
  Future<void> insert(Map<String, dynamic> data) async {
    final conn = DB.instance;
    final fields = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    final sql = 'INSERT INTO $table ($fields) VALUES ($placeholders)';
    final stmt = await conn.prepare(sql);
    await stmt.execute(data.values.toList());
  }

  /// Updates existing record(s) matching the `WHERE` clause.
  ///
  /// Throws an exception if no `WHERE` clause is set to prevent
  /// accidental updates to all rows.
  ///
  /// [data] is a map where:
  /// - Keys are column names
  /// - Values are the values to update
  Future<void> update(Map<String, dynamic> data) async {
    if (_wheres.isEmpty) {
      throw Exception('Update requires a where clause.');
    }

    final conn = DB.instance;
    final setClause = data.keys.map((k) => '$k = ?').join(', ');
    final sql = 'UPDATE $table SET $setClause WHERE ${_wheres.join(' AND ')}';
    final stmt = await conn.prepare(sql);
    await stmt.execute([...data.values, ..._bindings]);
  }

  /// Deletes record(s) matching the `WHERE` clause.
  ///
  /// Throws an exception if no `WHERE` clause is set to prevent
  /// accidental deletion of all rows.
  Future<void> delete() async {
    if (_wheres.isEmpty) {
      throw Exception('Delete requires a where clause.');
    }

    final conn = DB.instance;
    final sql = 'DELETE FROM $table WHERE ${_wheres.join(' AND ')}';
    final stmt = await conn.prepare(sql);
    await stmt.execute(_bindings);
  }
}
