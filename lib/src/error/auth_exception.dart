import 'dart:io';

import 'package:flint_dart/src/error/base_exception.dart';
import 'package:flint_dart/src/response.dart';

class AuthException extends BaseException {
  AuthException({
    super.message = 'Unauthorized',
    super.code = HttpStatus.unauthorized,
    super.responseType = RespondType.json,
  });

  @override
  String toString() => 'AuthException: $message';
}
