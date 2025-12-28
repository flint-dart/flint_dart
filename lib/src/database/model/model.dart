// model.dart - SIMPLIFIED WORKING VERSION
import 'dart:async';
import 'dart:convert';
import 'package:flint_dart/db.dart';
import 'package:flint_dart/schema.dart';
import 'package:flint_dart/src/database/model/_model_helper.dart';
import 'package:flint_dart/src/database/relations/relation_config.dart';
import 'package:flint_dart/src/database/relations/relation_definition.dart';
import "package:flint_dart/src/database/model/model_query.dart";

abstract class Model<T extends Model<T>> {
  final Map<String, dynamic> _attributes = {};
  final T Function() _factory;
  QueryBuilder? _queryBuilder;

  Model(this._factory) {
    _registerRelationLoaders();
  }

  /// Relations definition
  Map<String, RelationDefinition> get relations => {};

  /// Read raw attribute
  R? getAttribute<R>(String key) {
    final value = _attributes[key];
    if (value == null) return null;
    if (value is R) return value;
    if (R == dynamic) return value;

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
    return map;
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
    return fromMap(map);
  }

  Future<T?> firstWhere(String key, dynamic value) async {
    final map = await qb.where(key, "=", value).first();
    if (map == null) return null;
    return fromMap(map);
  }

  Future<List<T>> getWhere(String key, dynamic value) async {
    final results = await qb.where(key, "=", value).get();
    return results.map((map) => fromMap(map)).toList();
  }

  Future<List<T>> all() async {
    final results = await qb.get();
    return results.map((map) => fromMap(map)).toList();
  }

  Future<List<T>> get() async {
    final results = await qb.get();
    final models = results.map((map) => fromMap(map)).toList();

    // If we have requested relations, load them
    if (qb.withRelations.isNotEmpty) {
      await _loadRelationsForModels(models);
    }

    return models;
  }

  Future<T?> first() async {
    final result = await qb.first();
    if (result == null) return null;
    final model = fromMap(result);

    // If we have requested relations, load them
    if (qb.withRelations.isNotEmpty) {
      await _loadRelationsForModels([model]);
    }

    return model;
  }

  Future<void> delete() async {
    if (id == null) return;
    await qb.where(primaryKey, "=", id).delete();
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

  /// Load a relation for this single model
  Future<T> load(String relation, {List<String>? columns}) async {
    final loaderKey = '${runtimeType.toString()}.$relation';
    final loader = relationLoaders[loaderKey];

    if (loader == null) {
      throw Exception(
          "Relation '$relation' not found for ${runtimeType.toString()}. "
          "Available relations: ${relations.keys.join(', ')}");
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
        relationLoaders[loaderKey] = await _createRelationLoader(definition);
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
    final relatedResults = await relatedFactory()
        .resetQuery()
        .qb
        .whereIn(definition.ownerKey, fkValues.toList())
        .get();

    // Map related models by their owner key
    final relatedMap = <dynamic, Model>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(result);
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
    final relatedResults = await relatedFactory()
        .resetQuery()
        .qb
        .whereIn(definition.foreignKey, parentIds.toList())
        .get();

    // Map related models by foreign key
    final relatedMap = <dynamic, Model>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(result);
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
    final relatedResults = await relatedFactory()
        .resetQuery()
        .qb
        .whereIn(definition.foreignKey, parentIds.toList())
        .get();

    // Group related models by foreign key
    final groupedMap = <dynamic, List<Model>>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(result);
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
}
