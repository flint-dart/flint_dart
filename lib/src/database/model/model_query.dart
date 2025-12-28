// model_query.dart

import 'dart:convert';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/orm/query_builder.dart';

import 'model.dart';

extension ModelQuery<T extends Model<T>> on Model<T> {
  /// Internal query builder instance for chaining

  // ========== CHAINABLE QUERY METHODS ==========

  // static final Map<String, RelationLoader> _relationLoaders = {};

  /// Execute the query and get results - FIXED
  // Future<List<T>> get() async {
  //   final rows = await qb.get();

  //   final models =
  //       rows.map((map) => fromMap(_convertDatabaseTypes(map))).toList();

  //   // Load relations if any are specified
  //   if (qb.relations.isNotEmpty) {
  //     final modelClassName = runtimeType.toString();

  //     // Get the withRelations config from QueryBuilder
  //     // We need to access it - you might need to add a getter in QueryBuilder
  //     final relationConfigs =
  //         qb.withRelations; // Add this getter to QueryBuilder

  //     await loadRelations(models.cast<Model>(), qb.relations, modelClassName);
  //   }

  //   resetQuery();
  //   return models;
  // }

  /// Get first result - FIXED
  // Future<T?> first() async {
  //   final result = await qb.first();
  //   resetQuery();

  //   if (result == null) return null;

  //   final model = fromMap(_convertDatabaseTypes(result));

  //   // Load relations for single model
  //   if (qb.relations.isNotEmpty) {
  //     final modelClassName = runtimeType.toString();
  //     final relationConfigs = qb.withRelations;

  //     await loadRelations([model as Model], qb.relations, modelClassName);
  //   }

  //   return model;
  // }

  /// Custom query builder - starts a new chain
  QueryBuilder query() {
    return qb;
  }

  /// WHERE clause - chainable
  T where(String field, dynamic value) {
    qb.where(field, '=', value);
    return this as T;
  }

  /// WHERE with custom operator - chainable
  T whereOperator(String field, String operator, dynamic value) {
    qb.where(field, operator, value);
    return this as T;
  }

  /// WHERE IN clause - chainable
  T whereIn(String field, List<dynamic> values) {
    qb.whereIn(field, values);
    return this as T;
  }

  /// WHERE NOT IN clause - chainable
  T whereNotIn(String field, List<dynamic> values) {
    qb.whereNotIn(field, values);
    return this as T;
  }

  /// OR WHERE clause - chainable
  T orWhere(String field, dynamic value) {
    qb.orWhere(field, '=', value);
    return this as T;
  }

  /// WHERE NULL clause - chainable
  T whereNull(String field) {
    qb.whereNull(field);
    return this as T;
  }

  /// WHERE NOT NULL clause - chainable
  T whereNotNull(String field) {
    qb.whereNotNull(field);
    return this as T;
  }

  /// ORDER BY clause - chainable
  T orderBy(String field, [String direction = 'ASC']) {
    qb.orderBy(field, direction);
    return this as T;
  }

  /// LIMIT clause - chainable
  T limit(int value) {
    qb.limit(value);
    return this as T;
  }

  /// OFFSET clause - chainable
  T offset(int value) {
    qb.offset(value);
    return this as T;
  }

  /// GROUP BY clause - chainable
  T groupBy(String field) {
    qb.groupBy(field);
    return this as T;
  }

  /// SELECT specific fields - chainable
  T select(List<String> fields) {
    qb.select(fields);
    return this as T;
  }

  /// Paginate results
  Future<Map<String, dynamic>> paginate(int page, [int perPage = 15]) async {
    final result = await qb.paginate(page, perPage);
    // Convert data from maps to models
    final modelData = (result['data'] as List<Map<String, dynamic>>)
        .map((map) => fromMap(_convertDatabaseTypes(map)))
        .toList();

    resetQuery();
    return {
      'data': modelData,
      'current_page': result['current_page'],
      'per_page': result['per_page'],
      'total': result['total'],
      'last_page': result['last_page'],
    };
  }

  /// Get max value
  Future<dynamic> max(String column) async {
    final result = await qb.max(column);
    resetQuery();
    return result;
  }

  /// Get min value
  Future<dynamic> min(String column) async {
    final result = await qb.min(column);
    resetQuery();
    return result;
  }

  /// Get average value
  Future<double?> avg(String column) async {
    final result = await qb.avg(column);
    resetQuery();
    return result;
  }

  /// Get sum value
  Future<double?> sum(String column) async {
    final result = await qb.sum(column);
    resetQuery();
    return result;
  }

  T whereLike(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.whereLike(field, value, caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T whereNotLike(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.whereNotLike(field, value, caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T orWhereLike(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.orWhereLike(field, value, caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T whereBetween(String field, dynamic start, dynamic end) {
    qb.whereBetween(field, start, end);
    return this as T;
  }

  T whereNotBetween(String field, dynamic start, dynamic end) {
    qb.whereNotBetween(field, start, end);
    return this as T;
  }

  // Helper methods for contains, starts with, ends with
  T whereContains(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.whereContains(field, value,
        caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T whereStartsWith(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.whereStartsWith(field, value,
        caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T whereEndsWith(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.whereEndsWith(field, value,
        caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T orWhereContains(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.orWhereContains(field, value,
        caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T orWhereStartsWith(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.orWhereStartsWith(field, value,
        caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T orWhereEndsWith(String field, String value,
      {bool caseSensitive = false, bool escape = true}) {
    qb.orWhereEndsWith(field, value,
        caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  // ========== ORIGINAL CRUD METHODS (Preserved) ==========

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
          if (value is String && _looksLikeDateTime(value)) {
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
          _looksLikeDateTime(value)) {
        converted[key] = DateTime.parse(value);
      }
    }
    return converted;
  }

  static bool _looksLikeDateTime(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
  }
}
