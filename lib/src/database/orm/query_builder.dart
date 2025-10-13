import 'package:flint_dart/src/database/db.dart';

/// A simple SQL query builder for MySQL/PostgreSQL in Flint Dart.
class QueryBuilder {
  final String table;

  final List<String> _selects = [];
  final List<String> _wheres = [];
  final Map<String, dynamic> _bindings = {};
  int? _limit;
  int _paramIndex = 1;

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

    if (DB.driver == DBDriver.postgres) {
      _wheres.add('$field $operator :$paramName');
    } else {
      _wheres.add('$field $operator ?');
    }

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

  /// Internal query executor
  Future<List<Map<String, dynamic>>> _executeSelect(String sql) async {
    final result = await DB.query(
      sql,
      namedParams: DB.driver == DBDriver.postgres ? _bindings : null,
      positionalParams:
          DB.driver == DBDriver.mysql ? _bindings.values.toList() : null,
    );

    // Normalize maps and convert DateTime to ISO string
    return result.map((row) {
      return row.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key.toString(), value.toIso8601String());
        }
        return MapEntry(key.toString(), value);
      });
    }).toList();
  }

  /// Fetch all rows
  Future<List<Map<String, dynamic>>> get() async {
    final sql = _buildSelectQuery();
    return await _executeSelect(sql);
  }

  /// Fetch first row
  Future<Map<String, dynamic>?> first() async {
    limit(1);
    final rows = await get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// INSERT
  Future<void> insert(Map<String, dynamic> data) async {
    final fields = data.keys.join(', ');
    final placeholders = DB.driver == DBDriver.postgres
        ? data.keys.map((k) => ':$k').join(', ')
        : List.generate(data.length, (_) => '?').join(', ');

    final sql = 'INSERT INTO $table ($fields) VALUES ($placeholders)';
    await DB.query(
      sql,
      namedParams: DB.driver == DBDriver.postgres ? data : null,
      positionalParams:
          DB.driver == DBDriver.mysql ? data.values.toList() : null,
    );
  }

  /// UPDATE
  Future<void> update(Map<String, dynamic> data) async {
    if (_wheres.isEmpty) {
      throw Exception('Update requires a where clause.');
    }

    final setClauses = <String>[];
    final bindings = {..._bindings};

    if (DB.driver == DBDriver.postgres) {
      data.forEach((k, v) {
        setClauses.add('$k = :$k');
        bindings[k] = v;
      });
    } else {
      data.forEach((k, v) {
        setClauses.add('$k = ?');
        bindings[k] = v;
      });
    }

    final sql =
        'UPDATE $table SET ${setClauses.join(', ')} WHERE ${_wheres.join(' AND ')}';
    await DB.query(
      sql,
      namedParams: DB.driver == DBDriver.postgres ? bindings : null,
      positionalParams:
          DB.driver == DBDriver.mysql ? bindings.values.toList() : null,
    );
  }

  /// DELETE
  Future<void> delete() async {
    if (_wheres.isEmpty) {
      throw Exception('Delete requires a where clause.');
    }

    final sql = 'DELETE FROM $table WHERE ${_wheres.join(' AND ')}';
    await DB.query(
      sql,
      namedParams: DB.driver == DBDriver.postgres ? _bindings : null,
      positionalParams:
          DB.driver == DBDriver.mysql ? _bindings.values.toList() : null,
    );
  }
}
