import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flint_dart/src/storage/s3_config.dart';

/// S3 & MinIO client implementing AWS Signature Version 4 (SigV4).
class S3Client {
  final S3Config config;
  final HttpClient _httpClient;

  S3Client({required this.config, HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  /// Uploads raw bytes to S3/MinIO
  Future<String> putObject({
    required String key,
    required List<int> bytes,
    String? contentType,
    String? acl,
  }) async {
    final cleanKey = _sanitizeKey(key);
    final uri = _resolveUri(cleanKey);
    final payloadHash = sha256.convert(bytes).toString();

    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);

    final resolvedContentType =
        contentType ?? _detectContentType(cleanKey) ?? 'application/octet-stream';

    final headers = <String, String>{
      'host': _resolveHostHeader(uri),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'content-type': resolvedContentType,
      'content-length': bytes.length.toString(),
    };

    if (acl != null && acl.isNotEmpty) {
      headers['x-amz-acl'] = acl;
    }

    final authorization = _computeAuthorizationHeader(
      method: 'PUT',
      uri: uri,
      headers: headers,
      payloadHash: payloadHash,
      amzDate: amzDate,
      dateStamp: dateStamp,
    );

    final request = await _httpClient.putUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.headers.set('authorization', authorization);
    request.add(bytes);

    final response = await request.close();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return getPublicUrl(cleanKey);
    }

    final errorBody = await utf8.decodeStream(response);
    throw HttpException(
      'S3/MinIO putObject failed with status ${response.statusCode}: $errorBody',
      uri: uri,
    );
  }

  /// Deletes an object from S3/MinIO
  Future<void> deleteObject({required String key}) async {
    final cleanKey = _sanitizeKey(key);
    final uri = _resolveUri(cleanKey);
    final payloadHash = sha256.convert(const []).toString();

    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);

    final headers = <String, String>{
      'host': _resolveHostHeader(uri),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
    };

    final authorization = _computeAuthorizationHeader(
      method: 'DELETE',
      uri: uri,
      headers: headers,
      payloadHash: payloadHash,
      amzDate: amzDate,
      dateStamp: dateStamp,
    );

    final request = await _httpClient.deleteUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.headers.set('authorization', authorization);

    final response = await request.close();
    if (response.statusCode >= 200 && response.statusCode < 300 ||
        response.statusCode == 404) {
      return;
    }

    final errorBody = await utf8.decodeStream(response);
    throw HttpException(
      'S3/MinIO deleteObject failed with status ${response.statusCode}: $errorBody',
      uri: uri,
    );
  }

  /// Downloads object bytes from S3/MinIO
  Future<List<int>> getObject({required String key}) async {
    final cleanKey = _sanitizeKey(key);
    final uri = _resolveUri(cleanKey);
    final payloadHash = sha256.convert(const []).toString();

    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);

    final headers = <String, String>{
      'host': _resolveHostHeader(uri),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
    };

    final authorization = _computeAuthorizationHeader(
      method: 'GET',
      uri: uri,
      headers: headers,
      payloadHash: payloadHash,
      amzDate: amzDate,
      dateStamp: dateStamp,
    );

    final request = await _httpClient.getUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.headers.set('authorization', authorization);

    final response = await request.close();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final bytesBuilder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytesBuilder.add(chunk);
      }
      return bytesBuilder.takeBytes();
    }

    final errorBody = await utf8.decodeStream(response);
    throw HttpException(
      'S3/MinIO getObject failed with status ${response.statusCode}: $errorBody',
      uri: uri,
    );
  }

  /// Resolves the public URL for an object key
  String getPublicUrl(String key) {
    final cleanKey = _sanitizeKey(key);
    if (config.publicUrl != null && config.publicUrl!.isNotEmpty) {
      var base = config.publicUrl!;
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      return '$base/$cleanKey';
    }

    var base = config.endpoint.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    if (config.usePathStyle) {
      return '$base/${config.bucket}/$cleanKey';
    } else {
      final uri = Uri.parse(base);
      return '${uri.scheme}://${config.bucket}.${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/$cleanKey';
    }
  }

  // --- SigV4 Internals ---

  /// Generates the AWS SigV4 Authorization header string for a given request.
  String computeAuthorizationHeader({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String payloadHash,
    required String amzDate,
    required String dateStamp,
  }) =>
      _computeAuthorizationHeader(
        method: method,
        uri: uri,
        headers: headers,
        payloadHash: payloadHash,
        amzDate: amzDate,
        dateStamp: dateStamp,
      );

  String _computeAuthorizationHeader({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String payloadHash,
    required String amzDate,
    required String dateStamp,
  }) {
    // 1. Canonical Headers & Signed Headers
    final sortedHeaderKeys = headers.keys.map((k) => k.toLowerCase()).toList()..sort();
    final canonicalHeadersBuffer = StringBuffer();
    for (final k in sortedHeaderKeys) {
      final value = headers.entries
          .firstWhere((e) => e.key.toLowerCase() == k)
          .value
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      canonicalHeadersBuffer.write('$k:$value\n');
    }
    final signedHeaders = sortedHeaderKeys.join(';');

    // 2. Canonical URI
    final canonicalUri = uri.path.isEmpty ? '/' : uri.path;

    // 3. Canonical Query String
    final canonicalQuery = uri.hasQuery ? _canonicalQueryString(uri.queryParameters) : '';

    // 4. Canonical Request
    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQuery,
      canonicalHeadersBuffer.toString(),
      signedHeaders,
      payloadHash,
    ].join('\n');

    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    // 5. String to Sign
    final credentialScope = '$dateStamp/${config.region}/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    // 6. Signing Key
    final signingKey = _getSigningKey(
      secretKey: config.secretKey,
      dateStamp: dateStamp,
      region: config.region,
      service: 's3',
    );

    // 7. Signature
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    return 'AWS4-HMAC-SHA256 Credential=${config.accessKey}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';
  }

  List<int> _getSigningKey({
    required String secretKey,
    required String dateStamp,
    required String region,
    required String service,
  }) {
    final kSecret = utf8.encode('AWS4$secretKey');
    final kDate = Hmac(sha256, kSecret).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  String _canonicalQueryString(Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    return keys
        .map((k) => '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(query[k] ?? '')}')
        .join('&');
  }

  Uri _resolveUri(String cleanKey) {
    var base = config.endpoint.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    if (config.usePathStyle) {
      return Uri.parse('$base/${config.bucket}/$cleanKey');
    } else {
      final baseUri = Uri.parse(base);
      final host = '${config.bucket}.${baseUri.host}';
      return baseUri.replace(
        host: host,
        path: '/$cleanKey',
      );
    }
  }

  String _resolveHostHeader(Uri uri) {
    if (uri.hasPort &&
        !((uri.scheme == 'http' && uri.port == 80) ||
            (uri.scheme == 'https' && uri.port == 443))) {
      return '${uri.host}:${uri.port}';
    }
    return uri.host;
  }

  String _sanitizeKey(String key) {
    var clean = key.trim().replaceAll('\\', '/');
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  String _formatAmzDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min${s}Z';
  }

  String _formatDateStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String? _detectContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.zip')) return 'application/zip';
    return null;
  }
}
