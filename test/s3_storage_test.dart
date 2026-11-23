import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

void main() {
  group('S3Config & S3Client Unit Tests', () {
    test('S3Config initializes with provided values and defaults', () {
      const config = S3Config(
        endpoint: 'https://s3.example.com',
        bucket: 'test-bucket',
        accessKey: 'test_access_key',
        secretKey: 'test_secret_key',
        region: 'us-east-1',
        usePathStyle: true,
      );

      expect(config.endpoint, equals('https://s3.example.com'));
      expect(config.bucket, equals('test-bucket'));
      expect(config.accessKey, equals('test_access_key'));
      expect(config.secretKey, equals('test_secret_key'));
      expect(config.region, equals('us-east-1'));
      expect(config.usePathStyle, isTrue);
    });

    test('S3Client generates correct path-style URLs for MinIO', () {
      const config = S3Config(
        endpoint: 'https://s3.example.com',
        bucket: 'test-bucket',
        accessKey: 'test_key',
        secretKey: 'test_secret',
        usePathStyle: true,
      );
      final client = S3Client(config: config);

      final url = client.getPublicUrl('uploads/images/banner.png');
      expect(url, equals('https://s3.example.com/test-bucket/uploads/images/banner.png'));
    });

    test('S3Client respects custom publicUrl CDN prefix if configured', () {
      const config = S3Config(
        endpoint: 'https://s3.example.com',
        bucket: 'test-bucket',
        accessKey: 'test_key',
        secretKey: 'test_secret',
        publicUrl: 'https://cdn.example.com',
      );
      final client = S3Client(config: config);

      final url = client.getPublicUrl('content/document.pdf');
      expect(url, equals('https://cdn.example.com/content/document.pdf'));
    });

    test('Storage.disk routes minio to s3 driver', () {
      final s3Driver = Storage.disk('s3');
      final minioDriver = Storage.disk('minio');

      expect(s3Driver, isA<S3StorageDriver>());
      expect(minioDriver, isA<S3StorageDriver>());
      expect(identical(s3Driver, minioDriver), isTrue);
    });

    test('Storage.disk local returns LocalStorageDriver', () {
      final localDriver = Storage.disk('local');
      expect(localDriver, isA<LocalStorageDriver>());
    });

    test('S3Client builds AWS SigV4 auth headers correctly', () {
      const config = S3Config(
        endpoint: 'https://s3.example.com',
        bucket: 'test-bucket',
        accessKey: 'AKIAIOSFODNN7EXAMPLE',
        secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        region: 'us-east-1',
      );
      final client = S3Client(config: config);
      final sampleBytes = utf8.encode('Hello MinIO Object Storage');
      final payloadHash = sha256.convert(sampleBytes).toString();
      final uri = Uri.parse('https://s3.example.com/test-bucket/test/file.txt');

      final authHeader = client.computeAuthorizationHeader(
        method: 'PUT',
        uri: uri,
        headers: {
          'host': 's3.example.com',
          'x-amz-date': '20261123T120000Z',
          'x-amz-content-sha256': payloadHash,
          'content-type': 'text/plain',
        },
        payloadHash: payloadHash,
        amzDate: '20261123T120000Z',
        dateStamp: '20261123',
      );

      expect(authHeader, startsWith('AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20261123/us-east-1/s3/aws4_request'));
      expect(authHeader, contains('SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date'));
      expect(authHeader, contains('Signature='));
    });

    test('Storage putString and getString read/write text content on LocalStorageDriver', () async {
      Storage.reset();
      const content = '# Competitor Briefing\n- Strengths: Fast\n- Pricing: \$10/mo';
      final path = await Storage.disk('local').putString(
        content,
        filename: 'briefing_test.md',
        subdirectory: 'test-research',
      );

      expect(path, contains('briefing_test'));
      expect(path, endsWith('.md'));

      final exists = await Storage.disk('local').exists(path);
      expect(exists, isTrue);

      final readContent = await Storage.disk('local').getString(path);
      expect(readContent, equals(content));

      final readBytes = await Storage.disk('local').getBytes(path);
      expect(utf8.decode(readBytes), equals(content));

      await Storage.disk('local').delete(path);
      final existsAfterDelete = await Storage.disk('local').exists(path);
      expect(existsAfterDelete, isFalse);
    });
  });
}
