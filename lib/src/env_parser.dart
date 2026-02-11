import 'dart:io';

/// A lightweight environment variable loader for Dart applications.
///
/// `FlintEnv` provides a simple way to read configuration values
/// from multiple sources in the following priority order (highest to lowest):
/// 1. Global/System environment variables
/// 2. `.env` file values
/// 3. Default values
///
/// The `.env` file should contain key-value pairs in the format:
/// ```env
/// DB_HOST=localhost
/// DB_PORT=3306
/// PRODUCTION=true
/// ```
///
/// Lines starting with `#` are ignored as comments. Values can also be
/// wrapped in single `'` or double `"` quotes.
///
/// Example usage:
/// ```dart
/// final host = FlintEnv.get('DB_HOST', '127.0.0.1');
/// final port = FlintEnv.getInt('DB_PORT', 3306);
/// final isProd = FlintEnv.getBool('PRODUCTION', false);
/// ```
class FlintEnv {
  /// Internal in-memory store for environment variables from .env file.
  static final Map<String, String> _envFromFile = {};

  /// Tracks whether the `.env` file has been loaded already.
  static bool _isLoaded = false;

  /// Returns the value for the given [key].
  ///
  /// Priority order:
  /// 1. Global/System environment variables
  /// 2. `.env` file values
  /// 3. [defaultValue] (defaults to `''`)
  ///
  /// Example:
  /// ```dart
  /// final apiKey = FlintEnv.get('API_KEY', 'default-key');
  /// ```
  static String get(String key, [String defaultValue = '']) {
    _ensureLoaded();

    // 1. Check global/system environment variables first (highest priority)
    final globalValue = Platform.environment[key];
    if (globalValue != null) {
      return globalValue;
    }

    // 2. Check .env file values
    final envFileValue = _envFromFile[key];
    if (envFileValue != null) {
      return envFileValue;
    }

    // 3. Return default value
    return defaultValue;
  }

  /// Returns the integer value for the given [key].
  ///
  /// Priority order:
  /// 1. Global/System environment variables
  /// 2. `.env` file values
  /// 3. [defaultValue] (defaults to `0`)
  ///
  /// Example:
  /// ```dart
  /// final port = FlintEnv.getInt('DB_PORT', 3306);
  /// ```
  static int getInt(String key, [int defaultValue = 0]) {
    _ensureLoaded();

    // 1. Check global/system environment variables first
    final globalValue = Platform.environment[key];
    if (globalValue != null) {
      return int.tryParse(globalValue) ?? defaultValue;
    }

    // 2. Check .env file values
    final envFileValue = _envFromFile[key];
    if (envFileValue != null) {
      return int.tryParse(envFileValue) ?? defaultValue;
    }

    // 3. Return default value
    return defaultValue;
  }

  /// Returns the boolean value for the given [key].
  ///
  /// Priority order:
  /// 1. Global/System environment variables
  /// 2. `.env` file values
  /// 3. [defaultValue] (defaults to `false`)
  ///
  /// Accepted values for `true`: `'true'`, `'1'`, `'yes'`
  /// Accepted values for `false`: `'false'`, `'0'`, `'no'`
  ///
  /// Example:
  /// ```dart
  /// final isProd = FlintEnv.getBool('PRODUCTION', false);
  /// ```
  static bool getBool(String key, [bool defaultValue = false]) {
    _ensureLoaded();

    // 1. Check global/system environment variables first
    final globalValue = Platform.environment[key];
    if (globalValue != null) {
      return _parseBool(globalValue, defaultValue);
    }

    // 2. Check .env file values
    final envFileValue = _envFromFile[key];
    if (envFileValue != null) {
      return _parseBool(envFileValue, defaultValue);
    }

    // 3. Return default value
    return defaultValue;
  }

  /// Parses a string value to boolean.
  static bool _parseBool(String value, bool defaultValue) {
    final val = value.toLowerCase().trim();
    return val == 'true' || val == '1' || val == 'yes'
        ? true
        : val == 'false' || val == '0' || val == 'no'
            ? false
            : defaultValue;
  }

  /// Returns all available environment variables as a Map.
  ///
  /// Priority order is maintained: global variables override .env file values.
  static Map<String, String> getAll() {
    _ensureLoaded();

    final allEnv = <String, String>{};

    // 1. Add .env file values first (lower priority)
    allEnv.addAll(_envFromFile);

    // 2. Override with global/system environment variables (higher priority)
    allEnv.addAll(Platform.environment);

    return allEnv;
  }

  /// Checks if a specific key exists in any environment source.
  static bool exists(String key) {
    _ensureLoaded();
    return Platform.environment.containsKey(key) ||
        _envFromFile.containsKey(key);
  }

  /// Reloads the environment variables from both sources.
  ///
  /// Useful for development when .env files might change.
  static void reload() {
    _isLoaded = false;
    _envFromFile.clear();
    _ensureLoaded();
  }

  /// Ensures the `.env` file is loaded into memory.
  ///
  /// This is called automatically on first access of any getter.
  static void _ensureLoaded() {
    if (!_isLoaded) {
      final file = File('.env');
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        _envFromFile.addAll(_parseLines(lines));
      }
      _isLoaded = true;
    }
  }

  /// Parses lines of text into key-value pairs.
  ///
  /// Each line should be in the form `KEY=VALUE`.
  /// - Empty lines and lines starting with `#` are ignored.
  /// - Values surrounded by quotes (`'` or `"`) will have quotes removed.
  static Map<String, String> _parseLines(List<String> lines) {
    final result = <String, String>{};
    final regex = RegExp(r'^([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$');

    for (var line in lines) {
      line = line.trim();

      // Ignore full-line comments
      if (line.isEmpty || line.startsWith('#')) continue;

      // Remove inline comments (# ...)
      final commentIndex = line.indexOf('#');
      if (commentIndex != -1) {
        line = line.substring(0, commentIndex).trim();
      }

      if (line.isEmpty) continue;

      final match = regex.firstMatch(line);
      if (match != null) {
        final key = match.group(1)!;
        var value = match.group(2)!;

        // Remove surrounding quotes
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }

        result[key] = value;
      }
    }

    return result;
  }
}

/// Top-level helper for reading env values with optional type coercion.
///
/// If [defaultValue] is provided, the return type follows that type.
/// Supported types: String, int, double, bool.
/// If [defaultValue] is omitted or null, this will try to auto-parse
/// bool → int → double, and fall back to String.
dynamic env(String key, [dynamic defaultValue]) {
  final raw = FlintEnv.get(key, defaultValue?.toString() ?? '');

  if (defaultValue is bool) {
    return FlintEnv.getBool(key, defaultValue);
  }
  if (defaultValue is int) {
    return FlintEnv.getInt(key, defaultValue);
  }
  if (defaultValue is double) {
    final v = FlintEnv.get(key, defaultValue.toString());
    return double.tryParse(v) ?? defaultValue;
  }
  if (defaultValue is String) {
    return raw;
  }

  if (raw.isEmpty) return defaultValue;

  final lower = raw.toLowerCase();
  if (lower == 'true' || lower == 'false') return lower == 'true';
  final asInt = int.tryParse(raw);
  if (asInt != null) return asInt;
  final asDouble = double.tryParse(raw);
  if (asDouble != null) return asDouble;
  return raw;
}
