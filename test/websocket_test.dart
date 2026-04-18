import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:flint_dart/src/websocket/websocket.dart';
import 'package:flint_dart/src/websocket/ws_manager_instance.dart';

import 'helpers/fakes.dart';

void main() {
  tearDown(() {
    final ids = wsManager.clients.keys.toList();
    for (final id in ids) {
      wsManager.removeClient(id);
    }
  });

  test('dispatches event from JSON message', () async {
    final socket = FakeWebSocket();
    final client = FlintWebSocket(socket, 'c1');

    final done = Completer<void>();
    client.on('greet', (data) {
      expect(data, 'hi');
      if (!done.isCompleted) done.complete();
    });

    socket.emitIncoming(jsonEncode({'event': 'greet', 'data': 'hi'}));
    await done.future.timeout(const Duration(seconds: 2));
  });

  test('emit sends JSON to socket', () {
    final socket = FakeWebSocket();
    final client = FlintWebSocket(socket, 'c2');

    client.emit('ping', {'ok': true});

    expect(socket.sent.length, 1);
    final decoded = jsonDecode(socket.sent.first as String);
    expect(decoded['event'], 'ping');
    expect(decoded['data']['ok'], true);
  });

  test('emit normalizes DateTime payloads before encoding', () {
    final socket = FakeWebSocket();
    final client = FlintWebSocket(socket, 'c-date');
    final timestamp = DateTime.utc(2026, 4, 18, 20, 0, 0);

    client.emit('scheduled', {
      'at': timestamp,
      'nested': [timestamp],
    });

    final decoded = jsonDecode(socket.sent.first as String);
    expect(decoded['event'], 'scheduled');
    expect(decoded['data']['at'], timestamp.toIso8601String());
    expect(decoded['data']['nested'], [timestamp.toIso8601String()]);
  });

  test('emit normalizes custom objects through toMap and toJson', () {
    final socket = FakeWebSocket();
    final client = FlintWebSocket(socket, 'c-custom');

    client.emit('custom', {
      'profile': _WsProfile('Ada', DateTime.utc(2026, 4, 18, 20, 15, 0)),
      'meta': _WsMeta('online'),
    });

    final decoded = jsonDecode(socket.sent.first as String);
    expect(decoded['event'], 'custom');
    expect(decoded['data']['profile']['name'], 'Ada');
    expect(
      decoded['data']['profile']['createdAt'],
      DateTime.utc(2026, 4, 18, 20, 15, 0).toIso8601String(),
    );
    expect(decoded['data']['meta']['status'], 'online');
  });

  test('broadcast sends to other clients', () {
    final socket1 = FakeWebSocket();
    final socket2 = FakeWebSocket();
    final c1 = FlintWebSocket(socket1, 'c1');
    final c2 = FlintWebSocket(socket2, 'c2');

    c1.broadcast('hello');

    expect(socket1.sent, isEmpty);
    expect(socket2.sent, ['hello']);

    // Use the second client to avoid unused warnings.
    expect(c2.id, 'c2');
  });

  test('room emits are isolated to the socket namespace by default', () {
    final chatSocket = FakeWebSocket();
    final notificationSocket = FakeWebSocket();

    final chatClient =
        FlintWebSocket(chatSocket, 'chat-client', namespace: '/chat');
    final notificationClient = FlintWebSocket(
      notificationSocket,
      'notification-client',
      namespace: '/notification',
    );

    notificationClient.join('notifications');
    chatClient.join('notifications');

    chatClient.emitToRoom('notifications', 'notify', {
      'message': 'chat namespace only',
    });

    expect(chatSocket.sent, isEmpty);
    expect(notificationSocket.sent, isEmpty);
  });

  test('client can explicitly emit to a room in another websocket path', () {
    final chatSocket = FakeWebSocket();
    final notificationSocket = FakeWebSocket();

    final chatClient =
        FlintWebSocket(chatSocket, 'chat-client', namespace: '/chat');
    final notificationClient = FlintWebSocket(
      notificationSocket,
      'notification-client',
      namespace: '/notification',
    );

    notificationClient.join('notifications');

    chatClient.emitToRoomIn('/notification', 'notifications', 'notify', {
      'message': 'hello from chat',
    });

    expect(chatSocket.sent, isEmpty);
    expect(notificationSocket.sent, hasLength(1));

    final decoded = jsonDecode(notificationSocket.sent.first as String);
    expect(decoded['event'], 'notify');
    expect(decoded['data']['message'], 'hello from chat');
  });

  test('deprecated emitToPathRoom alias still emits to another namespace room',
      () {
    final chatSocket = FakeWebSocket();
    final notificationSocket = FakeWebSocket();

    final chatClient =
        FlintWebSocket(chatSocket, 'chat-client', namespace: '/chat');
    final notificationClient = FlintWebSocket(
      notificationSocket,
      'notification-client',
      namespace: '/notification',
    );

    notificationClient.join('notifications');

    chatClient.emitToPathRoom('/notification', 'notifications', 'notify', {
      'message': 'legacy alias still works',
    });

    expect(chatSocket.sent, isEmpty);
    expect(notificationSocket.sent, hasLength(1));

    final decoded = jsonDecode(notificationSocket.sent.first as String);
    expect(decoded['event'], 'notify');
    expect(decoded['data']['message'], 'legacy alias still works');
  });

  test('client can explicitly emit to everyone in another namespace', () {
    final chatSocket = FakeWebSocket();
    final notificationSocket1 = FakeWebSocket();
    final notificationSocket2 = FakeWebSocket();

    final chatClient =
        FlintWebSocket(chatSocket, 'chat-client', namespace: '/chat');
    final notificationClient1 = FlintWebSocket(
      notificationSocket1,
      'notification-client-1',
      namespace: '/notification',
    );
    final notificationClient2 = FlintWebSocket(
      notificationSocket2,
      'notification-client-2',
      namespace: '/notification',
    );

    notificationClient1.join('admins');
    expect(notificationClient2.namespace, '/notification');

    chatClient.emitToNamespace('/notification', 'notify_all', {
      'message': 'broadcast to namespace',
    });

    expect(chatSocket.sent, isEmpty);
    expect(notificationSocket1.sent, hasLength(1));
    expect(notificationSocket2.sent, hasLength(1));

    final firstDecoded = jsonDecode(notificationSocket1.sent.first as String);
    final secondDecoded = jsonDecode(notificationSocket2.sent.first as String);

    expect(firstDecoded['event'], 'notify_all');
    expect(secondDecoded['event'], 'notify_all');
    expect(firstDecoded['data']['message'], 'broadcast to namespace');
    expect(secondDecoded['data']['message'], 'broadcast to namespace');
  });

  test('same room names do not leak across websocket namespaces', () {
    final chatEmitterSocket = FakeWebSocket();
    final chatListenerSocket = FakeWebSocket();
    final notificationSocket = FakeWebSocket();

    final chatEmitter =
        FlintWebSocket(chatEmitterSocket, 'chat-emitter', namespace: '/chat');
    final chatListener = FlintWebSocket(
      chatListenerSocket,
      'chat-listener',
      namespace: '/chat',
    );
    final notificationClient = FlintWebSocket(
      notificationSocket,
      'notification-client',
      namespace: '/notification',
    );

    chatListener.join('shared-room');
    notificationClient.join('shared-room');

    chatEmitter.emitToRoom('shared-room', 'notify', {
      'message': 'chat only delivery',
    });

    expect(chatEmitterSocket.sent, isEmpty);
    expect(chatListenerSocket.sent, hasLength(1));
    expect(notificationSocket.sent, isEmpty);

    final chatDecoded = jsonDecode(chatListenerSocket.sent.first as String);
    expect(chatDecoded['event'], 'notify');
    expect(chatDecoded['data']['message'], 'chat only delivery');
  });
}

class _WsProfile {
  final String name;
  final DateTime createdAt;

  _WsProfile(this.name, this.createdAt);

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdAt': createdAt,
      };
}

class _WsMeta {
  final String status;

  _WsMeta(this.status);

  Map<String, dynamic> toJson() => {
        'status': status,
      };
}
