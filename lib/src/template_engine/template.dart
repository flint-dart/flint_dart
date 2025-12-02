// ----------------------------
// File: lib/core/flint_template.dart
// ----------------------------
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// FlintTemplate: Modern, safe, and efficient template engine for Flint Dart
///
/// Features:
/// - 🚀 Fast compilation and caching
/// - 🔒 HTML escaping by default
/// - 📦 Template inheritance & components
/// - 🎯 Robust control structures
/// - 🔧 Extensible filter system
/// - 👀 Hot reload in development
/// - 🛡️ Safe execution environment

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
    // Fixed cascade operator - each filter assignment should be on its own line
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

  /// Render template as HTTP response
  // static Response view(String template,
  //     {Map<String, dynamic> data = const {}}) {
  //   final content = render(template, data: data);
  //   return Response(200, content, {
  //     'Content-Type': 'text/html; charset=utf-8',
  //     'X-Powered-By': 'Flint Template Engine'
  //   });
  // }

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

    // Get the current working directory
    final currentDir = Directory.current.path;
    // Construct the correct path - remove any leading path separators
    var cleanNormalized = normalized;
    if (cleanNormalized.startsWith(Platform.pathSeparator)) {
      cleanNormalized = cleanNormalized.substring(1);
    }

    final flintPath = p.join(
        currentDir, 'lib', 'src', 'views', '$cleanNormalized.flint.html');
    final htmlPath =
        p.join(currentDir, 'lib', 'src', 'views', '$cleanNormalized.html');

    // Check if .flint.html file exists
    if (File(flintPath).existsSync()) {
      return flintPath;
    }

    // Fallback to .html file
    if (File(htmlPath).existsSync()) {
      return htmlPath;
    }

    // List files in the views directory for debugging
    try {
      final viewsDir = Directory(p.join(currentDir, 'lib', 'src', 'views'));
      if (viewsDir.existsSync()) {
        viewsDir.listSync(recursive: true).forEach((entity) {
          if (entity is File) {}
        });
      }
    } catch (e) {
      _log('Compiling template...');
    }

    return flintPath;
  }

  static String _compileTemplate(String content) {
    _log('Compiling template...');

    // Processing order is important!
    var processed = content;

    // 1. Process template inheritance first
    processed = _processExtends(processed);

    // 2. Process includes
    processed = _processIncludes(processed);

    // 3. Process sections
    processed = _processSections(processed);
    processed = _processBlocks(processed);

    // 4. Remove comments
    processed = _processComments(processed);

    return processed;
  }

  static String _processTemplate(String compiled, Map<String, dynamic> data) {
    final context = {..._globals, ...data};

    var processed = compiled;

    // 1. Process control structures
    processed = _processControlStructures(processed, context);

    // 2. Process variables (last)
    processed = _processVariables(processed, context);

    return processed;
  }

  static Map<String, String> _extractBlocks(String content) {
    final blocks = <String, String>{};
    // Regex for block syntax: {@ block('name') @} content {@ endblock @}
    final blockRegex = RegExp(
        r"""{@\s*block\(['"]([^'"]+)['"]\)\s*@}(.*?){@\s*endblock\s*@}""",
        dotAll: true);

    for (final match in blockRegex.allMatches(content)) {
      final name = match.group(1)!;
      final content = match.group(2) ?? '';
      blocks[name] = content.trim();
    }

    return blocks;
  }

  static String _processExtends(String content) {
    // Use triple quotes for regex with single quotes
    final extendsRegex = RegExp(r"""{@\s*extends\(['"]([^'"]+)['"]\)\s*@}""");
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
    final yieldRegex = RegExp(r"""{@\s*yield\(['"]([^'"]+)['"]\)\s*@}""");
    result = result.replaceAllMapped(yieldRegex, (match) {
      final sectionName = match.group(1)!;
      return sections[sectionName] ?? '';
    });

    final blockYieldRegex = RegExp(r"""{@\s*yield\(['"]([^'"]+)['"]\)\s*@}""");
    result = result.replaceAllMapped(blockYieldRegex, (match) {
      final blockName = match.group(1)!;
      return blocks[blockName] ?? '';
    });

    return result;
  }

  static Map<String, String> _extractSections(String content) {
    final sections = <String, String>{};
    // Use triple quotes for complex regex patterns
    final sectionRegex = RegExp(
        r"""{@\s*section\(['"]([^'"]+)['"](?:,\s*['"]([^'"]+)['"])?\)\s*@}(.*?){@\s*endsection\s*@}""",
        dotAll: true);

    for (final match in sectionRegex.allMatches(content)) {
      final name = match.group(1)!;
      final defaultValue = match.group(2);
      final content = match.group(3) ?? defaultValue ?? '';
      sections[name] = content.trim();
    }

    return sections;
  }

  static String _processBlocks(String content) {
    // Remove any remaining block definitions after layout merge
    return content.replaceAll(
        RegExp(r'{@\s*block\([^)]+\)\s*@}.*?{@\s*endblock\s*@}', dotAll: true),
        '');
  }

  static String _processSections(String content) {
    // Remove any remaining section definitions after layout merge
    return content.replaceAll(
        RegExp(r'{@\s*section\([^)]+\)\s*@}.*?{@\s*endsection\s*@}',
            dotAll: true),
        '');
  }

  static String _processIncludes(String content) {
    // Use triple quotes for regex with mixed quotes
    final includeRegex =
        RegExp(r"""{@\s*include\(['"]([^'"]+)['"](?:,\s*({[^}]*}))?\)\s*@}""");

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

  static String _processComments(String content) {
    return content.replaceAll(RegExp(r'{@#.*?#@}', dotAll: true), '');
  }

  static String _processControlStructures(
      String content, Map<String, dynamic> context) {
    var processed = content;

    // Process in order of complexity
    processed = _processForLoops(processed, context);
    processed = _processSwitch(processed, context);
    processed = _processIfElse(processed, context);

    return processed;
  }

  static String _processIfElse(String content, Map<String, dynamic> context) {
    final ifRegex = RegExp(
        r'{@\s*if\s+(.+?)\s*@}(.*?)(?:(?={@\s*elseif\s+)|(?={@\s*else\s*@})|(?={@\s*endif\s*@}))',
        dotAll: true);

    return content.replaceAllMapped(ifRegex, (match) {
      final condition = match.group(1)!.trim();
      final trueBlock = match.group(2)!;

      if (_evaluateCondition(condition, context)) {
        return trueBlock;
      }

      // Look for elseif/else blocks
      final remaining = content.substring(match.end);
      final elseIfRegex = RegExp(
          r'{@\s*elseif\s+(.+?)\s*@}(.*?)(?:(?={@\s*elseif\s+)|(?={@\s*else\s*@})|(?={@\s*endif\s*@}))',
          dotAll: true);

      final elseRegex =
          RegExp(r'{@\s*else\s*@}(.*?){@\s*endif\s*@}', dotAll: true);

      for (final elseifMatch in elseIfRegex.allMatches(remaining)) {
        final elseifCondition = elseifMatch.group(1)!.trim();
        final elseifBlock = elseifMatch.group(2)!;

        if (_evaluateCondition(elseifCondition, context)) {
          return elseifBlock;
        }
      }

      final elseMatch = elseRegex.firstMatch(remaining);
      return elseMatch?.group(1) ?? '';
    });
  }

  static String _processForLoops(String content, Map<String, dynamic> context) {
    final forRegex = RegExp(
        r'{@\s*for\s+(\w+)\s+in\s+(.+?)\s*@}(.*?){@\s*endfor\s*@}',
        dotAll: true);

    return content.replaceAllMapped(forRegex, (match) {
      final itemVar = match.group(1)!;
      final collectionExpr = match.group(2)!;
      final loopBody = match.group(3)!;

      final collection = _evaluateExpression(collectionExpr, context);
      if (collection is! Iterable) return '';

      final buffer = StringBuffer();
      int index = 0;

      for (final item in collection) {
        final loopContext = Map<String, dynamic>.from(context);
        loopContext[itemVar] = item;
        loopContext['loop'] = {
          'index': index,
          'index0': index,
          'first': index == 0,
          'last': index == collection.length - 1,
          'length': collection.length,
        };

        // Process nested content with loop context
        var processedBody = _processControlStructures(loopBody, loopContext);
        processedBody = _processVariables(processedBody, loopContext);
        buffer.write(processedBody);

        index++;
      }

      return buffer.toString();
    });
  }

  static String _processSwitch(String content, Map<String, dynamic> context) {
    final switchRegex = RegExp(
        r'{@\s*switch\s+(.+?)\s*@}(.*?){@\s*endswitch\s*@}',
        dotAll: true);

    return content.replaceAllMapped(switchRegex, (match) {
      final switchExpr = match.group(1)!;
      final switchBody = match.group(2)!;

      final value = _evaluateExpression(switchExpr, context);

      final caseRegex =
          RegExp(r'{@\s*case\s+(.+?)\s*@}(.*?){@\s*endcase\s*@}', dotAll: true);

      for (final caseMatch in caseRegex.allMatches(switchBody)) {
        final caseValue =
            _evaluateExpression(caseMatch.group(1)!.trim(), context);
        if (caseValue == value) {
          return caseMatch.group(2)!;
        }
      }

      final defaultRegex =
          RegExp(r'{@\s*default\s*@}(.*?){@\s*enddefault\s*@}', dotAll: true);
      final defaultMatch = defaultRegex.firstMatch(switchBody);

      return defaultMatch?.group(1) ?? '';
    });
  }

  static String _processVariables(
      String content, Map<String, dynamic> context) {
    final varRegex = RegExp(r'@{(!)?\s*([^}|]+)(?:\s*\|\s*([^}]+))?\s*}');

    return content.replaceAllMapped(varRegex, (match) {
      final unsafe = match.group(1) != null; // ! means don't escape
      final expression = match.group(2)!.trim();
      final filterChain = match.group(3);

      try {
        var value = _evaluateExpression(expression, context);

        // Apply filters
        if (filterChain != null) {
          value = _applyFilters(value, filterChain);
        }

        final result = value?.toString() ?? '';
        return unsafe ? result : _escapeHtml(result);
      } catch (e) {
        _log('Error evaluating expression: $expression - $e');
        return '';
      }
    });
  }

  static dynamic _evaluateExpression(
      String expression, Map<String, dynamic> context) {
    final trimmed = expression.trim();

    // Handle literals
    if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;
    if (trimmed == 'null') return null;

    final numValue = num.tryParse(trimmed);
    if (numValue != null) return numValue;

    // Handle dot notation for nested properties
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      dynamic current = context;

      for (final part in parts) {
        if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else {
          return null;
        }
      }
      return current;
    }

    // Handle dot notation for nested properties
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      dynamic current = context;

      for (final part in parts) {
        if (current is Map && current.containsKey(part)) {
          current = current[part]; // This is Dart Map access!
        } else {
          return null;
        }
      }
      return current;
    }

    return context[trimmed]; // Direct Map access
  }

  static bool _evaluateCondition(
      String condition, Map<String, dynamic> context) {
    final value = _evaluateExpression(condition, context);

    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;

    return value != null;
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

  static void _log(String message) {
    if (debugMode) {
      print('[FlintTemplate] $message');
    }
  }

  // Add this method to FlintTemplate class
  // static String renderFile(String filePath,
  //     {Map<String, dynamic> data = const {}}) {
  //   _ensureInitialized();

  //   final file = File(filePath);
  //   if (!file.existsSync()) {
  //     throw TemplateException('Template file not found: $filePath');
  //   }

  //   _log('Rendering template file: $filePath');

  //   // Check cache
  //   if (cacheEnabled) {
  //     final cached = _cache.get(filePath);
  //     if (cached != null) {
  //       _log('Using cached template file: $filePath');
  //       return _processTemplate(cached, data);
  //     }
  //   }

  //   // Read and compile template
  //   final content = file.readAsStringSync();
  //   final compiled = _compileTemplate(content);

  //   if (cacheEnabled) {
  //     _cache.set(filePath, compiled);
  //   }

  //   return _processTemplate(compiled, data);
  // }
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
