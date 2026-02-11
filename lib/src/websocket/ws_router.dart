import 'package:flint_dart/src/context.dart';
import 'package:flint_dart/src/middleware/middleware.dart';

class WsRoute {
  final String path;
  final Handler handler;
  final List<Middleware> middlewares;
  late final RegExp _regex;
  late final List<String> _params;

  WsRoute(this.path, this.handler, [this.middlewares = const []]) {
    final paramNames = <String>[];
    final regexPattern = path.replaceAllMapped(
      RegExp(r':(\w+)'),
      (m) {
        paramNames.add(m.group(1)!);
        return r'([^/]+)';
      },
    );
    _regex = RegExp('^$regexPattern\$');
    _params = paramNames;
  }

  Map<String, String>? match(String urlPath) {
    final match = _regex.firstMatch(urlPath);
    if (match == null) return null;
    final params = <String, String>{};
    for (var i = 0; i < _params.length; i++) {
      params[_params[i]] = match.group(i + 1)!;
    }
    return params;
  }
}
