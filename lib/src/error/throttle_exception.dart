import 'base_exception.dart';

class ThrottleError extends BaseException {
  final Map<String, String>? headers;

  ThrottleError({
    required String super.message,
    required super.code,
    this.headers,
  });
}
