import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';
import 'package:flint_dart/src/database/db.dart';

/// A simple SQL query builder for MySQL/PostgreSQL in Flint Dart.
class QueryBuilder {
  final String table;

  final List<String> _selects = [];
  final List<String> _wheres = [];
  final List<String> _orWheres = [];
  final List<String> _orderBys = [];
  final List<String> _groups = [];
  final List<String> _relations = [];
  // final Map<String, dynamic> _eagerLoaded = {};
  final Map<String, dynamic> _bindings = {};
  static final Map<String, _ColumnInfo> _columnCache = {};

  int? _limit;
  int? _offset;
  int _paramIndex = 1;

  QueryBuilder({required this.table});

  /// SELECT fields
  QueryBuilder select([List<String>? fields]) {
    if (fields != null && fields.isNotEmpty) {
      _selects.addAll(fields);
    }
    return this;
  }

  List<String> get relations => _relations;

  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// Adds a LIKE condition to the query.
  ///
  /// [field] is the column to match.
  /// [pattern] is the SQL pattern (supports % as wildcard).
  /// [caseSensitive] determines if the match is case-sensitive.
  /// [escape] determines if special characters in the pattern are escaped.
  QueryBuilder whereLike(String field, String pattern,
      {bool caseSensitive = false, bool escape = true}) {
    final paramName = 'p${_paramIndex++}';
    final processedPattern = escape ? _escapeLike(pattern) : pattern;

    if (DB.driver == DBDriver.postgres) {
      final sql = caseSensitive
          ? '$field LIKE :$paramName'
          : '$field ILIKE :$paramName';
      _wheres.add(sql);
    } else {
      final sql =
          caseSensitive ? '$field LIKE ?' : 'LOWER($field) LIKE LOWER(?)';
      _wheres.add(sql);
    }

    _bindings[paramName] = processedPattern;
    return this;
  }

  /// Adds a NOT LIKE condition to the query.
  ///
  /// [field] is the column to match.
  /// [pattern] is the SQL pattern.
  /// [caseSensitive] determines if the match is case-sensitive.
  /// [escape] determines if special characters in the pattern are escaped.
  QueryBuilder whereNotLike(String field, String pattern,
      {bool caseSensitive = false, bool escape = true}) {
    final paramName = 'p${_paramIndex++}';
    final processedPattern = escape ? _escapeLike(pattern) : pattern;

    if (DB.driver == DBDriver.postgres) {
      final sql = caseSensitive
          ? '$field NOT LIKE :$paramName'
          : '$field NOT ILIKE :$paramName';
      _wheres.add(sql);
    } else {
      final sql = caseSensitive
          ? '$field NOT LIKE ?'
          : 'LOWER($field) NOT LIKE LOWER(?)';
      _wheres.add(sql);
    }

    _bindings[paramName] = processedPattern;
    return this;
  }

  /// Adds an OR LIKE condition to the query.
  ///
  /// Works similarly to [whereLike] but combines with OR logic.
  QueryBuilder orWhereLike(String field, String pattern,
      {bool caseSensitive = false, bool escape = true}) {
    final paramName = 'p${_paramIndex++}';
    final processedPattern = escape ? _escapeLike(pattern) : pattern;

    if (DB.driver == DBDriver.postgres) {
      final sql = caseSensitive
          ? '$field LIKE :$paramName'
          : '$field ILIKE :$paramName';
      _orWheres.add(sql);
    } else {
      final sql =
          caseSensitive ? '$field LIKE ?' : 'LOWER($field) LIKE LOWER(?)';
      _orWheres.add(sql);
    }

    _bindings[paramName] = processedPattern;
    return this;
  }

  // Helper methods for contains, starts with, ends with
  // ------------------------
  // Helper Methods for LIKE
  // ------------------------

  /// Adds a WHERE condition that checks if [field] contains [value].
  QueryBuilder whereContains(String field, String value,
          {bool caseSensitive = false, bool escape = true}) =>
      whereLike(field, '%$value%',
          caseSensitive: caseSensitive, escape: escape);

  /// Adds a WHERE condition that checks if [field] starts with [value].
  QueryBuilder whereStartsWith(String field, String value,
          {bool caseSensitive = false, bool escape = true}) =>
      whereLike(field, '$value%', caseSensitive: caseSensitive, escape: escape);

  /// Adds a WHERE condition that checks if [field] ends with [value].
  QueryBuilder whereEndsWith(String field, String value,
          {bool caseSensitive = false, bool escape = true}) =>
      whereLike(field, '%$value', caseSensitive: caseSensitive, escape: escape);

  /// Adds an OR condition that checks if [field] contains [value].
  QueryBuilder orWhereContains(String field, String value,
          {bool caseSensitive = false, bool escape = true}) =>
      orWhereLike(field, '%$value%',
          caseSensitive: caseSensitive, escape: escape);

  /// Adds an OR condition that checks if [field] starts with [value].
  QueryBuilder orWhereStartsWith(String field, String value,
          {bool caseSensitive = false, bool escape = true}) =>
      orWhereLike(field, '$value%',
          caseSensitive: caseSensitive, escape: escape);

  /// Adds an OR condition that checks if [field] ends with [value].
  QueryBuilder orWhereEndsWith(String field, String value,
          {bool caseSensitive = false, bool escape = true}) =>
      orWhereLike(field, '%$value',
          caseSensitive: caseSensitive, escape: escape);
  // ------------------------
  // Range / Date Methods
  // ------------------------

  /// Adds a WHERE condition that filters [field] between [start] and [end].
  QueryBuilder whereBetween(
    String field,
    dynamic start,
    dynamic end,
  ) {
    final paramStart = 'p${_paramIndex++}';
    final paramEnd = 'p${_paramIndex++}';

    if (DB.driver == DBDriver.postgres) {
      _wheres.add('$field BETWEEN :$paramStart AND :$paramEnd');
    } else {
      _wheres.add('$field BETWEEN ? AND ?');
    }

    _bindings[paramStart] = start;
    _bindings[paramEnd] = end;

    return this;
  }

  /// Adds a WHERE condition that filters [field] NOT between [start] and [end].
  QueryBuilder whereNotBetween(String field, dynamic start, dynamic end) {
    final paramStart = 'p${_paramIndex++}';
    final paramEnd = 'p${_paramIndex++}';

    if (DB.driver == DBDriver.postgres) {
      _wheres.add('$field NOT BETWEEN :$paramStart AND :$paramEnd');
    } else {
      _wheres.add('$field NOT BETWEEN ? AND ?');
    }

    _bindings[paramStart] = start;
    _bindings[paramEnd] = end;

    return this;
  }

  /// Adds a WHERE condition that filters [field] to match the given [date].
  QueryBuilder whereDate(String field, DateTime date) {
    final paramName = 'p${_paramIndex++}';

    if (DB.driver == DBDriver.postgres) {
      _wheres.add("DATE($field) = DATE(:$paramName)");
    } else {
      _wheres.add("DATE($field) = DATE(?)");
    }

    _bindings[paramName] = date.toIso8601String();
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

  QueryBuilder withRelations(List<String> relations) {
    _relations.addAll(relations);
    return this;
  }

  /// WHERE IN clause
  QueryBuilder whereIn(String field, List<dynamic> values) {
    if (values.isEmpty) {
      _wheres.add('1 = 0'); // Always false if no values
      return this;
    }

    final paramNames = List.generate(values.length, (i) {
      final paramName = 'p${_paramIndex++}';
      _bindings[paramName] = values[i];
      return DB.driver == DBDriver.postgres ? ':$paramName' : '?';
    }).join(', ');

    _wheres.add('$field IN ($paramNames)');
    return this;
  }

  /// WHERE NOT IN clause
  QueryBuilder whereNotIn(String field, List<dynamic> values) {
    if (values.isEmpty) {
      _wheres.add('1 = 1'); // Always true if no values
      return this;
    }

    final paramNames = List.generate(values.length, (i) {
      final paramName = 'p${_paramIndex++}';
      _bindings[paramName] = values[i];
      return DB.driver == DBDriver.postgres ? ':$paramName' : '?';
    }).join(', ');

    _wheres.add('$field NOT IN ($paramNames)');
    return this;
  }

  /// OR WHERE clause
  QueryBuilder orWhere(String field, String operator, dynamic value) {
    final paramName = 'p${_paramIndex++}';

    if (DB.driver == DBDriver.postgres) {
      _orWheres.add('$field $operator :$paramName');
    } else {
      _orWheres.add('$field $operator ?');
    }

    _bindings[paramName] = value;
    return this;
  }

  /// WHERE NULL clause
  QueryBuilder whereNull(String field) {
    _wheres.add('$field IS NULL');
    return this;
  }

  /// WHERE NOT NULL clause
  QueryBuilder whereNotNull(String field) {
    _wheres.add('$field IS NOT NULL');
    return this;
  }

  /// ORDER BY clause
  QueryBuilder orderBy(String field, [String direction = 'ASC']) {
    final dir = direction.toUpperCase() == 'DESC' ? 'DESC' : 'ASC';
    _orderBys.add('$field $dir');
    return this;
  }

  /// GROUP BY clause
  QueryBuilder groupBy(String field) {
    _groups.add(field);
    return this;
  }

  /// LIMIT clause
  QueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  /// OFFSET clause
  QueryBuilder offset(int value) {
    _offset = value;
    return this;
  }

  /// JOIN clause
  QueryBuilder join(
      String table, String first, String operator, String second) {
    // Simple JOIN implementation - you can extend this for different JOIN types
    _selects.add('$table.*'); // Add joined table columns
    _wheres.add('$first $operator $second');
    return this;
  }

  /// COUNT aggregate
  Future<int> count([String column = '*']) async {
    final originalSelects = List<String>.from(_selects);
    final originalLimit = _limit;
    final originalOffset = _offset;

    _selects.clear();
    _limit = null;
    _offset = null;

    _selects.add('COUNT($column) as count');

    final result = await first();

    // Restore original state
    _selects.clear();
    _selects.addAll(originalSelects);
    _limit = originalLimit;
    _offset = originalOffset;

    if (result?["count"] is String) {
      return int.tryParse("${result?["count"] ?? 0}  ") ?? 0;
    }
    if (result?["count"] is num) {
      return result?["count"] as int;
    }

    if (result?["count"] is int) {
      return result?["count"];
    }
    return 0;
  }

  /// MAX aggregate
  Future<dynamic> max(String column) async {
    final originalSelects = List<String>.from(_selects);
    _selects.clear();
    _selects.add('MAX($column) as max_value');

    final result = await first();

    _selects.clear();
    _selects.addAll(originalSelects);

    return result?['max_value'];
  }

  /// MIN aggregate
  Future<dynamic> min(String column) async {
    final originalSelects = List<String>.from(_selects);
    _selects.clear();
    _selects.add('MIN($column) as min_value');

    final result = await first();

    _selects.clear();
    _selects.addAll(originalSelects);

    return result?['min_value'];
  }

  /// AVG aggregate
  Future<double?> avg(String column) async {
    final originalSelects = List<String>.from(_selects);
    _selects.clear();
    _selects.add('AVG($column) as avg_value');

    final result = await first();

    _selects.clear();
    _selects.addAll(originalSelects);

    return result?['avg_value']?.toDouble();
  }

  /// SUM aggregate
  Future<double?> sum(String column) async {
    final originalSelects = List<String>.from(_selects);
    _selects.clear();
    _selects.add('SUM($column) as sum_value');

    final result = await first();

    _selects.clear();
    _selects.addAll(originalSelects);

    return result?['sum_value']?.toDouble();
  }

  String _buildSelectQuery() {
    final select = _selects.isEmpty ? '*' : _selects.join(', ');
    var whereClause = '';

    if (_wheres.isNotEmpty || _orWheres.isNotEmpty) {
      final whereParts = <String>[];

      if (_wheres.isNotEmpty) {
        whereParts.add(_wheres.join(' AND '));
      }

      if (_orWheres.isNotEmpty) {
        if (_wheres.isNotEmpty) {
          whereParts.add('(${_orWheres.join(' OR ')})');
        } else {
          whereParts.add(_orWheres.join(' OR '));
        }
      }

      whereClause = ' WHERE ${whereParts.join(' AND ')}';
    }

    final groupClause =
        _groups.isNotEmpty ? ' GROUP BY ${_groups.join(', ')}' : '';
    final orderClause =
        _orderBys.isNotEmpty ? ' ORDER BY ${_orderBys.join(', ')}' : '';
    final limitClause = _limit != null ? ' LIMIT $_limit' : '';
    final offsetClause = _offset != null ? ' OFFSET $_offset' : '';

    return 'SELECT $select FROM $table$whereClause$groupClause$orderClause$limitClause$offsetClause';
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

  /// Paginate results
  Future<Map<String, dynamic>> paginate(int page, [int perPage = 15]) async {
    final offset = (page - 1) * perPage;
    final originalLimit = _limit;
    final originalOffset = _offset;

    _limit = perPage;
    _offset = offset;

    final data = await get();
    final total = await count();

    // Restore original state
    _limit = originalLimit;
    _offset = originalOffset;

    return {
      'data': data,
      'current_page': page,
      'per_page': perPage,
      'total': total,
      'last_page': (total / perPage).ceil(),
    };
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

    // Generate ID if needed
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
