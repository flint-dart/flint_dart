import 'package:flint_dart/src/swagger_gen/doc_parser.dart';
import 'package:flint_dart/src/swagger_gen/parser_state.dart';
import 'package:flint_dart/src/swagger_gen/route_extractor.dart';
import 'package:flint_dart/src/swagger_gen/swagger_generator.dart';

/// Parses route definitions from Dart files
class RouteParser {
  final _classPrefixReg =
      RegExp(r'''String\s+get\s+prefix\s*=>\s*['"]([^'"]+)['"]''');
  final _classTagReg =
      RegExp(r'''String\s+get\s+tag\s*=>\s*['"]([^'"]+)['"]''');

  void parseFile(List<String> lines, SwaggerGenerator generator) {
    final docParser = DocParser();
    final routeExtractor = RouteExtractor();

    // State tracking
    final state = ParserState();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Update parser state
      _updateParserState(state, trimmedLine, line);

      // Process documentation comments
      if (trimmedLine.startsWith('///')) {
        state.docBuffer.add(trimmedLine.substring(3).trim());
        continue;
      }

      // Parse class documentation
      if (state.insideRouteGroupClass && trimmedLine.contains('class ')) {
        final classDocs = docParser.parse(state.docBuffer);
        state.currentClassPrefixFromDocs = classDocs['prefix'];
        state.docBuffer.clear();
      }

      // Extract RouteGroup prefix/tag getters
      if (state.insideRouteGroupClass) {
        _extractRouteGroupInfo(state, line);
      }

      // Check for route definitions
      if (_isPotentialRouteStart(line)) {
        final parseResult = routeExtractor.extractRoute(lines, i);
        if (parseResult.routeInfo != null && state.insideRouteGroupClass) {
          _processRoute(parseResult.routeInfo!, state, docParser, generator);

          // Skip processed lines
          i += (parseResult.linesProcessed - 1);
          state.docBuffer.clear();
          continue;
        }
      }

      // Clear doc buffer on non-doc, non-whitespace lines
      if (trimmedLine.isNotEmpty && !trimmedLine.startsWith('///')) {
        state.docBuffer.clear();
      }

      // Check for end of class
      if (trimmedLine.contains('}') && state.insideRouteGroupClass) {
        state.insideRouteGroupClass = false;
      }
    }
  }

  void _updateParserState(ParserState state, String trimmedLine, String line) {
    if (trimmedLine.contains('class ') && trimmedLine.contains('RouteGroup')) {
      state.insideRouteGroupClass = true;
      state.currentClassPrefixFromDocs = null;
      state.currentGroupPrefix = null;
      state.currentGroupTag = null;
    }
  }

  void _extractRouteGroupInfo(ParserState state, String line) {
    final prefixMatch = _classPrefixReg.firstMatch(line);
    if (prefixMatch != null) {
      state.currentGroupPrefix = prefixMatch.group(1);
    }

    final tagMatch = _classTagReg.firstMatch(line);
    if (tagMatch != null) {
      state.currentGroupTag = tagMatch.group(1);
    }
  }

  bool _isPotentialRouteStart(String line) {
    // Pattern 1: Variable name followed by dot and HTTP method
    // Pattern 2: Just dot and HTTP method (for multi-line)
    // Pattern 3: Any valid Dart identifier followed by HTTP method
    final patterns = [
      RegExp(r'\b(\w+)\s*\.\s*(get|post|put|delete|patch|options|head)\s*\('),
      RegExp(r'\.\s*(get|post|put|delete|patch|options|head)\s*\('),
      RegExp(r'(get|post|put|delete|patch|options|head)\s*\('),
    ];

    for (var pattern in patterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }

    return false;
  }

  void _processRoute(
    Map<String, dynamic> routeInfo,
    ParserState state,
    DocParser docParser,
    SwaggerGenerator generator,
  ) {
    final routeDocs = docParser.parse(state.docBuffer);

    // Determine effective prefix
    final effectivePrefix = routeDocs['prefix'] ??
        state.currentClassPrefixFromDocs ??
        state.currentGroupPrefix;

    // Build full path with prefix
    final fullPath = _buildFullPath(routeInfo['path'] ?? '', effectivePrefix);

    // Build operation object
    final operation = generator.createOperation(
      summary: routeDocs['summary'] ?? '',
      tags: [state.currentGroupTag ?? 'Default'],
      responses: routeDocs['responses'] ??
          {
            '200': {'description': 'OK'}
          },
      requestBody: routeDocs['requestBody'],
      queryParameters: routeDocs['queryParameters'],
      parameters: routeDocs['parameters'],
      auth: routeDocs['auth'],
      fullPath: fullPath,
    );

    // Add to generator
    generator.addRoute(
      fullPath,
      routeInfo['method'] ?? 'get',
      operation,
      routeDocs['servers'] ?? [],
    );
  }

  String _buildFullPath(String routePath, String? prefix) {
    if (prefix == null || prefix.isEmpty) {
      return routePath;
    }

    // Clean the prefix
    var cleanPrefix = prefix;
    if (!cleanPrefix.startsWith('/')) {
      cleanPrefix = '/$cleanPrefix';
    }
    if (cleanPrefix.endsWith('/') && cleanPrefix != '/') {
      cleanPrefix = cleanPrefix.substring(0, cleanPrefix.length - 1);
    }

    // Clean the route path
    var cleanRoutePath = routePath;
    if (cleanRoutePath == '/') {
      cleanRoutePath = '';
    } else if (cleanRoutePath.startsWith('/')) {
      cleanRoutePath = cleanRoutePath.substring(1);
    }

    // Combine
    if (cleanRoutePath.isNotEmpty) {
      return '$cleanPrefix/$cleanRoutePath';
    } else {
      return cleanPrefix;
    }
  }
}
