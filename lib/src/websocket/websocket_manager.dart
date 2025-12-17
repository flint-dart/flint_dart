// websocket_manager.dart

import 'package:flint_dart/src/websocket/websocket.dart';

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

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

  // =========================
  // 🔥 EMIT HELPERS (IMPORTANT)
  // =========================

  void emitToRoom(String room, String event, dynamic data) {
    final roomClients = _rooms[room];
    if (roomClients == null) return;

    for (final client in roomClients) {
      client.emit(event, data);
    }
  }

  void emitToClient(String clientId, String event, dynamic data) {
    final client = _clients[clientId];
    if (client == null) return;
    client.emit(event, data);
  }

  void emitToAll(String event, dynamic data) {
    for (final client in _clients.values) {
      client.emit(event, data);
    }
  }
}

final wsManager = WebSocketManager();
