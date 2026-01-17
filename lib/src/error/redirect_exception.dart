import 'dart:io';
import 'package:flint_dart/flint_dart.dart';

import 'base_exception.dart';

class RedirectError extends BaseException {
  RedirectError({
    super.message,
    super.code = HttpStatus.found,
    super.responseType = RespondType.html,
  });
}
