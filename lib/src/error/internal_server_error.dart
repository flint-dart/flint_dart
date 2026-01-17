import 'dart:io';
import 'base_exception.dart';

class InternalServerError extends BaseException {
  InternalServerError({
    required super.message,
    super.code = HttpStatus.internalServerError,
  });
}
