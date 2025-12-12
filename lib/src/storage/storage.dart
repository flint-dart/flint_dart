import 'dart:io';
import 'package:flint_dart/flint_dart.dart';
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
    final safeFileName = file.filename.replaceAll(' ', '_');
    final uniqueFileName = '${Uuid().v4()}_$safeFileName';

    // Determine folder
    final folder = (subdirectory == null || subdirectory.isEmpty)
        ? _defaultUploadsFolder
        : subdirectory;

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
    if (fileUrl.startsWith('/')) {
      fileUrl = fileUrl.substring(1); // remove leading "/"
    }

    final filePath = '$_baseDir/$fileUrl';
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
}
