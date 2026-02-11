import 'dart:async';

import 'request.dart';
import 'response.dart';
import 'websocket/websocket.dart';

/// A legacy HTTP handler signature.
typedef LegacyHandler = FutureOr<Response?> Function(Request req, Response res);

/// Unified handler signature for HTTP + WebSocket routes.
///
/// Returning a value is optional and only applies to HTTP contexts.
typedef Handler = FutureOr<Object?> Function(Context ctx);

/// Legacy WebSocket handler signature.
typedef WsHandler = void Function(Request req, FlintWebSocket socket);

/// Adapter for legacy HTTP handlers.
///
/// Example:
/// ```dart
/// app.get('/hello', (req, res) {
///   res.json({'message': 'hello'});
/// });
/// ```
Handler adaptHttp(LegacyHandler legacy) {
  return (ctx) async {
    final res = ctx.res;
    if (res == null) return null;
    return await legacy(ctx.req, res);
  };
}

/// Adapter for legacy WebSocket handlers.
///
/// Example:
/// ```dart
/// app.websocket('/chat', (req, socket) {
///   socket.on('ping', (_) => socket.emit('pong', {}));
/// });
/// ```
Handler adaptWebSocket(WsHandler legacy) {
  return (ctx) {
    final socket = ctx.socket;
    if (socket == null) return null;
    legacy(ctx.req, socket);
    return null;
  };
}

/// Unified request context for HTTP and WebSocket routes.
///
/// Example:
/// ```dart
/// app.get('/hello', (ctx) {
///   ctx.res?.json({'message': 'hello'});
/// });
///
/// app.websocket('/chat', (ctx) {
///   ctx.socket?.on('ping', (_) => ctx.socket?.emit('pong', {}));
/// });
/// ```
class Context {
  final Request req;
  final Response? res;
  final FlintWebSocket? socket;

  Context({
    required this.req,
    this.res,
    this.socket,
  });

  bool get isHttp => res != null;
  bool get isWebSocket => socket != null;
}
