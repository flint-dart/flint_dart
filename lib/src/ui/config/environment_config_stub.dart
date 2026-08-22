class EnvironmentConfig {
  const EnvironmentConfig([this.values = const {}]);

  final Map<String, String> values;

  String? get(String key, {String? fallback}) {
    return values[key] ?? fallback;
  }

  bool getBool(String key, {bool fallback = false}) {
    final value = get(key);
    if (value == null) return fallback;
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' || 'yes' || 'on' => true,
      '0' || 'false' || 'no' || 'off' => false,
      _ => fallback,
    };
  }

  int getInt(String key, {int fallback = 0}) {
    return int.tryParse(get(key) ?? '') ?? fallback;
  }

  double getDouble(String key, {double fallback = 0}) {
    return double.tryParse(get(key) ?? '') ?? fallback;
  }

  EnvironmentConfig merge(Map<String, String> values) {
    return EnvironmentConfig({...this.values, ...values});
  }
}

const env = EnvironmentConfig();
