import 'dart:io';

import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/error/base_exception.dart';

class ForbiddenException extends BaseException {
  ForbiddenException({
    super.message = 'Forbidden',
    super.code = HttpStatus.forbidden,
    super.responseType = RespondType.json,
  });
}

typedef ForbiddenErorr = ForbiddenException;
