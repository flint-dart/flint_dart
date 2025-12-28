// _model_helper.dart
import '../relations/relation_config.dart';
import 'model.dart';

final Map<String, dynamic> relationLoaders = {};

bool looksLikeDateTime(String value) {
  return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
}

/// Load relations for a list of parent models
Future<void> loadRelations(
  List<Model> parents,
  List<String> relations,
  String modelClassName,
  Map<String, RelationConfig>? relationConfigs,
) async {
  if (parents.isEmpty || relations.isEmpty) return;

  for (final relation in relations) {
    final loaderKey = '$modelClassName.$relation';
    final loader = relationLoaders[loaderKey];

    if (loader == null) {
      throw Exception(
        "Relation '$relation' is not defined for $modelClassName. "
        "Make sure it's defined in the 'relations' getter.",
      );
    }

    final config = relationConfigs?[relation];
    await loader(parents, config);
  }
}
