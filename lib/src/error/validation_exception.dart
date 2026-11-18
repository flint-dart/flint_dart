import 'dart:io';

import 'base_exception.dart';

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
class ValidationException extends BaseException {
  /// The map of validation errors.
  ///
  /// Key: field name
  /// Value: list of error messages
  final Map<String, List<String>> errors;

  /// Creates a [ValidationException] with the given [errors].
  ValidationException(
    this.errors, {
    dynamic message,
    super.code = HttpStatus.unprocessableEntity,
  }) : super(message: message ?? errors);

  @override
  String toString() => 'ValidationException: $errors';
}

class ValidationError extends ValidationException {
  ValidationError({
    required Map<String, List<String>> errors,
    dynamic message,
    super.code = HttpStatus.unprocessableEntity,
  }) : super(errors, message: message);
}
