import 'dart:io';

import 'package:flint_dart/flint_dart.dart';

class ForbiddenException extends BaseException {
  ForbiddenException({
    super.message = 'Forbidden',
    super.code = HttpStatus.forbidden,
    super.responseType = RespondType.json,
  });
}

typedef ForbiddenErorr = ForbiddenException;
