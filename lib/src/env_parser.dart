import 'dart:io';

/// A lightweight environment variable loader for Dart applications.
///
/// `FlintEnv` provides a simple way to read configuration values
/// from a `.env` file and access them as `String`, `int`, or `bool`.
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
  /// Internal in-memory store for environment variables.
  static final Map<String, String> _env = {};

  /// Tracks whether the `.env` file has been loaded already.
  static bool _isLoaded = false;

  /// Returns the value for the given [key].
  ///
  /// If the key is not found, returns the [defaultValue] (defaults to `''`).
  ///
  /// Example:
  /// ```dart
  /// final apiKey = FlintEnv.get('API_KEY', 'default-key');
  /// ```
  static String get(String key, [String defaultValue = '']) {
    _ensureLoaded();
    return _env[key] ?? defaultValue;
  }

  /// Returns the integer value for the given [key].
  ///
  /// If the key is not found or cannot be parsed as an integer,
  /// returns the [defaultValue] (defaults to `0`).
  ///
  /// Example:
  /// ```dart
  /// final port = FlintEnv.getInt('DB_PORT', 3306);
  /// ```
  static int getInt(String key, [int defaultValue = 0]) {
    _ensureLoaded();
    return int.tryParse(_env[key] ?? '') ?? defaultValue;
  }

  /// Returns the boolean value for the given [key].
  ///
  /// Accepted values for `true`: `'true'`, `'1'`
  /// Accepted values for `false`: `'false'`, `'0'`
  /// If the key is not found or cannot be interpreted, returns [defaultValue] (defaults to `false`).
  ///
  /// Example:
  /// ```dart
  /// final isProd = FlintEnv.getBool('PRODUCTION', false);
  /// ```
  static bool getBool(String key, [bool defaultValue = false]) {
    _ensureLoaded();
    final val = _env[key]?.toLowerCase();
    return val == 'true' || val == '1'
        ? true
        : val == 'false' || val == '0'
            ? false
            : defaultValue;
  }

  /// Ensures the `.env` file is loaded into memory.
  ///
  /// This is called automatically on first access of any getter.
  static void _ensureLoaded() {
    if (!_isLoaded) {
      final file = File('.env');
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        _env.addAll(_parseLines(lines));
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
      if (line.isEmpty || line.startsWith('#')) continue;

      final match = regex.firstMatch(line);
      if (match != null) {
        final key = match.group(1)!;
        var value = match.group(2)!;

        // Remove surrounding quotes if present
        if (value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        } else if (value.startsWith("'") && value.endsWith("'")) {
          value = value.substring(1, value.length - 1);
        }

        result[key] = value;
      }
    }
    return result;
  }
}
