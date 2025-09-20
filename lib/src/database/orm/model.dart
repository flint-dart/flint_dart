import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/db.dart';
import 'query_builder.dart';

abstract class Model<T extends Model<T>> {
  /// Primary key column
  String get primaryKey => 'id';

  /// Table schema definition
  Table get table;

  /// Convert model to map
  Map<String, dynamic> toMap();

  /// Convert map to model
  T fromMap(Map<String, dynamic> map);

  /// Get the current ID
  dynamic get id => toMap()[primaryKey];

  /// Refresh the model from DB
  Future<T?> refresh([dynamic id]) async {
    final currentId = this.id ?? id;
    if (currentId == null) return null;

    if (DB.driver == DBDriver.mysql) {
      // For MySQL, use positional parameters
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $primaryKey = ? LIMIT 1',
        positionalParams: [currentId],
      );
      if (result.isEmpty) return null;
      return fromMap(_convertDatabaseTypes(result.first));
    } else {
      // For PostgreSQL, use named parameters
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $primaryKey = :id LIMIT 1',
        namedParams: {'id': currentId},
      );
      if (result.isEmpty) return null;
      return fromMap(_convertDatabaseTypes(result.first));
    }
  }

  /// Insert new record (works for both PostgreSQL and MySQL)
  Future<T?> create([Map<String, dynamic>? data]) async {
    final insertMap = data ?? toMap();
    insertMap.remove(primaryKey);

    if (insertMap.isEmpty) {
      throw Exception("No data provided for creation");
    }

    final fields = insertMap.keys.join(', ');

    if (DB.driver == DBDriver.postgres) {
      // PostgreSQL - use RETURNING clause with named parameters
      final placeholders = insertMap.keys.map((k) => ':$k').join(', ');
      final sql = '''
      INSERT INTO ${table.name} ($fields) 
      VALUES ($placeholders) 
      RETURNING *
    ''';

      final result = await DB.query(sql, namedParams: insertMap);
      return fromMap(_convertDatabaseTypes(result.first));
    } else {
      // MySQL - use positional parameters
      final placeholders =
          List.generate(insertMap.length, (_) => '?').join(', ');
      final sql = '''
      INSERT INTO ${table.name} ($fields) 
      VALUES ($placeholders)
    ''';

      await DB.query(sql, positionalParams: insertMap.values.toList());

      // Get the last inserted ID
      final lastId = await DB.getLastInsertId(table.name, primaryKey);

      // Fetch the complete record
      if (DB.driver == DBDriver.mysql) {
        final result = await DB.query(
          'SELECT * FROM ${table.name} WHERE $primaryKey = ?',
          positionalParams: [lastId],
        );
        return fromMap(_convertDatabaseTypes(result.first));
      } else {
        final result = await DB.query(
          'SELECT * FROM ${table.name} WHERE $primaryKey = :id',
          namedParams: {'id': lastId},
        );
        return fromMap(_convertDatabaseTypes(result.first));
      }
    }
  }

  /// Helper method to execute database queries with proper parameter handling
  Future<void> _executeQuery(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    if (DB.driver == DBDriver.mysql) {
      // Convert named parameters to positional for MySQL
      if (namedParams != null && namedParams.isNotEmpty) {
        final paramList = <dynamic>[];
        final processedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
          final paramName = match.group(1)!;
          final paramValue = namedParams[paramName];
          if (paramValue == null) {
            throw ArgumentError(
                "Named parameter :$paramName not provided or is null");
          }
          paramList.add(paramValue);
          return '?';
        });
        await DB.execute(processedSql, positionalParams: paramList);
      } else {
        await DB.execute(sql, positionalParams: positionalParams);
      }
    } else {
      // PostgreSQL supports named parameters natively
      await DB.execute(
        sql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );
    }
  }

  /// Update existing record using the helper method
  Future<T?> update([dynamic id, Map<String, dynamic>? data]) async {
    final currentId = this.id ?? id;
    if (currentId == null) {
      throw Exception("Cannot update: $primaryKey is null");
    }
    final updateMap = data ?? toMap();

    final updateData = Map<String, dynamic>.from(updateMap);
    updateData.remove(primaryKey);
    if (updateMap.isEmpty) {
      throw Exception("No data provided for update");
    }

    final setClause = updateMap.keys.map((k) => '$k = :$k').join(', ');
    final sql = 'UPDATE ${table.name} SET $setClause WHERE $primaryKey = :id';

    final params = {...updateMap, 'id': currentId};

    await _executeQuery(sql, namedParams: params);

    // Refresh from database
    return (await refresh(currentId));
  }

  /// Save model (create or update)
  Future<T?> save() async {
    final currentId = id;
    if (currentId == null) {
      return await create();
    } else {
      return await update();
    }
  }

  /// Delete this model
  /// Delete this model
  Future<bool> delete([
    dynamic id,
  ]) async {
    final currentId = this.id ?? id;
    if (currentId == null) return false;

    if (DB.driver == DBDriver.mysql) {
      // For MySQL, use positional parameters
      await DB.execute(
        'DELETE FROM ${table.name} WHERE $primaryKey = ?',
        positionalParams: [currentId],
      );
    } else {
      // For PostgreSQL, use named parameters
      await DB.execute(
        'DELETE FROM ${table.name} WHERE $primaryKey = :id',
        namedParams: {'id': currentId},
      );
    }

    return true;
  }

  /// Find by ID
  /// Find by ID
  Future<T?> find(dynamic id) async {
    if (DB.driver == DBDriver.mysql) {
      // Use positional parameters for MySQL
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $primaryKey = ? LIMIT 1',
        positionalParams: [id],
      );
      return result.isNotEmpty
          ? fromMap(_convertDatabaseTypes(result.first))
          : null;
    } else {
      // Use named parameters for PostgreSQL
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $primaryKey = :id LIMIT 1',
        namedParams: {'id': id},
      );
      return result.isNotEmpty
          ? fromMap(_convertDatabaseTypes(result.first))
          : null;
    }
  }

  /// Get all records
  Future<List<T>> all() async {
    final result = await DB.query('SELECT * FROM ${table.name}');
    return result.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
  }

  /// Where clause
  Future<List<T>> where(String field, dynamic value) async {
    if (DB.driver == DBDriver.mysql) {
      // For MySQL, use positional parameters
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $field = ?',
        positionalParams: [value],
      );
      return result.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
    } else {
      // For PostgreSQL, use named parameters
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $field = :value',
        namedParams: {'value': value},
      );
      return result.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
    }
  }

  /// Find records with custom conditions
  Future<List<T>> whereIn(String field, List<dynamic> values) async {
    if (values.isEmpty) return [];

    if (DB.driver == DBDriver.mysql) {
      // For MySQL, use positional parameters
      final placeholders = List.generate(values.length, (_) => '?').join(', ');
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $field IN ($placeholders)',
        positionalParams: values,
      );
      return result.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
    } else {
      // For PostgreSQL, use named parameters
      final placeholders =
          List.generate(values.length, (i) => ':value$i').join(', ');
      final params = {
        for (var i = 0; i < values.length; i++) 'value$i': values[i]
      };

      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $field IN ($placeholders)',
        namedParams: params,
      );
      return result.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
    }
  }

  /// Count all records
  Future<int> count() async {
    final result = await DB.query(
      'SELECT COUNT(*) as count FROM ${table.name}',
    );

    final count = result.first['count'];
    // Handle different database return types
    if (count is String) return int.parse(count);
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    return count as int;
  }

  /// Count records with condition
  Future<int> countWhere(String field, dynamic value) async {
    final result = await DB.query(
      'SELECT COUNT(*) as count FROM ${table.name} WHERE $field = :value',
      namedParams: {'value': value},
    );

    final count = result.first['count'];
    if (count is String) return int.parse(count);
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    return count as int;
  }

  /// Truncate table
  Future<void> truncate() async {
    if (DB.driver == DBDriver.postgres) {
      await DB.execute('TRUNCATE TABLE ${table.name} RESTART IDENTITY');
    } else {
      await DB.execute('TRUNCATE TABLE ${table.name}');
    }
  }

  /// Custom query builder
  QueryBuilder query() {
    return QueryBuilder(table: table.name);
  }

  /// Convert database-specific types to Dart types
  Map<String, dynamic> _convertDatabaseTypes(Map<dynamic, dynamic> map) {
    final converted = Map<String, dynamic>.from(map);

    converted.forEach((key, value) {
      if (value is DateTime) {
        // Already good
      } else if (value is String && _looksLikeDateTime(value)) {
        // Try to parse datetime strings
        try {
          converted[key] = DateTime.parse(value);
        } catch (e) {
          // Keep as string if parsing fails
        }
      } else if (value is BigInt) {
        converted[key] = value.toInt();
      } else if (value is String && _isNumeric(value)) {
        // Convert numeric strings to numbers
        if (value.contains('.')) {
          converted[key] = double.parse(value);
        } else {
          converted[key] = int.parse(value);
        }
      } else if (value == null) {
        converted[key] = null;
      }
    });

    return converted;
  }

  static bool _looksLikeDateTime(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
  }

  static bool _isNumeric(String value) {
    return double.tryParse(value) != null;
  }
}
