class HttpException implements Exception {
  final int status;
  final String message;
  final dynamic data;

  HttpException(this.status, this.message, {this.data});

  @override
  String toString() => message;
}
