import 'dart:io';

import 'package:path/path.dart' as p;

class FileTemplateReader {
  static String _resolveTemplatePath(String name) {
    final currentDir = Directory.current.path;

    // ✅ 1. If already an absolute or relative file path → use it directly
    final directPath =
        p.isAbsolute(name) ? name : p.normalize(p.join(currentDir, name));

    if (File(directPath).existsSync()) {
      return directPath;
    }

    // ✅ 2. Otherwise treat it as a logical view name
    final normalized = name.replaceAll('.', Platform.pathSeparator);

    final flintPath = p.join(
      currentDir,
      'lib',
      'src',
      'views',
      '$normalized.flint.html',
    );

    final htmlPath = p.join(
      currentDir,
      'lib',
      'src',
      'views',
      '$normalized.html',
    );

    if (File(flintPath).existsSync()) {
      return flintPath;
    }

    if (File(htmlPath).existsSync()) {
      return htmlPath;
    }

    throw FileSystemException('Html template not found', name);
  }

  String read(String template) {
    final filePath = _resolveTemplatePath(template);
    return File(filePath).readAsStringSync();
  }
}
