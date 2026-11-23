import 'dart:io';
import 'dart:typed_data';
import 'package:flint_dart/src/storage/s3_client.dart';
import 'package:flint_dart/src/storage/s3_config.dart';
import 'package:flint_dart/src/storage/uploaded_file.dart';
import 'package:uuid/uuid.dart';

/// Contract implemented by file storage drivers (Local, S3 / MinIO).
abstract class StorageDriver {
  /// Saves an uploaded file and returns its public URL or key.
  Future<String> create(UploadedFile file, {String? subdirectory});

  /// Saves raw bytes and returns its public URL or key.
  Future<String> putBytes(
    List<int> bytes, {
    required String filename,
    String? contentType,
    String? subdirectory,
  });

  /// Deletes a file by its URL or key.
  Future<void> delete(String fileUrl);

  /// Replaces an existing file with a new uploaded file.
  Future<String> update(
    String oldFileUrl,
    UploadedFile newFile, {
    String? subdirectory,
  });

  /// Resolves the URL for a stored key or path.
  String url(String path);
}

/// Local disk storage driver storing files under `public/`.
class LocalStorageDriver implements StorageDriver {
  static const String _baseDir = 'public';
  static const String _defaultUploadsFolder = 'uploads';

  @override
  Future<String> create(UploadedFile file, {String? subdirectory}) async {
    final safeFileName = _sanitizeFileName(file.filename);
    final uniqueFileName = '${Uuid().v4()}_$safeFileName';

    final folder = _normalizeRelativePath(
      subdirectory,
      fallback: _defaultUploadsFolder,
      label: 'subdirectory',
    );

    final directoryPath = '$_baseDir/$folder';
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final newFile = File('$directoryPath/$uniqueFileName');
    await file.content.pipe(newFile.openWrite());

    return '/$folder/$uniqueFileName';
  }

  @override
  Future<String> putBytes(
    List<int> bytes, {
    required String filename,
    String? contentType,
    String? subdirectory,
  }) async {
    final safeFileName = _sanitizeFileName(filename);
    final uniqueFileName = '${Uuid().v4()}_$safeFileName';

    final folder = _normalizeRelativePath(
      subdirectory,
      fallback: _defaultUploadsFolder,
      label: 'subdirectory',
    );

    final directoryPath = '$_baseDir/$folder';
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final newFile = File('$directoryPath/$uniqueFileName');
    await newFile.writeAsBytes(bytes);

    return '/$folder/$uniqueFileName';
  }

  @override
  Future<void> delete(String fileUrl) async {
    final safePath = _normalizePublicFileUrl(fileUrl);
    final filePath = '$_baseDir/$safePath';
    final fileToDelete = File(filePath);

    if (await fileToDelete.exists()) {
      await fileToDelete.delete();
    }
  }

  @override
  Future<String> update(
    String oldFileUrl,
    UploadedFile newFile, {
    String? subdirectory,
  }) async {
    await delete(oldFileUrl);
    return await create(newFile, subdirectory: subdirectory);
  }

  @override
  String url(String path) {
    var p = path.trim().replaceAll('\\', '/');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return '/$p';
  }

  static String _sanitizeFileName(String filename) {
    final parts = filename
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    final baseName = parts.isEmpty ? null : parts.last.trim();

    if (baseName == null ||
        baseName.isEmpty ||
        baseName == '.' ||
        baseName == '..') {
      throw ArgumentError('Uploaded filename is invalid.');
    }

    final safe = baseName
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

    if (safe.isEmpty || safe == '.' || safe == '..') {
      throw ArgumentError('Uploaded filename is invalid.');
    }

    return safe;
  }

  static String _normalizePublicFileUrl(String fileUrl) {
    var path = fileUrl.trim().replaceAll('\\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path == 'public') {
      throw ArgumentError('Storage file URL must point to a file.');
    }
    if (path.startsWith('public/')) {
      path = path.substring('public/'.length);
    }
    final normalized = _normalizeRelativePath(path, label: 'fileUrl');
    if (normalized.isEmpty || normalized.endsWith('/')) {
      throw ArgumentError('Storage file URL must point to a file.');
    }
    return normalized;
  }

  static String _normalizeRelativePath(
    String? value, {
    String? fallback,
    required String label,
  }) {
    var path = value?.trim().replaceAll('\\', '/') ?? '';
    if (path.isEmpty) {
      path = fallback ?? '';
    }
    if (path.isEmpty) {
      return path;
    }
    if (path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      throw ArgumentError('Storage $label must be relative to public/.');
    }
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.any((part) => part == '.' || part == '..')) {
      throw ArgumentError('Storage $label cannot contain . or .. segments.');
    }
    return parts.join('/');
  }
}

/// S3 and MinIO compatible storage driver.
class S3StorageDriver implements StorageDriver {
  final S3Client client;

  S3StorageDriver({S3Client? client, S3Config? config})
      : client = client ?? S3Client(config: config ?? S3Config.fromEnv());

  @override
  Future<String> create(UploadedFile file, {String? subdirectory}) async {
    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in file.content) {
      bytesBuilder.add(chunk);
    }
    final bytes = bytesBuilder.takeBytes();

    return putBytes(
      bytes,
      filename: file.filename,
      contentType: file.contentType,
      subdirectory: subdirectory,
    );
  }

  @override
  Future<String> putBytes(
    List<int> bytes, {
    required String filename,
    String? contentType,
    String? subdirectory,
  }) async {
    final safeFileName = LocalStorageDriver._sanitizeFileName(filename);
    final uniqueFileName = '${Uuid().v4()}_$safeFileName';

    var key = uniqueFileName;
    if (subdirectory != null && subdirectory.trim().isNotEmpty) {
      var folder = subdirectory.trim().replaceAll('\\', '/');
      while (folder.startsWith('/')) {
        folder = folder.substring(1);
      }
      while (folder.endsWith('/')) {
        folder = folder.substring(0, folder.length - 1);
      }
      if (folder.isNotEmpty) {
        key = '$folder/$uniqueFileName';
      }
    }

    return await client.putObject(
      key: key,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<void> delete(String fileUrl) async {
    final key = _extractKeyFromUrl(fileUrl);
    if (key.isNotEmpty) {
      await client.deleteObject(key: key);
    }
  }

  @override
  Future<String> update(
    String oldFileUrl,
    UploadedFile newFile, {
    String? subdirectory,
  }) async {
    try {
      await delete(oldFileUrl);
    } catch (_) {}
    return await create(newFile, subdirectory: subdirectory);
  }

  @override
  String url(String path) {
    return client.getPublicUrl(path);
  }

  String _extractKeyFromUrl(String fileUrl) {
    var raw = fileUrl.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final uri = Uri.parse(raw);
      var path = uri.path;
      while (path.startsWith('/')) {
        path = path.substring(1);
      }
      if (client.config.usePathStyle && path.startsWith('${client.config.bucket}/')) {
        path = path.substring('${client.config.bucket}/'.length);
      }
      return path;
    }
    while (raw.startsWith('/')) {
      raw = raw.substring(1);
    }
    return raw;
  }
}
