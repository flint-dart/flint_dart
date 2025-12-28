import 'package:flint_dart/model.dart';

enum RelationType {
  belongsTo,
  hasOne,
  hasMany,
  belongsToMany,
  hasManyThrough,
}

class RelationDefinition<T extends Model<T>> {
  final String name;
  final RelationType type;
  final T Function() relatedFactory;

  final String foreignKey; // on parent
  final String ownerKey; // on related (belongsTo)
  // optional
  final String? pivotTable;
  final String? relatedPivotKey;
  final String? foreignPivotKey;

  const RelationDefinition({
    required this.name,
    required this.type,
    required this.relatedFactory,
    required this.foreignKey,
    required this.ownerKey,
    this.pivotTable,
    this.relatedPivotKey,
    this.foreignPivotKey,
  });
}
