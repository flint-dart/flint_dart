import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

typedef WsHandler = void Function(
    FlintWebSocket client, Map<String, dynamic> params);
typedef WsAuthMiddleware = Future<bool> Function(HttpRequest req);

final wsManager = WebSocketManager();

class WebSocketManager {
  final Map<String, FlintWebSocket> _clients = {};
  final Map<String, Set<FlintWebSocket>> _rooms = {};

  Map<String, FlintWebSocket> get clients => _clients;
  Map<String, Set<FlintWebSocket>> get rooms => _rooms;

  void addClient(String id, FlintWebSocket client) => _clients[id] = client;

  void removeClient(String id) {
    final client = _clients.remove(id);
    if (client != null) {
      for (var room in client.rooms) {
        _rooms[room]?.remove(client);
        if (_rooms[room]?.isEmpty ?? false) _rooms.remove(room);
      }
    }
  }

  void addToRoom(String room, FlintWebSocket client) {
    _rooms.putIfAbsent(room, () => {}).add(client);
  }

  void removeFromRoom(String room, FlintWebSocket client) {
    _rooms[room]?.remove(client);
    if (_rooms[room]?.isEmpty ?? false) _rooms.remove(room);
  }
}

/// Represents a connected WebSocket client
class FlintWebSocket {
  final WebSocket _socket;
  final String id;
  final Set<String> rooms = {};
  final Map<String, List<Function(dynamic)>> _eventHandlers = {};

  FlintWebSocket(this._socket, this.id) {
    // Automatically handle incoming messages
    _socket.listen(_handleMessage,
        onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
  }

  /// Send raw string message
  void send(String message) => _socket.add(message);

  /// Send JSON message
  void sendJson(Map<String, dynamic> json) => _socket.add(jsonEncode(json));

  /// Listen for incoming messages (raw string or bytes)
  void onMessage(void Function(dynamic message) handler) {
    _socket.listen((message) {
      handler(message); // String or List<int>
    }, onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
  }

  /// Listen for incoming JSON messages
  void onJsonMessage(void Function(Map<String, dynamic> json) handler) {
    _socket.listen((message) {
      if (message is String) {
        try {
          final data = jsonDecode(message);
          if (data is Map<String, dynamic>) handler(data);
        } catch (_) {}
      }
    }, onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
  }

  /// Event system
  void on(String event, Function(dynamic data) handler) {
    _eventHandlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event, [Function? handler]) {
    if (handler == null) {
      _eventHandlers.remove(event);
    } else {
      _eventHandlers[event]?.remove(handler);
    }
  }

  void emit(String event, dynamic data) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(jsonEncode({"event": event, "data": data}));
    }
  }

  void _emitLocal(String event, [dynamic data]) {
    if (_eventHandlers[event] != null) {
      for (var h in _eventHandlers[event]!) {
        h(data);
      }
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded.containsKey("event")) {
        _emitLocal(decoded["event"], decoded["data"]);
      } else {
        _emitLocal("message", decoded);
      }
    } catch (_) {
      _emitLocal("message", raw);
    }
  }

  /// Rooms
  void join(String room) {
    rooms.add(room);
    wsManager.addToRoom(room, this);
  }

  void leave(String room) {
    rooms.remove(room);
    wsManager.removeFromRoom(room, this);
  }

  void leaveAll() {
    for (var room in rooms.toList()) {
      leave(room);
    }
  }

  /// Broadcast
  void broadcast(String message, {bool includeSelf = false}) {
    for (var client in wsManager.clients.values) {
      if (includeSelf || client.id != id) client.send(message);
    }
  }

  void broadcastToRoom(String room, String message,
      {bool includeSelf = false}) {
    final clients = wsManager.rooms[room];
    if (clients != null) {
      for (var client in clients) {
        if (includeSelf || client.id != id) client.send(message);
      }
    }
  }

  void onClose(void Function() handler) {
    _socket.done.then((_) {
      handler();
      _handleDisconnect();
    });
  }

  void _handleDisconnect() {
    leaveAll();
    wsManager.removeClient(id);
  }
}

/// Helper to accept a new WebSocket connection with optional JWT
Future<void> handleWs(HttpRequest req,
    {WsAuthMiddleware? auth, required WsHandler handler}) async {
  try {
    if (auth != null && !await auth(req)) {
      req.response.statusCode = HttpStatus.unauthorized;
      await req.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(req);
    final client = FlintWebSocket(socket, const Uuid().v4());
    wsManager.addClient(client.id, client);

    handler(client, req.uri.queryParameters);

    client.onClose(() {
      print('❌ Client disconnected: ${client.id}');
    });

    print('✅ Client connected: ${client.id}');
  } catch (e) {
    print('WebSocket error: $e');
  }
}
