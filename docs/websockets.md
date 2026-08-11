# WebSockets

WebSocket support is implemented by `Flint.websocket`, `WsRoute`, `FlintWebSocket`, and the singleton `wsManager`.

## Registering A WebSocket Route

`example/lib/main.dart` registers `/chat` with the legacy `(Request, FlintWebSocket)` signature:

```dart
app.websocket('/chat', (Request req, FlintWebSocket socket) {
  socket.emit('connected', {'clientId': socket.id});

  socket.on('send_message', (payload) {
    socket.emitToRoom('general', 'new_message', payload);
  });

  socket.join('general');
});
```

You can also use a request-scoped controller, as shown in `example/lib/controllers/websocket_controller_example.dart`:

```dart
class ChatSocketController extends Controller {
  void connect() {
    socket.emit('connected', {'clientId': socket.id});
    socket.on('message', (payload) {
      socket.emit('message:ack', {'received': true, 'payload': payload});
    });
  }
}

app.websocket(
  '/chat',
  controllerAction(ChatSocketController.new, (c) {
    c.connect();
  }),
);
```

## Message Format

`FlintWebSocket.emit(event, data)` sends JSON:

```json
{"event":"ping","data":{"ok":true}}
```

Incoming string messages are decoded as JSON when possible. If the decoded map has an `event` string, listeners registered with `socket.on(event, handler)` receive `data`.

Raw listeners are available:

```dart
socket.onMessage((message) {
  socket.send('raw: $message');
});

socket.onJsonMessage((json) {
  socket.emit('json:seen', json);
});
```

## Rooms And Namespaces

Each socket has a namespace equal to the normalized WebSocket path. Rooms are scoped by namespace in `WebSocketManager.scopeRoom(namespace, room)`.

```dart
socket.join('notifications');
socket.emitToRoom('notifications', 'notify', {'message': 'same namespace'});
socket.emitToRoomIn('/admin', 'notifications', 'notify', {'message': 'admin'});
socket.emitToNamespace('/admin', 'notify_all', {'message': 'all admins'});
```

Tests in `test/websocket_test.dart` verify that the same room name does not leak across namespaces.

## What Happens Internally

When a WebSocket upgrade request arrives:

1. `Flint._handleWebSocketUpgrade()` scans `_wsRoutes`.
2. `WsRoute.match()` extracts `:params`.
3. `WebSocketTransformer.upgrade(req)` creates the Dart socket.
4. `FlintWebSocket` subscribes to messages and registers itself with `wsManager`.
5. Route middleware and global middleware are folded around the WebSocket handler.
6. The handler receives `Context(req: wsRequest, socket: client)`.

## Important Limits

- WebSocket route params support `:name`, but not the HTTP router's regex param syntax.
- Global middleware must tolerate `ctx.res == null`.
- `WebSocketManager` is process-local memory. It does not broadcast across multiple server processes.
- `onClose()` calls `_handleDisconnect()` after `done`, and `_handleDisconnect()` also runs on the socket listener `onDone`; cleanup is designed to be idempotent but close handlers should be simple.
