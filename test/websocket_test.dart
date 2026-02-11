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
}
