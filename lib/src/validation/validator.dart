/// An exception that is thrown when validation fails.
///
/// Contains a map of validation errors, where each key is the field name
/// and the value is a list of error messages for that field.
///
/// Example:
/// ```dart
/// try {
///   await Validator.validate(data, {
///     "email": "required|email",
///   });
/// } on ValidationException catch (e) {
///   Log.debug(e.errors); // { "email": ["The email field is required."] }
/// }
/// ```
class ValidationException implements Exception {
  /// The map of validation errors.
  ///
  /// Key: field name
  /// Value: list of error messages
  final Map<String, List<String>> errors;

  /// Creates a [ValidationException] with the given [errors].
  ValidationException(this.errors);

  @override
  String toString() => 'ValidationException: $errors';
}

/// A utility class for validating input data against a set of rules.
///
/// The rules use a pipe-separated format (e.g., `"required|string|min:3"`)
/// and support the following checks:
///
/// - `required`: Field must be present and not empty.
/// - `string`: Value must be a string.
/// - `int`: Value must be an integer.
/// - `bool`: Value must be a boolean.
/// - `email`: Must be a valid email address.
/// - `regex:<pattern>`: Value must match the given regular expression.
/// - `list`: Value must be a list.
/// - `list:<type>`: All items in the list must match the given type
///   (`string`, `int`, `bool`).
/// - `min:<n>`: Minimum length (for strings/lists) or value (for numbers).
/// - `max:<n>`: Maximum length (for strings/lists) or value (for numbers).
///
/// Example:
/// ```dart
/// final body = {
///   "email": "test@example.com",
///   "name": "John Doe",
///   "password": "secret123"
/// };
///
/// await Validator.validate(body, {
///   "email": "required|email|min:3",
///   "name": "required|string|min:5",
///   "password": "required|string|min:8"
/// });
/// ```
class Validator {
  /// Validates the given [data] against the provided [rules].
  ///
  /// Throws a [ValidationException] if any validation errors are found.
  ///
  /// [data] is a `Map<String, dynamic>` containing the input data.
  /// [rules] is a `Map<String, String>` where the key is the field name
  /// and the value is a pipe-separated list of validation rules.
  ///
  /// [messages] is an optional map of custom messages. Keys can be:
  /// - `field.rule` (most specific, e.g. `email.required`)
  /// - `field` (field-wide fallback)
  /// - `rule` (global fallback, e.g. `required`)
  ///
  /// You can also use `:field`, `:min`, `:max`, and `:value` placeholders
  /// in custom messages.
  ///
  /// A utility class for validating input data against a set of rules.
  ///
  /// The rules use a pipe-separated format (e.g., `"required|string|min:3"`)
  /// and support the following checks:
  ///
  /// - `required`: Field must be present and not empty.
  /// - `string`: Value must be a string.
  /// - `int`: Value must be an integer.
  /// - `double`: Value must be an integer.
  /// - `bool`: Value must be a boolean.
  /// - `email`: Must be a valid email address.
  /// - `regex:<pattern>`: Value must match the given regular expression.
  /// - `list`: Value must be a list.
  /// - `list:<type>`: All items in the list must match the given type
  ///   (`string`, `int`, `bool`).
  /// - `confirmed` — Field must have a matching confirmation field (`confirm_field` or `field_confirmation`).
  /// - `min:<n>`: Minimum length (for strings/lists) or value (for numbers).
  /// - `max:<n>`: Maximum length (for strings/lists) or value (for numbers).
  ///
  /// Example:
  /// ```dart
  /// final body = {
  ///   "email": "test@example.com",
  ///   "name": "John Doe",
  ///   "password": "secret123"
  /// };
  ///
  /// await Validator.validate(
  ///   body,
  ///   {
  ///     "email": "required|email|min:3",
  ///     "name": "required|string|min:5",
  ///     "password": "required|string|min:8"
  ///   },
  ///   messages: {
  ///     "email.required": "Email is required.",
  ///     "email.email": "Enter a valid email address.",
  ///     "min": ":field is too short (min :min)."
  ///   },
  /// );
  static Future<void> validate(
    Map<String, dynamic> data,
    Map<String, String> rules, {
    Map<String, String>? messages,
  }) async {
    if (rules.isEmpty) return;

    final errors = <String, List<String>>{};

    String formatMessage(
      String template, {
      String? field,
      int? min,
      int? max,
      Object? value,
    }) {
      var result = template;
      if (field != null) result = result.replaceAll(':field', field);
      if (min != null) result = result.replaceAll(':min', min.toString());
      if (max != null) result = result.replaceAll(':max', max.toString());
      if (value != null) result = result.replaceAll(':value', value.toString());
      return result;
    }

    String? resolveMessage(String field, List<String> keys) {
      if (messages == null) return null;
      for (final key in keys) {
        final message = messages[key];
        if (message != null) return message;
      }
      return null;
    }

    void _addError(
      String field,
      String ruleKey,
      String defaultMessage, {
      int? min,
      int? max,
      Object? value,
    }) {
      final custom = resolveMessage(
        field,
        [
          '$field.$ruleKey',
          field,
          ruleKey,
        ],
      );
      final message = formatMessage(
        custom ?? defaultMessage,
        field: field,
        min: min,
        max: max,
        value: value,
      );
      errors.putIfAbsent(field, () => []).add(message);
    }

    // 🔹 1. Check for unknown fields
    for (final key in data.keys) {
      // Skip confirmation fields like "password_confirmation" or "confirm_password"
      if (key.endsWith('_confirmation') || key.startsWith('confirm_')) continue;

      if (!rules.containsKey(key)) {
        _addError(
          key,
          'unknown',
          'The field "$key" is not allowed.',
          value: data[key],
        );
      }
    }
    bool isInt(dynamic value) => value is int;
    bool isDouble(dynamic value) => value is double;
    bool isString(dynamic value) => value is String;
    bool isNotString(dynamic value) => value is! String;
    bool isList(dynamic value) => value is List;
    bool isBool(dynamic value) => value is bool;

    rules.forEach((field, rule) {
      final value = data[field];
      final ruleParts = rule.split('|');

      bool isListType = false;
      String? listItemType;
      int? minLength;
      int? maxLength;
      RegExp? regex;

      for (var part in ruleParts) {
        if (part == 'required') {
          if (value == null || (value is String && value.isEmpty)) {
            _addError(
              field,
              'required',
              'The $field field is required.',
              value: value,
            );
          }
        } else if (part == 'string') {
          if (value != null && !isString(value)) {
            _addError(
              field,
              'string',
              'The $field must be a string.',
              value: value,
            );
          }
        } else if (part == 'int') {
          if (value != null && !isInt(value)) {
            _addError(
              field,
              'int',
              'The $field must be an integer.',
              value: value,
            );
          }
        } else if (part == 'double') {
          if (value != null && !isDouble(value)) {
            _addError(
              field,
              'double',
              'The $field must be an double.',
              value: value,
            );
          }
        } else if (part == 'bool') {
          if (value != null && !isBool(value)) {
            _addError(
              field,
              'bool',
              'The $field must be a boolean.',
              value: value,
            );
          }
        } else if (part == 'email') {
          if (isNotString(value) ||
              value != null &&
                  isString(value) &&
                  !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
            _addError(
              field,
              'email',
              'The $field must be a valid email address.',
              value: value,
            );
          }
        } else if (part.startsWith('regex:')) {
          final pattern = part.substring(6);
          try {
            regex = RegExp(pattern);
            if (value != null && isString(value) && !regex.hasMatch(value)) {
              _addError(
                field,
                'regex',
                'The $field format is invalid.',
                value: value,
              );
            }
          } catch (e) {
            _addError(
              field,
              'regex',
              'Invalid regex pattern for $field.',
              value: value,
            );
          }
        } else if (part == 'list') {
          isListType = true;
          if (value != null && !isList(value)) {
            _addError(
              field,
              'list',
              'The $field must be a list.',
              value: value,
            );
          }
        } else if (part.startsWith('list:')) {
          isListType = true;
          listItemType = part.substring('list:'.length);
          if (value != null && isList(value)) {
            for (var item in value) {
              if (listItemType == 'string' && item is! String) {
                _addError(
                  field,
                  'list:$listItemType',
                  'All items in $field must be strings.',
                  value: value,
                );
                break;
              }
              if (listItemType == 'int' && item is! int) {
                _addError(
                  field,
                  'list:$listItemType',
                  'All items in $field must be integers.',
                  value: value,
                );
                break;
              }
              if (listItemType == 'double' && item is! double) {
                _addError(
                  field,
                  'list:$listItemType',
                  'All items in $field must be double.',
                  value: value,
                );
                break;
              }
              if (listItemType == 'bool' && item is! bool) {
                _addError(
                  field,
                  'list:$listItemType',
                  'All items in $field must be booleans.',
                  value: value,
                );
                break;
              }
            }
          }
        } else if (part.startsWith('min:')) {
          final val = int.tryParse(part.substring(4));
          if (val != null) minLength = val;
        } else if (part.startsWith('max:')) {
          final val = int.tryParse(part.substring(4));
          if (val != null) maxLength = val;
        } else if (part == 'confirmed') {
          // Support both "password_confirmation" and "confirm_password"
          final confirmField = data.containsKey('${field}_confirmation')
              ? '${field}_confirmation'
              : 'confirm_$field';

          // When confirmation field does not exist
          if (!data.containsKey(confirmField)) {
            _addError(
              field,
              'confirmed',
              'The $confirmField field is required for confirmation.',
              value: value,
            );
          }
          // When it exists but doesn’t match
          else if (data[confirmField] != value) {
            _addError(
              field,
              'confirmed',
              'The $field confirmation does not match.',
              value: value,
            );
          }
        } else if (part == 'date') {
          if (value != null) {
            if (value is! DateTime) {
              try {
                DateTime.parse(value.toString());
              } catch (_) {
                _addError(
                  field,
                  'date',
                  'The $field must be a valid date.',
                  value: value,
                );
              }
            }
          }
        }
        // ✅ NEW: in:<a,b,c>
        else if (part.startsWith('in:')) {
          final allowed = part.substring(3).split(',');
          if (value != null && !allowed.contains(value.toString())) {
            _addError(
              field,
              'in',
              'The $field must be one of: ${allowed.join(', ')}.',
              value: value,
            );
          }
        } else if (part.startsWith('not_in:')) {
          final options = part.split(':')[1].split(',');
          if (options.contains(value.toString())) {
            _addError(
              field,
              'not_in',
              'The $field must not be one of: ${options.join(', ')}.',
              value: value,
            );
          }
        }
      }

      if (value != null) {
        if (isListType && value is List) {
          if (minLength != null && value.length < minLength) {
            _addError(
              field,
              'min',
              'The $field list must have at least $minLength items.',
              min: minLength,
              value: value,
            );
          }
          if (maxLength != null && value.length > maxLength) {
            _addError(
              field,
              'max',
              'The $field list must have at most $maxLength items.',
              max: maxLength,
              value: value,
            );
          }
        } else if (value is String) {
          if (minLength != null && value.length < minLength) {
            _addError(
              field,
              'min',
              'The $field must be at least $minLength characters.',
              min: minLength,
              value: value,
            );
          }
          if (maxLength != null && value.length > maxLength) {
            _addError(
              field,
              'max',
              'The $field must be at most $maxLength characters.',
              max: maxLength,
              value: value,
            );
          }
        } else if (value is num) {
          if (minLength != null && value < minLength) {
            _addError(
              field,
              'min',
              'The $field must be at least $minLength.',
              min: minLength,
              value: value,
            );
          }
          if (maxLength != null && value > maxLength) {
            _addError(
              field,
              'max',
              'The $field must be at most $maxLength.',
              max: maxLength,
              value: value,
            );
          }
        }
      }
    });

    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }
}
