import 'package:flint_dart/flint_dart.dart';

class RouteBuilder {
  final Router _router;
  final String method;
  final String path;
  Handler handler;
  final List<Middleware> _middlewares = [];

  RouteBuilder(this._router, this.method, this.path, this.handler);

  RouteBuilder useMiddleware(Middleware middleware) {
    _middlewares.add(middleware);
    return this;
  }

  void register() {
    _router.add(method, path, handler, middlewares: _middlewares);
  }
}
