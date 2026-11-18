import 'navigation.dart';

/// Reads and updates the current browser URL query string.
class QueryParams {
  /// Creates a query parameter helper for the current browser URL.
  const QueryParams();

  Uri get _uri => currentUri;

  /// Returns the first value for [key], or `null` when it is absent.
  String? get(String key) {
    return _uri.queryParameters[key];
  }

  /// Returns all values for [key].
  List<String> getAll(String key) {
    return _uri.queryParametersAll[key] ?? const [];
  }

  /// All query parameters as a single-value map.
  Map<String, String> get all {
    return Map.unmodifiable(_uri.queryParameters);
  }

  /// All query parameters, preserving repeated values.
  Map<String, List<String>> get allValues {
    return Map.unmodifiable(_uri.queryParametersAll);
  }

  /// Whether the current URL contains [key].
  bool has(String key) {
    return _uri.queryParameters.containsKey(key);
  }

  /// Sets one query parameter and writes the updated URL to browser history.
  void set(String key, Object? value, {bool push = false, Object? state}) {
    update({key: value}, push: push, state: state);
  }

  /// Updates multiple query parameters and writes the updated URL.
  ///
  /// `null` values remove their keys. Iterable values become repeated query
  /// values.
  void update(Map<String, Object?> values, {bool push = false, Object? state}) {
    final next = Map<String, dynamic>.from(_uri.queryParameters);

    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) {
        next.remove(entry.key);
      } else if (value is Iterable) {
        next[entry.key] = value.map((item) => item.toString()).toList();
      } else {
        next[entry.key] = value.toString();
      }
    }

    _write(next, push: push, state: state);
  }

  /// Removes [key] from the current query string.
  void remove(String key, {bool push = false, Object? state}) {
    final next = Map<String, dynamic>.from(_uri.queryParameters)..remove(key);
    _write(next, push: push, state: state);
  }

  /// Removes all query parameters from the current URL.
  void clear({bool push = false, Object? state}) {
    _write(const {}, push: push, state: state);
  }

  void _write(
    Map<String, dynamic> values, {
    required bool push,
    Object? state,
  }) {
    final uri = _uri;
    final nextUri = values.isEmpty
        ? uri.replace(query: '')
        : uri.replace(queryParameters: values);
    final nextPath = nextUri.toString();

    if (push) {
      navigate(nextPath, state: state);
    } else {
      replace(nextPath, state: state);
    }
  }
}

/// Shared query string helper for the current browser URL.
const query = QueryParams();
