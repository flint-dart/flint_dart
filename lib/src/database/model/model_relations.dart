// model_relation.dart

import 'package:flint_dart/src/database/model/_model_helper.dart';

import 'model.dart';

/// Relation methods for Model
extension ModelRelations<T extends Model<T>> on Model<T> {
  /// Load a relation for this single model
  // Future<T> load(String relation, {List<String>? columns}) async {
  //   // _ensureRelationsRegistered();

  //   final loaderKey = '${runtimeType.toString()}.$relation';
  //   final loader = relationLoaders[loaderKey];

  //   if (loader == null) {
  //     throw Exception(
  //         "Relation '$relation' not found for ${runtimeType.toString()}");
  //   }
  //   Model model = this;
  //   await loader([model], RelationConfig(columns: columns));
  //   return this as T;
  // }

  /// Load multiple relations
  Future<T> loadMany(List<String> relations) async {
    // _ensureRelationsRegistered();

    for (final relation in relations) {
      final loaderKey = '${runtimeType.toString()}.$relation';
      final loader = relationLoaders[loaderKey];

      if (loader != null) {
        //  await loader([this], null);
      }
    }

    return this as T;
  }

  /// Type-safe relation accessor
  R? getRelation<R>(String name) => getAttribute<R>(name);

  /// Add relation to eager load
  T withRelation(String name, {List<String>? columns}) {
    qb.withRelation(name, columns: columns);
    return this as T;
  }

  /// Add multiple relations to eager load
}
