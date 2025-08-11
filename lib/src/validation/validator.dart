class ValidationException implements Exception {
  final Map<String, List<String>> errors;
  ValidationException(this.errors);

  @override
  String toString() => 'ValidationException: $errors';
}

class Validator {
  static Future<void> validate(
      Map<String, dynamic> data, Map<String, String> rules) async {
    if (rules.isEmpty) return;

    final errors = <String, List<String>>{};

    bool isInt(num? value) => value is int;
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
      // num? minValue;
      // num? maxValue;
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
