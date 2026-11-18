import 'base_run.dart';
import 'dart:math';

class VariablesProcessor implements BaseExpression {
  // Match all {{ ... }} and {{! ... }} patterns
  static final _allPatterns = RegExp(r'\{\{!?\s*([^{}]+)\s*\}\}', dotAll: true);

  // Patterns that should NOT be processed as variables
  // These are for other processors (IncludeProcessor, SectionProcessor, etc.)
  static final _excludedPatterns = [
    RegExp(r'^\s*extends\('), // extends(...)
    RegExp(r'^\s*include\('), // include(...)
    RegExp(r'^\s*section\('), // section(...)
    RegExp(r'^\s*yield\('), // yield(...)
    RegExp(r'^\s*endsection\b'), // endsection
    RegExp(r'^\s*show\b'), // show
  ];

  @override
  String run(String content, [Map<String, dynamic>? context]) {
    context ??= {};

    return content.replaceAllMapped(_allPatterns, (match) {
      final rawExpression = match.group(1)?.trim() ?? '';
      final originalMatch = match.group(0)!;

      // Check if it's a comment {{! ... }}
      if (originalMatch.startsWith('{{!')) {
        return ''; // Return empty string for comments
      }

      // Skip processor-specific patterns
      if (_shouldSkip(rawExpression)) {
        return originalMatch;
      }

      if (rawExpression.isEmpty) {
        return '';
      }

      // Process the variable/expression
      return _processExpression(rawExpression, context!);
    });
  }

  /// Check if this pattern should be skipped (processed by another processor)
  bool _shouldSkip(String expression) {
    // Simple variables without parentheses should never be skipped
    if (!expression.contains('(')) {
      return false;
    }

    for (final pattern in _excludedPatterns) {
      if (pattern.hasMatch(expression)) {
        return true;
      }
    }
    return false;
  }

  /// Process a single expression
  String _processExpression(String expression, Map<String, dynamic> context) {
    // Handle filters
    if (expression.contains('|')) {
      return _handleVariableWithFilters(expression, context);
    }

    // Evaluate expression
    final value = _evaluateExpression(expression, context);
    return _formatOutput(value);
  }

  /// Format the output value for display
  String _formatOutput(dynamic value) {
    if (value == null) return '';

    // Handle special types
    if (value is List) {
      // Check if it's a nested list and flatten it for display
      if (_isNestedList(value)) {
        return _formatList(_flattenNestedList(value));
      }
      return _formatList(value);
    }
    if (value is Map) {
      return _formatMap(value);
    }
    if (value is bool) {
      return value.toString(); // "true" or "false"
    }
    if (value is num) {
      return value.toString();
    }

    return value.toString();
  }

  /// Format a list for output - CRITICAL FIX HERE
  String _formatList(List<dynamic> list) {
    final items = list.map((e) {
      if (e is String) {
        // For JavaScript/JSON context, we need quoted strings
        return '"${_escapeForJs(e)}"';
      } else if (e is num || e is bool) {
        return e.toString();
      } else if (e is List) {
        return _formatList(e);
      } else if (e is Map) {
        return _formatMap(e);
      }
      return '"${_escapeForJs(e.toString())}"';
    }).join(', ');
    return '[$items]';
  }

  /// Format a map for output
  String _formatMap(Map<dynamic, dynamic> map) {
    final entries = map.entries.map((e) {
      final key = e.key is String
          ? '"${_escapeForJs(e.key.toString())}"'
          : e.key.toString();
      final value = e.value is String
          ? '"${_escapeForJs(e.value.toString())}"'
          : _formatOutput(e.value);
      return '$key: $value';
    }).join(', ');
    return '{$entries}';
  }

  /// Escape string for JavaScript/JSON
  String _escapeForJs(String str) {
    return str
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
  }

  /// Check if list is nested (contains other lists)
  bool _isNestedList(List<dynamic> list) {
    for (final item in list) {
      if (item is List) {
        return true;
      }
    }
    return false;
  }

  /// Flatten a nested list
  List<dynamic> _flattenNestedList(List<dynamic> list) {
    final result = <dynamic>[];

    void flatten(dynamic item) {
      if (item is List) {
        for (final subItem in item) {
          flatten(subItem);
        }
      } else {
        result.add(item);
      }
    }

    flatten(list);
    return result;
  }

  String _handleVariableWithFilters(
    String rawExpression,
    Map<String, dynamic> context,
  ) {
    final parts = rawExpression.split('|').map((e) => e.trim()).toList();
    final variableName = parts.first;
    final filters = parts.sublist(1);

    dynamic value = _evaluateExpression(variableName, context);

    for (final filter in filters) {
      value = _applyFilter(value, filter);
    }

    return _formatOutput(value);
  }

  dynamic _evaluateExpression(String expr, Map<String, dynamic> context) {
    expr = expr.trim();

    // ✅ ADD THIS
    final nullCoalescing = _evaluateNullCoalescing(expr, context);
    if (nullCoalescing != null) return nullCoalescing;

    // If it's just a simple variable path, fetch it directly
    if (!_containsOperators(expr)) {
      return _fetchValue(expr, context) ?? expr;
    }

    // Handle parentheses first
    expr = _evaluateParentheses(expr, context);

    // Ternary operator
    final ternaryResult = _evaluateTernary(expr, context);
    if (ternaryResult != null) return ternaryResult;

    // Comparison operators
    final comparisonResult = _evaluateComparison(expr, context);
    if (comparisonResult != null) return comparisonResult;

    // Arithmetic expressions
    expr = _evaluateArithmetic(expr, context);

    // Simple operand
    return _evalOperand(expr, context);
  }

// Null coalescing operator ??
  dynamic _evaluateNullCoalescing(String expr, Map<String, dynamic> context) {
    if (!expr.contains('??')) return null;

    final parts = expr.split('??').map((e) => e.trim()).toList();
    if (parts.length != 2) return null;

    final left = _evaluateExpression(parts[0], context);
    if (left != null && left.toString().isNotEmpty) {
      return left;
    }

    return _evaluateExpression(parts[1], context);
  }

  /// Check if expression contains operators
  bool _containsOperators(String expr) {
    const operators = [
      '+',
      '-',
      '*',
      '/',
      '%',
      '^',
      '?',
      ':',
      '==',
      '!=',
      '>',
      '<',
      '>=',
      '<=',
      '(',
      ')'
    ];

    for (final op in operators) {
      if (expr.contains(op)) {
        return true;
      }
    }
    return false;
  }

  String _evaluateParentheses(String expr, Map<String, dynamic> context) {
    while (expr.contains('(') && expr.contains(')')) {
      final parenMatch = RegExp(r'\(([^()]+)\)').firstMatch(expr);
      if (parenMatch == null) break;

      final inside = parenMatch.group(1)!;
      final result = _evaluateExpression(inside, context);
      expr = expr.replaceFirst('($inside)', _formatOutput(result));
    }
    return expr;
  }

  dynamic _evaluateTernary(String expr, Map<String, dynamic> context) {
    final pattern = RegExp(r'^(.+?)\s*\?\s*(.+?)\s*:\s*(.+)$');
    final match = pattern.firstMatch(expr);

    if (match != null) {
      final condition = match.group(1)!.trim();
      final trueValue = match.group(2)!.trim();
      final falseValue = match.group(3)!.trim();

      final conditionResult = _evaluateExpression(condition, context);
      final boolCondition = _boolFromAnything(conditionResult);

      return boolCondition
          ? _evaluateExpression(trueValue, context)
          : _evaluateExpression(falseValue, context);
    }

    return null;
  }

  dynamic _evaluateComparison(String expr, Map<String, dynamic> context) {
    const operators = ['>=', '<=', '==', '!=', '>', '<'];

    for (final op in operators) {
      final index = expr.indexOf(op);
      if (index > 0) {
        final left = expr.substring(0, index).trim();
        final right = expr.substring(index + op.length).trim();

        final leftVal = _evaluateExpression(left, context);
        final rightVal = _evaluateExpression(right, context);

        return _compareValues(leftVal, rightVal, op);
      }
    }

    return null;
  }

  String _evaluateArithmetic(String expr, Map<String, dynamic> context) {
    // Handle exponentiation first (highest precedence)
    expr = _evaluateOperations(expr, context, ['^']);

    // Handle multiplication, division, modulus
    expr = _evaluateOperations(expr, context, ['*', '/', '%']);

    // Handle addition, subtraction (lowest precedence)
    expr = _evaluateOperations(expr, context, ['+', '-']);

    return expr;
  }

  String _evaluateOperations(
      String expr, Map<String, dynamic> context, List<String> operators) {
    for (final op in operators) {
      final escapedOp = RegExp.escape(op);
      // Pattern to match operand operator operand
      final pattern = RegExp(r'(-?\d+(?:\.\d+)?|\w+(?:\.\w+)*(?:\[\d+\])*)\s*' +
          escapedOp +
          r'\s*(-?\d+(?:\.\d+)?|\w+(?:\.\w+)*(?:\[\d+\])*)');

      while (true) {
        final match = pattern.firstMatch(expr);
        if (match == null) break;

        final left = match.group(1)!.trim();
        final right = match.group(2)!.trim();

        final leftVal = _evaluateExpression(left, context);
        final rightVal = _evaluateExpression(right, context);

        final result = _arithValues(leftVal, rightVal, op);
        expr = expr.replaceFirst(match.group(0)!, _formatOutput(result));
      }
    }

    return expr;
  }

  dynamic _evalOperand(String raw, Map<String, dynamic> context) {
    raw = raw.trim();

    // Check for numbers
    if (int.tryParse(raw) != null) return int.parse(raw);
    if (double.tryParse(raw) != null) return double.parse(raw);

    // Check for booleans
    if (raw == 'true') return true;
    if (raw == 'false') return false;

    // Check for quoted strings (keep quotes for JSON context)
    if ((raw.startsWith('"') && raw.endsWith('"')) ||
        (raw.startsWith("'") && raw.endsWith("'"))) {
      // Return without quotes for variable processing
      return raw.substring(1, raw.length - 1);
    }

    // Check for null
    if (raw == 'null') return null;

    // Try to fetch as variable path
    final value = _fetchValue(raw, context);
    if (value != null) return value;

    // If not found in context, return the raw string
    return raw;
  }

  dynamic _fetchValue(String path, Map<String, dynamic> context) {
    if (path.isEmpty) return null;

    // Handle array indices with variables
    path = _resolveBracketIndices(path, context);

    final segments = path.split('.');
    dynamic current = context;

    for (final segment in segments) {
      current = _resolveSegment(current, segment);
      if (current == null) return null;
    }

    return current;
  }

  String _resolveBracketIndices(String path, Map<String, dynamic> context) {
    final pattern = RegExp(r'(\w+)\[([^\]]+)\]');

    return path.replaceAllMapped(pattern, (match) {
      final varName = match.group(1)!;
      final indexExpr = match.group(2)!.trim();

      // Direct number
      if (int.tryParse(indexExpr) != null) {
        return match.group(0)!;
      }

      // Try to evaluate the index
      final indexResult = _evaluateExpression(indexExpr, context);
      if (indexResult is int) {
        return '$varName[$indexResult]';
      }

      return match.group(0)!;
    });
  }

  dynamic _resolveSegment(dynamic current, String segment) {
    if (current == null) return null;

    // Check for array access: items[0] or school.students[0]
    final arrayMatch = RegExp(r'^(\w+)\[(\d+)\]$').firstMatch(segment);
    if (arrayMatch != null) {
      final key = arrayMatch.group(1)!;
      final index = int.parse(arrayMatch.group(2)!);

      if (current is Map && current.containsKey(key)) {
        final value = current[key];
        if (value is List) {
          return index >= 0 && index < value.length ? value[index] : null;
        }
      }
      return null;
    }

    // Regular map access
    if (current is Map) {
      return current[segment];
    }

    // List access by index
    if (current is List && int.tryParse(segment) != null) {
      final index = int.parse(segment);
      return index >= 0 && index < current.length ? current[index] : null;
    }

    return null;
  }

  dynamic _applyFilter(dynamic value, String filter) {
    filter = filter.trim();

    // Default filter: default:"value"
    if (filter.startsWith('default:')) {
      if (value == null || value.toString().isEmpty) {
        return _extractFilterValue(filter.substring(8));
      }
      return value;
    }

    // Join filter: join:","
    if (filter.startsWith('join:')) {
      if (value is List) {
        final delimiter = _extractFilterValue(filter.substring(5));
        return value.join(delimiter);
      }
      return value;
    }

    // JSON filter: json (for JavaScript context)
    if (filter == 'json') {
      return _toJson(value);
    }

    // Flatten filter: flatten (for nested lists)
    if (filter == 'flatten') {
      if (value is List) {
        return _flattenNestedList(value);
      }
      return value;
    }

    // First filter: first (get first item from list)
    if (filter == 'first') {
      if (value is List && value.isNotEmpty) {
        return value[0];
      }
      return value;
    }

    // Raw filter: raw (output without quotes for strings)
    if (filter == 'raw') {
      if (value is String) {
        return value; // Return without quotes
      }
      return value;
    }

    // Other filters
    switch (filter) {
      case 'uppercase':
        return value?.toString().toUpperCase() ?? '';
      case 'lowercase':
        return value?.toString().toLowerCase() ?? '';
      case 'capitalize':
        final str = value?.toString() ?? '';
        return str.isNotEmpty
            ? str[0].toUpperCase() + str.substring(1).toLowerCase()
            : str;
      case 'length':
        if (value is List) return value.length;
        if (value is String) return value.length;
        if (value is Map) return value.length;
        return 0;
      case 'string':
        return value?.toString() ?? '';
      case 'bool':
      case 'boolean':
        return _boolFromAnything(value);
      default:
        return value;
    }
  }

  /// Convert value to JSON string
  String _toJson(dynamic value) {
    if (value == null) return 'null';
    if (value is String) {
      // Escape special characters for JSON
      return '"${_escapeForJs(value)}"';
    }
    if (value is bool || value is num) return value.toString();
    if (value is List) {
      // Handle nested lists by flattening them for JSON
      if (_isNestedList(value)) {
        final flattened = _flattenNestedList(value);
        final items = flattened.map((e) => _toJson(e)).join(', ');
        return '[$items]';
      }
      final items = value.map((e) => _toJson(e)).join(', ');
      return '[$items]';
    }
    if (value is Map) {
      final entries = value.entries
          .map(
              (e) => '"${_escapeForJs(e.key.toString())}": ${_toJson(e.value)}')
          .join(', ');
      return '{$entries}';
    }
    return '"${_escapeForJs(value.toString())}"';
  }

  String _extractFilterValue(String raw) {
    raw = raw.trim();
    if ((raw.startsWith('"') && raw.endsWith('"')) ||
        (raw.startsWith("'") && raw.endsWith("'"))) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  bool _compareValues(dynamic left, dynamic right, String operator) {
    // Try numeric comparison first
    final leftNum = _tryParseNumber(left);
    final rightNum = _tryParseNumber(right);

    if (leftNum != null && rightNum != null) {
      switch (operator) {
        case '==':
          return leftNum == rightNum;
        case '!=':
          return leftNum != rightNum;
        case '>':
          return leftNum > rightNum;
        case '>=':
          return leftNum >= rightNum;
        case '<':
          return leftNum < rightNum;
        case '<=':
          return leftNum <= rightNum;
      }
    }

    // String comparison
    final leftStr = left?.toString() ?? '';
    final rightStr = right?.toString() ?? '';

    switch (operator) {
      case '==':
        return leftStr == rightStr;
      case '!=':
        return leftStr != rightStr;
      case '>':
        return leftStr.compareTo(rightStr) > 0;
      case '>=':
        return leftStr.compareTo(rightStr) >= 0;
      case '<':
        return leftStr.compareTo(rightStr) < 0;
      case '<=':
        return leftStr.compareTo(rightStr) <= 0;
      default:
        return false;
    }
  }

  num? _tryParseNumber(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      // Try to parse as int first, then double
      return int.tryParse(value) ?? double.tryParse(value);
    }
    return null;
  }

  dynamic _arithValues(dynamic left, dynamic right, String operator) {
    final leftNum = _tryParseNumber(left);
    final rightNum = _tryParseNumber(right);

    if (leftNum != null && rightNum != null) {
      switch (operator) {
        case '+':
          return leftNum + rightNum;
        case '-':
          return leftNum - rightNum;
        case '*':
          return leftNum * rightNum;
        case '/':
          return rightNum == 0 ? 0 : leftNum / rightNum;
        case '%':
          return rightNum == 0 ? 0 : leftNum % rightNum;
        case '^':
          return pow(leftNum, rightNum);
      }
    }

    // String concatenation for addition
    if (operator == '+') {
      return '${left?.toString() ?? ''}${right?.toString() ?? ''}';
    }

    return null;
  }

  bool _boolFromAnything(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
      return value.isNotEmpty;
    }
    return value != null;
  }
}
