import 'dart:io';

class TemplateEngine {
  final String viewsPath;

  TemplateEngine({this.viewsPath = 'views'});

  Future<String> render(String template, {Map<String, dynamic>? data}) async {
    final file = File(template);
    if (!await file.exists()) throw Exception('Template not found: $template');

    // Raw HTML for non-.flint.html
    if (!template.endsWith('.flint.html')) {
      return await file.readAsString();
    }

    String content = await file.readAsString();

    // Process {{ ... }} blocks recursively
    return await _processCodeBlocks(content, data ?? {});
  }

  Future<String> _processCodeBlocks(
      String content, Map<String, dynamic> data) async {
    final regex = RegExp(r'{{(.*?)}}', dotAll: true);
    while (regex.hasMatch(content)) {
      content = content.replaceAllMapped(regex, (match) {
        final code = match.group(1)!.trim();
        try {
          return _evaluate(code, data);
        } catch (e) {
          return '';
        }
      });
    }
    return content;
  }

  String _evaluate(String code, Map<String, dynamic> data) {
    code = code.trim();

    // ----------- For Loops -----------
    final forMatch = RegExp(
            r'for\s*\(\s*var\s+(\w+)\s+in\s+(.*?)\s*\)\s*{([\s\S]*)}',
            dotAll: true)
        .firstMatch(code);
    if (forMatch != null) {
      final varName = forMatch.group(1)!;
      final iterableExpr = forMatch.group(2)!;
      final body = forMatch.group(3)!;

      dynamic iterable = _resolveExpression(iterableExpr, data);
      if (iterable is! Iterable) return '';

      final buffer = StringBuffer();
      for (var item in iterable) {
        final newData = Map<String, dynamic>.from(data);
        newData[varName] = item;
        buffer.write(_processNestedBody(body, newData));
      }
      return buffer.toString();
    }

    // ----------- If Statements -----------
    final ifMatch = RegExp(
            r'if\s*\((.*?)\)\s*{([\s\S]*?)}(?:\s*else\s*{([\s\S]*?)})?',
            dotAll: true)
        .firstMatch(code);
    if (ifMatch != null) {
      final conditionExpr = ifMatch.group(1)!;
      final ifBody = ifMatch.group(2)!;
      final elseBody = ifMatch.group(3);

      bool cond = _resolveCondition(conditionExpr, data);
      return _processNestedBody(cond ? ifBody : (elseBody ?? ''), data);
    }

    // ----------- Variable or string -----------
    return _resolveExpression(code, data).toString();
  }

  String _processNestedBody(String body, Map<String, dynamic> data) {
    // Recursively process inner {{ }} blocks
    final innerRegex = RegExp(r'{{(.*?)}}', dotAll: true);
    return body.replaceAllMapped(
        innerRegex, (m) => _evaluate(m.group(1)!.trim(), data));
  }

  dynamic _resolveExpression(String expr, Map<String, dynamic> data) {
    expr = expr.trim();

    // Simple variable substitution: data['key'] or $var
    if (expr.startsWith('data[')) {
      final key =
          RegExp(r"""data\[['\"](.+?)['\"]\]""").firstMatch(expr)?.group(1);
      if (key != null && data.containsKey(key)) return data[key];
    }

    if (expr.startsWith(r'$')) {
      final key = expr.substring(1);
      if (data.containsKey(key)) return data[key];
    }

    // Strings in quotes
    final stringMatch =
        RegExp(r"""^['"](.*)['"]$""", dotAll: true).firstMatch(expr);
    if (stringMatch != null) return stringMatch.group(1);

    // Fallback: return literal
    return expr;
  }

  bool _resolveCondition(String expr, Map<String, dynamic> data) {
    final value = _resolveExpression(expr, data);
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is num) return value != 0;
    return false;
  }
}
