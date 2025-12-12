// ----------------------------
// File: lib/core/flint_template.dart
// ----------------------------
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// FlintTemplate: Modern, safe, and efficient template engine for Flint Dart
class FlintTemplateEngine {
  static bool cacheEnabled = true;
  static bool watchFiles = false;
  static bool debugMode = false;

  static final TemplateCache _cache = TemplateCache();
  static final Map<String, dynamic> _globals = {};
  static final Map<String, TemplateFilter> _filters = {};
  static StreamSubscription<FileSystemEvent>? _watchSub;

  // Initialize with common filters
  static void _initialize() {
    if (_filters.isNotEmpty) return;

    _filters['upper'] = (input) => input.toString().toUpperCase();
    _filters['lower'] = (input) => input.toString().toLowerCase();
    _filters['capitalize'] = (input) {
      final str = input.toString();
      return str.isEmpty
          ? str
          : str[0].toUpperCase() + str.substring(1).toLowerCase();
    };
    _filters['length'] = (input) {
      if (input is Iterable) return input.length.toString();
      if (input is Map) return input.length.toString();
      if (input is String) return input.length.toString();
      return '0';
    };
    _filters['currency'] = (input) {
      final num = double.tryParse(input.toString()) ?? 0;
      return '\$${num.toStringAsFixed(2)}';
    };
    _filters['date'] = (input) {
      if (input is DateTime) {
        return '${input.year}-${input.month.toString().padLeft(2, '0')}-${input.day.toString().padLeft(2, '0')}';
      }
      return input.toString();
    };
  }

  /// Set global data available to all templates
  static void global(String key, dynamic value) => _globals[key] = value;
  static void globals(Map<String, dynamic> values) => _globals.addAll(values);

  /// Register custom template filters
  static void filter(String name, TemplateFilter filter) =>
      _filters[name] = filter;

  /// Render a template to string
  static String render(String template,
      {Map<String, dynamic> data = const {}}) {
    _initialize();

    final path = _resolveTemplatePath(template);
    if (!File(path).existsSync()) {
      throw TemplateException('Template not found: $template at $path');
    }

    final content = File(path).readAsStringSync();
    final compiled = _compileTemplate(content);
    final result = _processTemplate(compiled, data);

    return result;
  }

  /// Render a string template (for nested processing)
  static String renderString(String content, Map<String, dynamic> context) {
    _initialize();
    var processed = content;
    processed = _processControlStructures(processed, context);
    processed = _processVariables(processed, context);
    return processed;
  }

  /// Start file watcher for hot reload
  static void watch({String? customPath}) {
    if (!watchFiles) return;

    final path = customPath;
    _log('Starting file watcher on: $path');

    _watchSub = Directory(path ?? "").watch(recursive: true).listen((event) {
      if (event is FileSystemModifyEvent) {
        _log('Template changed: ${event.path}');
        _cache.clear();
      }
    });
  }

  /// Stop file watcher
  static void stop() => _watchSub?.cancel();

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

  static String _compileTemplate(String content) {
    _log('Compiling template...');
    var processed = content;

    // Processing order is important!
    processed = _processExtends(processed);
    processed = _processIncludes(processed);
    processed = _processSections(processed);
    processed = _processBlocks(processed);
    processed = _processComments(processed);

    return processed;
  }

  static String _processTemplate(String compiled, Map<String, dynamic> data) {
    final context = {..._globals, ...data};
    return renderString(compiled, context);
  }

  // ==================== IF/ELSE PROCESSING (NEW IMPROVED VERSION) ====================

  static String _processIfElse(String content, Map<String, dynamic> context) {
    final buffer = StringBuffer();
    int index = 0;

    while (true) {
      final startPos = content.indexOf('{{ if', index);
      if (startPos == -1) {
        buffer.write(content.substring(index));
        break;
      }

      buffer.write(content.substring(index, startPos));

      // Find the closing }} of the if tag
      final ifStartClose = content.indexOf('}}', startPos);
      if (ifStartClose == -1) {
        buffer.write(content.substring(startPos));
        break;
      }

      // Extract the condition (remove "if " from the beginning)
      final ifConditionExpr =
          content.substring(startPos + 5, ifStartClose).trim();

      // Start of the block content (after the }})
      int blockStart = ifStartClose + 2;
      int searchPos = blockStart;
      int nested = 0;
      int endifPos = -1;

      // Find matching endif, accounting for nested ifs
      while (true) {
        final nextIf = content.indexOf('{{ if', searchPos);
        final nextEndif = content.indexOf('{{ endif }}', searchPos);

        if (nextEndif == -1) {
          break;
        }

        if (nextIf != -1 && nextIf < nextEndif) {
          nested++;
          searchPos = nextIf + 1;
        } else {
          if (nested > 0) {
            nested--;
            searchPos = nextEndif + 1;
          } else {
            endifPos = nextEndif;
            break;
          }
        }
      }

      if (endifPos == -1) {
        buffer.write(content.substring(blockStart));
        break;
      }

      final ifBlockContent = content.substring(blockStart, endifPos);
      final expanded = _expandIfBlock(ifConditionExpr, ifBlockContent, context);
      buffer.write(expanded);

      final endifClose = endifPos + '{{ endif }}'.length;
      index = endifClose;
    }

    return buffer.toString();
  }

  /// Expands an if-else block by evaluating conditions and returning the appropriate content.
  static String _expandIfBlock(
    String ifConditionExpr,
    String ifBlockContent,
    Map<String, dynamic> context,
  ) {
    var cursor = 0;
    var currentCondition = ifConditionExpr;
    final segments = <_ConditionalSegment>[];

    // Match elseif and else tags
    final elseIfRegex = RegExp(r'{{\s*elseif\s+(.*?)\s*}}');
    final elseRegex = RegExp(r'{{\s*else\s*}}');

    while (true) {
      final matchElseIf = elseIfRegex.firstMatch(
        ifBlockContent.substring(cursor),
      );
      final matchElse = elseRegex.firstMatch(ifBlockContent.substring(cursor));

      final elseIfPos = (matchElseIf == null) ? -1 : cursor + matchElseIf.start;
      final elsePos = (matchElse == null) ? -1 : cursor + matchElse.start;

      int nextPos = -1;
      bool isElseIf = false;

      if (elseIfPos == -1 && elsePos == -1) {
        // No more elseif or else tags found
      } else if (elseIfPos == -1) {
        nextPos = elsePos;
      } else if (elsePos == -1) {
        nextPos = elseIfPos;
        isElseIf = true;
      } else {
        // Both found, take the earlier one
        if (elseIfPos < elsePos) {
          nextPos = elseIfPos;
          isElseIf = true;
        } else {
          nextPos = elsePos;
        }
      }

      if (nextPos == -1) {
        // No more tags, this is the last segment
        final block = ifBlockContent.substring(cursor);
        segments.add(
          _ConditionalSegment(
            condition: currentCondition,
            content: block,
            isConditionSegment: true,
          ),
        );
        break;
      } else {
        // Extract content up to the next tag
        final block = ifBlockContent.substring(cursor, nextPos);
        segments.add(
          _ConditionalSegment(
            condition: currentCondition,
            content: block,
            isConditionSegment: true,
          ),
        );

        if (isElseIf) {
          // Process elseif
          final elseIfMatch = elseIfRegex.firstMatch(
            ifBlockContent.substring(nextPos),
          );
          if (elseIfMatch == null) break;
          currentCondition = elseIfMatch.group(1)!.trim();
          cursor = nextPos + elseIfMatch.end;
        } else {
          // Process else
          final elseMatch = elseRegex.firstMatch(
            ifBlockContent.substring(nextPos),
          );
          if (elseMatch == null) break;
          final elseStart = nextPos + elseMatch.end;
          final elseContent = ifBlockContent.substring(elseStart);

          segments.add(
            _ConditionalSegment(
              condition: '',
              content: elseContent,
              isConditionSegment: false, // else has no condition
            ),
          );
          break;
        }
      }
    }

    // Evaluate segments in order
    for (final seg in segments) {
      if (seg.isConditionSegment) {
        if (_evaluateCondition(seg.condition, context)) {
          return renderString(seg.content, context);
        }
      } else {
        // else block - always execute
        return renderString(seg.content, context);
      }
    }

    return ''; // No condition matched and no else block
  }

  /// Evaluate a condition expression
  static bool _evaluateCondition(
      String condition, Map<String, dynamic> context) {
    condition = condition.trim();

    if (condition.isEmpty) return false;

    // Handle boolean literals
    if (condition == 'true') return true;
    if (condition == 'false') return false;

    // Handle numeric literals
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(condition)) {
      final numValue = double.tryParse(condition) ?? int.tryParse(condition);
      return numValue != 0;
    }

    // Handle string literals
    if ((condition.startsWith("'") && condition.endsWith("'")) ||
        (condition.startsWith('"') && condition.endsWith('"'))) {
      final stringValue = condition.substring(1, condition.length - 1);
      return stringValue.isNotEmpty;
    }

    // Handle parentheses
    if (condition.startsWith('(') && condition.endsWith(')')) {
      final inner = condition.substring(1, condition.length - 1).trim();
      return _evaluateCondition(inner, context);
    }

    // Handle logical OR
    if (condition.contains('||')) {
      final parts = condition.split('||');
      for (final part in parts) {
        if (_evaluateCondition(part.trim(), context)) {
          return true;
        }
      }
      return false;
    }

    // Handle logical AND
    if (condition.contains('&&')) {
      final parts = condition.split('&&');
      for (final part in parts) {
        if (!_evaluateCondition(part.trim(), context)) {
          return false;
        }
      }
      return true;
    }

    // Handle NOT operator
    if (condition.startsWith('!')) {
      final inner = condition.substring(1).trim();
      return !_evaluateCondition(inner, context);
    }

    // Handle comparison operators
    for (final op in ['==', '!=', '>=', '<=', '>', '<']) {
      final parts = _splitByOperator(condition, op);
      if (parts != null) {
        final left = parts[0].trim();
        final right = parts[1].trim();

        final lval = _getValue(left, context);
        final rval = _getValue(right, context);

        // Numeric comparison
        if (lval is num && rval is num) {
          switch (op) {
            case '>':
              return lval > rval;
            case '<':
              return lval < rval;
            case '>=':
              return lval >= rval;
            case '<=':
              return lval <= rval;
            case '==':
              return lval == rval;
            case '!=':
              return lval != rval;
          }
        }

        // String comparison
        final lstr = lval?.toString() ?? '';
        final rstr = rval?.toString() ?? '';

        switch (op) {
          case '==':
            return lstr == rstr;
          case '!=':
            return lstr != rstr;
          case '>':
            return lstr.compareTo(rstr) > 0;
          case '<':
            return lstr.compareTo(rstr) < 0;
          case '>=':
            return lstr.compareTo(rstr) >= 0;
          case '<=':
            return lstr.compareTo(rstr) <= 0;
        }
      }
    }

    // Simple variable lookup
    final value = _getValue(condition, context);

    // Convert to boolean
    return _isTruthy(value);
  }

  static List<String>? _splitByOperator(String expr, String op) {
    int depth = 0;
    bool inSingleQuote = false;
    bool inDoubleQuote = false;

    for (int i = 0; i <= expr.length - op.length; i++) {
      final ch = expr[i];

      // Handle quotes
      if (ch == "'" && !inDoubleQuote) inSingleQuote = !inSingleQuote;
      if (ch == '"' && !inSingleQuote) inDoubleQuote = !inDoubleQuote;

      if (!inSingleQuote && !inDoubleQuote) {
        // Handle parentheses
        if (ch == '(') depth++;
        if (ch == ')') depth--;

        // Check for operator at top level
        if (depth == 0 && expr.substring(i, i + op.length) == op) {
          return [expr.substring(0, i), expr.substring(i + op.length)];
        }
      }
    }

    return null;
  }

  static dynamic _getValue(String expr, Map<String, dynamic> context) {
    expr = expr.trim();

    // Remove parentheses
    while (expr.startsWith('(') && expr.endsWith(')')) {
      expr = expr.substring(1, expr.length - 1).trim();
    }

    // String literals
    if ((expr.startsWith("'") && expr.endsWith("'")) ||
        (expr.startsWith('"') && expr.endsWith('"'))) {
      return expr.substring(1, expr.length - 1);
    }

    // Numeric literals
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(expr)) {
      return double.tryParse(expr) ?? int.tryParse(expr);
    }

    // Boolean literals
    if (expr.toLowerCase() == 'true') return true;
    if (expr.toLowerCase() == 'false') return false;

    // Variable lookup
    return _resolveVariable(expr, context);
  }

  static dynamic _resolveVariable(
      String varName, Map<String, dynamic> context) {
    varName = varName.trim();

    // Direct lookup
    if (context.containsKey(varName)) {
      return context[varName];
    }

    // Case-insensitive lookup
    for (final key in context.keys) {
      if (key.toString().toLowerCase() == varName.toLowerCase()) {
        return context[key];
      }
    }

    // Dot notation
    if (varName.contains('.')) {
      final parts = varName.split('.');
      dynamic current = context;

      for (final part in parts) {
        if (current is Map) {
          // Case-insensitive lookup for each part
          String? matchingKey;
          for (final key in current.keys) {
            if (key.toString().toLowerCase() == part.toLowerCase()) {
              matchingKey = key.toString();
              break;
            }
          }

          if (matchingKey != null) {
            current = current[matchingKey];
          } else {
            return null;
          }
        } else {
          return null;
        }
      }
      return current;
    }

    return null;
  }

  static bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value.isEmpty) return false;
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
      return true;
    }
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  // ==================== OTHER TEMPLATE FEATURES ====================

  static String _processControlStructures(
      String content, Map<String, dynamic> context) {
    var processed = content;
    // Process in order of complexity
    processed = _processForLoops(processed, context);
    processed = _processSwitch(processed, context);
    processed = _processIfElse(processed, context);
    return processed;
  }

  static String _processForLoops(String content, Map<String, dynamic> context) {
    final forRegex = RegExp(
        r'{{\s*for\s+(\w+)\s+in\s+(.+?)\s*}}(.*?){{\s*endfor\s*}}',
        dotAll: true);

    return content.replaceAllMapped(forRegex, (match) {
      final itemVar = match.group(1)!;
      final collectionExpr = match.group(2)!;
      final loopBody = match.group(3)!;

      final collection = _getValue(collectionExpr, context);
      if (collection is! Iterable) return '';

      final buffer = StringBuffer();
      int index = 0;

      for (final item in collection) {
        final loopContext = Map<String, dynamic>.from(context);
        loopContext[itemVar] = item;
        loopContext['loop'] = {
          'index': index + 1,
          'index0': index,
          'first': index == 0,
          'last': index == collection.length - 1,
          'length': collection.length,
        };

        final processedBody = renderString(loopBody, loopContext);
        buffer.write(processedBody);

        index++;
      }

      return buffer.toString();
    });
  }

  static String _processSwitch(String content, Map<String, dynamic> context) {
    final switchRegex = RegExp(
        r'{{\s*switch\s+(.+?)\s*}}(.*?){{\s*endswitch\s*}}',
        dotAll: true);

    return content.replaceAllMapped(switchRegex, (match) {
      final switchExpr = match.group(1)!;
      final switchBody = match.group(2)!;

      final value = _getValue(switchExpr, context);

      final caseRegex =
          RegExp(r'{{\s*case\s+(.+?)\s*}}(.*?){{\s*endcase\s*}}', dotAll: true);

      for (final caseMatch in caseRegex.allMatches(switchBody)) {
        final caseValue = _getValue(caseMatch.group(1)!.trim(), context);
        if (caseValue == value) {
          return caseMatch.group(2)!;
        }
      }

      final defaultRegex =
          RegExp(r'{{\s*default\s*}}(.*?){{\s*enddefault\s*}}', dotAll: true);
      final defaultMatch = defaultRegex.firstMatch(switchBody);

      return defaultMatch?.group(1) ?? '';
    });
  }

  static String _processVariables(
      String content, Map<String, dynamic> context) {
    final varRegex = RegExp(r'{{(!)?\s*([^}|]+)(?:\s*\|\s*([^}]+))?\s*}}');

    return content.replaceAllMapped(varRegex, (match) {
      final unsafe = match.group(1) != null;
      final expression = match.group(2)!.trim();
      final filterChain = match.group(3);

      try {
        var value = _getValue(expression, context);

        if (filterChain != null) {
          value = _applyFilters(value, filterChain);
        }

        final scriptContext = _isInsideScript(content, match.start);

        if (value is List || value is Map) {
          return scriptContext
              ? jsonEncode(value)
              : _escapeHtml(jsonEncode(value));
        }

        final result = value?.toString() ?? '';
        return unsafe ? result : _escapeHtml(result);
      } catch (e) {
        _log('Error evaluating expression: $expression - $e');
        return '';
      }
    });
  }

  static dynamic _applyFilters(dynamic value, String filterChain) {
    var result = value;
    final filters = filterChain.split('|').map((f) => f.trim());

    for (final filterName in filters) {
      if (_filters.containsKey(filterName)) {
        result = _filters[filterName]!(result);
      }
    }

    return result;
  }

  static bool _isInsideScript(String content, int position) {
    final before = content.substring(0, position).toLowerCase();
    final lastScriptOpen = before.lastIndexOf('<script');
    final lastScriptClose = before.lastIndexOf('</script>');
    return lastScriptOpen > lastScriptClose;
  }

  static String _escapeHtml(String text) {
    const escapes = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#x27;',
      '/': '&#x2F;',
    };

    return text.replaceAllMapped(
        RegExp(r'''[&<>"\'/]'''), (match) => escapes[match.group(0)]!);
  }

  // ==================== TEMPLATE INHERITANCE ====================

  static String _processExtends(String content) {
    final extendsRegex = RegExp(r"""{{\s*extends\(['"]([^'"]+)['"]\)\s*}}""");
    final match = extendsRegex.firstMatch(content);

    if (match == null) return content;

    final layoutName = match.group(1)!;
    final layoutPath = _resolveTemplatePath(layoutName);

    if (!File(layoutPath).existsSync()) {
      throw TemplateException('Layout not found: $layoutName at $layoutPath');
    }

    final layoutContent = File(layoutPath).readAsStringSync();
    final childContent = content.replaceFirst(match.group(0)!, '');

    return _mergeLayout(layoutContent, childContent);
  }

  static String _mergeLayout(String layout, String child) {
    final sections = _extractSections(child);
    final blocks = _extractBlocks(child);

    var result = layout;

    // Replace yields with section content
    final yieldRegex = RegExp(r"""{{\s*yield\(['"]([^'"]+)['"]\)\s*}}""");
    result = result.replaceAllMapped(yieldRegex, (match) {
      final sectionName = match.group(1)!;
      return sections[sectionName] ?? '';
    });

    // Replace block yields
    final blockYieldRegex = RegExp(r"""{{\s*block\(['"]([^'"]+)['"]\)\s*}}""");
    result = result.replaceAllMapped(blockYieldRegex, (match) {
      final blockName = match.group(1)!;
      return blocks[blockName] ?? '';
    });

    return result;
  }

  static Map<String, String> _extractSections(String content) {
    final sections = <String, String>{};
    final sectionRegex = RegExp(
        r"""{{\s*section\(['"]([^'"]+)['"](?:,\s*['"]([^'"]+)['"])?\)\s*}}(.*?){{\s*endsection\s*}}""",
        dotAll: true);

    for (final match in sectionRegex.allMatches(content)) {
      final name = match.group(1)!;
      final defaultValue = match.group(2);
      final content = match.group(3) ?? defaultValue ?? '';
      sections[name] = content.trim();
    }

    return sections;
  }

  static Map<String, String> _extractBlocks(String content) {
    final blocks = <String, String>{};
    final blockRegex = RegExp(
        r"""{{\s*block\(['"]([^'"]+)['"]\)\s*}}(.*?){{\s*endblock\s*}}""",
        dotAll: true);

    for (final match in blockRegex.allMatches(content)) {
      final name = match.group(1)!;
      final content = match.group(2) ?? '';
      blocks[name] = content.trim();
    }

    return blocks;
  }

  static String _processIncludes(String content) {
    final includeRegex =
        RegExp(r"""{{\s*include\(['"]([^'"]+)['"](?:,\s*({[^}]*}))?\)\s*}}""");

    return content.replaceAllMapped(includeRegex, (match) {
      final templateName = match.group(1)!;
      final jsonData = match.group(2);

      Map<String, dynamic> data = {};
      if (jsonData != null) {
        try {
          data = jsonDecode(jsonData);
        } catch (e) {
          _log('Warning: Invalid JSON in include: $jsonData');
        }
      }

      return render(templateName, data: data);
    });
  }

  static String _processBlocks(String content) {
    return content.replaceAll(
        RegExp(r'{{\s*block\([^)]+\)\s*}}.*?{{\s*endblock\s*}}', dotAll: true),
        '');
  }

  static String _processSections(String content) {
    return content.replaceAll(
        RegExp(r'{{\s*section\([^)]+\)\s*}}.*?{{\s*endsection\s*}}',
            dotAll: true),
        '');
  }

  static String _processComments(String content) {
    return content.replaceAll(RegExp(r'{{#.*?#}}', dotAll: true), '');
  }

  static void _log(String message) {
    if (debugMode) {
      print('[FlintTemplate] $message');
    }
  }
}

/// Represents a conditional segment in an if-else block
class _ConditionalSegment {
  final String condition;
  final String content;
  final bool isConditionSegment;

  _ConditionalSegment({
    required this.condition,
    required this.content,
    required this.isConditionSegment,
  });
}

// ----------------------------
// File: lib/core/template_cache.dart
// ----------------------------
class TemplateCache {
  final _cache = HashMap<String, String>();
  final _timestamps = HashMap<String, DateTime>();

  String? get(String key) {
    final file = File(key);
    if (file.existsSync()) {
      final lastModified = file.lastModifiedSync();
      if (_timestamps[key] != lastModified) {
        _cache.remove(key);
        return null;
      }
    }
    return _cache[key];
  }

  void set(String key, String value) {
    final file = File(key);
    _cache[key] = value;
    _timestamps[key] =
        file.existsSync() ? file.lastModifiedSync() : DateTime.now();
  }

  void clear() {
    _cache.clear();
    _timestamps.clear();
  }

  int get size => _cache.length;
}

// ----------------------------
// File: lib/core/template_exception.dart
// ----------------------------
class TemplateException implements Exception {
  final String message;
  final String? template;
  final int? line;

  TemplateException(this.message, {this.template, this.line});

  @override
  String toString() {
    var result = 'TemplateException: $message';
    if (template != null) result += ' in $template';
    if (line != null) result += ' at line $line';
    return result;
  }
}

typedef TemplateFilter = dynamic Function(dynamic input);
