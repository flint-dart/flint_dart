import 'dart:io';

import 'package:path/path.dart' as p;

class FileTemplateReader {
  static String _resolveTemplatePath(String name) {
    final root = Directory.current.path;

    final candidates = <String>[];

    // 1️⃣ Absolute path
    if (p.isAbsolute(name)) {
      candidates.add(name);
    }

    // 2️⃣ Direct relative path
    candidates.add(p.join(root, name));

    // 3️⃣ Relative to lib/
    candidates.add(p.join(root, 'lib', name));

    // 4️⃣ Logical view resolution
    final normalized = name.replaceAll('.', Platform.pathSeparator);

    candidates.addAll([
      p.join(root, 'lib', 'views', '$normalized.flint.html'),
      p.join(root, 'lib', 'views', '$normalized.html'),
      p.join(root, 'lib', 'mail', 'views', '$normalized.flint.html'),
      p.join(root, 'lib', 'mail', 'views', '$normalized.html'),
    ]);

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    throw FileSystemException(
      'Html template not found. Tried:\n${candidates.join('\n')}',
      name,
    );
  }

  String read(String template) {
    final filePath = _resolveTemplatePath(template);
    return File(filePath).readAsStringSync();
  }
}
