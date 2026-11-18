import 'dart:io';
import 'package:flint_dart/src/response.dart';
import 'base_exception.dart';

class NotFoundException extends BaseException {
  NotFoundException({
    super.message = 'Not Found',
    super.code = HttpStatus.notFound,
    super.responseType = RespondType.html,
  });
}
