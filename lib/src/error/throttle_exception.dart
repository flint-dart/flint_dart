import 'base_http_error.dart';

class ThrottleError extends BaseHttpResponseErorr {
  final Map<String, String>? headers;

  ThrottleError({
    required String super.message,
    required super.code,
    this.headers,
  });
}
