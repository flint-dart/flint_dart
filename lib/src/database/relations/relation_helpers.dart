// lib/src/database/relations/relations.dart
import 'package:flint_dart/model.dart';

/// Clean, static helper methods for defining relations
class Relations {
  /// Define a belongsTo relationship
  /// Example: Relations.belongsTo('category', () => Category())
  static RelationDefinition belongsTo<T extends Model<T>>(
    String name,
    T Function() relatedFactory, {
    String? foreignKey,
    String? ownerKey,
  }) {
    return RelationDefinition<T>(
      name: name,
      type: RelationType.belongsTo,
      relatedFactory: relatedFactory,
      foreignKey: foreignKey ?? '${name}_id',
      ownerKey: ownerKey ?? 'id',
    );
  }

  /// Define a hasOne relationship
  /// Example: Relations.hasOne('profile', () => Profile())
  static RelationDefinition hasOne<T extends Model<T>>(
    String name,
    T Function() relatedFactory, {
    String? foreignKey,
    String? ownerKey,
  }) {
    return RelationDefinition<T>(
      name: name,
      type: RelationType.hasOne,
      relatedFactory: relatedFactory,
      foreignKey: foreignKey ?? '${_singularize(name)}_id',
      ownerKey: ownerKey ?? 'id',
    );
  }

  /// Define a hasMany relationship
  /// Example: Relations.hasMany('comments', () => Comment())
  static RelationDefinition hasMany<T extends Model<T>>(
    String name,
    T Function() relatedFactory, {
    String? foreignKey,
    String? ownerKey,
  }) {
    return RelationDefinition<T>(
      name: name,
      type: RelationType.hasMany,
      relatedFactory: relatedFactory,
      foreignKey: foreignKey ?? '${_singularize(name)}_id',
      ownerKey: ownerKey ?? 'id',
    );
  }

  /// Define a belongsToMany (many-to-many) relationship
  /// Example: Relations.belongsToMany('tags', () => Tag(), ...)
  static RelationDefinition belongsToMany<T extends Model<T>>(
    String name,
    T Function() relatedFactory, {
    required String pivotTable,
    required String relatedPivotKey,
    required String foreignPivotKey,
    String? foreignKey,
    String? ownerKey,
  }) {
    return RelationDefinition<T>(
      name: name,
      type: RelationType.belongsToMany,
      relatedFactory: relatedFactory,
      foreignKey: foreignKey ?? '${_singularize(name)}_id',
      ownerKey: ownerKey ?? 'id',
      pivotTable: pivotTable,
      relatedPivotKey: relatedPivotKey,
      foreignPivotKey: foreignPivotKey,
    );
  }

  /// Helper to singularize table names
  static String _singularize(String name) {
    // Handle common plural patterns
    if (name.endsWith('ies')) {
      return '${name.substring(0, name.length - 3)}y';
    }
    if (name.endsWith('es')) {
      // Check for special endings
      final specialEndings = ['ss', 'x', 'ch', 'sh'];
      for (final ending in specialEndings) {
        if (name.endsWith('${ending}es')) {
          return name.substring(0, name.length - 2);
        }
      }
    }
    if (name.endsWith('s') && !name.endsWith('ss')) {
      return name.substring(0, name.length - 1);
    }
    return name;
  }
}
