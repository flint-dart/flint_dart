import 'package:flint_dart/flint_dart.dart';

class _ParsedSegment {
  final bool isParam;
  final String text;
  final RegExp? regex;

  const _ParsedSegment({
    required this.isParam,
    required this.text,
    this.regex,
  });
}

class _ParamSegment {
  final String name;
  final String? pattern;

  const _ParamSegment(this.name, this.pattern);
}

class Route {
  final String method;
  final String path;
  final Handler handler;
  final List<Middleware> middlewares;

  Handler? _cachedPipeline;
  int _cachedMiddlewareCount = -1;

  Handler get pipeline {
    if (_cachedPipeline == null || _cachedMiddlewareCount != middlewares.length) {
      _cachedPipeline = middlewares.fold<Handler>(
        handler,
        (prev, middleware) => middleware.handle(prev),
      );
      _cachedMiddlewareCount = middlewares.length;
    }
    return _cachedPipeline!;
  }

  late final bool isWildcard;
  late final String? wildcardPrefix;
  late final bool isStatic;
  late final List<_ParsedSegment> _parsedSegments;

  Route(this.method, this.path, this.handler, [this.middlewares = const []]) {
    if (path.endsWith('/*')) {
      isWildcard = true;
      wildcardPrefix = path.substring(0, path.length - 1);
      isStatic = false;
      _parsedSegments = const [];
    } else {
      isWildcard = false;
      wildcardPrefix = null;
      final rawSegments = path.split('/');
      var hasParam = false;
      final list = <_ParsedSegment>[];

      for (final raw in rawSegments) {
        if (raw.startsWith(':')) {
          hasParam = true;
          final parsed = _parseParam(raw);
          if (parsed != null) {
            final reg = parsed.pattern != null
                ? RegExp('^${parsed.pattern}\$')
                : null;
            list.add(_ParsedSegment(isParam: true, text: parsed.name, regex: reg));
          } else {
            list.add(_ParsedSegment(isParam: false, text: raw));
          }
        } else {
          list.add(_ParsedSegment(isParam: false, text: raw));
        }
      }

      isStatic = !hasParam;
      _parsedSegments = list;
    }
  }

  static _ParamSegment? _parseParam(String segment) {
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

  bool matches(List<String> pathParts, Map<String, String>? paramsOut) {
    if (isWildcard || isStatic) return false;
    if (_parsedSegments.length != pathParts.length) return false;

    final params = <String, String>{};
    for (int i = 0; i < _parsedSegments.length; i++) {
      final seg = _parsedSegments[i];
      final part = pathParts[i];

      if (seg.isParam) {
        if (seg.regex != null && !seg.regex!.hasMatch(part)) {
          return false;
        }
        params[seg.text] = part;
      } else {
        if (seg.text != part) return false;
      }
    }

    if (paramsOut != null) {
      paramsOut.addAll(params);
    }
    return true;
  }
}

class Router {
  final List<Route> _routes = [];
  List<Route> get routes => _routes;

  final Map<String, Map<String, Route>> _staticRoutesByMethod = {};
  final Map<String, List<Route>> _paramRoutesByMethod = {};
  final Map<String, List<Route>> _wildcardRoutesByMethod = {};

  void add(String method, String path, Object handler,
      {List<Middleware> middlewares = const []}) {
    final route = Route(
      method.toUpperCase(),
      path,
      _coerceHandler(handler),
      middlewares,
    );
    _routes.add(route);

    if (route.isStatic) {
      _staticRoutesByMethod
          .putIfAbsent(route.method, () => {})[route.path] = route;
    } else if (route.isWildcard) {
      _wildcardRoutesByMethod
          .putIfAbsent(route.method, () => [])
          .add(route);
    } else {
      _paramRoutesByMethod
          .putIfAbsent(route.method, () => [])
          .add(route);
    }
  }

  Handler? match(
      String method, String pathToMatch, Map<String, String> paramsOut) {
    final normalizedMethod = method.toUpperCase();

    // 1) Direct match for requested method
    final direct = _matchMethod(normalizedMethod, pathToMatch, paramsOut);
    if (direct != null) return direct;

    // 2) Auto HEAD from GET
    if (normalizedMethod == 'HEAD') {
      final headFromGet = _matchMethod('GET', pathToMatch, paramsOut);
      if (headFromGet != null) return headFromGet;
    }

    // 3) OPTIONS / 405 handling
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

  Handler? _matchMethod(
    String method,
    String pathToMatch,
    Map<String, String> paramsOut,
  ) {
    // 1. Fast O(1) static lookup
    final staticRoute = _staticRoutesByMethod[method]?[pathToMatch];
    if (staticRoute != null) {
      return staticRoute.pipeline;
    }

    // 2. Parameterized routes matching (pre-split path once)
    final paramRoutes = _paramRoutesByMethod[method];
    if (paramRoutes != null && paramRoutes.isNotEmpty) {
      final pathParts = pathToMatch.split('/');
      for (final route in paramRoutes) {
        final params = <String, String>{};
        if (route.matches(pathParts, params)) {
          paramsOut.addAll(params);
          return route.pipeline;
        }
      }
    }

    // 3. Wildcard routes matching
    final wildcardRoutes = _wildcardRoutesByMethod[method];
    if (wildcardRoutes != null) {
      for (final route in wildcardRoutes) {
        if (pathToMatch.startsWith(route.wildcardPrefix!)) {
          return route.pipeline;
        }
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

  List<String> _allowedMethods(String pathToMatch) {
    final methods = <String>{};
    List<String>? cachedParts;

    // Check static routes
    for (final entry in _staticRoutesByMethod.entries) {
      if (entry.value.containsKey(pathToMatch)) {
        methods.add(entry.key);
      }
    }

    // Check param routes
    for (final entry in _paramRoutesByMethod.entries) {
      if (entry.value.isNotEmpty) {
        cachedParts ??= pathToMatch.split('/');
        for (final route in entry.value) {
          if (route.matches(cachedParts, null)) {
            methods.add(entry.key);
            break;
          }
        }
      }
    }

    // Check wildcard routes
    for (final entry in _wildcardRoutesByMethod.entries) {
      for (final route in entry.value) {
        if (pathToMatch.startsWith(route.wildcardPrefix!)) {
          methods.add(entry.key);
          break;
        }
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
