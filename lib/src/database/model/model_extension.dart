// model_extension.dart

import 'model.dart';

extension ModelListExtension<T extends Model<T>> on List<T> {
  /// Convert list of models to list of maps
  List<Map<String, dynamic>> asMaps() {
    return map((model) => model.asMap()).toList();
  }
}

// Extension for Future<List<Model>>
extension FutureModelListExtension<T extends Model<T>> on Future<List<T>> {
  /// Convert Future&ltList&ltModel&rt&rt to Future&ltList&ltMap&rt&rt
  Future<List<Map<String, dynamic>>> get asMaps async {
    final models = await this;
    return models.asMaps();
  }
}
