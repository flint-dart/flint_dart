import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';
import 'package:flint_dart/src/database/db.dart';

/// A simple SQL query builder for MySQL/PostgreSQL in Flint Dart.
class QueryBuilder {
  final String table;

  final List<String> _selects = [];
  final List<String> _wheres = [];
  final Map<String, dynamic> _bindings = {};
  static final Map<String, _ColumnInfo> _columnCache = {};

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
  Future<void> insert(Map<String, dynamic> data,
      {String idColumn = 'id'}) async {
    _ColumnInfo columnInfo;

    if (_columnCache.containsKey(table)) {
      columnInfo = _columnCache[table]!;
    } else {
      columnInfo = await _loadIdColumnInfo(idColumn);
      _columnCache[table] = columnInfo;
    }

    // --- Step 2: Generate ID if needed ---
    if (!columnInfo.isAutoIncrement) {
      if (columnInfo.isString &&
          (!data.containsKey(idColumn) ||
              data[idColumn] == null ||
              data[idColumn].toString().isEmpty)) {
        data[idColumn] = Str.uuid();
      } else if (!columnInfo.isString &&
          (!data.containsKey(idColumn) || data[idColumn] == null)) {}
    }

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

    return;
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

  /// --- Load primary key info from the database ---

  Future<_ColumnInfo> _loadIdColumnInfo(String idColumn) async {
    try {
      if (DB.driver == DBDriver.mysql) {
        final result = await DB.query('''
        SELECT DATA_TYPE, EXTRA
        FROM information_schema.columns
        WHERE TABLE_SCHEMA = :db
          AND TABLE_NAME = :table
          AND COLUMN_NAME = :id
      ''', namedParams: {
          'db': FlintEnv.get("DB_NAME", ''),
          'table': table,
          'id': idColumn,
        });

        if (result.isNotEmpty) {
          final dt = result.first['DATA_TYPE'];
          final dataType = dt is List<int>
              ? String.fromCharCodes(dt).toLowerCase()
              : dt.toString().toLowerCase();
          final extra = (result.first['EXTRA'] as String).toLowerCase();
          final isAuto = extra.contains('auto_increment');

          return _ColumnInfo(
            isAutoIncrement: isAuto,
            isString:
                !isAuto && (dataType.contains('char') || dataType == 'uuid'),
          );
        }
      } else if (DB.driver == DBDriver.postgres) {
        final result = await DB.query('''
        SELECT data_type, is_identity
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = :table
          AND column_name = :id
      ''', namedParams: {
          'table': table,
          'id': idColumn,
        });

        if (result.isNotEmpty) {
          final dataType = (result.first['data_type'] as String).toLowerCase();
          final isIdentity =
              (result.first['is_identity'] as String).toUpperCase() == 'YES';
          final isSerial = dataType.contains('serial');

          return _ColumnInfo(
            isAutoIncrement: isIdentity || isSerial,
            isString: dataType.contains('char') || dataType == 'uuid',
          );
        }
      }
    } catch (_) {}

    // Fallback: assume integer if not found
    return _ColumnInfo(isAutoIncrement: false, isString: false);
  }
}

/// --- Helper class to cache column info ---
class _ColumnInfo {
  final bool isAutoIncrement;
  final bool isString;

  _ColumnInfo({required this.isAutoIncrement, required this.isString});
}
