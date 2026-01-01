import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/websocket/websocket.dart';

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  final Map<String, FlintWebSocket> _clients = {};
  final Map<String, Set<FlintWebSocket>> _rooms = {};

  Map<String, FlintWebSocket> get clients => Map.unmodifiable(_clients);
  Map<String, Set<FlintWebSocket>> get rooms => Map.unmodifiable(_rooms);

  void addClient(String id, FlintWebSocket client) {
    _clients[id] = client;
  }

  void removeClient(String id) {
    final client = _clients.remove(id);
    if (client != null) {
      for (var room in client.rooms.toList()) {
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

  void emit(String room, String event, dynamic data) {
    final roomClients = _rooms[room];
    if (roomClients == null) return;

    Log.debug('[WS] Emitting to room $room: $event');
    for (final client in roomClients) {
      client.emit(event, data);
    }
  }

  void emitToRoom(String room, String event, dynamic data) {
    emit(room, event, data);
  }

  void emitToClient(String clientId, String event, dynamic data) {
    final client = clients[clientId];
    if (client == null) return;

    client.emit(event, data);
  }

  void emitToAll(String event, dynamic data) {
    for (final client in clients.values) {
      client.emit(event, data);
    }
  }

  void debugPrintStatus() {
    Log.info('=== WebSocketManager info ===');
    Log.info('Instance hash: ${identityHashCode(this)}');
    Log.info('Total clients: ${clients.length}');
    Log.info('Clients IDs: ${clients.keys.toList()}');
    Log.info('Rooms: ${rooms.keys.toList()}');
    Log.info('==============================');
  }

  static WebSocketManager get instance => _instance;
}
