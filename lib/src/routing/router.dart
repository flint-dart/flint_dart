import 'package:flint_dart/flint_dart.dart';

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

  void add(String method, String path, Object handler,
      {List<Middleware> middlewares = const []}) {
    _routes.add(Route(
        method.toUpperCase(), path, _coerceHandler(handler), middlewares));
  }

  Handler? match(
      String method, String pathToMatch, Map<String, String> paramsOut) {
    final normalizedMethod = method.toUpperCase();

    // 1) Exact/param matches (no wildcard)
    final direct = _matchForMethod(
      normalizedMethod,
      pathToMatch,
      paramsOut,
      includeWildcard: false,
    );
    if (direct != null) return direct;

    // 2) Wildcard matches (only if no direct match)
    final wildcard = _matchForMethod(
      normalizedMethod,
      pathToMatch,
      paramsOut,
      includeWildcard: true,
    );
    if (wildcard != null) return wildcard;

    // 3) Auto HEAD from GET
    if (normalizedMethod == 'HEAD') {
      final headFromGet = _matchForMethod(
        'GET',
        pathToMatch,
        paramsOut,
        includeWildcard: false,
      );
      if (headFromGet != null) return headFromGet;
      final headFromGetWildcard = _matchForMethod(
        'GET',
        pathToMatch,
        paramsOut,
        includeWildcard: true,
      );
      if (headFromGetWildcard != null) return headFromGetWildcard;
    }

    // 4) OPTIONS / 405 handling
    final allowedMethods = _allowedMethods(pathToMatch);
    if (allowedMethods.isEmpty) return null;

    final allowHeader = _formatAllowHeader(allowedMethods);

    if (normalizedMethod == 'OPTIONS') {
      return (ctx) async {
        final res = ctx.res;
        if (res == null) return null;
        try {
          res.raw.headers.set('Allow', allowHeader);
        } on StateError {
          return null;
        }
        return res.status(204).send('');
      };
    }

    return (ctx) async {
      final res = ctx.res;
      if (res == null) return null;
      try {
        res.raw.headers.set('Allow', allowHeader);
      } on StateError {
        return null;
      }
      return res.status(405).send('Method Not Allowed');
    };
  }

  Handler _wrapWithMiddlewares(Handler handler, List<Middleware> middlewares) {
    return middlewares.fold<Handler>(
      handler,
      (prev, middleware) => middleware.handle(prev),
    );
  }

  Handler? _matchForMethod(
    String method,
    String pathToMatch,
    Map<String, String> paramsOut, {
    required bool includeWildcard,
  }) {
    for (final route in routes) {
      if (route.method != method) continue;

      if (!includeWildcard && route.path.endsWith('/*')) continue;

      final params = <String, String>{};
      if (_pathMatches(route.path, pathToMatch, params)) {
        paramsOut.addAll(params);
        return _wrapWithMiddlewares(route.handler, route.middlewares);
      }
    }
    return null;
  }

  Handler _coerceHandler(Object handler) {
    if (handler is Handler) return handler;
    if (handler is LegacyHandler) return adaptHttp(handler);
    if (handler is Function) {
      return (ctx) async {
        final res = ctx.res;
        if (res == null) return null;
        final result = Function.apply(handler, [ctx.req, res]);
        if (result is Future) {
          return await result;
        }
        return result;
      };
    }
    throw ArgumentError(
      'Handler must be a Handler or LegacyHandler',
    );
  }

  bool _pathMatches(
    String routePath,
    String pathToMatch,
    Map<String, String>? paramsOut,
  ) {
    // Wildcard: /prefix/*
    if (routePath.endsWith('/*')) {
      final prefix = routePath.substring(0, routePath.length - 1);
      return pathToMatch.startsWith(prefix);
    }

    final routeParts = routePath.split('/');
    final pathParts = pathToMatch.split('/');

    if (routeParts.length != pathParts.length) return false;

    final params = <String, String>{};
    for (int i = 0; i < routeParts.length; i++) {
      final routeSegment = routeParts[i];
      final pathSegment = pathParts[i];

      if (routeSegment.startsWith(':')) {
        final parsed = _parseParamSegment(routeSegment);
        if (parsed == null) return false;

        if (parsed.pattern != null) {
          final regex = RegExp('^${parsed.pattern}\$');
          if (!regex.hasMatch(pathSegment)) {
            return false;
          }
        }

        params[parsed.name] = pathSegment;
        continue;
      }

      if (routeSegment != pathSegment) return false;
    }

    if (paramsOut != null) {
      paramsOut.addAll(params);
    }
    return true;
  }

  _ParamSegment? _parseParamSegment(String segment) {
    if (!segment.startsWith(':')) return null;

    final rest = segment.substring(1);
    if (rest.isEmpty) return null;

    final openIdx = rest.indexOf('(');
    if (openIdx == -1) {
      return _ParamSegment(rest, null);
    }

    final closeIdx = rest.lastIndexOf(')');
    if (closeIdx <= openIdx) {
      return _ParamSegment(rest, null);
    }

    final name = rest.substring(0, openIdx);
    final pattern = rest.substring(openIdx + 1, closeIdx);
    if (name.isEmpty || pattern.isEmpty) {
      return _ParamSegment(rest, null);
    }

    return _ParamSegment(name, pattern);
  }

  List<String> _allowedMethods(String pathToMatch) {
    final methods = <String>{};
    for (final route in routes) {
      if (_pathMatches(route.path, pathToMatch, null)) {
        methods.add(route.method);
      }
    }

    if (methods.contains('GET')) {
      methods.add('HEAD');
    }
    if (methods.isNotEmpty) {
      methods.add('OPTIONS');
    }

    return methods.toList();
  }

  String _formatAllowHeader(List<String> methods) {
    const preferredOrder = [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'QUERY',
      'DELETE',
      'HEAD',
      'OPTIONS'
    ];

    methods.sort((a, b) {
      final ia = preferredOrder.indexOf(a);
      final ib = preferredOrder.indexOf(b);
      if (ia == -1 && ib == -1) return a.compareTo(b);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });

    return methods.join(', ');
  }
}

class _ParamSegment {
  final String name;
  final String? pattern;

  const _ParamSegment(this.name, this.pattern);
}
