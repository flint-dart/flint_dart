import 'dart:io';

import 'base_exception.dart';

class ValidationError extends BaseException {
  ValidationError({
    required super.message,
    super.code = HttpStatus.unprocessableEntity,
  });
}
