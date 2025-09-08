import 'package:flint_dart/flint_dart.dart';

typedef Handler = Future<Response?> Function(Request req, Response res);

class Route {
  final String method;
  final String path;
  final Handler handler;

  Route(this.method, this.path, this.handler);
}

class Router {
  final List<Route> _routes = [];
  List<Route> get routes => _routes;

  void add(String method, String path, Handler handler) {
    _routes.add(Route(method.toUpperCase(), path, handler));
  }

  Handler? match(
      String method, String pathToMatch, Map<String, String> paramsOut) {
    for (final route in routes) {
      if (route.method != method) continue;

      if (route.path.endsWith('/*')) {
        final prefix = route.path.substring(0, route.path.length - 1);
        if (pathToMatch.startsWith(prefix)) {
          return route.handler;
        }
      }
      final routeParts = route.path.split('/');
      final pathParts = pathToMatch.split('/');

      if (routeParts.length != pathParts.length) continue;

      final params = <String, String>{};
      var matched = true;

      for (int i = 0; i < routeParts.length; i++) {
        final routeSegment = routeParts[i];
        final pathSegment = pathParts[i];

        if (routeSegment.startsWith(':')) {
          final key = routeSegment.substring(1);
          params[key] = pathSegment;
        } else if (routeSegment != pathSegment) {
          matched = false;
          break;
        }
      }

      if (matched) {
        paramsOut.addAll(params);
        return route.handler;
      }
    }

    return null; // No match
  }
}
