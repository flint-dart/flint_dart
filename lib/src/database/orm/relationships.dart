// flint_relationships.dart
// Production-ready relationships for Flint Dart
// - Uses factory constructors for AOT safety (no reflection)
// - Provides: belongsTo, hasOne, hasMany, belongsToMany, hasManyThrough
// - Optional lightweight caching (off by default)
// - Safe parameter usage for values; pivot/table names must be valid identifiers

import 'dart:async';
import 'dart:convert';

import 'package:flint_dart/db.dart';
import 'package:flint_dart/model.dart';

/// NOTE / ASSUMPTIONS
/// - `Model` must expose:
///   - `dynamic getField(String name)` -> fetch field value by column/key
///   - `QueryBuilder query()` -> returns a query builder for the model
///   - `dynamic id` -> model primary identifier (used for caching keys)
/// - `QueryBuilder` is expected to implement fluent methods:
///   - `where(field, op, value)`, `whereIn(field, List)`, `first()`, `get()`, `withRelations(List<String>)`
/// - This file intentionally avoids runtime reflection and `Type` constructors.

// final _logger = developer.log;

String _toSnakeCase(String input) {
  // Simple snake_case converter for typical PascalCase or camelCase input
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i > 0) buffer.write('_');
    buffer.write(char.toLowerCase());
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
}

String _encodeParams(Map<String, dynamic>? params) {
  if (params == null || params.isEmpty) return '';
  try {
    return base64Url.encode(utf8.encode(jsonEncode(params)));
  } catch (e) {
    return params.toString();
  }
}

String _buildCacheKey({
  required String modelType,
  required Object? modelId,
  required String relationship,
  required String relatedType,
  String? extra,
}) {
  final idPart = modelId?.toString() ?? 'no-id';
  final extras = extra == null || extra.isEmpty ? '' : '_$extra';
  return '${modelType}_${idPart}_${relationship}_$relatedType$extras';
}

/// Lightweight in-memory cache used only if callers set useCache = true.
class _RelationshipCache {
  final Map<String, _CacheEntry> _cache = {};
  final Duration ttl;

  _RelationshipCache({this.ttl = const Duration(minutes: 5)});

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void set<T>(String key, T value) {
    _cache[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  void clear(String key) => _cache.remove(key);
  void clearAll() => _cache.clear();
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
}

final _relationshipCache = _RelationshipCache();

/// Relationships extension using factory constructors for each related model.
/// Usage examples (in model classes):
/// Defines a one-to-one inverse relationship between models.
///
/// This method establishes a "belongs to" relationship, indicating that the current model
/// belongs to a single instance of the related model specified by [relatedFactory].
///
/// **Example:**
/// ```dart
/// class Post extends Model {
///   Future<User?> user() => belongsTo(() => User(), localKey: 'user_id');
/// }
/// ```
///
/// **Parameters:**
/// - [relatedFactory]: A factory function that returns an instance of the related model.
/// - [localKey]: The local key on the current model used to establish the relationship.
///   If not specified, defaults to the foreign key convention.
/// - [foreignKey]: The foreign key on the related model. Defaults to `'id'`.
/// - [useCache]: Whether to cache the relationship result. Defaults to `false`.
///
/// **Returns:**
/// A [Future] that resolves to a single instance of the related model, or `null` if no
/// related model exists.
///
/// **See also:**
/// - [hasMany] for one-to-many relationships
/// - [belongsToMany] for many-to-many relationships
///   Future&gt;List&gt;Post>> posts() => hasMany(() => Post());
///   Future&lt;List&gt;Role&gt;&gt; roles() => belongsToMany(() => Role(), pivotTable: 'role_user');
extension ModelRelationships on Model {
  // ------------- BELONGS TO -------------
  Future<R?> belongsTo<R>(
    Model Function() relatedFactory, {
    String? localKey,
    String foreignKey = 'id',
    bool useCache = false,
    Map<String, dynamic>? extraCacheParams,
  }) async {
    final related = relatedFactory();
    // default localKey: relatedModel snake_case + '_id'
    final defaultLocal = '${_toSnakeCase(related.runtimeType.toString())}_id';
    final lKey = localKey ?? defaultLocal;

    final localValue = getField(lKey);
    if (localValue == null) return null;

    final cacheKey = useCache
        ? _buildCacheKey(
            modelType: runtimeType.toString(),
            modelId: id,
            relationship: 'belongsTo',
            relatedType: related.runtimeType.toString(),
            extra: _encodeParams(extraCacheParams),
          )
        : '';

    if (useCache) {
      final cached = _relationshipCache.get<R?>(cacheKey);
      if (cached != null) return cached;
    }

    final query = related.query().where(foreignKey, '=', localValue);
    final result = await query.first();

    if (useCache) _relationshipCache.set<R?>(cacheKey, result as R?);

    return result as R?;
  }

  // ------------- HAS MANY -------------
  Future<List<R>> hasMany<R>(
    Model Function() relatedFactory, {
    String? foreignKey,
    String localKey = 'id',
    bool useCache = false,
    List<String>? eagerLoad,
    Map<String, dynamic>? extraCacheParams,
    Map<String, dynamic>? additionalConditions,
  }) async {
    final related = relatedFactory();
    final defaultFk = '${_toSnakeCase(runtimeType.toString())}_id';
    final fKey = foreignKey ?? defaultFk;

    // gather params for cache key
    final cacheExtra = _encodeParams({
      'fk': fKey,
      'eager': eagerLoad,
      'conds': additionalConditions,
      ...?extraCacheParams,
    });

    final cacheKey = useCache
        ? _buildCacheKey(
            modelType: runtimeType.toString(),
            modelId: id,
            relationship: 'hasMany',
            relatedType: related.runtimeType.toString(),
            extra: cacheExtra,
          )
        : '';

    if (useCache) {
      final cached = _relationshipCache.get<List<R>>(cacheKey);
      if (cached != null) return cached;
    }

    final localValue = getField(localKey);
    if (localValue == null) return <R>[];

    var query = related.query().where(fKey, '=', localValue);

    if (additionalConditions != null) {
      additionalConditions.forEach((field, value) {
        if (value is List) {
          query = query.whereIn(field, value);
        } else {
          query = query.where(field, '=', value);
        }
      });
    }

    if (eagerLoad != null && eagerLoad.isNotEmpty) {
      query = query.withRelations(eagerLoad);
    }

    final results = await query.get();

    if (useCache) _relationshipCache.set<List<R>>(cacheKey, results.cast<R>());

    return (results as List).cast<R>();
  }

  // ------------- HAS ONE -------------
  Future<R?> hasOne<R>(
    Model Function() relatedFactory, {
    String? foreignKey,
    String localKey = 'id',
    bool useCache = false,
    Map<String, dynamic>? extraCacheParams,
  }) async {
    final related = relatedFactory();
    final defaultFk = '${_toSnakeCase(runtimeType.toString())}_id';
    final fKey = foreignKey ?? defaultFk;

    final cacheKey = useCache
        ? _buildCacheKey(
            modelType: runtimeType.toString(),
            modelId: id,
            relationship: 'hasOne',
            relatedType: related.runtimeType.toString(),
            extra: _encodeParams(extraCacheParams),
          )
        : '';

    if (useCache) {
      final cached = _relationshipCache.get<R?>(cacheKey);
      if (cached != null) return cached;
    }

    final localValue = getField(localKey);
    if (localValue == null) return null;

    final query = related.query().where(fKey, '=', localValue);
    final result = await query.first();

    if (useCache) _relationshipCache.set<R?>(cacheKey, result as R?);

    return result as R?;
  }

  // ------------- BELONGS TO MANY -------------
  /// IMPORTANT: pivotTable should be a valid table identifier (no user input).
  /// foreignPivotKey defaults to <parent>_id, relatedPivotKey defaults to <related>_id
  Future<List<R>> belongsToMany<R>(
    Model Function() relatedFactory, {
    required String pivotTable,
    String? foreignPivotKey,
    String? relatedPivotKey,
    String localKey = 'id',
    String relatedKey = 'id',
    bool useCache = false,
    List<String>? eagerLoad,
    Map<String, dynamic>? pivotConditions,
    Map<String, dynamic>? extraCacheParams,
  }) async {
    final related = relatedFactory();

    final defaultFPk = '${_toSnakeCase(runtimeType.toString())}_id';
    final defaultRPk = '${_toSnakeCase(related.runtimeType.toString())}_id';

    final fPivotKey = foreignPivotKey ?? defaultFPk;
    final rPivotKey = relatedPivotKey ?? defaultRPk;

    final cacheExtra = _encodeParams({
      'pivot': pivotTable,
      'fpk': fPivotKey,
      'rpk': rPivotKey,
      ...?extraCacheParams,
      ...?pivotConditions,
    });

    final cacheKey = useCache
        ? _buildCacheKey(
            modelType: runtimeType.toString(),
            modelId: id,
            relationship: 'belongsToMany',
            relatedType: related.runtimeType.toString(),
            extra: cacheExtra,
          )
        : '';

    if (useCache) {
      final cached = _relationshipCache.get<List<R>>(cacheKey);
      if (cached != null) return cached;
    }

    final localValue = getField(localKey);
    if (localValue == null) return <R>[];

    // Build pivot SQL safely for values. Table/column names are inserted raw and must be valid.
    final buffer = StringBuffer();
    buffer.write(
        'SELECT $rPivotKey FROM $pivotTable WHERE $fPivotKey = :localValue');

    final params = <String, dynamic>{'localValue': localValue};
    if (pivotConditions != null && pivotConditions.isNotEmpty) {
      pivotConditions.forEach((k, v) {
        buffer.write(' AND $k = :$k');
        params[k] = v;
      });
    }

    final pivotQuery = buffer.toString();

    final pivotResults = await DB.query(pivotQuery, namedParams: params);
    if (pivotResults.isEmpty) return <R>[];

    final relatedIds = pivotResults.map((r) => r[rPivotKey]).toList();

    var query = related.query().whereIn(relatedKey, relatedIds);
    if (eagerLoad != null && eagerLoad.isNotEmpty) {
      query = query.withRelations(eagerLoad);
    }

    final results = await query.get();

    if (useCache) _relationshipCache.set<List<R>>(cacheKey, results.cast<R>());

    return (results as List).cast<R>();
  }

  // ------------- HAS MANY THROUGH -------------
  /// Example: Country hasMany Posts through Users
  /// throughFactory builds the "through" model (e.g. () => User())
  Future<List<R>> hasManyThrough<T, R>(
    Model Function() throughFactory,
    Model Function() relatedFactory, {
    String?
        firstKey, // foreign key on through model referencing parent (e.g. country_id)
    String?
        secondKey, // foreign key on related model referencing through (e.g. user_id on posts)
    String localKey = 'id',
    String relatedKey = 'id',
    bool useCache = false,
  }) async {
    final through = throughFactory();
    final related = relatedFactory();

    final defaultFirst =
        firstKey ?? '${_toSnakeCase(runtimeType.toString())}_id';
    final defaultSecond =
        secondKey ?? '${_toSnakeCase(through.runtimeType.toString())}_id';

    final cacheExtra =
        _encodeParams({'first': defaultFirst, 'second': defaultSecond});
    final cacheKey = useCache
        ? _buildCacheKey(
            modelType: runtimeType.toString(),
            modelId: id,
            relationship: 'hasManyThrough',
            relatedType: related.runtimeType.toString(),
            extra: cacheExtra,
          )
        : '';

    if (useCache) {
      final cached = _relationshipCache.get<List<R>>(cacheKey);
      if (cached != null) return cached;
    }

    final localValue = getField(localKey);
    if (localValue == null) return <R>[];

    // 1) Load through IDs where through.firstKey = localValue
    final throughQuery = through.query().where(defaultFirst, '=', localValue);
    final throughRows = await throughQuery.get();
    if (throughRows.isEmpty) return <R>[];

    final throughIds = throughRows.map((r) => r['id']).toList();

    // 2) Load related where related.secondKey IN (throughIds)
    final query = related.query().whereIn(defaultSecond, throughIds);
    final results = await query.get();

    if (useCache) _relationshipCache.set<List<R>>(cacheKey, results.cast<R>());

    return (results as List).cast<R>();
  }

  // ------------- CACHE HELPERS -------------
  void clearRelationshipCacheFor(String relationshipKey) =>
      _relationshipCache.clear(relationshipKey);
  void clearAllRelationshipCache() => _relationshipCache.clearAll();

  /// Preload relationships for N models using a loader function to avoid N+1 queries.
  /// Example: await Model.preload(models, (m) => m.posts());
  static Future<void> preload<T, R>(
    List<T> models,
    Future<List<R>> Function(T model) loader,
  ) async {
    if (models.isEmpty) return;
    // execute all loaders concurrently
    await Future.wait(models.map((m) => loader(m)));
  }
}
