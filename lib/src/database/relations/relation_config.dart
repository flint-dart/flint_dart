// relation_config.dart
class RelationConfig {
  final List<String>? columns;
  final String? relationName;
  final Map<String, dynamic>? extra;

  const RelationConfig({
    this.columns,
    this.relationName,
    this.extra,
  });

  Map<String, dynamic> toMap() {
    return {
      'columns': columns,
      'relationName': relationName,
      'extra': extra,
    };
  }
}
