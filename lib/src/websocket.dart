import 'dart:io';
import 'dart:convert';

typedef WsHandler = void Function(
    FlintWebSocket client, Map<String, String> params);
typedef WsAuthMiddleware = Future<bool> Function(HttpRequest req);

/// Manages all active WebSocket clients and rooms
class WebSocketManager {
  final Map<String, FlintWebSocket> _clients = {};
  final Map<String, Set<FlintWebSocket>> _rooms = {};

  Map<String, FlintWebSocket> get clients => _clients;
  Map<String, Set<FlintWebSocket>> get rooms => _rooms;

  void addClient(String id, FlintWebSocket client) {
    _clients[id] = client;
  }

  void removeClient(String id) {
    final client = _clients.remove(id);
    if (client != null) {
      for (var room in client.rooms) {
        _rooms[room]?.remove(client);
        if (_rooms[room]?.isEmpty ?? false) {
          _rooms.remove(room);
        }
      }
    }
  }

  void addToRoom(String room, FlintWebSocket client) {
    _rooms.putIfAbsent(room, () => {}).add(client);
  }

  void removeFromRoom(String room, FlintWebSocket client) {
    _rooms[room]?.remove(client);
    if (_rooms[room]?.isEmpty ?? false) {
      _rooms.remove(room);
    }
  }
}

final wsManager = WebSocketManager();

/// Represents a connected WebSocket client
class FlintWebSocket {
  final WebSocket _socket;
  final String id;
  final Set<String> rooms = {};

  FlintWebSocket(this._socket, this.id);

  /// Send a text message
  void send(String message) => _socket.add(message);

  /// Send binary data
  void sendBytes(List<int> data) => _socket.add(data);

  /// Send JSON
  void sendJson(Map<String, dynamic> json) => _socket.add(jsonEncode(json));

  /// Listen for incoming messages (string or binary)
  void onMessage(void Function(dynamic message) handler) {
    _socket.listen((message) {
      handler(message); // message can be String or List<int>
    }, onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
  }

  /// Listen for JSON messages
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

  /// Register a callback when socket is closed
  void onClose(void Function() handler) {
    _socket.done.then((_) {
      handler();
      _handleDisconnect();
    });
  }

  /// Join a room
  void join(String room) {
    rooms.add(room);
    wsManager.addToRoom(room, this);
  }

  /// Leave a room
  void leave(String room) {
    rooms.remove(room);
    wsManager.removeFromRoom(room, this);
  }

  /// Leave all rooms
  void leaveAll() {
    for (var room in rooms.toList()) {
      leave(room);
    }
  }

  /// Broadcast to all connected clients
  void broadcast(String message, {bool includeSelf = false}) {
    for (var client in wsManager.clients.values) {
      if (includeSelf || client.id != id) {
        client.send(message);
      }
    }
  }

  /// Broadcast to a specific room
  void broadcastToRoom(String room, String message,
      {bool includeSelf = false}) {
    final roomClients = wsManager.rooms[room];
    if (roomClients != null) {
      for (var client in roomClients) {
        if (includeSelf || client.id != id) {
          client.send(message);
        }
      }
    }
  }

  void _handleDisconnect() {
    leaveAll();
    wsManager.removeClient(id);
  }
}
