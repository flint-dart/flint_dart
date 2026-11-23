import 'package:flint_dart/src/env_parser.dart';

/// Configuration for AWS S3 and MinIO compatible object storage.
class S3Config {
  final String endpoint;
  final String bucket;
  final String accessKey;
  final String secretKey;
  final String region;
  final bool usePathStyle;
  final String? publicUrl;

  const S3Config({
    required this.endpoint,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    this.region = 'us-east-1',
    this.usePathStyle = true,
    this.publicUrl,
  });

  /// Factory loading from environment variables with fallback support:
  /// - `S3_ENDPOINT` / `MINIO_ENDPOINT` (e.g. `https://s3.example.com`)
  /// - `S3_BUCKET` / `MINIO_BUCKET` (e.g. `my-bucket`)
  /// - `S3_ACCESS_KEY` / `MINIO_ACCESS_KEY` / `AWS_ACCESS_KEY_ID`
  /// - `S3_SECRET_KEY` / `MINIO_SECRET_KEY` / `AWS_SECRET_ACCESS_KEY`
  /// - `S3_REGION` / `MINIO_REGION` / `AWS_DEFAULT_REGION` (default: `us-east-1`)
  /// - `S3_USE_PATH_STYLE` / `MINIO_USE_PATH_STYLE` (default: `true` for MinIO)
  /// - `S3_PUBLIC_URL` / `MINIO_PUBLIC_URL` (optional custom CDN / public URL prefix)
  factory S3Config.fromEnv() {
    String firstOf(List<String> keys, [String defaultValue = '']) {
      for (final k in keys) {
        final val = FlintEnv.get(k, '').trim();
        if (val.isNotEmpty) return val;
      }
      return defaultValue;
    }

    final endpoint = firstOf(['S3_ENDPOINT', 'MINIO_ENDPOINT'], '');
    final bucket = firstOf(['S3_BUCKET', 'MINIO_BUCKET'], '');
    final accessKey = firstOf(['S3_ACCESS_KEY', 'MINIO_ACCESS_KEY', 'AWS_ACCESS_KEY_ID'], '');
    final secretKey = firstOf(['S3_SECRET_KEY', 'MINIO_SECRET_KEY', 'AWS_SECRET_ACCESS_KEY'], '');
    final region = firstOf(['S3_REGION', 'MINIO_REGION', 'AWS_DEFAULT_REGION', 'AWS_REGION'], 'us-east-1');
    final usePathStyle = FlintEnv.getBool('S3_USE_PATH_STYLE', FlintEnv.getBool('MINIO_USE_PATH_STYLE', true));
    final publicUrlRaw = firstOf(['S3_PUBLIC_URL', 'MINIO_PUBLIC_URL'], '');

    return S3Config(
      endpoint: endpoint,
      bucket: bucket,
      accessKey: accessKey,
      secretKey: secretKey,
      region: region.isNotEmpty ? region : 'us-east-1',
      usePathStyle: usePathStyle,
      publicUrl: publicUrlRaw.isNotEmpty ? publicUrlRaw : null,
    );
  }

  bool get isValid =>
      endpoint.isNotEmpty &&
      bucket.isNotEmpty &&
      accessKey.isNotEmpty &&
      secretKey.isNotEmpty;
}
