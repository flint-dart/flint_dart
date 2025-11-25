// lib/flint_ui/core/flint_template.dart
import 'package:flint_dart/src/flint_ui/widgets/head.dart';
import 'flint_widget.dart';

abstract class FlintTemplate extends FlintWidget {
  FlintTemplate({super.id, super.script});

  /// Optional head for template: meta, title, links, etc.
  Head? get head => null;

  /// Additional <style> blocks (inline or external)
  List<String> styles() => [];

  /// Additional <script> blocks (inline or external)
  List<String> scripts() => [];

  @override
  FlintWidget buildTemplate();

  /// Build full HTML scaffold
  String scaffoldHtml({String lang = 'en'}) {
    final template = buildTemplate();
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="$lang">');
    buffer.writeln('<head>');

    // Head meta, title, links
    if (head != null) buffer.writeln(head!.toHtml());

    // Additional styles
    for (final style in styles()) {
      buffer.writeln('<style>');
      buffer.writeln(style);
      buffer.writeln('</style>');
    }

    // Additional scripts
    for (final script in scripts()) {
      buffer.writeln('<script>');
      buffer.writeln(script);
      buffer.writeln('</script>');
    }

    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln(template.toHtml());
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  @override
  String toHtml() => scaffoldHtml();

  @override
  String toText() => buildTemplate().toText();

  @override
  Map<String, dynamic> toJson() => {
        'head': head?.toJson() ?? {},
        'headStyles': styles(),
        'headScripts': scripts(),
        'body': buildTemplate().toJson(),
      };
}
