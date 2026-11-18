import 'dart:io';

import 'package:flint_dart/src/error/base_exception.dart';
import 'package:flint_dart/src/response.dart';

class ForbiddenException extends BaseException {
  ForbiddenException({
    super.message = 'Forbidden',
    super.code = HttpStatus.forbidden,
    super.responseType = RespondType.json,
  });
}

typedef ForbiddenError = ForbiddenException;

@Deprecated('Use ForbiddenError instead.')
typedef ForbiddenErorr = ForbiddenException;
