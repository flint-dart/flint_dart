import 'dart:io';
import 'commands.dart';

class MakeMailCommand extends FlintCommand {
  MakeMailCommand()
      : super('make:mail', 'Create a new mail class and HTML view.');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      print('❌ Usage: flint make:mail <name>');
      print('   Example: flint make:mail welcome');
      print('   Example: flint make:mail password_reset');
      return;
    }

    final rawName = args.first;

    if (!_isValidName(rawName)) {
      print(
          '❌ Invalid name. Use alphanumeric characters with underscores or hyphens.');
      return;
    }

    final name = _toSnakeCase(rawName);
    final className = _toPascalCase(rawName) + 'Mail';

    try {
      await _createMailFiles(name, className);
    } catch (e) {
      print('❌ Error creating mail: $e');
    }
  }

  Future<void> _createMailFiles(String name, String className) async {
    final mailDir = Directory('lib/mail/$name');

    if (!mailDir.existsSync()) {
      mailDir.createSync(recursive: true);
    }

    final dartFile = File('${mailDir.path}/$name.dart');
    final htmlFile = File('${mailDir.path}/view.flint.html');

    if (dartFile.existsSync() || htmlFile.existsSync()) {
      print('⚠️  Mail "$name" already exists.');
      return;
    }

    final dartContent = _generateDartContent(name, className);
    await dartFile.writeAsString(dartContent);
    print('✅ Created: ${dartFile.path}');

    final htmlContent = _generateHtmlContent(className);
    await htmlFile.writeAsString(htmlContent);
    print('✅ Created: ${htmlFile.path}');
  }

  String _generateDartContent(String name, String className) {
    final subject = _generateSubject(className);

    return '''
import 'package:flint_dart/mail.dart';

class $className extends Mailable {
  final String recipientName;
  final String recipientEmail;

  $className({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => '$subject';

  @override
  String get view => 'mail/$name/view.flint.html';

  @override
  Map<String, dynamic> get data => {
    'recipientName': recipientName,
    'recipientEmail': recipientEmail,
    'currentYear': DateTime.now().year,
  };

  @override
  List<String> get to => [recipientEmail];
}
'''
        .trim();
  }

  String _generateHtmlContent(String className) {
    final readableName = _getReadableName(className);

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ subject }}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .footer {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            font-size: 14px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Hello, {{ recipientName }}!</h1>
    </div>
    
    <div class="content">
        <p>This is your <strong>$readableName</strong> email.</p>
        <p>We're excited to have you on board!</p>
    </div>
    
    <div class="footer">
        <p>&copy; {{ currentYear }} Your Company. All rights reserved.</p>
    </div>
</body>
</html>
'''
        .trim();
  }

  String _generateSubject(String className) {
    return _getReadableName(className);
  }

  String _getReadableName(String className) {
    return className
        .replaceAll('Mail', '')
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim();
  }

  bool _isValidName(String input) {
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(input);
  }

  String _toSnakeCase(String input) {
    if (input.isEmpty) return input;

    final regex = RegExp(r'(?<=[a-z])[A-Z]');
    return input.replaceAllMapped(regex, (m) => ' ${m} ').toLowerCase();
  }

  String _toPascalCase(String input) {
    if (input.isEmpty) return input;

    return input.split(RegExp(r'[_\-\s]')).map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join();
  }
}
