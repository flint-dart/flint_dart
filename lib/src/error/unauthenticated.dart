import 'dart:io';

import 'package:flint_dart/src/error/auth_exception.dart';

class Unauthenticated extends AuthException {
  Unauthenticated({
    super.message = 'Unauthenticated',
    super.code = HttpStatus.unauthorized,
  });
}
