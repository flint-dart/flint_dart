/// Reactive state management for Flint widgets
class FlintState {
  final Map<String, dynamic> _data;
  final List<Function(Map<String, dynamic>)> _listeners = [];

  FlintState([Map<String, dynamic>? initialData]) : _data = initialData ?? {};

  Map<String, dynamic> get data => Map.unmodifiable(_data);

  dynamic get(String key) => _data[key];

  void update(Map<String, dynamic> newData) {
    _data.addAll(newData);
    _notifyListeners();
  }

  void set(String key, dynamic value) {
    _data[key] = value;
    _notifyListeners();
  }

  void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_data);
    }
  }

  /// Convert state to Alpine.js compatible format
  Map<String, dynamic> toAlpineData() {
    return Map.from(_data);
  }

  /// Add computed properties for Alpine.js
  void addComputedProperty(String name, dynamic Function() computeFn) {
    _data['_computed_$name'] = computeFn;
  }

  String toJsObject() {
    final entries = data.entries.map((e) {
      final value = e.value;
      if (value is String) return '${e.key}: "$value"';
      if (value is bool || value is num) return '${e.key}: $value';
      if (value is List) {
        return '${e.key}: [${value.map((v) => '"$v"').join(',')}]';
      }
      return '${e.key}: "$value"';
    }).join(',');
    return '{$entries}';
  }
}
