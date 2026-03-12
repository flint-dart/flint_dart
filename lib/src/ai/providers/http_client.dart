import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Normalized HTTP transport error used by AI providers.
class AiHttpException implements Exception {
  final String message;
  final Object? cause;

  const AiHttpException(this.message, {this.cause});

  @override
  String toString() => 'AiHttpException: $message';
}

/// Immutable outbound AI HTTP request.
class AiHttpRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;

  const AiHttpRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.body,
  });
}

/// Immutable AI HTTP response wrapper.
class AiHttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  const AiHttpResponse({
    required this.statusCode,
    this.headers = const {},
    this.body = '',
  });

  /// Whether the response status is in the 2xx range.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Decodes the response body as JSON.
  dynamic jsonBody() {
    if (body.trim().isEmpty) return const <String, dynamic>{};
    return jsonDecode(body);
  }
}

/// Contract for HTTP clients used by AI providers.
abstract class AiHttpClient {
  Future<AiHttpResponse> send(AiHttpRequest request);
}

/// Retry configuration for provider HTTP requests.
class AiRetryPolicy {
  final int maxAttempts;
  final Duration baseDelay;
  final bool Function(AiHttpResponse response) shouldRetryResponse;
  final bool Function(Object error) shouldRetryError;

  const AiRetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
    this.shouldRetryResponse = _defaultRetryResponse,
    this.shouldRetryError = _defaultRetryError,
  });

  static bool _defaultRetryResponse(AiHttpResponse response) {
    return response.statusCode == 429 || response.statusCode >= 500;
  }

  static bool _defaultRetryError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is AiHttpException;
  }
}

/// Default `dart:io` based HTTP client for provider adapters.
class DartIoAiHttpClient implements AiHttpClient {
  final Duration timeout;

  DartIoAiHttpClient({
    this.timeout = const Duration(seconds: 30),
  });

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    final client = HttpClient();
    try {
      final req = await client
          .openUrl(request.method.toUpperCase(), request.uri)
          .timeout(timeout);

      request.headers.forEach(req.headers.set);

      final body = request.body;
      if (body != null) {
        if (body is List<int>) {
          req.add(body);
        } else {
          req.write(body.toString());
        }
      }

      final response = await req.close().timeout(timeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      final responseBody = await utf8.decoder.bind(response).join();
      return AiHttpResponse(
        statusCode: response.statusCode,
        headers: responseHeaders,
        body: responseBody,
      );
    } on SocketException catch (error) {
      throw AiHttpException('Network request failed', cause: error);
    } on TimeoutException catch (error) {
      throw AiHttpException('HTTP request timed out', cause: error);
    } finally {
      client.close(force: true);
    }
  }
}

/// HTTP client wrapper that retries transient provider failures.
class RetryingAiHttpClient implements AiHttpClient {
  final AiHttpClient inner;
  final AiRetryPolicy retryPolicy;

  RetryingAiHttpClient(
    this.inner, {
    this.retryPolicy = const AiRetryPolicy(),
  });

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    Object? lastError;

    for (var attempt = 1; attempt <= retryPolicy.maxAttempts; attempt++) {
      try {
        final response = await inner.send(request);
        if (attempt < retryPolicy.maxAttempts &&
            retryPolicy.shouldRetryResponse(response)) {
          await Future.delayed(_delayForAttempt(attempt));
          continue;
        }
        return response;
      } catch (error) {
        lastError = error;
        if (attempt >= retryPolicy.maxAttempts ||
            !retryPolicy.shouldRetryError(error)) {
          rethrow;
        }
        await Future.delayed(_delayForAttempt(attempt));
      }
    }

    throw AiHttpException(
      'HTTP request failed after ${retryPolicy.maxAttempts} attempts',
      cause: lastError,
    );
  }

  Duration _delayForAttempt(int attempt) {
    final multiplier = attempt <= 1 ? 1 : 1 << (attempt - 1);
    return Duration(
      milliseconds: retryPolicy.baseDelay.inMilliseconds * multiplier,
    );
  }
}
