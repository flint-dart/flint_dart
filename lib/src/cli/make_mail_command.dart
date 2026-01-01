import 'dart:io';
import 'package:flint_dart/logs.dart';

import 'commands.dart';

class MakeMailCommand extends FlintCommand {
  MakeMailCommand()
      : super('make:mail',
            'Create a new HTML-based Flint mail class and template.');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      Log.debug('❌ Usage: flint make:mail <name>');
      Log.debug('   Example: flint make:mail newsletter');
      return;
    }

    final rawName = args.first;

    if (!_isValidName(rawName)) {
      Log.debug(
          '❌ Invalid name. Use alphanumeric characters, underscores, or hyphens.');
      return;
    }

    final name = _toSnakeCase(rawName);
    final className = '${_toPascalCase(rawName)}Mail';

    try {
      await _createHtmlMailFiles(name, className);
    } catch (e) {
      Log.debug('❌ Error creating mail: $e');
    }
  }

  /// --- HTML mode ---
  Future<void> _createHtmlMailFiles(String name, String className) async {
    final mailDir = Directory('lib/mail');
    final htmlDir = Directory('lib/mail/views');

    if (!await mailDir.exists()) mailDir.createSync(recursive: true);
    if (!await htmlDir.exists()) htmlDir.createSync(recursive: true);

    final mailFile = File('${mailDir.path}/${name}_mail.dart');
    final htmlFile = File('${htmlDir.path}/$name.flint.html');

    if (await mailFile.exists() || await htmlFile.exists()) {
      Log.debug('⚠️  Mail "$name" already exists.');
      return;
    }

    await mailFile.writeAsString(_generateHtmlMailClass(name, className));
    await htmlFile.writeAsString(_generateHtmlView(className));

    Log.debug('✅ Created: ${mailFile.path}');
    Log.debug('✅ Created: ${htmlFile.path}');
  }

  /// --- Generate Dart Mail class ---
  String _generateHtmlMailClass(String name, String className) {
    return '''
import 'package:flint_dart/mail.dart';

class $className extends ViewMailable {
  final String recipientName;
  final String recipientEmail;

  $className({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => '${_getReadableName(className)}';

  @override
  String get view => 'mail/views/$name.flint.html';

  @override
  Map<String, dynamic> get data => {
    'recipientName': recipientName,
    'recipientEmail': recipientEmail,
    'currentYear': DateTime.now().year,
  };

  @override
  List<String> get to => [recipientEmail];
}
''';
  }

  /// --- Generate HTML template ---
  String _generateHtmlView(String className) {
    final readableName = _getReadableName(className);
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>{{ subject }}</title>
  <style>
    body { font-family: Arial, sans-serif; color: #333; padding: 20px; }
    .footer { margin-top: 30px; font-size: 12px; color: #999; }
  </style>
</head>
<body>
  <h2>Hello, {{ recipientName }}!</h2>
  <p>This is your <strong>$readableName</strong> email.</p>
  <div class="footer">
    <p>&copy; {{ currentYear }} Flint Dart. All rights reserved.</p>
  </div>
</body>
</html>
''';
  }

  /// --- Helpers ---
  String _getReadableName(String className) {
    return className
        .replaceAll('Mail', '')
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .trim();
  }

  bool _isValidName(String input) =>
      RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(input);

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase();
  }

  String _toPascalCase(String input) {
    return input
        .split(RegExp(r'[_\-\s]'))
        .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
        .join();
  }
}
