import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Storage', () {
    late Directory previousDirectory;
    late Directory tempDir;

    setUp(() async {
      previousDirectory = Directory.current;
      tempDir = await Directory.systemTemp.createTemp('flint_storage_');
      Directory.current = tempDir.path;
    });

    tearDown(() async {
      Directory.current = previousDirectory.path;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates uploaded files under public and returns a public URL',
        () async {
      final url = await Storage.create(
        _uploadedFile('profile picture.png', 'avatar'),
        subdirectory: 'profiles',
      );

      expect(url, startsWith('/profiles/'));
      expect(url, endsWith('_profile_picture.png'));
      expect(
          await File('public${url.replaceAll('/', Platform.pathSeparator)}')
              .readAsString(),
          'avatar');
    });

    test('uses public uploads by default', () async {
      final url = await Storage.create(_uploadedFile('avatar.png', 'avatar'));

      expect(url, startsWith('/uploads/'));
      expect(
          await File('public${url.replaceAll('/', Platform.pathSeparator)}')
              .exists(),
          isTrue);
    });

    test('updates by deleting the old public file and creating the new file',
        () async {
      final oldUrl = await Storage.create(_uploadedFile('old.png', 'old'));

      final newUrl = await Storage.update(
        oldUrl,
        _uploadedFile('new.png', 'new'),
      );

      expect(newUrl, startsWith('/uploads/'));
      expect(
          await File('public${oldUrl.replaceAll('/', Platform.pathSeparator)}')
              .exists(),
          isFalse);
      expect(
          await File('public${newUrl.replaceAll('/', Platform.pathSeparator)}')
              .readAsString(),
          'new');
    });

    test('deletes using a public URL', () async {
      final url = await Storage.create(_uploadedFile('delete-me.png', 'bye'));

      await Storage.delete(url);

      expect(
          await File('public${url.replaceAll('/', Platform.pathSeparator)}')
              .exists(),
          isFalse);
    });

    test('sanitizes uploaded filenames', () async {
      final url = await Storage.create(
        _uploadedFile('../unsafe name.png', 'safe'),
      );

      expect(url, isNot(contains('..')));
      expect(url, endsWith('_unsafe_name.png'));
      expect(
          await File('public${url.replaceAll('/', Platform.pathSeparator)}')
              .exists(),
          isTrue);
    });

    test('rejects unsafe storage paths', () async {
      expect(
        () => Storage.create(
          _uploadedFile('avatar.png', 'avatar'),
          subdirectory: '../private',
        ),
        throwsArgumentError,
      );

      expect(
        () => Storage.create(
          _uploadedFile('avatar.png', 'avatar'),
          subdirectory: '/absolute',
        ),
        throwsArgumentError,
      );

      expect(
        () => Storage.delete('/uploads/../secret.txt'),
        throwsArgumentError,
      );
    });
  });
}

UploadedFile _uploadedFile(String filename, String content) {
  final bytes = utf8.encode(content);
  return UploadedFile(
    fieldName: 'file',
    filename: filename,
    contentType: 'text/plain',
    size: bytes.length,
    content: Stream<List<int>>.fromIterable([bytes]),
  );
}
