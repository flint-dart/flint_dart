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
  final Map<Object, Object?> extras;

  Context({
    required this.req,
    this.res,
    this.socket,
    Map<Object, Object?>? extras,
  }) : extras = Map<Object, Object?>.from(extras ?? const {});

  bool get isHttp => res != null;
  bool get isWebSocket => socket != null;

  bool hasExtra(Object key) => extras.containsKey(key);

  Object? operator [](Object key) => extras[key];

  void operator []=(Object key, Object? value) {
    extras[key] = value;
  }

  T? getExtra<T>(Object key) {
    final value = extras[key];
    if (value == null) return null;
    if (value is T) return value as T;
    throw StateError(
      'Context extra "$key" is ${value.runtimeType}, not $T.',
    );
  }

  void setExtra(Object key, Object? value) {
    extras[key] = value;
  }

  /// Type-keyed storage for future session/user injection patterns.
  T? read<T>() => getExtra<T>(T);

  /// Type-keyed storage for future session/user injection patterns.
  void write<T>(T value) {
    setExtra(T, value);
  }
}
