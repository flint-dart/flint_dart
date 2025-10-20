import 'dart:io';
import 'commands.dart';

class MakeMailCommand extends FlintCommand {
  MakeMailCommand()
      : super('make:mail', 'Create a new Flint mail class and template.');

  @override
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      print('❌ Usage: flint make:mail <name> [--html]');
      print('   Example: flint make:mail newsletter');
      print('   Example: flint make:mail welcome --html');
      return;
    }

    final rawName = args.first;
    final useHtml = args.contains('--html');

    if (!_isValidName(rawName)) {
      print(
          '❌ Invalid name. Use alphanumeric characters, underscores, or hyphens.');
      return;
    }

    final name = _toSnakeCase(rawName);
    final className = '${_toPascalCase(rawName)}Mail';
    final templateName = '${_toPascalCase(rawName)}Template';

    try {
      if (useHtml) {
        await _createHtmlMailFiles(name, className);
      } else {
        await _createFlintUiMailFiles(name, className, templateName);
      }
    } catch (e) {
      print('❌ Error creating mail: $e');
    }
  }

  // --- HTML mode ---
  Future<void> _createHtmlMailFiles(String name, String className) async {
    final mailDir = Directory('lib/src/mail');
    final htmlDir = Directory('lib/src/mail/views');

    if (!mailDir.existsSync()) mailDir.createSync(recursive: true);
    if (!htmlDir.existsSync()) htmlDir.createSync(recursive: true);

    final mailFile = File('${mailDir.path}/${name}_mail.dart');
    final htmlFile = File('${htmlDir.path}/$name.flint.html');

    if (mailFile.existsSync() || htmlFile.existsSync()) {
      print('⚠️  Mail "$name" already exists.');
      return;
    }

    await mailFile.writeAsString(_generateHtmlMailClass(name, className));
    await htmlFile.writeAsString(_generateHtmlView(className));

    print('✅ Created: ${mailFile.path}');
    print('✅ Created: ${htmlFile.path}');
  }

  // --- Flint UI mode ---
  Future<void> _createFlintUiMailFiles(
    String name,
    String className,
    String templateName,
  ) async {
    final mailDir = Directory('lib/src/mail');
    final templateDir = Directory('lib/src/mail/templates');

    if (!mailDir.existsSync()) mailDir.createSync(recursive: true);
    if (!templateDir.existsSync()) templateDir.createSync(recursive: true);

    final mailFile = File('${mailDir.path}/${name}_mail.dart');
    final templateFile = File('${templateDir.path}/${name}_template.dart');

    if (mailFile.existsSync() || templateFile.existsSync()) {
      print('⚠️  Mail "$name" already exists.');
      return;
    }

    await mailFile.writeAsString(_generateMailClass(className, templateName));
    await templateFile.writeAsString(_generateTemplateClass(templateName));

    print('✅ Created: ${mailFile.path}');
    print('✅ Created: ${templateFile.path}');
  }

  // --- Flint UI mail class ---
  String _generateMailClass(String className, String templateName) {
    return '''
import 'package:flint_dart/flint_ui.dart';
import './templates/${_toSnakeCase(templateName.replaceAll('Template', ''))}_template.dart';
import 'package:flint_dart/mail.dart';

class $className extends TransactionalMailable {
  final String title;
  final String content;
  final String? imageUrl;

  $className({
    required super.recipientEmail,
    required super.recipientName,
    required this.title,
    required this.content,
    this.imageUrl,
  });

  @override
  String get subject => title;

  @override
  FlintWidget build() {
    return $templateName(
      title: title,
      content: content,
      imageUrl: imageUrl,
    );
  }
}
''';
  }

  // --- Flint UI template ---
  String _generateTemplateClass(String className) {
    final shortName = className.replaceAll('Template', '');
    return '''
import 'package:flint_dart/flint_ui.dart';

class $className extends FlintEmailTemplate {
  final String title;
  final String content;
  final String? imageUrl;
  final String? ctaUrl;
  final String? ctaText;

  $className({
    required this.title,
    required this.content,
    this.imageUrl,
    this.ctaUrl,
    this.ctaText = 'Learn More',
    super.theme = const FlintTheme(),
  }) : super(
          recipientName: 'Subscriber',
          recipientEmail: 'newsletter@example.com',
        );

  @override
  FlintWidget buildContent() {
    return FlintBox(
      padding: EdgeInsets.all(0),
      children: [
        if (imageUrl != null)
          FlintImage(
            src: imageUrl!,
            alt: title,
            width: 600,
            height: 200,
            style: const ImageStyle(fit: ObjectFit.cover),
          ),
        FlintBox(
          padding: EdgeInsets.all(24),
          children: [
            FlintText(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: '#1a1a1a',
              ),
              align: TextAlign.center,
            ),
            FlintText(
              content,
              style: TextStyle(
                fontSize: 14,
                color: '#666666',
              ),
              align: TextAlign.center,
            ),
            if (ctaUrl != null)
              FlintButton(
                text: ctaText!,
                url: ctaUrl!,
                style: ButtonStyle.primary().copyWith(
                  backgroundColor: theme.primaryColor,
                  textStyle: TextStyle(
                    color: '#ffffff',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                borderRadius: BorderRadius.circular(6),
              ),
            FlintBox(
              margin: EdgeInsets.only(top: 32),
              padding: EdgeInsets.all(16),
              backgroundColor: '#f8f9fa',
              borderRadius: BorderRadius.circular(6),
              children: [
                FlintText(
                  'You received this email because you subscribed to our $shortName updates.',
                  style: TextStyle(
                    fontSize: 12,
                    color: '#666666',
                  ),
                  align: TextAlign.center,
                ),
                FlintBox(
                  margin: EdgeInsets.only(top: 8),
                  children: [
                    FlintRichText(
                      children: [
                        FlintTextSpan(
                          'Unsubscribe',
                          style: TextStyle(
                            color: '#999999',
                            decoration: TextDecoration.underline,
                          ),
                          onTap: 'https://example.com/unsubscribe',
                        ),
                      ],
                      align: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
''';
  }

  // --- HTML mail ---
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

  // --- Helpers ---
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
