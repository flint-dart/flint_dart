import 'package:flint_dart/src/database/db.dart';

/// A simple SQL query builder for MySQL/PostgreSQL in Flint Dart.
class QueryBuilder {
  final String table;

  final List<String> _selects = [];
  final List<String> _wheres = [];
  final Map<String, dynamic> _bindings = {};
  int? _limit;
  int _paramIndex = 1; // for @p1, @p2, ... bindings

  QueryBuilder({required this.table});

  /// SELECT fields
  QueryBuilder select([List<String>? fields]) {
    if (fields != null && fields.isNotEmpty) {
      _selects.addAll(fields);
    }
    return this;
  }

  /// WHERE clause
  QueryBuilder where(String field, String operator, dynamic value) {
    final paramName = 'p${_paramIndex++}';
    _wheres.add('$field $operator @$paramName');
    _bindings[paramName] = value;
    return this;
  }

  /// LIMIT
  QueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  String _buildSelectQuery() {
    final select = _selects.isEmpty ? '*' : _selects.join(', ');
    final whereClause =
        _wheres.isNotEmpty ? ' WHERE ${_wheres.join(' AND ')}' : '';
    final limitClause = _limit != null ? ' LIMIT $_limit' : '';
    return 'SELECT $select FROM $table$whereClause$limitClause';
  }

  /// Fetch all rows
  Future<List<Map<String, dynamic>>> get() async {
    final conn = DB.instance;
    final sql = _buildSelectQuery();
    final result = await conn.query(sql, namedParams: _bindings);
    return result;
  }

  /// Fetch first row
  Future<Map<String, dynamic>?> first() async {
    limit(1);
    final rows = await get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// INSERT
  Future<void> insert(Map<String, dynamic> data) async {
    final conn = DB.instance;
    final fields = data.keys.join(', ');
    final params = <String>[];
    final bindings = <String, dynamic>{};

    var i = 1;
    data.forEach((k, v) {
      final param = 'p${i++}';
      params.add('@$param');
      bindings[param] = v;
    });

    final sql = 'INSERT INTO $table ($fields) VALUES (${params.join(', ')})';
    await conn.query(sql, namedParams: bindings);
  }

  /// UPDATE
  Future<void> update(Map<String, dynamic> data) async {
    if (_wheres.isEmpty) {
      throw Exception('Update requires a where clause.');
    }

    final conn = DB.instance;
    final setClauses = <String>[];
    final bindings = {..._bindings};
    var i = bindings.length + 1;

    data.forEach((k, v) {
      final param = 'p${i++}';
      setClauses.add('$k = @$param');
      bindings[param] = v;
    });

    final sql =
        'UPDATE $table SET ${setClauses.join(', ')} WHERE ${_wheres.join(' AND ')}';
    await conn.query(sql, namedParams: bindings);
  }

  /// DELETE
  Future<void> delete() async {
    if (_wheres.isEmpty) {
      throw Exception('Delete requires a where clause.');
    }

    final sql = 'DELETE FROM $table WHERE ${_wheres.join(' AND ')}';
    await DB.query(sql, namedParams: _bindings);
  }
}
