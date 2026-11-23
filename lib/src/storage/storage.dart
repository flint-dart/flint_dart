import 'dart:convert';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/storage/s3_client.dart';
import 'package:flint_dart/src/storage/s3_config.dart';
import 'package:flint_dart/src/storage/storage_driver.dart';
import 'package:flint_dart/src/storage/uploaded_file.dart';

export 'package:flint_dart/src/storage/s3_client.dart';
export 'package:flint_dart/src/storage/s3_config.dart';
export 'package:flint_dart/src/storage/storage_driver.dart';

/// Handles file storage operations for uploaded files in Flint Dart.
///
/// Supports multiple storage drivers:
/// - `local`: Stores files in `public/uploads` (default)
/// - `s3` / `minio`: Uploads objects to S3 or MinIO buckets (e.g. `s3.eulogia.net`)
///
/// Configure in `.env`:
/// ```env
/// STORAGE_DRIVER=s3 # or 'local', 'minio'
/// S3_ENDPOINT=https://s3.eulogia.net
/// S3_BUCKET=eulogia
/// S3_ACCESS_KEY=your-access-key
/// S3_SECRET_KEY=your-secret-key
/// S3_REGION=us-east-1
/// S3_USE_PATH_STYLE=true
/// ```
class Storage {
  static final Map<String, StorageDriver> _disks = {};

  /// Returns the configured default storage driver.
  static StorageDriver get driver {
    final driverKey = FlintEnv.get('STORAGE_DRIVER', 'local').trim().toLowerCase();
    return disk(driverKey);
  }

  /// Returns a specific named storage disk (`'local'`, `'s3'`, `'minio'`).
  static StorageDriver disk([String? name]) {
    final key = (name ?? FlintEnv.get('STORAGE_DRIVER', 'local')).trim().toLowerCase();
    final normalized = (key == 'minio') ? 's3' : key;

    if (_disks.containsKey(normalized)) {
      return _disks[normalized]!;
    }

    if (normalized == 's3') {
      final config = S3Config.fromEnv();
      final client = S3Client(config: config);
      final driver = S3StorageDriver(client: client);
      _disks[normalized] = driver;
      return driver;
    }

    final localDriver = LocalStorageDriver();
    _disks[normalized] = localDriver;
    return localDriver;
  }

  /// Registers or overrides a custom storage driver disk.
  static void registerDisk(String name, StorageDriver customDriver) {
    _disks[name.toLowerCase().trim()] = customDriver;
  }

  /// Resets cached storage driver instances (useful in tests).
  static void reset() {
    _disks.clear();
  }

  /// Saves an uploaded file to the active storage disk.
  static Future<String> create(
    UploadedFile file, {
    String? subdirectory,
  }) async {
    return await driver.create(file, subdirectory: subdirectory);
  }

  /// Saves raw binary bytes to the active storage disk.
  static Future<String> putBytes(
    List<int> bytes, {
    required String filename,
    String? contentType,
    String? subdirectory,
  }) async {
    return await driver.putBytes(
      bytes,
      filename: filename,
      contentType: contentType,
      subdirectory: subdirectory,
    );
  }

  /// Deletes a file using its public URL or key.
  static Future<void> delete(String fileUrl) async {
    await driver.delete(fileUrl);
  }

  /// Replaces an old file with a new uploaded file.
  static Future<String> update(
    String oldFileUrl,
    UploadedFile newFile, {
    String? subdirectory,
  }) async {
    return await driver.update(
      oldFileUrl,
      newFile,
      subdirectory: subdirectory,
    );
  }

  /// Saves a UTF-8 string to the active storage disk.
  static Future<String> putString(
    String content, {
    required String filename,
    String? contentType,
    String? subdirectory,
  }) async {
    return await driver.putString(
      content,
      filename: filename,
      contentType: contentType,
      subdirectory: subdirectory,
    );
  }

  /// Retrieves raw binary bytes from the active storage disk or URL.
  static Future<List<int>> getBytes(String pathOrUrl) async {
    return await driver.getBytes(pathOrUrl);
  }

  /// Retrieves UTF-8 string text content from the active storage disk or URL.
  static Future<String> getString(String pathOrUrl, {Encoding encoding = utf8}) async {
    return await driver.getString(pathOrUrl, encoding: encoding);
  }

  /// Checks if a file exists on the active storage disk or URL.
  static Future<bool> exists(String pathOrUrl) async {
    return await driver.exists(pathOrUrl);
  }

  /// Resolves the URL for a stored key or path.
  static String url(String path) {
    return driver.url(path);
  }
}
