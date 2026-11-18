import 'package:flint_client/flint_client.dart';

class FlintDbApiException implements Exception {
  const FlintDbApiException(
    this.code,
    this.message, {
    this.statusCode = 400,
    this.details,
  });

  final FlintDbErrorCode code;
  final String message;
  final int statusCode;
  final Object? details;

  FlintDbError toProtocolError() => FlintDbError(
        code: code,
        message: message,
        details: details,
      );

  @override
  String toString() => 'FlintDbApiException(${code.value}): $message';
}
