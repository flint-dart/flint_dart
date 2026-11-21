// model_relations.dart

import 'model.dart';

/// Extension methods for relation operations on [Model].
///
/// Note: [Model] already provides [load], [loadMany], [withRelation],
/// [withRelations], and [getRelation] directly on the model instance.
/// This extension provides backwards compatibility.
extension ModelRelations<T extends Model<T>> on Model<T> {
  /// Load a relation for this single model instance.
  Future<T> load(String relation, {List<String>? columns}) =>
      (this as dynamic).load(relation, columns: columns);

  /// Load multiple relations for this single model instance.
  Future<T> loadMany(List<String> relations) =>
      (this as dynamic).loadMany(relations);

  /// Type-safe relation accessor.
  R? getRelation<R>(String name) => getAttribute<R>(name);

  /// Add relation to eager load.
  T withRelation(String name, {List<String>? columns}) {
    qb.withRelation(name, columns: columns);
    return this as T;
  }

  /// Add multiple relations to eager load.
  T withRelations(List<String> names) {
    for (final name in names) {
      qb.withRelation(name);
    }
    return this as T;
  }
}
