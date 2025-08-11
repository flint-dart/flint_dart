// lib/src/storage/storage.dart
import 'dart:io';
import 'package:flint_dart/flint_dart.dart';
import 'package:uuid/uuid.dart';

class Storage {
  /// The base directory where all files are stored.
  static const String _baseDir = 'public/uploads';

  /// The base URL path for accessing files.
  static const String _baseUrl = '/uploads';

  /// Saves an uploaded file to the server.
  ///
  /// This method generates a unique filename and ensures the target
  /// directory exists before saving the file's content.
  ///
  /// @param file The [UploadedFile] object from the request.
  /// @param subdirectory The optional subdirectory within the base directory.
  /// @returns A [Future] that completes with the public URL of the saved file.
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
  /// @param fileUrl The public URL of the file to delete.
  /// @returns A [Future] that completes when the file is deleted or if it does not exist.
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
  /// This is a convenience method that first deletes the old file
  /// and then creates the new one.
  ///
  /// @param oldFileUrl The public URL of the file to replace.
  /// @param newFile The [UploadedFile] object for the new file.
  /// @param subdirectory The optional subdirectory for the new file.
  /// @returns A [Future] that completes with the public URL of the new file.
  static Future<String> update(String oldFileUrl, UploadedFile newFile,
      {String subdirectory = ''}) async {
    await delete(oldFileUrl);
    return await create(newFile, subdirectory: subdirectory);
  }
}
