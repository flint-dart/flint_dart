import 'dart:convert';

/// Base API for browser-backed key/value storage.
abstract class BrowserStorage {
  /// Creates a browser storage wrapper.
  const BrowserStorage();

  /// Reads a string value by [key].
  String? read(String key);

  /// Writes a string [value] by [key].
  void write(String key, String value);

  /// Whether [key] currently exists in storage.
  bool has(String key) {
    return read(key) != null;
  }

  /// Reads and decodes a JSON value by [key].
  Object? readJson(String key) {
    final value = read(key);
    if (value == null || value.isEmpty) return null;
    return jsonDecode(value);
  }

  /// Reads a JSON object by [key], returning an empty map when absent.
  Map<String, dynamic> readMap(String key) {
    final decoded = readJson(key);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  /// Encodes and writes [value] as JSON by [key].
  void writeJson(String key, Object? value) {
    write(key, jsonEncode(value));
  }

  /// Removes [key] and returns the previous value when present.
  String? remove(String key);

  /// Removes every value from this storage backend.
  void clear();
}
