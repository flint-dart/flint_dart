import 'dart:async';

import 'package:flint_dart/flint_dart.dart';

typedef Handler = FutureOr<Response?> Function(Request req, Response res);

class Route {
  final String method;
  final String path;
  final Handler handler;
  final List<Middleware> middlewares;

  Route(this.method, this.path, this.handler, [this.middlewares = const []]);
}

class Router {
  final List<Route> _routes = [];
  List<Route> get routes => _routes;

  void add(String method, String path, Handler handler,
      {List<Middleware> middlewares = const []}) {
    _routes.add(Route(method.toUpperCase(), path, handler, middlewares));
  }

  Handler? match(
      String method, String pathToMatch, Map<String, String> paramsOut) {
    for (final route in routes) {
      if (route.method != method) continue;

      if (route.path.endsWith('/*')) {
        final prefix = route.path.substring(0, route.path.length - 1);
        if (pathToMatch.startsWith(prefix)) {
          return _wrapWithMiddlewares(route.handler, route.middlewares);
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
        return _wrapWithMiddlewares(route.handler, route.middlewares);
      }
    }

    return null; // No match
  }

  Handler _wrapWithMiddlewares(Handler handler, List<Middleware> middlewares) {
    return middlewares.fold<Handler>(
      handler,
      (prev, middleware) => middleware.handle(prev),
    );
  }
}
