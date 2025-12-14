import 'package:flint_dart/src/template_engine/all_expression/baseRun.dart';

class SectionProcessor implements BaseExpression {
  @override
  String run(String content, [Map<String, dynamic>? context]) {
    context ??= {};

    // Process yield statements
    content = _processYields(content, context);

    // Process parent sections
    content = _processParentSections(content, context);

    return content;
  }

  String _processYields(String content, Map<String, dynamic> context) {
    final pattern = RegExp(
      r'''\{\{\s*yield\(\s*["\']([^"\']+)["\']\s*\)\s*\}\}''',
      dotAll: true,
    );

    return content.replaceAllMapped(pattern, (match) {
      final sectionName = match.group(1)?.trim() ?? '';
      final value = context[sectionName];

      if (value == null) {
        return '';
      }

      return value.toString();
    });
  }

  String _processParentSections(String content, Map<String, dynamic> context) {
    final pattern = RegExp(
      r'''\{\{\s*section\(\s*["\']([^"\']+)["\']\s*\)\s*\}\}(.*?)\{\{\s*show\s*\}\}''',
      dotAll: true,
    );

    return content.replaceAllMapped(pattern, (match) {
      final sectionName = match.group(1)?.trim() ?? '';
      final defaultContent = match.group(2)?.trim() ?? '';

      if (context.containsKey(sectionName)) {
        return context[sectionName].toString();
      }

      return defaultContent;
    });
  }

  Map<String, String> parseChildSections(String childTemplate) {
    final sections = <String, String>{};

    // Parse block sections
    final blockPattern = RegExp(
      r'''\{\{\s*section\(\s*["\']([^"\']+)["\']\s*\)\s*\}\}(.*?)\{\{\s*endsection\s*\}\}''',
      dotAll: true,
    );

    for (final match in blockPattern.allMatches(childTemplate)) {
      final name = match.group(1)?.trim() ?? '';
      final content = match.group(2)?.trim() ?? '';
      sections[name] = content;
    }

    // Parse inline sections
    final inlinePattern = RegExp(
      r'''\{\{\s*section\(\s*["\']([^"\']+)["\']\s*,\s*["\'](.*?)["\']\s*\)\s*\}\}''',
      dotAll: true,
    );

    for (final match in inlinePattern.allMatches(childTemplate)) {
      final name = match.group(1)?.trim() ?? '';
      final content = match.group(2)?.trim() ?? '';
      sections[name] = content;
    }

    return sections;
  }
}
