import 'package:flint_dart/src/database/connection.dart';

class QueryBuilder {
  final String table;
  final List<String> _selects = [];
  final List<String> _wheres = [];
  final List<dynamic> _bindings = [];
  int? _limit;

  QueryBuilder({required this.table});

  /// Adds selected fields to the query
  QueryBuilder select([List<String>? fields]) {
    if (fields != null && fields.isNotEmpty) {
      _selects.addAll(fields);
    }
    return this;
  }

  /// Adds WHERE condition with binding
  QueryBuilder where(String field, String operator, dynamic value) {
    _wheres.add('$field $operator ?');
    _bindings.add(value);
    return this;
  }

  /// Adds LIMIT clause
  QueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  /// Build SELECT SQL string
  String _buildSelectQuery() {
    final select = _selects.isEmpty ? '*' : _selects.join(', ');
    final whereClause =
        _wheres.isNotEmpty ? ' WHERE ${_wheres.join(' AND ')}' : '';
    final limitClause = _limit != null ? ' LIMIT $_limit' : '';
    return 'SELECT $select FROM $table$whereClause$limitClause';
  }

  /// Run SELECT and return all rows
  Future<List<Map<String, dynamic>>> get() async {
    final conn = DB.instance;
    final sql = _buildSelectQuery();
    final stmt = await conn.prepare(sql);
    final result = await stmt.execute(_bindings);
    return result.rows.map((row) => row.assoc()).toList();
  }

  /// Run SELECT and return first row
  Future<Map<String, dynamic>?> first() async {
    limit(1);
    final rows = await get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Insert a new record
  Future<void> insert(Map<String, dynamic> data) async {
    final conn = DB.instance;
    final fields = data.keys.join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    final sql = 'INSERT INTO $table ($fields) VALUES ($placeholders)';
    final stmt = await conn.prepare(sql);
    await stmt.execute(data.values.toList());
  }

  /// Update record(s) with WHERE clause
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

  /// Delete record(s) with WHERE clause
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
