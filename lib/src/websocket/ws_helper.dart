import 'dart:io';

import 'package:flint_dart/src/websocket/websocket.dart';

typedef WsHandler = void Function(
    FlintWebSocket client, Map<String, String> params);
typedef WsAuthMiddleware = Future<bool> Function(HttpRequest req);
