import 'dart:io';
import 'package:path/path.dart' as path;

class FlintTemplateEngine {
  /// Renders a template file with the provided data.
  Future<String> render(String templatePath,
      {Map<String, dynamic>? data}) async {
    final file = File(templatePath);
    if (!await file.exists()) {
      throw Exception('Template not found: $templatePath');
    }

    String content = await file.readAsString();
    final context = data ?? {};

    // Process all template features
    content = await _processIncludes(content, context, templatePath);
    content = await _processLoops(content, context, templatePath);
    content = await _processIfs(content, context, templatePath);
    content = _processVariables(content, context);
    content = _processComments(content);

    return content;
  }

  /// Renders a string template with the provided data.
  Future<String> renderString(String template,
      {Map<String, dynamic>? data}) async {
    String content = template;
    final context = data ?? {};

    content = await _processLoops(content, context, '');
    content = await _processIfs(content, context, '');
    content = _processVariables(content, context);
    content = _processComments(content);

    return content;
  }

  String _processVariables(String content, Map<String, dynamic> data) {
    // Handle simple variables: {{ variable }}
    final simpleVarRegex = RegExp(r'{{\s*(\w+)\s*}}');
    content = content.replaceAllMapped(simpleVarRegex, (match) {
      final key = match.group(1);
      return key != null && data.containsKey(key) ? data[key].toString() : '';
    });

    // Handle object properties: {{ user.name }}
    final objectVarRegex = RegExp(r'{{\s*(\w+(?:\.\w+)+)\s*}}');
    content = content.replaceAllMapped(objectVarRegex, (match) {
      final keyPath = match.group(1)!;
      final value = _getNestedValue(data, keyPath);
      return value?.toString() ?? '';
    });

    return content;
  }

  dynamic _getNestedValue(Map<String, dynamic> data, String keyPath) {
    final keys = keyPath.split('.');
    dynamic value = data;

    for (final key in keys) {
      if (value is Map<String, dynamic>) {
        value = value[key];
      } else {
        return null;
      }
    }

    return value;
  }

  Future<String> _processLoops(
      String content, Map<String, dynamic> data, String templatePath) async {
    final loopRegex = RegExp(
      r'{{\s*for\s+(\w+)\s+in\s+(\w+(?:\.\w+)*)\s*}}([\s\S]*?){{\s*endfor\s*}}',
      dotAll: true,
    );

    return content.replaceAllMapped(loopRegex, (match) {
      final varName = match.group(1)!;
      final listPath = match.group(2)!;
      final body = match.group(3)!;

      final iterable = _getNestedValue(data, listPath);
      if (iterable is! Iterable) return '';

      final buffer = StringBuffer();
      for (var item in iterable) {
        final innerData = Map<String, dynamic>.from(data);
        innerData[varName] = item;

        // Process nested content with the new context
        var processedBody = body;
        processedBody = _processVariables(processedBody, innerData);
        buffer.write(processedBody);
      }
      return buffer.toString();
    });
  }

  Future<String> _processIfs(
      String content, Map<String, dynamic> data, String templatePath) async {
    final ifRegex = RegExp(
      r'{{\s*if\s+(\w+(?:\.\w+)*)\s*}}([\s\S]*?)(?:{{\s*else\s*}}([\s\S]*?))?{{\s*endif\s*}}',
      dotAll: true,
    );

    return content.replaceAllMapped(ifRegex, (match) {
      final condPath = match.group(1)!;
      final ifBody = match.group(2)!;
      final elseBody = match.group(3) ?? '';

      final condValue = _getNestedValue(data, condPath);
      final result = _evaluateCondition(condValue) ? ifBody : elseBody;

      return _processVariables(result, data);
    });
  }

  bool _evaluateCondition(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  Future<String> _processIncludes(
      String content, Map<String, dynamic> data, String templatePath) async {
    final includeRegex = RegExp(
      r"\{@\s*include\(\s*'([^']+)'\s*(,\s*(\{.*?\}))?\)\s*@\}",
      dotAll: true,
    );
    final matches = includeRegex.allMatches(content).toList();

    for (final match in matches.reversed) {
      final includePath = match.group(1)!;
      final fullPath = path.join(path.dirname(templatePath), includePath);

      try {
        final includedContent = await render(fullPath, data: data);
        content = content.replaceRange(match.start, match.end, includedContent);
      } catch (e) {
        // If include fails, remove the include tag
        content = content.replaceRange(match.start, match.end, '');
      }
    }

    return content;
  }

  String _processComments(String content) {
    // Remove comment blocks: {{-- comment --}}
    final commentRegex = RegExp(r'{{--[\s\S]*?--}}');
    return content.replaceAll(commentRegex, '');
  }

  // Additional utility methods
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _escapeJson(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}
