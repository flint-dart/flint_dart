// model.dart - SIMPLIFIED WORKING VERSION
import 'dart:async';
import 'dart:convert';
import 'package:flint_dart/db.dart';
import 'package:flint_dart/helper.dart';
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
    // A QueryBuilder captures its executor at construction time. Reset it so
    // a model that enters a transaction cannot retain the global DB executor.
    _queryBuilder = null;
    return this as T;
  }

  Model(this._factory) {
    _registerRelationLoaders();
    _initSchema();
  }

  /// Creates a fresh instance of this model's concrete type.
  ///
  /// Integration packages can use this for metadata registration without
  /// retaining or reusing a stateful model instance.
  T newInstance() => _factory();

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

  /// Reads a strongly-typed attribute using a compile-time [ColumnField] descriptor.
  R? getField<R>(ColumnField<dynamic> field) {
    final value = getAttribute<R>(field.name);
    if (value != null) return value;
    final defaultVal = field.defaultValue;
    if (defaultVal is R) return defaultVal;
    return null;
  }

  /// Sets a strongly-typed attribute using a compile-time [ColumnField] descriptor.
  void setField<R>(ColumnField<dynamic> field, R? value) {
    setAttribute(field.name, value);
  }

  final List<Column> _schemaColumns = [];

  /// Override this method to fluently define the model's database schema.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// String get tableName => 'blog_posts';
  ///
  /// @override
  /// void schema() {
  ///   string('title', length: 255);
  ///   string('slug', isUnique: true);
  ///   text('content');
  ///   json('tagIds', isNullable: true);
  ///   string('status', defaultValue: 'draft');
  /// }
  /// ```
  void schema() {}

  void _initSchema() {
    schema();
  }

  /// Appends a raw or custom [Column] definition to the model's schema.
  Column column(Column col) {
    _schemaColumns.add(col);
    return col;
  }

  /// Adds a string column (e.g. VARCHAR) to the model's schema.
  Column string(
    String name, {
    int length = 255,
    bool isNullable = false,
    bool isUnique = false,
    String? defaultValue,
    bool isPrimaryKey = false,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.string,
      length: length,
      isNullable: isNullable,
      isUnique: isUnique,
      defaultValue: defaultValue,
      isPrimaryKey: isPrimaryKey,
      comment: comment,
      after: after,
    ));
  }

  /// Adds a text column (e.g. TEXT) to the model's schema.
  Column text(
    String name, {
    bool isNullable = false,
    String? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.text,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Alias for [text] to avoid naming collisions when UI packages are imported.
  Column textCol(
    String name, {
    bool isNullable = false,
    String? defaultValue,
    String? comment,
    String? after,
  }) =>
      text(name, isNullable: isNullable, defaultValue: defaultValue, comment: comment, after: after);

  /// Adds a medium text column (e.g. MEDIUMTEXT) to the model's schema.
  Column mediumText(
    String name, {
    bool isNullable = false,
    String? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.mediumText,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Adds a long text column (e.g. LONGTEXT) to the model's schema.
  Column longText(
    String name, {
    bool isNullable = false,
    String? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.longText,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Adds an integer column (e.g. INT) to the model's schema.
  Column integer(
    String name, {
    bool isNullable = false,
    bool isUnique = false,
    int? defaultValue,
    bool isPrimaryKey = false,
    bool isAutoIncrement = false,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.integer,
      isNullable: isNullable,
      isUnique: isUnique,
      defaultValue: defaultValue,
      isPrimaryKey: isPrimaryKey,
      isAutoIncrement: isAutoIncrement,
      comment: comment,
      after: after,
    ));
  }

  /// Adds a boolean column (e.g. BOOLEAN / TINYINT(1)) to the model's schema.
  Column boolean(
    String name, {
    bool isNullable = false,
    bool? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.boolean,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Adds a double/float column to the model's schema.
  Column float(
    String name, {
    bool isNullable = false,
    double? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.double,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Adds a datetime column to the model's schema.
  Column datetime(
    String name, {
    bool isNullable = false,
    DateTime? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.datetime,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Adds a timestamp column to the model's schema.
  Column timestamp(
    String name, {
    bool isNullable = false,
    DateTime? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.timestamp,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Adds a JSON column to the model's schema.
  Column json(
    String name, {
    bool isNullable = false,
    dynamic defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.json,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Adds an enumeration column to the model's schema.
  Column enumeration(
    String name, {
    required List<String> options,
    bool isNullable = false,
    String? defaultValue,
    String? comment,
    String? after,
  }) {
    return column(Column(
      name: name,
      type: ColumnType.enumeration,
      options: options,
      isNullable: isNullable,
      defaultValue: defaultValue,
      comment: comment,
      after: after,
    ));
  }

  /// Primary key column. Defaults to the column with `isPrimaryKey: true` in
  /// `_schemaColumns` or `fields`, or `'id'` if not specified.
  String get primaryKey {
    for (final col in _schemaColumns) {
      if (col.isPrimaryKey) return col.name;
    }
    for (final f in fields) {
      if (f.isPrimaryKey) return f.name;
    }
    return 'id';
  }

  /// Optional table name for this model.
  ///
  /// When provided alongside [schema] or [fields], [table] is automatically constructed
  /// without needing to instantiate [Table] manually.
  String get tableName => '';

  /// Optional list of [ColumnField] descriptors. When provided alongside [tableName],
  /// [table] is automatically constructed without needing to instantiate [Table] manually.
  List<ColumnField<dynamic>> get fields => const [];

  /// Table schema definition.
  ///
  /// Subclasses can either override [table] directly, implement [schema], or provide
  /// [tableName] and [fields] to have [table] automatically constructed for them.
  Table get table {
    if (_schemaColumns.isNotEmpty && tableName.isNotEmpty) {
      return Table(
        name: tableName,
        columns: List<Column>.from(_schemaColumns),
      );
    }
    if (tableName.isNotEmpty) {
      if (fields.isNotEmpty) {
        return Table.fromFields(name: tableName, fields: fields);
      }
      return Table(name: tableName, columns: const []);
    }
    throw UnimplementedError(
      'Model $runtimeType must either override `Table get table`, implement `void schema()`, or provide `String get tableName` and `List<ColumnField> get fields`.',
    );
  }

  /// Concealed fields that should not appear in toMap()
  List<String> get conceal => [];

  /// Returns the safe map including concealed filter and timestamps
  Map<String, dynamic> toMap() {
    final map = Map<String, dynamic>.from(_attributes);
    for (final key in conceal) {
      map.remove(key);
    }

    return convertDatabaseTypes(map);
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
      final attributeKey = key.toString();
      model.setAttribute(
        attributeKey,
        _hydrateRelationValue(attributeKey, value),
      );
    });
    return model;
  }

  T fromJson(String json) => fromMap(jsonDecode(json));

  dynamic _hydrateRelationValue(String key, dynamic value) {
    final definition = relations[key];
    if (definition == null || value == null) return value;

    if (value is Map) {
      return definition.relatedFactory().fromMap(
            Map<dynamic, dynamic>.from(value),
          );
    }

    if (value is List) {
      return value.map((item) {
        if (item is Map) {
          return definition.relatedFactory().fromMap(
                Map<dynamic, dynamic>.from(item),
              );
        }
        return item;
      }).toList();
    }

    return value;
  }

  /// Get or create query builder
  QueryBuilder get qb {
    _queryBuilder ??= QueryBuilder(
      table: table.name,
      executor: _trx,
    );
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
    resetQuery();
    if (map == null) return null;
    return fromMap(convertDatabaseTypes(map));
  }

  Future<T?> firstWhere(String key, dynamic value) async {
    final map = await qb.where(key, "=", value).first();
    resetQuery();
    if (map == null) return null;
    return fromMap(convertDatabaseTypes(map));
  }

  Future<List<T>> getWhere(String key, dynamic value) async {
    final results = await qb.where(key, "=", value).get();
    resetQuery();
    return results.map((map) => fromMap(convertDatabaseTypes(map))).toList();
  }

  Future<List<T>> get() async {
    final results = await qb.get();
    final models =
        results.map((map) => fromMap(convertDatabaseTypes(map))).toList();

    // If we have requested relations, load them
    if (qb.withRelations.isNotEmpty) {
      await _loadRelationsForModels(models);
    }

    resetQuery();
    return models;
  }

  Future<T?> first() async {
    final result = await qb.first();
    if (result == null) {
      resetQuery();
      return null;
    }
    final model = fromMap(convertDatabaseTypes(result));

    // If we have requested relations, load them
    if (qb.withRelations.isNotEmpty) {
      await _loadRelationsForModels([model]);
    }

    resetQuery();
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
        "Available relations: ${relations.keys.join(', ')}",
      );
    }

    final relatedModel = definition.relatedFactory();
    if (_trx != null) relatedModel.useTransaction(_trx!);
    final query = relatedModel.resetQuery().qb;

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
    final relatedModel = relatedFactory();
    if (_trx != null) relatedModel.useTransaction(_trx!);
    final relatedQuery = relatedModel.resetQuery().qb;
    _applyRelationColumns(relatedQuery, config, [definition.ownerKey]);
    final relatedResults = await relatedQuery
        .whereIn(definition.ownerKey, fkValues.toList())
        .get();
    // Map related models by their owner key
    final relatedMap = <dynamic, Model>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(convertDatabaseTypes(result));
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
    final relatedModel = relatedFactory();
    if (_trx != null) relatedModel.useTransaction(_trx!);
    final relatedQuery = relatedModel.resetQuery().qb;
    _applyRelationColumns(relatedQuery, config, [definition.foreignKey]);
    final relatedResults = await relatedQuery
        .whereIn(definition.foreignKey, parentIds.toList())
        .get();

    // Map related models by foreign key
    final relatedMap = <dynamic, Model>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(convertDatabaseTypes(result));
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
    final relatedModel = relatedFactory();
    if (_trx != null) relatedModel.useTransaction(_trx!);
    final relatedQuery = relatedModel.resetQuery().qb;
    _applyRelationColumns(relatedQuery, config, [definition.foreignKey]);
    final relatedResults = await relatedQuery
        .whereIn(definition.foreignKey, parentIds.toList())
        .get();

    // Group related models by foreign key
    final groupedMap = <dynamic, List<Model>>{};
    for (final result in relatedResults) {
      final related = relatedFactory().fromMap(convertDatabaseTypes(result));
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

  // ========== DIRECT CHAINABLE QUERY METHODS ==========

  /// Custom query builder - starts or continues a query chain.
  QueryBuilder query() => qb;

  /// WHERE clause (`field = value`) - chainable.
  T where(String field, dynamic value) {
    qb.where(field, '=', value);
    return this as T;
  }

  /// Strongly-typed WHERE clause using a compile-time [ColumnField].
  T whereField<V>(ColumnField<V> field, V value, [String operator = '=']) {
    qb.where(field.name, operator, value);
    return this as T;
  }

  /// WHERE with custom operator - chainable.
  T whereOperator(String field, String operator, dynamic value) {
    qb.where(field, operator, value);
    return this as T;
  }

  /// WHERE IN clause - chainable.
  T whereIn(String field, List<dynamic> values) {
    qb.whereIn(field, values);
    return this as T;
  }

  /// Strongly-typed WHERE IN clause using a compile-time [ColumnField].
  T whereInField<V>(ColumnField<V> field, List<V> values) {
    qb.whereIn(field.name, values);
    return this as T;
  }

  /// WHERE NOT IN clause - chainable.
  T whereNotIn(String field, List<dynamic> values) {
    qb.whereNotIn(field, values);
    return this as T;
  }

  /// OR WHERE clause - chainable.
  T orWhere(String field, dynamic value) {
    qb.orWhere(field, '=', value);
    return this as T;
  }

  /// OR WHERE with custom operator - chainable.
  T orWhereOperator(String field, String operator, dynamic value) {
    qb.orWhere(field, operator, value);
    return this as T;
  }

  /// WHERE NULL clause - chainable.
  T whereNull(String field) {
    qb.whereNull(field);
    return this as T;
  }

  /// WHERE NOT NULL clause - chainable.
  T whereNotNull(String field) {
    qb.whereNotNull(field);
    return this as T;
  }

  /// ORDER BY clause - chainable with `asc` or `desc` options.
  T orderBy(String field, {bool? asc, bool? desc}) {
    final String direction;
    if (asc != null) {
      direction = asc ? 'ASC' : 'DESC';
    } else if (desc != null) {
      direction = desc ? 'DESC' : 'ASC';
    } else {
      direction = 'DESC';
    }
    qb.orderBy(field, direction);
    return this as T;
  }

  /// Strongly-typed ORDER BY clause using a compile-time [ColumnField].
  T orderByField<V>(ColumnField<V> field, {bool? asc, bool? desc}) {
    return orderBy(field.name, asc: asc, desc: desc);
  }

  /// LIMIT clause - chainable.
  T limit(int value) {
    qb.limit(value);
    return this as T;
  }

  /// OFFSET clause - chainable.
  T offset(int value) {
    qb.offset(value);
    return this as T;
  }

  /// GROUP BY clause - chainable.
  T groupBy(String field) {
    qb.groupBy(field);
    return this as T;
  }

  /// SELECT specific fields - chainable.
  T select(List<String> fields) {
    qb.select(fields);
    return this as T;
  }

  /// Select specific typed [ColumnField] descriptors - chainable.
  T selectFields(Iterable<ColumnField<dynamic>> fields) {
    qb.select(fields.map((f) => f.name).toList(growable: false));
    return this as T;
  }

  /// Paginate results.
  Future<Map<String, dynamic>> paginate(int page, [int perPage = 15]) async {
    final result = await qb.paginate(page, perPage);
    final modelData = (result['data'] as List<Map<String, dynamic>>)
        .map((map) => fromMap(convertDatabaseTypes(map)))
        .toList();

    resetQuery();
    return {
      'data': modelData,
      'current_page': result['current_page'],
      'per_page': result['per_page'],
      'total': result['total'],
      'last_page': result['last_page'],
      'page': result['page'],
      'perPage': result['perPage'],
      'totalPages': result['totalPages'],
      'from': result['from'],
      'to': result['to'],
      'hasPreviousPage': result['hasPreviousPage'],
      'hasNextPage': result['hasNextPage'],
    };
  }

  /// Count matching rows without loading the whole result set.
  Future<int> count([String column = '*']) async {
    final result = await qb.count(column);
    resetQuery();
    return result;
  }

  /// Get max value.
  Future<dynamic> max(String column) async {
    final result = await qb.max(column);
    resetQuery();
    return result;
  }

  /// Get min value.
  Future<dynamic> min(String column) async {
    final result = await qb.min(column);
    resetQuery();
    return result;
  }

  /// Get average value.
  Future<double?> avg(String column) async {
    final result = await qb.avg(column);
    resetQuery();
    return result;
  }

  /// Get sum value.
  Future<double?> sum(String column) async {
    final result = await qb.sum(column);
    resetQuery();
    return result;
  }

  T whereLike(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.whereLike(field, value, caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T whereNotLike(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.whereNotLike(field, value, caseSensitive: caseSensitive, escape: escape);
    return this as T;
  }

  T orWhereLike(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
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

  T whereContains(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.whereContains(
      field,
      value,
      caseSensitive: caseSensitive,
      escape: escape,
    );
    return this as T;
  }

  T whereStartsWith(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.whereStartsWith(
      field,
      value,
      caseSensitive: caseSensitive,
      escape: escape,
    );
    return this as T;
  }

  T whereEndsWith(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.whereEndsWith(
      field,
      value,
      caseSensitive: caseSensitive,
      escape: escape,
    );
    return this as T;
  }

  T orWhereContains(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.orWhereContains(
      field,
      value,
      caseSensitive: caseSensitive,
      escape: escape,
    );
    return this as T;
  }

  T orWhereStartsWith(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.orWhereStartsWith(
      field,
      value,
      caseSensitive: caseSensitive,
      escape: escape,
    );
    return this as T;
  }

  T orWhereEndsWith(
    String field,
    String value, {
    bool caseSensitive = false,
    bool escape = true,
  }) {
    qb.orWhereEndsWith(
      field,
      value,
      caseSensitive: caseSensitive,
      escape: escape,
    );
    return this as T;
  }

  // ========== DIRECT CRUD METHODS ==========

  /// Refresh the model from DB.
  Future<T?> refresh([dynamic id]) async {
    final currentId = this.id ?? id;
    if (currentId == null) return null;

    if (DB.driver == DBDriver.mysql) {
      final result = await runQuery(
        'SELECT * FROM ${table.name} WHERE $primaryKey = ? LIMIT 1',
        positionalParams: [currentId],
      );
      if (result.isEmpty) return null;
      return fromMap(convertDatabaseTypes(result.first));
    } else {
      final result = await runQuery(
        'SELECT * FROM ${table.name} WHERE $primaryKey = :id LIMIT 1',
        namedParams: {'id': currentId},
      );
      if (result.isEmpty) return null;
      return fromMap(convertDatabaseTypes(result.first));
    }
  }

  /// Insert new record (works for both PostgreSQL and MySQL).
  Future<T?> create([Map<String, dynamic>? data]) async {
    final Map<String, dynamic> insertMap =
        Map<String, dynamic>.from(data ?? asMap());

    final idColumn = table.columns.firstWhere(
      (c) => c.isPrimaryKey,
      orElse: () => const Column(
        name: 'id',
        type: ColumnType.string,
        isPrimaryKey: true,
        isAutoIncrement: false,
      ),
    );

    if (!idColumn.isAutoIncrement &&
        idColumn.type == ColumnType.string &&
        (insertMap[idColumn.name] == null ||
            insertMap[idColumn.name].toString().isEmpty)) {
      insertMap[idColumn.name] = Str.uuid();
    }

    if (idColumn.isAutoIncrement) {
      insertMap.remove(idColumn.name);
    }

    insertMap.removeWhere((key, data) => data == null);

    if (insertMap.isEmpty) {
      throw Exception("No data provided for creation");
    }
    insertMap["updated_at"] = DateTime.now();
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
      if (value is Enum) return value = value.name;
      return value;
    });
    final fields = insertMap.keys.join(', ');

    if (DB.driver == DBDriver.postgres) {
      final placeholders = insertMap.keys.map((k) => ':$k').join(', ');
      final sql = '''
      INSERT INTO ${table.name} ($fields)
      VALUES ($placeholders)
      RETURNING *
      ''';

      final result = await runQuery(sql, namedParams: insertMap);
      final converted = convertDatabaseTypes(result.first);
      setAttributes(converted);
      return fromMap(converted);
    } else {
      final placeholders =
          List.generate(insertMap.length, (_) => '?').join(', ');
      final sql = '''
      INSERT INTO ${table.name} ($fields)
      VALUES ($placeholders)
      ''';

      await runQuery(sql, positionalParams: insertMap.values.toList());

      if (idColumn.isAutoIncrement) {
        final lastId = await DB.getLastInsertId(table.name, idColumn.name);
        final result = await runQuery(
          'SELECT * FROM ${table.name} WHERE ${idColumn.name} = ?',
          positionalParams: [lastId],
        );
        final converted = convertDatabaseTypes(result.first);
        setAttributes(converted);
        return fromMap(converted);
      } else {
        final insertedId = insertMap[idColumn.name];
        final result = await runQuery(
          'SELECT * FROM ${table.name} WHERE ${idColumn.name} = ?',
          positionalParams: [insertedId],
        );
        final converted = convertDatabaseTypes(result.first);
        setAttributes(converted);
        return fromMap(converted);
      }
    }
  }

  Future<void> _executeCrudQuery(
    String sql, {
    List<dynamic>? positionalParams,
    Map<String, dynamic>? namedParams,
  }) async {
    if (DB.driver == DBDriver.mysql) {
      if (namedParams != null && namedParams.isNotEmpty) {
        final paramList = <dynamic>[];
        final processedSql = sql.replaceAllMapped(RegExp(r':(\w+)'), (match) {
          final paramName = match.group(1)!;
          if (!namedParams.containsKey(paramName)) {
            throw ArgumentError("Named parameter :$paramName not provided");
          }
          final paramValue = namedParams[paramName];
          paramList.add(paramValue);
          return '?';
        });
        await runExecute(processedSql, positionalParams: paramList);
      } else {
        await runExecute(sql, positionalParams: positionalParams);
      }
    } else {
      await runExecute(
        sql,
        positionalParams: positionalParams,
        namedParams: namedParams,
      );
    }
  }

  /// Update existing record.
  Future<T?> update({
    dynamic id,
    Map<String, dynamic>? data,
  }) async {
    final currentId = this.id ?? id;
    final hasWhere = qb.hasWhereClause;

    if (currentId == null && !hasWhere) {
      throw Exception(
        "Cannot update: no primary key and no where clause provided",
      );
    }
    final bool isUpdate = (data == null || data.isEmpty);
    final updateMap = isUpdate ? asMap() : data;
    final updateData = Map<String, dynamic>.from(updateMap)
      ..remove(primaryKey)
      ..removeWhere((k, v) => k.trim().isEmpty);

    if (updateData.isEmpty) {
      throw Exception("No data provided for update");
    }
    if (DB.driver == DBDriver.mysql) {
      updateData.updateAll((key, value) {
        final column = table.columns.firstWhere(
          (c) => c.name == key,
          orElse: () => Column(name: key, type: ColumnType.string),
        );

        if (value == null) return null;

        if (column.type == ColumnType.json) return jsonEncode(value);
        if (value is bool) return value ? 1 : 0;
        if (value is Enum) return value.name;
        return value;
      });
    }
    if (currentId != null) {
      final setClause = updateData.keys.map((k) => '`$k` = :$k').join(', ');
      final params = <String, dynamic>{...updateData, 'id': currentId};
      final sql =
          'UPDATE `${table.name}` SET $setClause WHERE `$primaryKey` = :id';

      await _executeCrudQuery(sql, namedParams: params);
    } else {
      final whereSql = qb.compileWhereSql();
      if (DB.driver == DBDriver.mysql) {
        final setClause = updateData.keys.map((k) => '`$k` = ?').join(', ');
        final sql = 'UPDATE `${table.name}` SET $setClause $whereSql';
        final positionalParams = [
          ...updateData.values,
          ...qb.whereParams.values,
        ];

        await _executeCrudQuery(sql, positionalParams: positionalParams);
      } else {
        final setClause = updateData.keys.map((k) => '`$k` = :$k').join(', ');
        final sql = 'UPDATE `${table.name}` SET $setClause $whereSql';
        final params = <String, dynamic>{...updateData, ...qb.whereParams};

        await _executeCrudQuery(sql, namedParams: params);
      }
    }

    resetQuery();
    return await refresh(currentId);
  }

  /// Save model (create or update).
  Future<T?> save() async {
    final currentId = id;
    if (currentId == null) {
      return await create();
    } else {
      return await update();
    }
  }

  Future<T?> firstOrCreate({
    required Map<String, dynamic> where,
    required Map<String, dynamic> values,
  }) async {
    var queryModel = resetQuery();
    where.forEach((key, value) {
      queryModel.qb.where(key, '=', value);
    });
    final existing = await queryModel.first();
    if (existing != null) return existing;

    final newData = {...where, ...values};
    return await create(newData);
  }

  @Deprecated('Use update(id: ..., data: ...) instead')
  Future<T?> updateLegacy([dynamic id, Map<String, dynamic>? data]) {
    return update(id: id, data: data);
  }

  /// Universal upsert for Flint Dart.
  Future<T?> upsert({
    Map<String, dynamic>? where,
    List<String>? uniqueBy,
    Map<String, dynamic>? data,
    Map<String, dynamic>? createData,
    Map<String, dynamic>? updateData,
    List<String>? excludeUpdatedData,
  }) async {
    if (where == null) {
      if (uniqueBy == null || uniqueBy.isEmpty) {
        throw Exception('upsert requires either where or uniqueBy');
      }
    }

    final hasOldApi = data != null;
    final hasNewApi = createData != null || updateData != null;

    if (!hasOldApi && !hasNewApi) {
      throw Exception(
        'upsert requires either `data` or (`createData` / `updateData`)',
      );
    }

    if (hasOldApi && hasNewApi) {
      throw Exception(
        'Use either `data` or (`createData` / `updateData`), not both',
      );
    }

    if (!hasOldApi &&
        excludeUpdatedData != null &&
        excludeUpdatedData.isNotEmpty) {
      throw Exception(
        '`excludeUpdatedData` can only be used with the legacy `data` payload',
      );
    }

    late final Map<String, dynamic> resolvedCreateData;
    late final Map<String, dynamic> resolvedUpdateData;

    if (hasOldApi) {
      final sharedData = Map<String, dynamic>.from(data);
      resolvedCreateData = Map<String, dynamic>.from(sharedData);
      resolvedUpdateData = Map<String, dynamic>.from(sharedData);

      if (excludeUpdatedData != null && excludeUpdatedData.isNotEmpty) {
        for (final key in excludeUpdatedData) {
          resolvedUpdateData.remove(key);
        }
      }
    } else {
      resolvedCreateData = Map<String, dynamic>.from(createData ?? {});
      resolvedUpdateData = Map<String, dynamic>.from(updateData ?? {});
    }

    if (where == null) {
      final resolvedUniqueBy = uniqueBy!;
      final source = {
        ...resolvedCreateData,
        ...resolvedUpdateData,
      };

      where = {};

      for (final key in resolvedUniqueBy) {
        if (!source.containsKey(key)) {
          throw Exception(
            'Missing unique key "$key" in payload for upsert',
          );
        }
        where[key] = source[key];
      }
    } else {
      where = Map<String, dynamic>.from(where);
    }

    var queryModel = resetQuery();
    where.forEach((key, value) {
      queryModel.qb.where(key, '=', value);
    });

    final existing = await queryModel.first();

    if (existing != null) {
      if (resolvedUpdateData.isEmpty) {
        return existing;
      }
      return await existing.update(data: resolvedUpdateData);
    }

    if (resolvedCreateData.isEmpty) {
      throw Exception('No create data available for insert');
    }

    final insertData = {
      ...where,
      ...resolvedCreateData,
    };

    return await create(insertData);
  }

  Future<List<T?>> upsertMany({
    required List<Map<String, dynamic>> records,
    required List<String> uniqueBy,
    List<String>? excludeUpdatedData,
    Map<String, dynamic> Function(Map<String, dynamic> record)?
        createDataBuilder,
    Map<String, dynamic> Function(Map<String, dynamic> record)?
        updateDataBuilder,
  }) async {
    if (records.isEmpty) return [];

    if (uniqueBy.isEmpty) {
      throw Exception('upsertMany requires at least one unique column');
    }

    final results = <T?>[];

    for (final record in records) {
      final where = <String, dynamic>{};

      for (final key in uniqueBy) {
        if (!record.containsKey(key)) {
          throw Exception(
            'Missing unique key "$key" in record: $record',
          );
        }
        where[key] = record[key];
      }

      final model = await resetQuery().upsert(
        where: where,
        data: createDataBuilder == null && updateDataBuilder == null
            ? record
            : null,
        createData: createDataBuilder?.call(record),
        updateData: updateDataBuilder?.call(record),
        excludeUpdatedData: excludeUpdatedData,
      );

      results.add(model);
    }

    return results;
  }

  /// Delete this model.
  Future<bool> delete([dynamic id]) async {
    final currentId = this.id ?? id;
    if (currentId == null) return false;

    if (DB.driver == DBDriver.mysql) {
      await runExecute(
        'DELETE FROM ${table.name} WHERE $primaryKey = ?',
        positionalParams: [currentId],
      );
    } else {
      await runExecute(
        'DELETE FROM ${table.name} WHERE $primaryKey = :id',
        namedParams: {'id': currentId},
      );
    }

    return true;
  }

  /// Get all records.
  Future<List<T>> all() async => await get();

  /// Simple where clause (non-chainable).
  Future<List<T>> whereSimple(String field, dynamic value) async {
    if (DB.driver == DBDriver.mysql) {
      if (value is bool) value = value ? 1 : 0;
      if (value is Enum) value = value.name;
    }

    if (DB.driver == DBDriver.mysql) {
      final result = await runQuery(
        'SELECT * FROM ${table.name} WHERE $field = ?',
        positionalParams: [value],
      );
      return result.map((map) => fromMap(convertDatabaseTypes(map))).toList();
    } else {
      final result = await runQuery(
        'SELECT * FROM ${table.name} WHERE $field = :value',
        namedParams: {'value': value},
      );
      return result.map((map) => fromMap(convertDatabaseTypes(map))).toList();
    }
  }

  /// Simple where IN clause (non-chainable).
  Future<List<T>> whereInSimple(String field, List<dynamic> values) async {
    if (values.isEmpty) return [];

    if (DB.driver == DBDriver.mysql) {
      values = values.map((v) {
        if (v is bool) return v ? 1 : 0;
        if (v is Enum) return v.name;
        return v;
      }).toList();
    }

    if (DB.driver == DBDriver.mysql) {
      final placeholders = List.generate(values.length, (_) => '?').join(', ');
      final result = await runQuery(
        'SELECT * FROM ${table.name} WHERE $field IN ($placeholders)',
        positionalParams: values,
      );
      return result.map((map) => fromMap(convertDatabaseTypes(map))).toList();
    } else {
      final placeholders =
          List.generate(values.length, (i) => ':value$i').join(', ');
      final params = {
        for (var i = 0; i < values.length; i++)
          'value$i': values[i] is Enum ? values[i].name : values[i],
      };

      final result = await runQuery(
        'SELECT * FROM ${table.name} WHERE $field IN ($placeholders)',
        namedParams: params,
      );
      return result.map((map) => fromMap(convertDatabaseTypes(map))).toList();
    }
  }

  /// Count all records.
  Future<int> countAll() async {
    final result = await runQuery(
      'SELECT COUNT(*) as count FROM ${table.name}',
    );

    final count = result.first['count'];
    if (count is String) return int.parse(count);
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    return count as int;
  }

  /// Count records with condition.
  Future<int> countWhere(String field, dynamic value) async {
    if (DB.driver == DBDriver.mysql) {
      if (value is bool) value = value ? 1 : 0;
      if (value is Enum) value = value.name;
    }

    final result = await runQuery(
      'SELECT COUNT(*) as count FROM ${table.name} WHERE $field = :value',
      namedParams: {'value': value},
    );

    final count = result.first['count'];
    if (count is String) return int.parse(count);
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    return count as int;
  }

  /// Truncate table.
  Future<void> truncate() async {
    if (DB.driver == DBDriver.postgres) {
      await runExecute('TRUNCATE TABLE ${table.name} RESTART IDENTITY');
    } else {
      await runExecute('TRUNCATE TABLE ${table.name}');
    }
  }

  // Helper to check if string looks like a DateTime
  static bool looksLikeDateTime(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
  }

  /// Convert database-specific types to Dart types safely,
  /// respecting the model's schema definition.
  Map<String, dynamic> convertDatabaseTypes(Map<dynamic, dynamic> map) {
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
        case ColumnType.mediumText:
        case ColumnType.longText:
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

        case ColumnType.enumeration:
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
              converted[key] = String.fromCharCodes(value);
            }
          }
          break;
      }
    }

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
