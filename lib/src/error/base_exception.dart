import 'package:flint_dart/src/response.dart';

class BaseException {
  final dynamic message;
  final RespondType responseType;
  final int code;

  const BaseException({
    required this.message,
    required this.code,
    this.responseType = RespondType.json,
  });
}
