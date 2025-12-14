import 'dart:io';

import 'package:path/path.dart' as p;

class FileTemplateReader {
  static String _resolveTemplatePath(String name) {
    final normalized = name.replaceAll('.', Platform.pathSeparator);
    final currentDir = Directory.current.path;

    var cleanNormalized = normalized;
    if (cleanNormalized.startsWith(Platform.pathSeparator)) {
      cleanNormalized = cleanNormalized.substring(1);
    }

    final flintPath = p.join(
        currentDir, 'lib', 'src', 'views', '$cleanNormalized.flint.html');
    final htmlPath =
        p.join(currentDir, 'lib', 'src', 'views', '$cleanNormalized.html');

    if (File(flintPath).existsSync()) {
      return flintPath;
    }

    if (File(htmlPath).existsSync()) {
      return htmlPath;
    }

    return flintPath;
  }

  String read(String template) {
    final filePath = _resolveTemplatePath(template);
    File file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Html template not found', filePath);
    }
    return file.readAsStringSync();
  }
}
