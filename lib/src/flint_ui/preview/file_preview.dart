// lib/flint_ui/preview/file_preview.dart
import 'dart:io';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/flint_ui/core/flint_widget.dart';
import 'package:flint_dart/src/flint_ui/preview/html_preview.dart';
import 'package:path/path.dart' as path;

class FlintFilePreview {
  /// Save preview to file and open in browser
  static Future<void> previewInBrowser(FlintWidget content,
      {String? outputPath}) async {
    final tempDir = Directory.systemTemp;
    final previewFile = File(path.join(tempDir.path,
        'flint_preview_${DateTime.now().millisecondsSinceEpoch}.html'));

    final html = FlintPreview.generatePreviewHtml(content);
    await previewFile.writeAsString(html);

    // Open in default browser
    if (Platform.isWindows) {
      Process.run('start', [previewFile.path], runInShell: true);
    } else if (Platform.isMacOS) {
      Process.run('open', [previewFile.path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [previewFile.path]);
    }

    Log.debug('📧 Preview generated: ${previewFile.path}');
  }

  /// Save as HTML file
  static Future<File> saveAsHtml(FlintWidget content, String filePath) async {
    final html = FlintPreview.generatePreviewHtml(content);
    final file = File(filePath);
    await file.writeAsString(html);
    Log.debug('✅ HTML saved: $filePath');
    return file;
  }

  /// Save email-ready HTML (without preview wrapper)
  static Future<File> saveEmailHtml(
      FlintWidget content, String filePath) async {
    final emailHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Template</title>
    <style>
        body { 
            margin: 0; 
            padding: 20px; 
            background: #f5f5f5; 
            font-family: Arial, sans-serif; 
        }
        .email-container { 
            max-width: 600px; 
            margin: 0 auto; 
            background: white; 
            border-radius: 8px; 
            overflow: hidden; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
        }
    </style>
</head>
<body>
    <div class="email-container">
        ${content.toHtml()}
    </div>
</body>
</html>
''';

    final file = File(filePath);
    await file.writeAsString(emailHtml);
    Log.debug('✅ Email HTML saved: $filePath');
    return file;
  }
}
