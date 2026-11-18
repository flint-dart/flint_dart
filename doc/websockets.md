# WebSockets

WebSocket support in Flint is the realtime layer for chat, presence,
notifications, collaborative screens, live dashboards, terminals, and any
feature where the server needs to push events to connected clients.

Use this guide before adding or reviewing WebSocket code. It explains how
socket routes, `Context`, event messages, rooms, middleware, and controllers
work before implementation.

Before changing WebSocket code in an app, inspect:

- `lib/main.dart` for `Flint(...)`, global middleware, route registration, and `listen(...)`.
- `lib/routes/` for `RouteGroup` classes that register socket endpoints.
- `lib/controllers/` for socket controllers.
- `lib/middlewares/` for auth, tenant, role, and rate-limit checks.
- `lib/models/` or `lib/services/` when events are persisted or trigger workflows.
- `lib/ui/` when frontend code connects to WebSocket endpoints.
- `docs/routing.md` for `Context`, route groups, and route params.
- `docs/middleware.md` for middleware behavior with `ctx.res == null`.
- `docs/authentication.md` before protecting sockets with JWT, cookies, sessions, or one-time socket tokens.
- `docs/swagger-and-api-docs.md` for documenting the WebSocket handshake route.

Framework source to inspect when behavior is unclear:

- `lib/src/app.dart`
- `lib/src/context.dart`
- `lib/src/controller.dart`
- `lib/src/websocket/websocket.dart`
- `lib/src/websocket/websocket_manager.dart`
- `lib/src/websocket/ws_router.dart`
- `lib/src/websocket/ws_manager_instance.dart`

## The Mental Model

Flint WebSocket routes use the same unified `Context` shape as HTTP routes.

```dart
app.websocket('/chat', (Context ctx) {
  final socket = ctx.socket;
  if (socket == null) return;

  socket.emit('connected', {'clientId': socket.id});
});
```

For WebSocket routes:

- `ctx.req` is the HTTP upgrade request wrapped as a Flint `Request`.
- `ctx.socket` is the connected `FlintWebSocket`.
- `ctx.res` is `null`.
- `ctx.isWebSocket` is `true`.
- `ctx.isHttp` is `false`.

Do not write WebSocket handlers that depend on `ctx.res`. The HTTP response has
already become a socket connection.

WebSocket handlers should communicate through `ctx.socket`. Returning a value
from a WebSocket route does not serialize a response the way HTTP handlers do.

## Registering A Socket Route

Use `app.websocket(...)` and a `Context ctx` handler.

```dart
import 'package:flint_dart/flint_dart.dart';

void registerSockets(Flint app) {
  app.websocket('/chat', (Context ctx) {
    final socket = ctx.socket;
    if (socket == null) return;

    socket.emit('connected', {'clientId': socket.id});

    socket.on('send_message', (payload) {
      socket.emitToRoom('general', 'new_message', payload);
    });

    socket.join('general');
  });
}
```

WebSocket paths should start with `/`.

```dart
app.websocket('/chat', handler);
app.websocket('/notifications', handler);
app.websocket('/rooms/:room', handler);
```

Do not use a missing leading slash:

```dart
app.websocket('chat', handler);
```

`WsRoute` matches against the request URI path, such as `/chat`.

## Route Groups

WebSocket routes can live inside `RouteGroup` classes.

File: `lib/routes/chat_routes.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../controllers/chat_socket_controller.dart';
import '../middlewares/chat_socket_auth_middleware.dart';

class ChatRoutes extends RouteGroup {
  @override
  String get prefix => '/ws';

  @override
  String get tag => 'Chat';

  @override
  void register(Flint app) {
    final chat = app.controller(ChatSocketController.new);

    chat.websocket(
      '/chat/:room',
      (controller) => controller.connect(),
      middlewares: [ChatSocketAuthMiddleware()],
    );
  }
}
```

Register the route group:

```dart
app.routes(ChatRoutes());
```

The runtime endpoint is:

```text
/ws/chat/:room
```

If a client connects to `/ws/chat/general`, `req.param('room')` is `general`.

Current middleware note: `RouteGroup.prefix` is applied to mounted WebSocket
paths. In the current implementation, `RouteGroup.middlewares` are not merged
into mounted WebSocket routes. For socket-specific guards, pass middleware with
the `middlewares:` argument on `app.websocket(...)` or `chat.websocket(...)`.
Global middleware registered with `app.use(...)` still runs for WebSocket
routes.

## What Happens Internally

When a request reaches Flint, `_handleIncomingRequest(...)` checks whether it is
a WebSocket upgrade request before normal HTTP routing.

For a matching WebSocket request:

1. `Flint._handleWebSocketUpgrade(...)` scans registered `WsRoute` entries in order.
2. `WsRoute.match(...)` checks the request path and extracts simple `:params`.
3. `Request(req, params: params)` wraps the upgrade request.
4. `WebSocketTransformer.upgrade(req)` upgrades the connection.
5. Flint creates a `FlintWebSocket` with a generated connection id.
6. The socket namespace is set from the normalized request path.
7. `FlintWebSocket` subscribes to messages and registers itself with the manager.
8. Route middleware is wrapped around the socket handler.
9. Global middleware is wrapped around the route pipeline.
10. The handler receives `Context(req: wsRequest, socket: client)`.

If no WebSocket route matches the upgrade request, Flint sends an HTTP `404`
response and closes the response.

Because upgrade happens before WebSocket middleware runs, middleware can emit a
socket error and close the connection, but it cannot send a normal HTTP JSON
response after the socket is established.

## Controller-Backed WebSockets

For non-trivial socket features, use a controller. Controllers should extend
`Controller` and live in their own file.

File: `lib/controllers/chat_socket_controller.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

class ChatSocketController extends Controller {
  void connect() {
    final room = req.param('room') ?? 'general';

    socket.join(room);
    socket.emit('connected', {
      'clientId': socket.id,
      'room': room,
    });

    socket.on('message:send', (payload) {
      socket.emitToRoom(room, 'message:new', payload);
    });

    socket.on('typing:start', (payload) {
      socket.emitToRoom(room, 'typing:start', payload);
    });

    socket.onClose(() {
      // Keep close handlers short. Flint also performs socket cleanup.
    });
  }
}
```

Route file:

```dart
final chat = app.controller(ChatSocketController.new);

chat.websocket(
  '/chat/:room',
  (controller) => controller.connect(),
  middlewares: [ChatSocketAuthMiddleware()],
);
```

Inside a WebSocket controller:

- `context` is the bound `Context`.
- `req` is the upgrade request.
- `socket` is the connected `FlintWebSocket`.
- `isWebSocket` is `true`.
- `read<T>()` and `write<T>(value)` use typed context storage.

Do not call `res` inside a WebSocket controller. The controller `res` getter
throws when the action is running in a WebSocket context.

## One Socket Thing Per File

Use the same Flint app structure rules for WebSockets:

- one socket controller per file
- one socket middleware per file
- one reusable socket service/action per file
- one payload mapper or presenter per file when it becomes reusable
- one frontend WebSocket helper/component per file under `lib/ui`

Do not hide socket workflows inside private controller methods such as
`_joinRoom()` or `_broadcastMessage()` when those workflows are meaningful. Make
them named classes or helpers in their own files.

Example structure:

```text
lib/routes/chat_routes.dart
lib/controllers/chat_socket_controller.dart
lib/middlewares/chat_socket_auth_middleware.dart
lib/services/chat/join_chat_room_action.dart
lib/services/chat/broadcast_chat_message_action.dart
lib/services/chat/load_recent_messages_action.dart
lib/ui/components/chat_socket_status.dart
lib/ui/helpers/connect_chat_socket.dart
```

## Path Params

WebSocket path params use the simple `:name` syntax.

```dart
app.websocket('/rooms/:room/messages/:messageId', (Context ctx) {
  final room = ctx.req.param('room');
  final messageId = ctx.req.param('messageId');

  ctx.socket?.emit('route:params', {
    'room': room,
    'messageId': messageId,
  });
});
```

Current path matching limits:

- Simple `:name` path params are supported.
- HTTP regex params such as `:id([0-9]+)` are not supported by `WsRoute`.
- HTTP wildcard paths such as `*` are not supported by `WsRoute`.
- Paths should begin with `/`.

Validate route params yourself before trusting them:

```dart
final room = ctx.req.param('room');
if (room == null || room.isEmpty) {
  ctx.socket?.emit('error', {'message': 'Room is required'});
  await ctx.socket?.close();
  return;
}
```

## Message Protocol

`FlintWebSocket.emit(event, data)` sends an event envelope:

```dart
socket.emit('ping', {'ok': true});
```

The client receives:

```json
{
  "event": "ping",
  "data": {
    "ok": true
  }
}
```

Clients should send the same envelope when they want Flint to dispatch to
`socket.on(...)`:

```json
{
  "event": "message:send",
  "data": {
    "text": "Hello"
  }
}
```

Server handler:

```dart
socket.on('message:send', (payload) {
  socket.emit('message:ack', {
    'received': true,
    'payload': payload,
  });
});
```

Incoming event dispatch works only for string messages that decode to a JSON
object with an `event` string. The event handler receives the `data` value.

Invalid JSON still reaches raw message listeners, but it does not reach named
event listeners.

## Sending Methods

`FlintWebSocket` supports raw, binary, JSON, and event-style sends.

```dart
socket.send('plain text');
socket.sendBytes([1, 2, 3]);
socket.sendJson({'type': 'ready', 'ok': true});
socket.emit('ready', {'ok': true});
```

Use `emit(...)` for most app events because it gives every message the same
shape: `{ "event": "...", "data": ... }`.

Use `sendJson(...)` when the client expects a raw JSON object without the event
envelope.

Use `send(...)` or `sendBytes(...)` for protocol-specific features such as
terminal streams, binary media, or external socket protocols.

## Listening Methods

Listen for named Flint events:

```dart
socket.on('message:send', (payload) {
  socket.emit('message:ack', {'received': true});
});
```

Listen for every raw incoming socket message:

```dart
socket.onMessage((message) {
  socket.send('raw: $message');
});
```

Listen for incoming JSON objects:

```dart
socket.onJsonMessage((json) {
  socket.emit('json:seen', json);
});
```

Remove listeners when needed:

```dart
void handleTyping(dynamic payload) {}

socket.on('typing:start', handleTyping);
socket.off('typing:start', handleTyping);
socket.offAll('typing:start');
socket.offAllListeners();
```

In normal route handlers, listener cleanup is automatic when the socket closes.

## Payload Normalization

`emit(...)` and `sendJson(...)` normalize common Dart values before encoding.

Supported normalization includes:

- `DateTime` to ISO 8601 string
- `Uri` to string
- `Duration` to microseconds
- `Exception` to `{ "error": "...", "message": "..." }`
- `List` recursively
- `Set` to list
- `Map` with keys converted to strings
- objects with `toMap()`
- objects with `toJson()`

Example:

```dart
class ChatMessageResource {
  ChatMessageResource(this.message);

  final ChatMessage message;

  Map<String, dynamic> toMap() => {
        'id': message.id,
        'body': message.body,
        'createdAt': message.createdAt,
      };
}

socket.emit('message:new', ChatMessageResource(message));
```

The `createdAt` `DateTime` is converted to an ISO string inside the emitted
payload.

## Rooms

Rooms let a socket send to a subset of connected clients.

```dart
socket.join('general');
socket.leave('general');
socket.leaveAll();
```

Emit to a room in the current namespace:

```dart
socket.emitToRoom('general', 'message:new', {
  'text': 'Hello room',
});
```

By default, `emitToRoom(...)` does not send to the socket that called it. Include
the sender when needed:

```dart
socket.emitToRoom(
  'general',
  'message:new',
  {'text': 'Hello everyone'},
  includeSelf: true,
);
```

Send raw text to a room:

```dart
socket.broadcastToRoom('general', 'raw room message');
```

Rooms are in memory and exist only while clients are connected. Flint removes a
socket from its rooms when the socket disconnects.

## Namespaces

Every `FlintWebSocket` has a namespace. Flint sets the namespace from the
normalized request path.

Examples:

```text
/chat                 -> namespace /chat
/chat/                -> namespace /chat
/ws/chat/general      -> namespace /ws/chat/general
```

Room names are scoped by namespace. A room named `notifications` in `/chat` is
not the same as a room named `notifications` in `/admin`.

```dart
final namespace = socket.namespace;
final scopedRooms = socket.scopedRooms;
```

Important detail for dynamic paths: the namespace uses the real request path,
not the route template.

```dart
app.websocket('/chat/:room', handler);
```

If the client connects to:

```text
/chat/general
```

the namespace is:

```text
/chat/general
```

not:

```text
/chat/:room
```

Use `req.param('room')` for the logical room name when you need all clients for
one chat room to join the same app-level room.

```dart
final room = ctx.req.param('room') ?? 'general';
socket.join(room);
```

## Sending Across Namespaces

Send to a room in another namespace:

```dart
socket.emitToRoomIn('/notifications', 'admins', 'notify', {
  'message': 'New support request',
});
```

Send to every client in another namespace:

```dart
socket.emitToNamespace('/notifications', 'notify_all', {
  'message': 'System maintenance starts soon',
});
```

`emitToPathRoom(...)` still exists as a deprecated alias for
`emitToRoomIn(...)`.

## Manager-Level Sends

Application code can use `WebSocketManager.instance` when it needs to emit from
outside the current socket handler.

```dart
final manager = WebSocketManager.instance;

manager.emitToClient(socketId, 'notification:new', {
  'title': 'Invoice paid',
});

manager.emitToRoom(
  'admins',
  'notification:new',
  {'title': 'New signup'},
  namespace: '/notifications',
);

manager.emitToNamespace('/notifications', 'system:reload', {
  'reason': 'settings changed',
});

manager.emitToAll('system:ping', {'ok': true});
```

`socket.id` is generated when the connection is created. Treat it as a runtime
connection id, not a user identity. Store your own user id, session id, or tenant
id in a service if you need to target business identities.

The framework also has an internal `wsManager` singleton used inside source and
tests. App code should prefer the public `WebSocketManager.instance` access.

## Browser Client Example

The browser should connect with `ws://` on HTTP pages and `wss://` on HTTPS
pages.

```html
<script>
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const socket = new WebSocket(`${protocol}//${window.location.host}/chat`);

  socket.addEventListener('open', () => {
    socket.send(JSON.stringify({
      event: 'message:send',
      data: { text: 'Hello from the browser' }
    }));
  });

  socket.addEventListener('message', (event) => {
    let message;
    try {
      message = JSON.parse(event.data);
    } catch (_) {
      return;
    }

    if (message.event === 'connected') {
      console.log('Connected as', message.data.clientId);
    }

    if (message.event === 'message:new') {
      console.log('New message', message.data);
    }
  });
</script>
```

If the socket endpoint is protected, prefer a signed, short-lived socket token
or an auth cookie. Browser WebSocket constructors do not let you set arbitrary
headers such as `Authorization`. Server-to-server clients can send headers, but
browser clients usually use cookies or query strings:

```js
const socket = new WebSocket(
  `${protocol}//${window.location.host}/chat?token=${encodeURIComponent(token)}`
);
```

## Auth Middleware

WebSocket middleware receives `Context`, just like HTTP middleware. The
difference is that `ctx.res` is `null`.

```dart
import 'package:flint_dart/flint_dart.dart';

class ChatSocketAuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final socket = ctx.socket;
      if (socket == null) {
        return await next(ctx);
      }

      final token = ctx.req.queryParam('token') ?? ctx.req.authToken;
      if (token == null || token.isEmpty) {
        socket.emit('auth:error', {
          'message': 'Missing socket token',
        });
        await socket.close();
        return null;
      }

      final user = await VerifySocketTokenAction().call(token);
      if (user == null) {
        socket.emit('auth:error', {
          'message': 'Invalid socket token',
        });
        await socket.close();
        return null;
      }

      ctx.write<UserSession>(user);
      return await next(ctx);
    };
  }
}
```

Attach it directly to the WebSocket route:

```dart
app.websocket(
  '/chat',
  (Context ctx) {
    final user = ctx.read<UserSession>();
    ctx.socket?.emit('connected', {'userId': user?.id});
  },
  middlewares: [ChatSocketAuthMiddleware()],
);
```

Because the WebSocket upgrade happens before route middleware runs, middleware
cannot send an HTTP JSON response. To reject before the upgrade, issue and
validate auth through an HTTP route before the client connects, then let the
socket route close unauthorized connections after upgrade if needed.

## Validation In Socket Events

`ExceptionMiddleware` can turn validation errors into HTTP JSON responses only
when `ctx.res` exists. In WebSocket routes, validate event payloads and emit
socket errors yourself.

```dart
app.websocket('/chat/:room', (Context ctx) {
  final socket = ctx.socket;
  if (socket == null) return;

  socket.on('message:send', (payload) async {
    final room = ctx.req.param('room') ?? 'general';

    try {
      if (payload is! Map) {
        throw ValidationException({
          'message': ['Message payload must be an object.'],
        });
      }

      final data = Map<String, dynamic>.from(payload);

      await Validator.validate(data, {
        'text': 'required|string|min:1|max:1000',
      });

      await BroadcastChatMessageAction().call(
        room: room,
        text: data['text'].toString(),
      );
    } on ValidationException catch (error) {
      socket.emit('message:error', {'errors': error.errors});
    } catch (_) {
      socket.emit('message:error', {
        'message': 'Message could not be sent.',
      });
    }
  });
});
```

Do not trust socket payloads just because the connection was authenticated.
Validate every event that writes data, triggers work, or changes state.

`socket.on(...)` handlers are typed as void callbacks. If you use an `async`
handler, catch errors inside that handler so failures can be emitted to the
client instead of becoming unhandled asynchronous errors.

## Close Handling

Register a close callback with `onClose(...)`:

```dart
socket.onClose(() {
  Log.info('Socket closed: ${socket.id}');
});
```

Flint also runs internal cleanup when the socket closes:

- cancels the message subscription
- removes event listeners
- leaves all rooms
- removes the client from `WebSocketManager`

Close handlers should be short and idempotent. Do not assume the socket can
still send after close.

Close from the server when needed:

```dart
await socket.close();
await socket.close(1008, 'Policy violation');
```

## Full Chat Example

Route file: `lib/routes/chat_routes.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../controllers/chat_socket_controller.dart';
import '../middlewares/chat_socket_auth_middleware.dart';

class ChatRoutes extends RouteGroup {
  @override
  String get prefix => '/ws';

  @override
  String get tag => 'Chat';

  @override
  void register(Flint app) {
    final chat = app.controller(ChatSocketController.new);

    /// @summary Chat websocket handshake
    /// @param room path string required Chat room
    /// @response 101 Switching Protocols
    chat.websocket(
      '/chat/:room',
      (controller) => controller.connect(),
      middlewares: [ChatSocketAuthMiddleware()],
    );
  }
}
```

Controller file: `lib/controllers/chat_socket_controller.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../services/chat/broadcast_chat_message_action.dart';

class ChatSocketController extends Controller {
  void connect() {
    final room = req.param('room');
    if (room == null || room.isEmpty) {
      socket.emit('chat:error', {'message': 'Room is required'});
      socket.close();
      return;
    }

    socket.join(room);
    socket.emit('chat:ready', {
      'clientId': socket.id,
      'room': room,
    });

    socket.on('message:send', (payload) async {
      try {
        if (payload is! Map) {
          throw ValidationException({
            'message': ['Message payload must be an object.'],
          });
        }

        final data = Map<String, dynamic>.from(payload);

        await Validator.validate(data, {
          'text': 'required|string|min:1|max:1000',
        });

        final message = await BroadcastChatMessageAction().call(
          room: room,
          text: data['text'].toString(),
        );

        socket.emitToRoom(
          room,
          'message:new',
          message,
          includeSelf: true,
        );
      } on ValidationException catch (error) {
        socket.emit('message:error', {'errors': error.errors});
      } catch (_) {
        socket.emit('message:error', {
          'message': 'Message could not be sent.',
        });
      }
    });
  }
}
```

Register the route group in `lib/main.dart`:

```dart
app.routes(ChatRoutes());
```

## Swagger Documentation

Swagger/OpenAPI can document the WebSocket handshake endpoint. It cannot describe
every event payload by itself, so document event names and payloads in this file
or a feature-specific markdown file.

Route comments:

```dart
/// @summary Chat websocket handshake
/// @param room path string required Chat room
/// @response 101 Switching Protocols
app.websocket('/chat/:room', (Context ctx) {
  ctx.socket?.emit('ready', {'ok': true});
});
```

Generated Swagger stores WebSocket routes as `GET` operations with Flint
extensions:

```json
{
  "x-websocket": true,
  "x-flint-transport": "websocket",
  "x-flint-namespace": "/chat/{room}"
}
```

See `docs/swagger-and-api-docs.md` for the full generated shape.

## Testing

Use `test/websocket_test.dart` as the framework reference for event dispatch,
emits, payload normalization, rooms, namespaces, and manager behavior.

Useful test cases for app sockets:

- server emits a `connected` or `ready` event on connect
- incoming event envelopes call the right listener
- invalid payloads emit field errors instead of crashing the handler
- room messages do not echo to sender unless `includeSelf: true`
- users in different namespaces do not receive each other's room events
- auth middleware closes unauthorized sockets
- close handlers do not fail when called more than once

## Common Mistakes

- Do not use `(Request req, FlintWebSocket socket)` for new socket routes; use `Context ctx`.
- Do not read `ctx.res` in a WebSocket handler.
- Do not call controller `res` from a WebSocket controller.
- Do not rely on `RouteGroup.middlewares` to protect mounted WebSocket routes in the current implementation; use the `middlewares:` argument.
- Do not forget that browser clients usually cannot send custom WebSocket headers.
- Do not trust socket event payloads without validation.
- Do not use `socket.id` as a user id.
- Do not assume rooms persist after disconnect.
- Do not expect room names to cross namespaces automatically.
- Do not use `/chat/:room` as the namespace for an actual `/chat/general` connection; the namespace is the real request path.
- Do not use `emitToAll(...)` when the event should stay inside a room or namespace.
- Do not store critical cross-process presence only in `WebSocketManager`; it is process-local memory.

## Current Limits

- `WebSocketManager` is process-local. It does not broadcast across multiple server processes or machines.
- WebSocket route params support simple `:name` segments only.
- WebSocket route matching does not support HTTP regex params or wildcards.
- WebSocket route middleware runs after `WebSocketTransformer.upgrade(...)`.
- `ExceptionMiddleware` cannot format JSON responses in socket-only contexts because `ctx.res` is null.
- The framework does not provide a built-in distributed adapter yet. Use app code, Redis, a queue, or another pub/sub layer when multiple server processes need to share socket events.

## Review Checklist

Before finishing a WebSocket feature:

1. The route uses `app.websocket(...)` or `app.controller(...).websocket(...)`.
2. The handler uses `Context ctx` or a `Controller` bound through `app.controller(...)`.
3. The route path starts with `/`.
4. Socket auth is handled with route `middlewares: [...]` or a clear HTTP token flow before connect.
5. Middleware handles `ctx.res == null`.
6. Every incoming event that changes data is validated.
7. Room names, namespaces, and `includeSelf` behavior are intentional.
8. Socket controllers, middleware, services, and frontend helpers each live in their own file.
9. Swagger route comments document the handshake with `@response 101`.
10. Event names and payloads are documented in `docs/websockets.md` or a feature-specific doc.
