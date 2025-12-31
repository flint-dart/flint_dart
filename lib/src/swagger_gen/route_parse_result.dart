/// Result of route extraction
class RouteParseResult {
  final Map<String, dynamic>? routeInfo;
  final int linesProcessed;

  RouteParseResult(this.routeInfo, this.linesProcessed);
}
