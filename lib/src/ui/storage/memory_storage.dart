import 'browser_storage.dart';

class MemoryStorage extends BrowserStorage {
  const MemoryStorage();

  static final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) {
    _values[key] = value;
  }

  @override
  String? remove(String key) => _values.remove(key);

  @override
  void clear() {
    _values.clear();
  }
}
