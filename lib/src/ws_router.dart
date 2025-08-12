import 'dart:io';

import 'package:flint_dart/src/websocket.dart';

// typedef WsHandler = void Function(
//     FlintWebSocket client, Map<String, String> params);
// typedef WsAuthMiddleware = Future<bool> Function(HttpRequest req);

class WsRoute {
  final String path;
  final WsHandler handler;
  final WsAuthMiddleware? auth;
  late final RegExp _regex;
  late final List<String> _params;

  WsRoute(this.path, this.handler, this.auth) {
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
