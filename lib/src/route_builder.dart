import 'package:flint_dart/flint_dart.dart';

class RouteBuilder {
  final Router _router;
  final String method;
  final String _rawPath;
  Handler handler;
  final List<Middleware> _middlewares = [];

  RouteBuilder(this._router, this.method, String path, this.handler)
      : _rawPath = path;

  // Normalize the route path
  String get normalizedPath {
    String p = _rawPath.trim();

    // Root should remain "/"
    if (p == "/") return "/";

    // Ensure leading slash
    if (!p.startsWith('/')) {
      p = '/$p';
    }

    // Remove trailing slash except root
    if (p != "/" && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }

    return p;
  }

  RouteBuilder useMiddleware(Middleware middleware) {
    _middlewares.add(middleware);
    return this;
  }

  void register() {
    _router.add(
      method,
      normalizedPath,
      handler,
      middlewares: _middlewares,
    );
  }
}
