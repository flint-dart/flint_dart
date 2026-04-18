import 'package:flint_dart/src/swagger_gen/route_parse_result.dart';

/// Extracts route information from code
class RouteExtractor {
  RouteParseResult extractRoute(List<String> lines, int startIndex) {
    var currentLine = lines[startIndex];

    // Check if this could be the start of a route
    // Either: variable.method( or just .method( for multi-line
    final hasRouteMethod = currentLine
        .contains(RegExp(r'\.(get|post|put|delete|patch|options|head|websocket)\s*\('));

    if (!hasRouteMethod && !currentLine.contains('.')) {
      return RouteParseResult(null, 1);
    }

    var buffer = StringBuffer(currentLine);
    var linesProcessed = 1;
    var parenBalance = _countParentheses(currentLine);

    // Keep reading lines until we have balanced parentheses
    for (var i = startIndex + 1; i < lines.length; i++) {
      final nextLine = lines[i];
      buffer.write(nextLine);
      linesProcessed++;

      parenBalance += _countParentheses(nextLine);

      // Stop when parentheses are balanced
      if (parenBalance <= 0) {
        // Check if we have a valid route method
        if (_containsRouteMethod(buffer.toString())) {
          final routeInfo = _parseRouteFromBuffer(buffer.toString());
          if (routeInfo != null) {
            return RouteParseResult(routeInfo, linesProcessed);
          }
        }

        // Check for chained methods
        if (i + 1 < lines.length) {
          final nextNextLine = lines[i + 1].trim();
          if (nextNextLine.startsWith('.useMiddleware') ||
              (nextNextLine.startsWith('.') && nextNextLine.contains('('))) {
            continue;
          }
        }
        break;
      }
    }

    // Final attempt to parse
    final routeInfo = _parseRouteFromBuffer(buffer.toString());
    return RouteParseResult(routeInfo, linesProcessed);
  }

  int _countParentheses(String line) {
    int balance = 0;
    for (var char in line.runes) {
      if (char == '(') balance++;
      if (char == ')') balance--;
    }
    return balance;
  }

  bool _containsRouteMethod(String text) {
    return RegExp(r'\.(get|post|put|delete|patch|options|head|websocket)\s*\(')
        .hasMatch(text);
  }

  Map<String, dynamic>? _parseRouteFromBuffer(String buffer) {
    final normalized =
        buffer.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

    final pattern = RegExp(
      r'''\.(get|post|put|delete|patch|options|head|websocket)\s*\(\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(normalized);
    if (match != null) {
      final extractedMethod = match.group(1)!.toLowerCase();
      var path = match.group(2)!;

      // Convert :param to {param}
      path = path.replaceAllMapped(RegExp(r':(\w+)'), (m) => '{${m[1]}}');

      return {
        "method": extractedMethod == 'websocket' ? 'get' : extractedMethod,
        "path": path,
        "isWebSocket": extractedMethod == 'websocket',
      };
    }

    return null;
  }
}
