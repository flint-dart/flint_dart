import 'dart:io';

import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('FlintWebUiBuilder', () {
    late Directory originalCurrent;
    late Directory tempDir;

    setUp(() {
      originalCurrent = Directory.current;
      tempDir = Directory.systemTemp.createTempSync('flint_web_ui_builder_');
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalCurrent;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('uses sibling public directory for flint_ui entrypoints', () {
      final uiDir = Directory(path.join(tempDir.path, 'flint_ui'))
        ..createSync(recursive: true);
      final publicDir = Directory(path.join(tempDir.path, 'public'))
        ..createSync(recursive: true);
      final entry = File(path.join(uiDir.path, 'main.dart'))
        ..writeAsStringSync('void main() {}');

      final build = FlintWebUiBuilder.resolve(entryArg: entry.path);

      expect(build, isNotNull);
      expect(
          path.normalize(build!.webDir.path), path.normalize(publicDir.path));
      expect(
        path.normalize(build.jsOut),
        path.normalize(path.join(publicDir.path, 'main.dart.js')),
      );
    });
  });
}
