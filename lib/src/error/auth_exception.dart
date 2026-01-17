import 'dart:io';

import 'package:flint_dart/exception.dart';
import 'package:flint_dart/src/response.dart';

class AuthException extends BaseException {
  AuthException({
    super.message = 'Not Fount 404',
    super.code = HttpStatus.forbidden,
    super.responseType = RespondType.json,
  });

  @override
  String toString() => 'AuthException: $message';
}
