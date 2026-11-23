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

  /// Factory loading from environment variables:
  /// - `S3_ENDPOINT` (e.g. `https://s3.eulogia.net`)
  /// - `S3_BUCKET` (e.g. `eulogia`)
  /// - `S3_ACCESS_KEY`
  /// - `S3_SECRET_KEY`
  /// - `S3_REGION` (default: `us-east-1`)
  /// - `S3_USE_PATH_STYLE` (default: `true` for MinIO)
  /// - `S3_PUBLIC_URL` (optional custom CDN / public URL prefix)
  factory S3Config.fromEnv() {
    final endpoint = FlintEnv.get('S3_ENDPOINT', 'https://s3.eulogia.net').trim();
    final bucket = FlintEnv.get('S3_BUCKET', 'eulogia').trim();
    final accessKey = FlintEnv.get('S3_ACCESS_KEY', '').trim();
    final secretKey = FlintEnv.get('S3_SECRET_KEY', '').trim();
    final region = FlintEnv.get('S3_REGION', 'us-east-1').trim();
    final usePathStyle = FlintEnv.getBool('S3_USE_PATH_STYLE', true);
    final publicUrlRaw = FlintEnv.get('S3_PUBLIC_URL', '').trim();

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
