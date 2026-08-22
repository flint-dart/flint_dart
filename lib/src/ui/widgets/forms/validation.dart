/// Collection of validation messages keyed by form field name.
class FormErrors {
  final Map<String, List<String>> _messages;

  /// Creates a validation error collection from normalized messages.
  const FormErrors([Map<String, List<String>> messages = const {}])
    : _messages = messages;

  /// Creates validation errors from common error response shapes.
  factory FormErrors.from(Object? value) {
    if (value == null) return const FormErrors();
    if (value is FormErrors) return value;
    if (value is Map<String, String>) {
      return FormErrors({
        for (final entry in value.entries) entry.key: [entry.value],
      });
    }
    if (value is Map) {
      final source = _extractErrorMap(value);
      return FormErrors({
        for (final entry in source.entries)
          entry.key.toString(): _normalizeMessages(entry.value),
      });
    }

    return const FormErrors();
  }

  /// Creates validation errors from a JSON-like map.
  factory FormErrors.fromJson(Map<String, Object?> json) {
    return FormErrors.from(json);
  }

  /// Immutable validation messages keyed by field name.
  Map<String, List<String>> get messages => Map.unmodifiable(_messages);

  /// Whether there are no validation messages.
  bool get isEmpty => _messages.isEmpty;

  /// Whether there is at least one validation message.
  bool get isNotEmpty => _messages.isNotEmpty;

  /// Returns all validation messages for [name].
  List<String> fieldMessages(String? name) {
    if (name == null || name.isEmpty) return const [];
    return List.unmodifiable(_messages[name] ?? const []);
  }

  /// Returns the first validation message for [name], if any.
  String? field(String? name) {
    final messages = fieldMessages(name);
    return messages.isEmpty ? null : messages.first;
  }

  /// Whether [name] has at least one validation message.
  bool has(String? name) => fieldMessages(name).isNotEmpty;

  /// Combines this error collection with [other].
  FormErrors merge(FormErrors other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;

    return FormErrors({
      ..._messages,
      for (final entry in other._messages.entries)
        entry.key: [...(_messages[entry.key] ?? const []), ...entry.value],
    });
  }

  /// Returns a copy without errors for [keys].
  FormErrors without([List<String> keys = const []]) {
    if (keys.isEmpty) return const FormErrors();
    return FormErrors(
      {..._messages}..removeWhere((key, _) => keys.contains(key)),
    );
  }

  /// First validation message for each field.
  Map<String, String> get firstMessages => {
    for (final entry in _messages.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.first,
  };

  /// Converts validation messages to a JSON-like map.
  Map<String, Object?> toJson() => {
    for (final entry in _messages.entries) entry.key: entry.value,
  };
}

/// Resolves an explicit field error before falling back to [errors].
String? resolveFieldError({
  required String? name,
  String? error,
  FormErrors? errors,
}) {
  if (error != null && error.isNotEmpty) return error;
  return errors?.field(name);
}

Map _extractErrorMap(Map value) {
  final nested = value['errors'];

  if (nested is Map) return nested;
  return value;
}

List<String> _normalizeMessages(Object? value) {
  if (value == null) return const [];

  if (value is String) return [value];

  if (value is Iterable) {
    return [
      for (final item in value)
        if (item != null && item.toString().isNotEmpty) item.toString(),
    ];
  }
  return [value.toString()];
}
