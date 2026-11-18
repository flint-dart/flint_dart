import 'dart:io';
import 'package:flint_dart/src/storage/uploaded_file.dart';
import 'package:uuid/uuid.dart';

/// Handles file storage operations for uploaded files in Flint Dart.
///
/// Default behavior:
/// - Files are stored in `public/uploads`
/// - Public URL is `/uploads/<generated-filename>`
///
/// If user passes a `subdirectory`, files go to:
/// - `public/<subdirectory>`
/// - URL `/subdirectory/<generated-filename>`
class Storage {
  /// Base root directory for filesystem storage.
  static const String _baseDir = 'public';

  /// The default uploads folder inside public.
  static const String _defaultUploadsFolder = 'uploads';

  /// Saves an uploaded file to the server.
  ///
  /// [file] - The uploaded file.
  /// [subdirectory] - Optional folder inside `/public`.
  ///
  /// Examples:
  /// `Storage.create(file)` → public/uploads/
  /// `Storage.create(file, subdirectory: 'schools/logo')`
  static Future<String> create(
    UploadedFile file, {
    String? subdirectory,
  }) async {
    final safeFileName = _sanitizeFileName(file.filename);
    final uniqueFileName = '${Uuid().v4()}_$safeFileName';

    final folder = _normalizeRelativePath(
      subdirectory,
      fallback: _defaultUploadsFolder,
      label: 'subdirectory',
    );

    final directoryPath = '$_baseDir/$folder';

    final Directory dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final File newFile = File('$directoryPath/$uniqueFileName');
    await file.content.pipe(newFile.openWrite());

    // Return public URL
    return '/$folder/$uniqueFileName';
  }

  /// Deletes file using its public URL.
  ///
  /// Example:
  /// `/uploads/abc.png` → deletes `public/uploads/abc.png`
  static Future<void> delete(String fileUrl) async {
    final safePath = _normalizePublicFileUrl(fileUrl);

    final filePath = '$_baseDir/$safePath';
    final fileToDelete = File(filePath);

    if (await fileToDelete.exists()) {
      await fileToDelete.delete();
    }
  }

  /// Replaces an old file with a new one.
  ///
  /// Deletes the old file and uploads the new one.
  static Future<String> update(
    String oldFileUrl,
    UploadedFile newFile, {
    String? subdirectory,
  }) async {
    await delete(oldFileUrl);
    return await create(newFile, subdirectory: subdirectory);
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

    final normalized = _normalizeRelativePath(
      path,
      label: 'fileUrl',
    );

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
