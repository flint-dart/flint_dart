// model_crud.dart

import 'dart:convert';

import 'package:flint_dart/helper.dart';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/db.dart';
import 'package:flint_dart/src/database/model/_model_helper.dart';

import 'model.dart';

extension ModelCrud<T extends Model<T>> on Model<T> {
  // ========== ORIGINAL CRUD METHODS (Preserved) ==========

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
    final insertMap = data ?? asMap();

    final idColumn = table.columns.firstWhere((c) => c.isPrimaryKey,
        orElse: () => Column(
              name: 'id',
              type: ColumnType.string,
              isPrimaryKey: true,
              isAutoIncrement: false,
            ));

    // --- ✅ Auto-generate UUID for string-based primary keys ---
    if (!idColumn.isAutoIncrement &&
        idColumn.type == ColumnType.string &&
        (insertMap[idColumn.name] == null ||
            insertMap[idColumn.name].toString().isEmpty)) {
      // Use Dart-generated UUID
      insertMap[idColumn.name] = Str.uuid();
    }

    // --- Remove auto-increment id from insert map ---
    if (idColumn.isAutoIncrement) {
      insertMap.remove(idColumn.name);
    }

    insertMap.removeWhere((key, data) => data == null);

    if (insertMap.isEmpty) {
      throw Exception("No data provided for creation");
    }

    // --- ✅ Convert bool → 1/0 for MySQL ---
    insertMap.updateAll((key, value) {
      final column = table.columns.firstWhere(
        (c) => c.name == key,
        orElse: () => Column(name: key, type: ColumnType.string),
      );
      if (value is bool) {
        return value ? 1 : 0;
      }
      if (column.type == ColumnType.json && value != null) {
        return jsonEncode(value);
      }
      if (value is Enum) return value = value.name; // enum → string
      return value;
    });
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

      if (idColumn.isAutoIncrement) {
        // Fetch using last inserted ID
        final lastId = await DB.getLastInsertId(table.name, idColumn.name);
        final result = await DB.query(
          'SELECT * FROM ${table.name} WHERE ${idColumn.name} = ?',
          positionalParams: [lastId],
        );
        return fromMap(_convertDatabaseTypes(result.first));
      } else {
        // Fetch using UUID we just inserted
        final insertedId = insertMap[idColumn.name];
        final result = await DB.query(
          'SELECT * FROM ${table.name} WHERE ${idColumn.name} = ?',
          positionalParams: [insertedId],
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
    bool isUpdate = (data == null || data.isEmpty);
    final updateMap = isUpdate ? asMap() : data;
    final updateData = Map<String, dynamic>.from(updateMap)
      ..remove(primaryKey)
      ..removeWhere((k, v) => k.trim().isEmpty)
      ..removeWhere((k, v) => v == null);

    if (updateData.isEmpty) {
      throw Exception("No data provided for update");
    }
    // --- ✅ Convert bool → 1/0 for MySQL ---
    if (DB.driver == DBDriver.mysql) {
      updateData.updateAll((key, value) {
        final column = table.columns.firstWhere(
          (c) => c.name == key,
          orElse: () => Column(name: key, type: ColumnType.string),
        );

        if (value == null) return null;

        if (column.type == ColumnType.json) return jsonEncode(value);
        if (value is bool) return value ? 1 : 0;
        if (value is Enum) return value.name; // enum → string
        if (value is DateTime) {
          return value.toIso8601String(); // <-- convert DateTime
        }
        return value;
      });
    }

    // Use backticks for column names to handle reserved words
    final setClause = updateData.keys.map((k) => '`$k` = :$k').join(', ');

    final sql =
        'UPDATE `${table.name}` SET $setClause WHERE `$primaryKey` = :id';
    final params = {...updateData, 'id': currentId};

    await _executeQuery(sql, namedParams: params);

    return await refresh(currentId);
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
  Future<bool> delete([dynamic id]) async {
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

  /// Simple where clause (non-chainable)
  Future<List<T>> whereSimple(String field, dynamic value) async {
    // --- ✅ Convert bool → 1/0 for MySQL ---
    if (DB.driver == DBDriver.mysql) {
      if (value is bool) value = value ? 1 : 0; // bool → 1/0
      if (value is Enum) value = value.name; // enum → string
    }

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

  /// Simple where IN clause (non-chainable)
  Future<List<T>> whereInSimple(String field, List<dynamic> values) async {
    if (values.isEmpty) return [];

    // --- ✅ Normalize values for MySQL ---
    if (DB.driver == DBDriver.mysql) {
      values = values.map((v) {
        if (v is bool) return v ? 1 : 0; // MySQL stores bool as tinyint
        if (v is Enum) return v.name; // Store enum as string name
        return v;
      }).toList();
    }

    if (DB.driver == DBDriver.mysql) {
      // --- MySQL: use positional parameters ---
      final placeholders = List.generate(values.length, (_) => '?').join(', ');
      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $field IN ($placeholders)',
        positionalParams: values,
      );
      return result.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
    } else {
      // --- PostgreSQL: use named parameters ---
      final placeholders =
          List.generate(values.length, (i) => ':value$i').join(', ');
      final params = {
        for (var i = 0; i < values.length; i++)
          'value$i': values[i] is Enum ? values[i].name : values[i],
      };

      final result = await DB.query(
        'SELECT * FROM ${table.name} WHERE $field IN ($placeholders)',
        namedParams: params,
      );
      return result.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
    }
  }

  /// Count all records
  Future<int> countAll() async {
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
    // --- ✅ Normalize value for MySQL ---
    if (DB.driver == DBDriver.mysql) {
      if (value is bool) value = value ? 1 : 0; // bool → 1/0
      if (value is Enum) value = value.name; // enum → string
    }

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

  /// Convert database-specific types to Dart types
  /// Convert database-specific types to Dart types safely,
  /// respecting the model's schema definition.
  Map<String, dynamic> _convertDatabaseTypes(Map<dynamic, dynamic> map) {
    final converted = Map<String, dynamic>.from(map);

    for (final column in table.columns) {
      final key = column.name;
      if (!converted.containsKey(key)) continue;

      final value = converted[key];
      if (value == null) continue;

      switch (column.type) {
        case ColumnType.integer:
          if (value is String && int.tryParse(value) != null) {
            converted[key] = int.parse(value);
          } else if (value is BigInt) {
            converted[key] = value.toInt();
          }
          break;

        case ColumnType.double:
          if (value is String && double.tryParse(value) != null) {
            converted[key] = double.parse(value);
          }
          break;

        case ColumnType.boolean:
          if (value is bool) {
            converted[key] = value;
          } else if (value is num) {
            converted[key] = value == 1;
          } else if (value is String) {
            final v = value.toLowerCase();
            converted[key] = (v == 'true' || v == '1' || v == 'yes');
          } else {
            converted[key] = false;
          }
          break;

        case ColumnType.datetime:
        case ColumnType.timestamp:
          if (value is String && looksLikeDateTime(value)) {
            try {
              converted[key] = DateTime.parse(value);
            } catch (_) {}
          }
          break;

        case ColumnType.string:
        case ColumnType.text:
          // 🔥 Handle both normal string and byte array text
          if (value is String) {
            converted[key] = value;
          } else if (value is List<int>) {
            try {
              converted[key] = utf8.decode(value);
            } catch (_) {
              // fallback if UTF8 fails
              converted[key] = String.fromCharCodes(value);
            }
          } else {
            converted[key] = value.toString();
          }
          break;

        case ColumnType.enumeration:
          // Enums are stored as strings in SQL
          if (value is String) {
            converted[key] = value;
          } else if (value is List<int>) {
            try {
              converted[key] = utf8.decode(value);
            } catch (_) {
              converted[key] = String.fromCharCodes(value);
            }
          } else {
            converted[key] = value.toString();
          }
          break;

        case ColumnType.json:
          if (value is String) {
            try {
              converted[key] = jsonDecode(value);
            } catch (_) {
              converted[key] = value;
            }
          } else if (value is List<int>) {
            try {
              final decoded = utf8.decode(value);
              converted[key] = jsonDecode(decoded);
            } catch (_) {
              // fallback to string if not valid json
              converted[key] = String.fromCharCodes(value);
            }
          }
          break;
      }
    }

    // --- 🔥 GLOBAL TIMESTAMP SAFETY (created_at, updated_at) ---
    for (final entry in converted.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String &&
          (key == 'created_at' || key == 'updated_at') &&
          looksLikeDateTime(value)) {
        converted[key] = DateTime.parse(value);
      }
    }
    return converted;
  }
}
