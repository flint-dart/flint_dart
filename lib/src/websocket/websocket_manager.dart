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
      for (final room in client.scopedRooms.toList()) {
        _rooms[room]?.remove(client);
        if (_rooms[room]?.isEmpty ?? false) {
          _rooms.remove(room);
        }
      }
    }
  }

  String normalizeNamespace(String namespace) {
    var normalized = namespace.trim();
    if (normalized.isEmpty) return '/';
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    normalized = normalized.replaceAll(RegExp(r'/+'), '/');
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  String scopeRoom(String namespace, String room) {
    return '${normalizeNamespace(namespace)}::$room';
  }

  Set<FlintWebSocket>? roomClients(String namespace, String room) {
    return _rooms[scopeRoom(namespace, room)];
  }

  Iterable<FlintWebSocket> namespaceClients(String namespace) sync* {
    final normalizedNamespace = normalizeNamespace(namespace);
    for (final client in _clients.values) {
      if (client.namespace == normalizedNamespace) {
        yield client;
      }
    }
  }

  void addToRoom(String namespace, String room, FlintWebSocket client) {
    final scopedRoom = scopeRoom(namespace, room);
    _rooms.putIfAbsent(scopedRoom, () => {}).add(client);
  }

  void removeFromRoom(String namespace, String room, FlintWebSocket client) {
    final scopedRoom = scopeRoom(namespace, room);
    _rooms[scopedRoom]?.remove(client);
    if (_rooms[scopedRoom]?.isEmpty ?? false) {
      _rooms.remove(scopedRoom);
    }
  }

  void emit(String room, String event, dynamic data, {String namespace = '/'}) {
    emitToPathRoom(namespace, room, event, data);
  }

  void emitToRoom(String room, String event, dynamic data,
      {String namespace = '/'}) {
    emitToPathRoom(namespace, room, event, data);
  }

  void emitToPathRoom(
    String namespace,
    String room,
    String event,
    dynamic data, {
    String? excludeClientId,
  }) {
    final roomClients = this.roomClients(namespace, room);
    if (roomClients == null) return;

    final normalizedNamespace = normalizeNamespace(namespace);
    Log.debug('[WS] Emitting to room $room in $normalizedNamespace: $event');
    for (final client in roomClients) {
      if (excludeClientId != null && client.id == excludeClientId) {
        continue;
      }
      client.emit(event, data);
    }
  }

  void emitToNamespace(
    String namespace,
    String event,
    dynamic data, {
    String? excludeClientId,
  }) {
    final normalizedNamespace = normalizeNamespace(namespace);
    Log.debug('[WS] Emitting to namespace $normalizedNamespace: $event');
    for (final client in namespaceClients(normalizedNamespace)) {
      if (excludeClientId != null && client.id == excludeClientId) {
        continue;
      }
      client.emit(event, data);
    }
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
