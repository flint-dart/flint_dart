import 'dart:convert';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/template_engine/all_expression/base_run.dart';
import 'package:flint_dart/src/template_engine/template_engine.dart';
import 'package:flint_dart/src/template_engine/template_reader.dart';

class IncludeProcessor implements BaseExpression {
  /// Replaces `{{ include('file', {...}) }}` blocks in [content] with the
  /// rendered content of the included file.
  @override
  String run(String content, [Map<String, dynamic>? context]) {
    // Pattern to match: {{ include('filename', {json}) }}
    final includePattern = RegExp(
      r'''\{\{\s*include\(\s*["\']([^"\']+)["\']\s*(?:,\s*({.*?}))?\s*\)\s*\}\}''',
      dotAll: true,
    );

    int lastIndex = 0;
    StringBuffer buffer = StringBuffer();

    // Use iterative approach to handle nested includes
    for (final match in includePattern.allMatches(content)) {
      // Add text before the match
      buffer.write(content.substring(lastIndex, match.start));

      final filePath = match.group(1)?.trim() ?? '';
      final rawData = match.group(2)?.trim() ?? '{}';

      try {
        // Parse the JSON data if provided
        final childContext = rawData.isNotEmpty && rawData != '{}'
            ? jsonDecode(rawData) as Map<String, dynamic>
            : <String, dynamic>{};

        // Merge contexts (child context overrides parent context)
        final mergedContext = {
          ...context ?? {},
          ...childContext,
        };

        // Read and render the included template
        final includedTemplate = FileTemplateReader().read(filePath);
        final rendered =
            TemplateEngine().renderString(includedTemplate, mergedContext);

        buffer.write(rendered);
      } catch (e) {
        // If there's an error, keep the original include tag
        buffer.write(match.group(0));
        Log.debug('Error processing include $filePath: $e');
      }

      lastIndex = match.end;
    }

    // Add remaining content
    buffer.write(content.substring(lastIndex));

    return buffer.toString();
  }
}
