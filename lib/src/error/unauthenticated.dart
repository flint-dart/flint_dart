import 'dart:io';

import 'package:flint_dart/src/error/auth_exception.dart';

class Unauthenticated extends AuthException {
  Unauthenticated({super.code = HttpStatus.unauthorized});
}
