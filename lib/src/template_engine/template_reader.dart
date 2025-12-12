import 'dart:io';

import 'package:path/path.dart' as p;

/// An interface (abstract class) for reading template files.
abstract class TemplateReader {
  /// Reads the template contents from the given [filePath].
  String read(String filePath);
}

class FileTemplateReader implements TemplateReader {
  static final FileTemplateReader _singleton = FileTemplateReader._internal();
  factory FileTemplateReader() => _singleton;
  FileTemplateReader._internal();

  /// Reads the html template from the given [template] path.
  ///
  /// The template path is relative to the `lib/resources/view/` directory.
  /// The template file must end with `.html`.
  ///
  /// Throws a [FileSystemException] if the file does not exist.
  ///
  ///
  // Private implementation
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

  @override
  String read(String template) {
    print(template);
    final filePath = _resolveTemplatePath(template);
    File file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Html template not found', filePath);
    }
    return file.readAsStringSync();
  }
}
