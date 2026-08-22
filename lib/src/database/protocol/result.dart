import 'error.dart';

class FlintDbMeta {
  const FlintDbMeta({
    required this.requestId,
    this.count,
    this.nextCursor,
  });

  final String requestId;
  final int? count;
  final String? nextCursor;

  factory FlintDbMeta.fromJson(Map<String, dynamic> json) => FlintDbMeta(
        requestId: json['requestId']?.toString() ?? '',
        count: json['count'] is num ? (json['count'] as num).toInt() : null,
        nextCursor: json['nextCursor']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        if (count != null) 'count': count,
        'nextCursor': nextCursor,
      };
}

class FlintDbResult<T> {
  const FlintDbResult.success(this.data, this.meta) : error = null;
  const FlintDbResult.failure(this.error, this.meta) : data = null;

  final T? data;
  final FlintDbMeta meta;
  final FlintDbError? error;

  bool get isSuccess => error == null;

  factory FlintDbResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) parseData,
  ) {
    final meta = FlintDbMeta.fromJson(
      Map<String, dynamic>.from(json['meta'] as Map? ?? const {}),
    );
    final rawError = json['error'];
    if (rawError is Map) {
      return FlintDbResult.failure(
        FlintDbError.fromJson(Map<String, dynamic>.from(rawError)),
        meta,
      );
    }
    return FlintDbResult.success(parseData(json['data']), meta);
  }

  Map<String, dynamic> toJson(Object? Function(T data) serializeData) => {
        'data': data == null ? null : serializeData(data as T),
        'meta': meta.toJson(),
        'error': error?.toJson(),
      };
}
