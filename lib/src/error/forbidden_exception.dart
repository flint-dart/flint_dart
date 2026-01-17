import 'dart:io';

import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/error/base_exception.dart';

class ForbiddenErorr extends BaseException {
  ForbiddenErorr({
    super.message = 'Forbidden',
    super.code = HttpStatus.forbidden,
    super.responseType = RespondType.json,
  });
}
