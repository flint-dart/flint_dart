enum FlintDbErrorCode {
  invalidRequest('invalid_request'),
  authenticationRequired('authentication_required'),
  invalidToken('invalid_token'),
  permissionDenied('permission_denied'),
  resourceNotFound('resource_not_found'),
  recordNotFound('record_not_found'),
  conflict('conflict'),
  validationFailed('validation_failed'),
  queryLimitExceeded('query_limit_exceeded'),
  rateLimited('rate_limited'),
  transactionFailed('transaction_failed'),
  internalError('internal_error');

  const FlintDbErrorCode(this.value);
  final String value;

  static FlintDbErrorCode fromValue(String value) => values.firstWhere(
        (code) => code.value == value,
        orElse: () => FlintDbErrorCode.internalError,
      );
}

class FlintDbError {
  const FlintDbError({
    required this.code,
    required this.message,
    this.details,
  });

  final FlintDbErrorCode code;
  final String message;
  final Object? details;

  factory FlintDbError.fromJson(Map<String, dynamic> json) => FlintDbError(
        code: FlintDbErrorCode.fromValue(json['code']?.toString() ?? ''),
        message: json['message']?.toString() ?? 'Unknown Flint DB error.',
        details: json['details'],
      );

  Map<String, dynamic> toJson() => {
        'code': code.value,
        'message': message,
        'details': details,
      };
}
