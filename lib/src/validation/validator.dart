/// An exception that is thrown when validation fails.
///
/// Contains a map of validation errors, where each key is the field name
/// and the value is a list of error messages for that field.
///
/// Example:
/// ```dart
/// try {
///   await Validator.validate(data, {
///     "email": "required|string|email",
///   });
/// } on ValidationException catch (e) {
///   print(e.errors); // { "email": ["The email field is required."] }
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
///   "email": "required|string|email|min:3",
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
  static Future<void> validate(
      Map<String, dynamic> data, Map<String, String> rules) async {
    if (rules.isEmpty) return;

    final errors = <String, List<String>>{};

    // 🔹 1. Check for unknown fields
    for (final key in data.keys) {
      // Skip confirmation fields like "password_confirmation" or "confirm_password"
      if (key.endsWith('_confirmation') || key.startsWith('confirm_')) continue;

      if (!rules.containsKey(key)) {
        errors
            .putIfAbsent(key, () => [])
            .add('The field "$key" is not allowed.');
      }
    }
    bool isInt(num? value) => value is int;
    bool isDouble(num? value) => value is double;
    bool isString(dynamic value) => value is String;
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
            errors
                .putIfAbsent(field, () => [])
                .add('The $field field is required.');
          }
        } else if (part == 'string') {
          if (value != null && !isString(value)) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be a string.');
          }
        } else if (part == 'int') {
          if (value != null && !isInt(value)) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be an integer.');
          }
        } else if (part == 'double') {
          if (value != null && !isDouble(value)) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be an double.');
          }
        } else if (part == 'bool') {
          if (value != null && !isBool(value)) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be a boolean.');
          }
        } else if (part == 'email') {
          if (value != null &&
              isString(value) &&
              !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be a valid email address.');
          }
        } else if (part.startsWith('regex:')) {
          final pattern = part.substring(6);
          try {
            regex = RegExp(pattern);
            if (value != null && isString(value) && !regex.hasMatch(value)) {
              errors
                  .putIfAbsent(field, () => [])
                  .add('The $field format is invalid.');
            }
          } catch (e) {
            errors
                .putIfAbsent(field, () => [])
                .add('Invalid regex pattern for $field.');
          }
        } else if (part == 'list') {
          isListType = true;
          if (value != null && !isList(value)) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be a list.');
          }
        } else if (part.startsWith('list:')) {
          isListType = true;
          listItemType = part.substring('list:'.length);
          if (value != null && isList(value)) {
            for (var item in value) {
              if (listItemType == 'string' && item is! String) {
                errors
                    .putIfAbsent(field, () => [])
                    .add('All items in $field must be strings.');
                break;
              }
              if (listItemType == 'int' && item is! int) {
                errors
                    .putIfAbsent(field, () => [])
                    .add('All items in $field must be integers.');
                break;
              }
              if (listItemType == 'double' && item is! double) {
                errors
                    .putIfAbsent(field, () => [])
                    .add('All items in $field must be double.');
                break;
              }
              if (listItemType == 'bool' && item is! bool) {
                errors
                    .putIfAbsent(field, () => [])
                    .add('All items in $field must be booleans.');
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
            errors
                .putIfAbsent(field, () => [])
                .add('The $confirmField field is required for confirmation.');
          }
          // When it exists but doesn’t match
          else if (data[confirmField] != value) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field confirmation does not match.');
          }
        }
      }

      if (value != null) {
        if (isListType && value is List) {
          if (minLength != null && value.length < minLength) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field list must have at least $minLength items.');
          }
          if (maxLength != null && value.length > maxLength) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field list must have at most $maxLength items.');
          }
        } else if (value is String) {
          if (minLength != null && value.length < minLength) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be at least $minLength characters.');
          }
          if (maxLength != null && value.length > maxLength) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be at most $maxLength characters.');
          }
        } else if (value is num) {
          if (minLength != null && value < minLength) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be at least $minLength.');
          }
          if (maxLength != null && value > maxLength) {
            errors
                .putIfAbsent(field, () => [])
                .add('The $field must be at most $maxLength.');
          }
        }
      }
    });

    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }
}
