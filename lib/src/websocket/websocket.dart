// flint_websocket.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'ws_manager_instance.dart';

/// Represents a connected WebSocket client
class FlintWebSocket {
  final WebSocket _socket;
  final String id;
  final Set<String> rooms = {};

  // Event listeners storage
  final Map<String, List<void Function(dynamic)>> _eventListeners = {};
  StreamSubscription<dynamic>? _messageSubscription;

  FlintWebSocket(this._socket, this.id) {
    // Setup the main message listener
    _messageSubscription = _socket.listen(
      _handleIncomingMessage,
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );

    // Add to manager
    wsManager.addClient(id, this);
  }

  /// Send a text message
  void send(String message) => _socket.add(message);

  /// Send binary data
  void sendBytes(List<int> data) => _socket.add(data);

  /// Send JSON
  void sendJson(Map<String, dynamic> json) => _socket.add(jsonEncode(json));

  /// Emit an event with data
  void emit(String event, dynamic data) {
    final message = jsonEncode({
      'event': event,
      'data': data,
    });
    send(message);
  }

  /// Listen for incoming messages (string or binary)
  void onMessage(void Function(dynamic message) handler) {
    on('*message', handler);
  }

  /// Remove message listener
  void offMessage(void Function(dynamic message) handler) {
    off('*message', handler);
  }

  /// Listen for JSON messages
  void onJsonMessage(void Function(Map<String, dynamic> json) handler) {
    on('*json', (dynamic data) => handler(data as Map<String, dynamic>));
  }

  /// Remove JSON message listener
  void offJsonMessage(void Function(Map<String, dynamic> json) handler) {
    off('*json', (dynamic data) => handler(data as Map<String, dynamic>));
  }

  /// Listen for specific events
  void on(String event, void Function(dynamic data) handler) {
    _eventListeners.putIfAbsent(event, () => []).add(handler);
  }

  /// Remove specific event listener
  void off(String event, void Function(dynamic data) handler) {
    final listeners = _eventListeners[event];
    if (listeners != null) {
      listeners.remove(handler);
      if (listeners.isEmpty) {
        _eventListeners.remove(event);
      }
    }
  }

  /// Remove all listeners for a specific event
  void offAll(String event) {
    _eventListeners.remove(event);
  }

  /// Remove all event listeners
  void offAllListeners() {
    _eventListeners.clear();
  }

  /// Handle incoming messages and dispatch to event listeners
  void _handleIncomingMessage(dynamic message) {
    // Dispatch to raw message listeners
    _dispatchEvent('*message', message);

    if (message is String) {
      try {
        final data = jsonDecode(message);
        if (data is Map<String, dynamic>) {
          // Dispatch to JSON listeners
          _dispatchEvent('*json', data);

          // Dispatch to specific event listeners
          final event = data['event'];
          final eventData = data['data'];
          if (event is String) {
            _dispatchEvent(event, eventData);
          }
        }
      } catch (_) {
        // If not valid JSON, still dispatch to raw message listeners
      }
    }
  }

  /// Dispatch event to all registered listeners
  void _dispatchEvent(String event, dynamic data) {
    final listeners = _eventListeners[event]?.toList();
    if (listeners != null) {
      for (final handler in listeners) {
        try {
          handler(data);
        } catch (e) {
          print('Error in event handler for $event: $e');
        }
      }
    }
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

  /// Emit to all connected clients
  void emitToAll(String event, dynamic data, {bool includeSelf = false}) {
    for (var client in wsManager.clients.values) {
      if (includeSelf || client.id != id) {
        client.emit(event, data);
      }
    }
  }

  /// Emit to a specific room
  void emitToRoom(String room, String event, dynamic data,
      {bool includeSelf = false}) {
    final roomClients = wsManager.rooms[room];
    if (roomClients != null) {
      for (var client in roomClients) {
        if (includeSelf || client.id != id) {
          client.emit(event, data);
        }
      }
    }
  }

  void _handleDisconnect() {
    // Clean up all listeners
    _messageSubscription?.cancel();
    offAllListeners();

    // Leave rooms and remove from manager
    leaveAll();
    wsManager.removeClient(id);
  }
}
