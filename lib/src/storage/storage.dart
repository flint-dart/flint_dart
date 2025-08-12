// lib/src/storage/storage.dart
import 'dart:io';
import 'package:flint_dart/flint_dart.dart';
import 'package:uuid/uuid.dart';

/// Handles file storage operations for uploaded files in Flint Dart.
///
/// This class provides static helper methods to:
/// - Save uploaded files to a public directory
/// - Delete files by their public URL
/// - Replace existing files with new ones
///
/// Files are stored in the `public/uploads` directory by default
/// and accessed via the `/uploads` URL path.
///
/// Example:
/// ```dart
/// final fileUrl = await Storage.create(uploadedFile);
/// await Storage.delete(fileUrl);
/// final newFileUrl = await Storage.update(fileUrl, newUploadedFile);
/// ```
class Storage {
  /// The base directory where all files are stored.
  static const String _baseDir = 'public/uploads';

  /// The base URL path for accessing files.
  static const String _baseUrl = '/uploads';

  /// Saves an uploaded file to the server.
  ///
  /// Generates a unique filename to avoid collisions, ensures the target
  /// directory exists, and writes the file's content to disk.
  ///
  /// [file] - The [UploadedFile] object from the request.
  /// [subdirectory] - Optional subdirectory within the base directory.
  ///
  /// Returns the public URL of the saved file.
  static Future<String> create(UploadedFile file,
      {String subdirectory = ''}) async {
    final String uniqueFileName = '${Uuid().v4()}_${file.filename}';
    final String uploadPath = '$_baseDir/$subdirectory';

    final Directory dir = Directory(uploadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final File newFile = File('$uploadPath/$uniqueFileName');
    await file.content.pipe(newFile.openWrite());

    return '$_baseUrl/$subdirectory/$uniqueFileName';
  }

  /// Deletes a file from the server using its public URL.
  ///
  /// [fileUrl] - The public URL of the file to delete.
  ///
  /// Does nothing if the file does not exist or the URL is invalid.
  static Future<void> delete(String fileUrl) async {
    if (!fileUrl.startsWith(_baseUrl)) {
      return;
    }

    final filePath = fileUrl.replaceFirst(_baseUrl, _baseDir);
    final fileToDelete = File(filePath);

    if (await fileToDelete.exists()) {
      await fileToDelete.delete();
    }
  }

  /// Replaces an old file with a new uploaded file.
  ///
  /// Deletes the existing file (if it exists) and saves the new file.
  ///
  /// [oldFileUrl] - The public URL of the file to replace.
  /// [newFile] - The [UploadedFile] object for the new file.
  /// [subdirectory] - Optional subdirectory for the new file.
  ///
  /// Returns the public URL of the new file.
  static Future<String> update(String oldFileUrl, UploadedFile newFile,
      {String subdirectory = ''}) async {
    await delete(oldFileUrl);
    return await create(newFile, subdirectory: subdirectory);
  }
}
