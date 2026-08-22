import '../../protocol/flint_db_protocol.dart';

import '../errors/flint_db_api_exception.dart';
import 'flint_db_resource.dart';

class FlintDbResourceRegistry {
  FlintDbResourceRegistry([Iterable<FlintDbResource> resources = const []]) {
    for (final resource in resources) {
      register(resource);
    }
  }

  final Map<String, FlintDbResource> _resources = {};

  Iterable<FlintDbResource> get resources => _resources.values;

  void register(FlintDbResource resource) {
    if (_resources.containsKey(resource.resourceName)) {
      throw StateError(
        'Flint DB resource "${resource.resourceName}" is already registered.',
      );
    }
    _resources[resource.resourceName] = resource;
  }

  FlintDbResource resolve(String name) {
    final resource = _resources[name];
    if (resource == null) {
      throw const FlintDbApiException(
        FlintDbErrorCode.resourceNotFound,
        'The requested resource is not available.',
        statusCode: 404,
      );
    }
    return resource;
  }

  List<FlintDbResourceSchema> schema() => _resources.values
      .map((resource) => resource.toSchema())
      .toList(growable: false);
}
