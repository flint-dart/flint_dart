import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/websocket/websocket.dart';
import 'package:flint_dart/src/websocket/ws_manager_instance.dart';
import 'package:test/test.dart';

import 'helpers/fakes.dart';

void main() {
  tearDown(() {
    final ids = wsManager.clients.keys.toList();
    for (final id in ids) {
      wsManager.removeClient(id);
    }
  });

  group('Context', () {
    test('isHttp is true when response is present', () {
      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/ctx-http'));
      final request = Request(raw);
      final response = Response(raw.response);
      final ctx = Context(req: request, res: response);

      expect(ctx.req, same(request));
      expect(ctx.res, same(response));
      expect(ctx.socket, isNull);
      expect(ctx.isHttp, isTrue);
      expect(ctx.isWebSocket, isFalse);
    });

    test('isWebSocket is true when socket is present', () async {
      final rawReq =
          FakeHttpRequest(method: 'GET', uri: Uri.parse('/ctx-socket'));
      final request = Request(rawReq);
      final rawSocket = FakeWebSocket();
      final socket = FlintWebSocket(rawSocket, 'ctx-ws-1');
      final ctx = Context(req: request, socket: socket);

      expect(ctx.req, same(request));
      expect(ctx.res, isNull);
      expect(ctx.socket, same(socket));
      expect(ctx.isHttp, isFalse);
      expect(ctx.isWebSocket, isTrue);

      await rawSocket.close();
    });

    test('supports mixed context with both response and socket', () async {
      final rawReq =
          FakeHttpRequest(method: 'GET', uri: Uri.parse('/ctx-mixed'));
      final request = Request(rawReq);
      final response = Response(rawReq.response);
      final rawSocket = FakeWebSocket();
      final socket = FlintWebSocket(rawSocket, 'ctx-ws-2');
      final ctx = Context(req: request, res: response, socket: socket);

      expect(ctx.isHttp, isTrue);
      expect(ctx.isWebSocket, isTrue);

      await rawSocket.close();
    });
  });

  group('Context adapters', () {
    test('adaptHttp delegates to legacy handler with request and response',
        () async {
      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/adapt-http'));
      final request = Request(raw);
      final response = Response(raw.response);

      late Request seenReq;
      late Response seenRes;
      final handler = adaptHttp((req, res) {
        seenReq = req;
        seenRes = res;
        return res.send('ok', status: 201);
      });

      final result = await handler(Context(req: request, res: response));

      expect(seenReq, same(request));
      expect(seenRes, same(response));
      expect(result, isA<Response>());
      expect((raw.response as FakeHttpResponse).statusCode, 201);
      expect((raw.response as FakeHttpResponse).buffer.toString(), 'ok');
    });

    test('adaptHttp returns null when response is missing', () async {
      final raw =
          FakeHttpRequest(method: 'GET', uri: Uri.parse('/adapt-http-null'));
      final request = Request(raw);
      var called = false;
      final handler = adaptHttp((req, res) {
        called = true;
        return res;
      });

      final result = await handler(Context(req: request));

      expect(result, isNull);
      expect(called, isFalse);
    });

    test('adaptWebSocket delegates to legacy handler with request and socket',
        () async {
      final rawReq =
          FakeHttpRequest(method: 'GET', uri: Uri.parse('/adapt-ws'));
      final request = Request(rawReq);
      final rawSocket = FakeWebSocket();
      final socket = FlintWebSocket(rawSocket, 'ctx-ws-3');

      late Request seenReq;
      late FlintWebSocket seenSocket;
      final handler = adaptWebSocket((req, ws) {
        seenReq = req;
        seenSocket = ws;
      });

      final result = await handler(Context(req: request, socket: socket));

      expect(result, isNull);
      expect(seenReq, same(request));
      expect(seenSocket, same(socket));

      await rawSocket.close();
    });

    test('adaptWebSocket returns null when socket is missing', () async {
      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/adapt-ws-no'));
      final request = Request(raw);
      var called = false;
      final handler = adaptWebSocket((req, socket) {
        called = true;
      });

      final result = await handler(Context(req: request));

      expect(result, isNull);
      expect(called, isFalse);
    });
  });
}
