/// Dart backend actions registry and handler
class DartActions {
  static final Map<String, Function(Map<String, dynamic>)> _actions = {};

  /// Register a new action
  static void register(
      String actionName, Function(Map<String, dynamic>) action) {
    _actions[actionName] = action;
  }

  /// Execute an action with the given state
  static Map<String, dynamic> execute(
      String actionName, Map<String, dynamic> state) {
    if (_actions.containsKey(actionName)) {
      return _actions[actionName]!(state);
    } else {
      throw Exception('Action "$actionName" not found');
    }
  }

  /// Handle HTTP request for Flint actions
  static Map<String, dynamic> handleRequest(Map<String, dynamic> request) {
    try {
      final actionName = request['action'] as String;
      final state = Map<String, dynamic>.from(request['state'] ?? {});

      final result = execute(actionName, state);
      return result;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get all registered action names
  static List<String> get registeredActions => _actions.keys.toList();
}
