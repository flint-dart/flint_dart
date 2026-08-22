import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:universal_web/web.dart' as web;

/// Reads browser-side environment configuration for Flint UI apps.
class EnvironmentConfig {
  /// Creates an environment config with explicit override [values].
  const EnvironmentConfig([this.values = const {}]);

  /// Explicit configuration values checked before browser-provided values.
  final Map<String, String> values;

  /// Reads a string value by [key].
  ///
  /// Values are checked from explicit overrides, meta tags, browser globals,
  /// and finally [fallback].
  String? get(String key, {String? fallback}) {
    return values[key] ??
        _fromMeta(key) ??
        _fromBrowserGlobal('__FLINT_ENV__', key) ??
        _fromBrowserGlobal('flintEnv', key) ??
        fallback;
  }

  /// Reads a boolean value by [key].
  bool getBool(String key, {bool fallback = false}) {
    final value = get(key);
    if (value == null) return fallback;
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' || 'yes' || 'on' => true,
      '0' || 'false' || 'no' || 'off' => false,
      _ => fallback,
    };
  }

  /// Reads an integer value by [key].
  int getInt(String key, {int fallback = 0}) {
    return int.tryParse(get(key) ?? '') ?? fallback;
  }

  /// Reads a double value by [key].
  double getDouble(String key, {double fallback = 0}) {
    return double.tryParse(get(key) ?? '') ?? fallback;
  }

  /// Returns a new config with [values] layered over the current values.
  EnvironmentConfig merge(Map<String, String> values) {
    return EnvironmentConfig({...this.values, ...values});
  }

  String? _fromMeta(String key) {
    final names = ['flint-env:$key', 'flint:$key', key];

    for (final name in names) {
      final element = web.document.querySelector('meta[name="$name"]');
      final content = element?.getAttribute('content');
      if (content != null) return content;
    }

    return null;
  }

  String? _fromBrowserGlobal(String scope, String key) {
    final rawScope = globalContext.getProperty<JSAny?>(scope.toJS);
    final scopeValue = rawScope?.dartify();
    if (scopeValue is! Map) return null;

    final value = scopeValue[key];
    return value?.toString();
  }
}

/// Shared browser environment configuration helper.
const env = EnvironmentConfig();
