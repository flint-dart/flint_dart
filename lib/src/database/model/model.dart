// model.dart - SIMPLIFIED WORKING VERSION
import 'dart:async';
import 'dart:convert';
import 'package:flint_dart/db.dart';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/model/_model_helper.dart';
import 'package:flint_dart/src/database/relations/relation_config.dart';
import 'package:flint_dart/src/database/relations/relation_definition.dart';

abstract class Model<T extends Model<T>> {
  final Map<String, dynamic> _attributes = {};
  final T Function() _factory;
  QueryBuilder? _queryBuilder;
  DBTransaction? _trx;

  T useTransaction(DBTransaction trx) {
    _trx = trx;
    return this as T;
  }

  Model(this._factory) {
    _registerRelationLoaders();
  }

  /// Relations definition
  Map<String, RelationDefinition> get relations => {};

  /// Set multiple attributes at once
  void setAttributes(Map<String, dynamic> attrs) {
    _attributes.addAll(attrs);
  }

  /// Read raw attribute
  R? getAttribute<R>(String key) {
    final value = _attributes[key];
    if (value == null) return null;
    if (value is R) return value;
    if (R == dynamic) return value;

    final modelValue = _coerceModelValueForRequestedType<R>(value);
    if (modelValue is R) return modelValue;

    // List of typed items

    // DateTime parsing
    if (R == DateTime && value is String) {
      return DateTime.tryParse(value) as R?;
    }

    // Numeric parsing
    if (R == int && value is String) return int.tryParse(value) as R?;
    if (R == double && value is String) return double.tryParse(value) as R?;
    if (R == num && value is String) return num.tryParse(value) as R?;

    // Bool parsing
    if (R == bool && value is! bool) {
      final str = value.toString().toLowerCase();
      if (str == 'true' || str == '1') return true as R;
      if (str == 'false' || str == '0') return false as R;
    }

    // String conversion
    if (R == String) return value.toString() as R;

    return null;
  }

  /// Set raw attribute
  void setAttribute(String key, dynamic value) {
    _attributes[key] = value;
  }

  /// Primary key column
  String get primaryKey => 'id';

  /// Table schema definition
  Table get table;

  /// Concealed fields that should not appear in toMap()
  List<String> get conceal => [];

  /// Returns the safe map including concealed filter and timestamps
  Map<String, dynamic> toMap() {
    final map = Map<String, dynamic>.from(_attributes);
    for (final key in conceal) {
      map.remove(key);
    }

    return _convertDatabaseTypes(map);
  }

  String toJson() => jsonEncode(toMap());

  Map<String, dynamic> asMap() => Map.from(_attributes);

  DateTime? get createdAt => getAttribute<DateTime>('created_at');
  DateTime? get updatedAt => getAttribute<DateTime>('updated_at');
  dynamic get id => _attributes[primaryKey];

  /// Convert DB map into a model instance
  T fromMap(Map<dynamic, dynamic> map) {
    final model = _factory();
    map.forEach((key, value) {
      model.setAttribute(key.toString(), value);
    });
    return model;
  }

  T fromJson(String json) => fromMap(jsonDecode(json));

  /// Get or create query builder
  QueryBuilder get qb {
    _queryBuilder ??= QueryBuilder(table: table.name);
    return _queryBuilder!;
  }

  /// Reset query builder
  T resetQuery() {
    _queryBuilder = null;
    return this as T;
  }

  // ========== BASIC CRUD ==========

  Future<T?> find(dynamic id) async {
    final map = await qb.where(primaryKey, "=", id).first();
    if (map == null) return null;
    return fromMap(_convertDatabaseTypes(map));
  }

  Future<T?> firstWhere(String key, dynamic value) async {
    final map = await qb.where(key, "=", value).first();
    if (map == null) return null;
    return fromMap(_convertDatabaseTypes(map));
  }

  Future<List<T>> getWhere(String key, dynamic value) async {
    final results = await qb.where(key, "=", value).get();
    return results.map((map) => fromMap(_convertDatabaseTypes(map))).toList();
  }

  Future<List<T>> get() async {
    final results = await qb.get();
    final models = results
        .map((map) => fromMap(_convertDatabaseTypes(map)))
        .toList();

    // If we have requested relations, load them
    if (qb.withRelations.isNotEmpty) {
      await _loadRelationsForModels(models);
    }

    return models;
  }

  Future<T?> first() async {
    final result = await qb.first();
    if (result == null) return null;
    final model = fromMap(_convertDatabaseTypes(result));

    // If we have requested relations, load them
    if (qb.withRelations.isNotEmpty) {
      await _loadRelationsForModels([model]);
    }

    return model;
  }

  // ========== RELATION METHODS ==========

  /// Chainable withRelation
  T withRelation(String name, {List<String>? columns}) {
    qb.withRelation(name, columns: columns);
    return this as T;
  }

  /// Chainable withRelations for multiple
  T withRelations(List<String> names) {
    for (final name in names) {
      qb.withRelation(name);
    }
    return this as T;
  }

  /// Check if relation is loaded
  bool hasRelation(String name) => _attributes.containsKey(name);

  /// Get loaded relation
  R? getRelation<R>(String name) => getAttribute<R>(name);

  dynamic _coerceModelValueForRequestedType<R>(dynamic value) {
    final requestedType = R.toString();

    if (value is Model && requestedType == 'Map<String, dynamic>') {
      return value.toMap();
    }

    if (value is List && requestedType == 'List<Map<String, dynamic>>') {
      final maps = <Map<String, dynamic>>[];

      for (final item in value) {
        if (item is Model) {
          maps.add(item.toMap());
        } else if (item is Map) {
          maps.add(Map<String, dynamic>.from(item));
        } else {
          return null;
        }
      }

      return maps;
    }

    return null;
  }

  /// Load a relation for this single model
  Future<T> load(String relation, {List<String>? columns}) async {
    final loaderKey = '${runtimeType.toString()}.$relation';
    final loader = relationLoaders[loaderKey];

    if (loader == null) {
      throw Exception(
        "Relation '$relation' not found for ${runtimeType.toString()}. "
        "Available relations: ${relations.keys.join(', ')}",
      );
    }

    await loader([this as Model], RelationConfig(columns: columns));
    return this as T;
  }

  /// Load multiple relations for this single model
  Future<T> loadMany(List<String> relations) async {
    for (final relation in relations) {
      await load(relation);
    }
    return this as T;
  }

  /// Get relation or load it if not loaded
  Future<R> getRelationOrLoad<R>(String name) async {
    if (hasRelation(name)) {
      final relation = getRelation<R>(name);
      if (relation != null) return relation;
    }

    await load(name);
    final relation = getRelation<R>(name);
    if (relation == null) {
      throw Exception('Failed to load relation $name');
    }
    return relation;
  }

  /// Build a query for a relation using this model's relation definition.
  ///
  /// This is useful when you need filtered relation counts or existence checks
  /// without loading every related model.
  QueryBuilder relationQuery(
    String name, {
    void Function(QueryBuilder query)? constrain,
  }) {
    final definition = relations[name];
    if (definition == null) {
      throw Exception(
          "Relation '$name' not found for ${runtimeType.toString()}. "
          "Available relations: ${relations.keys.join(', ')}");
    }

    final query = definition.relatedFactory().resetQuery().qb;

    switch (definition.type) {
      case RelationType.belongsTo:
        final fkValue = getAttribute(definition.foreignKey);
        if (fkValue == null) {
          throw StateError(
            "Cannot query relation '$name' because "
            "'${definition.foreignKey}' is null.",
          );
        }
        query.where(definition.ownerKey, '=', fkValue);
        break;
      case RelationType.hasOne:
      case RelationType.hasMany:
        final parentId = id;
        if (parentId == null) {
          throw StateError(
            "Cannot query relation '$name' because '$primaryKey' is null.",
          );
        }
        query.where(definition.foreignKey, '=', parentId);
        break;
      case RelationType.belongsToMany:
      case RelationType.hasManyThrough:
        throw UnsupportedError(
          "Relation query for '${definition.type.name}' is not supported yet.",
        );
    }

    constrain?.call(query);
    return query;
  }

  /// Count related records without loading the relation.
  Future<int> countRelation(
    String name, {
    void Function(QueryBuilder query)? constrain,
    String column = '*',
  }) {
    return relationQuery(name, constrain: constrain).count(column);
  }

  /// Count the same relation multiple ways without repeating relation metadata.
  Future<Map<String, int>> relationCounts(
    String name,
    Map<String, void Function(QueryBuilder query)?> groups, {
    String column = '*',
  }) async {
    final counts = <String, int>{};
    for (final entry in groups.entries) {
      counts[entry.key] = await countRelation(
        name,
        constrain: entry.value,
        column: column,
      );
    }
    return counts;
  }

  /// Count related records and store the count as an attribute on this model.
  Future<T> loadRelationCount(
    String name, {
    String? as,
    void Function(QueryBuilder query)? constrain,
    String column = '*',
  }) async {
    final count = await countRelation(
      name,
      constrain: constrain,
      column: column,
    );
    setAttribute(as ?? '${name}Count', count);
    return this as T;
  }

  /// Check whether at least one related record exists.
  Future<bool> hasRelated(
    String name, {
    void Function(QueryBuilder query)? constrain,
  }) async {
    return await countRelation(name, constrain: constrain) > 0;
  }

  // ========== PRIVATE METHODS ==========

  /// Load relations for a list of models
  Future<void> _loadRelationsForModels(List<T> models) async {
    if (models.isEmpty || qb.withRelations.isEmpty) return;

    for (final relationName in qb.withRelations) {
      await _loadSingleRelation(models, relationName);
    }
  }

  /// Load a single relation for multiple models
  Future<void> _loadSingleRelation(List<T> models, String relationName) async {
    final loaderKey = '${runtimeType.toString()}.$relationName';
    final loader = relationLoaders[loaderKey];

    if (loader == null) {
      throw Exception("Relation loader not found for '$relationName'");
    }

    final columns = qb.getColumnsForRelation(relationName);
    final config = RelationConfig(columns: columns);

    await loader(models.cast<Model>().toList(), config);
  }

  /// Register relation loaders for this model
  bool _relationsRegistered = false;

  void _registerRelationLoaders() async {
    if (_relationsRegistered || relations.isEmpty) return;
    _relationsRegistered = true;

    final className = runtimeType.toString();

    for (final entry in relations.entries) {
      final relationName = entry.key;
      final definition = entry.value;
      final loaderKey = '$className.$relationName';

      if (!relationLoaders.containsKey(loaderKey)) {
        relationLoaders[loaderKey] = _createRelationLoader(definition);
      }
    }
  }

  /// Create a relation loader from definition
  FutureOr<void> Function(List<Model>, RelationConfig?) _createRelationLoader(
    RelationDefinition definition,
  ) {
    return (List<Model> parents, RelationConfig? config) async {
      if (parents.isEmpty) return;

      switch (definition.type) {
        case RelationType.belongsTo:
          await _loadBelongsTo(parents, definition, config);
          break;
        case RelationType.hasOne:
          await _loadHasOne(parents, definition, config);
          break;
        case RelationType.hasMany:
          await _loadHasMany(parents, definition, config);
          break;
        case RelationType.belongsToMany:
          await _loadBelongsToMany(parents, definition, config);
          break;
        case RelationType.hasManyThrough:
          await _loadHasManyThrough(parents, definition, config);
          break;
      }
    };
  }

  /// Load belongsTo relationship
  Future<void> _loadBelongsTo(
    List<Model> parents,
    RelationDefinition definition,
    RelationConfig? config,
  ) async {
    final relatedFactory = definition.relatedFactory;

    // Collect foreign key values
    final fkValues = <dynamic>{};
    final parentMap = <dynamic, Model>{};

    for (final parent in parents) {
      final fkValue = parent.getAttribute(definition.foreignKey);
      if (fkValue != null) {
        fkValues.add(fkValue);
        parentMap[fkValue] = parent;
      }
    }

    if (fkValues.isEmpty) return;

    // Fetch related models
    final relatedQuery = relatedFactory().resetQuery().qb;
    _applyRelationColumns(relatedQuery, config, [definition.ownerKey]);
    final relatedResults = await relatedQuery
        .whereIn(definition.ownerKey, fkValues.toList())
        .get();
    // Map related models by their owner key
    final relatedMap = <dynamic, Model>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(_convertDatabaseTypes(result));
      final key = related.getAttribute(definition.ownerKey);
      if (key != null) {
        relatedMap[key] = related;
      }
    }

    // Assign to parents
    for (final parent in parents) {
      final fkValue = parent.getAttribute(definition.foreignKey);
      if (fkValue != null && relatedMap.containsKey(fkValue)) {
        parent.setAttribute(definition.name, relatedMap[fkValue]);
      }
    }
  }

  /// Load hasOne relationship
  Future<void> _loadHasOne(
    List<Model> parents,
    RelationDefinition definition,
    RelationConfig? config,
  ) async {
    final relatedFactory = definition.relatedFactory;

    // Collect parent IDs
    final parentIds = <dynamic>{};
    final parentMap = <dynamic, Model>{};

    for (final parent in parents) {
      final parentId = parent.id;
      if (parentId != null) {
        parentIds.add(parentId);
        parentMap[parentId] = parent;
      }
    }

    if (parentIds.isEmpty) return;

    // Fetch related models
    final relatedQuery = relatedFactory().resetQuery().qb;
    _applyRelationColumns(relatedQuery, config, [definition.foreignKey]);
    final relatedResults = await relatedQuery
        .whereIn(definition.foreignKey, parentIds.toList())
        .get();

    // Map related models by foreign key
    final relatedMap = <dynamic, Model>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(_convertDatabaseTypes(result));
      final fkValue = related.getAttribute(definition.foreignKey);
      if (fkValue != null && !relatedMap.containsKey(fkValue)) {
        relatedMap[fkValue] = related;
      }
    }

    // Assign to parents
    for (final parent in parents) {
      final parentId = parent.id;
      if (parentId != null && relatedMap.containsKey(parentId)) {
        parent.setAttribute(definition.name, relatedMap[parentId]);
      }
    }
  }

  /// Load hasMany relationship
  Future<void> _loadHasMany(
    List<Model> parents,
    RelationDefinition definition,
    RelationConfig? config,
  ) async {
    final relatedFactory = definition.relatedFactory;

    // Collect parent IDs
    final parentIds = <dynamic>{};
    final parentMap = <dynamic, List<Model>>{};

    for (final parent in parents) {
      final parentId = parent.id;
      if (parentId != null) {
        parentIds.add(parentId);
        parentMap.putIfAbsent(parentId, () => []).add(parent);
      }
    }

    if (parentIds.isEmpty) {
      for (final parent in parents) {
        parent.setAttribute(definition.name, []);
      }
      return;
    }

    // Fetch related models
    final relatedQuery = relatedFactory().resetQuery().qb;
    _applyRelationColumns(relatedQuery, config, [definition.foreignKey]);
    final relatedResults = await relatedQuery
        .whereIn(definition.foreignKey, parentIds.toList())
        .get();

    // Group related models by foreign key
    final groupedMap = <dynamic, List<Model>>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(_convertDatabaseTypes(result));
      final fkValue = related.getAttribute(definition.foreignKey);
      if (fkValue != null) {
        groupedMap.putIfAbsent(fkValue, () => []).add(related);
      }
    }

    // Assign to parents
    for (final entry in parentMap.entries) {
      final parentId = entry.key;
      final relatedList = groupedMap[parentId] ?? [];
      for (final parent in entry.value) {
        parent.setAttribute(definition.name, relatedList);
      }
    }
  }

  void _applyRelationColumns(
    QueryBuilder query,
    RelationConfig? config,
    List<String> requiredColumns,
  ) {
    final columns = config?.columns;
    if (columns == null || columns.isEmpty) return;

    final selected = <String>[];
    for (final column in [...columns, ...requiredColumns]) {
      final clean = column.trim();
      if (clean.isEmpty || selected.contains(clean)) continue;
      selected.add(clean);
    }
    query.select(selected);
  }

  /// Load belongsToMany relationship
  Future<void> _loadBelongsToMany(
    List<Model> parents,
    RelationDefinition definition,
    RelationConfig? config,
  ) async {
    // Simplified - you can implement this later
    for (final parent in parents) {
      parent.setAttribute(definition.name, []);
    }
  }

  /// Load hasManyThrough relationship
  Future<void> _loadHasManyThrough(
    List<Model> parents,
    RelationDefinition definition,
    RelationConfig? config,
  ) async {
    // Simplified - you can implement this later
    for (final parent in parents) {
      parent.setAttribute(definition.name, []);
    }
  }

  // Helper to check if string looks like a DateTime
  static bool looksLikeDateTime(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
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
              print(
                "Warning: Failed to decode JSON for key '$key'. Keeping original string.",
              );
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

  /// Internal: execute query (transaction-aware)
  Future<List<Map<String, dynamic>>> runQuery(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) {
    if (_trx != null) {
      return _trx!.query(
        sql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );
    }
    return DB.query(
      sql,
      positionalParams: positionalParams,
      namedParams: namedParams,
    );
  }

  /// Internal: execute command (transaction-aware)
  Future<void> runExecute(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) {
    if (_trx != null) {
      return _trx!.execute(
        sql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );
    }
    return DB.execute(
      sql,
      positionalParams: positionalParams,
      namedParams: namedParams,
    );
  }
}
