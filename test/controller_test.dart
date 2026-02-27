import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/websocket/ws_manager_instance.dart';
import 'package:test/test.dart';

import 'helpers/fakes.dart';

class _TestController extends Controller {}

void main() {
  tearDown(() {
    final ids = wsManager.clients.keys.toList();
    for (final id in ids) {
      wsManager.removeClient(id);
    }
  });

  group('Controller', () {
    test('exposes req and res in HTTP context and flags websocket as false', () {
      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/http'));
      final request = Request(raw);
      final response = Response(raw.response);

      final controller = _TestController()..bind(Context(req: request, res: response));

      expect(controller.req, same(request));
      expect(controller.res, same(response));
      expect(controller.isWebSocket, isFalse);
      expect(controller.isHttp, isTrue);
    });

    test('throws meaningful error when socket is accessed in HTTP context', () {
      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/http'));
      final controller = _TestController()
        ..bind(Context(req: Request(raw), res: Response(raw.response)));

      expect(
        () => controller.socket,
        throwsA(
          isA<ControllerContextException>().having(
            (e) => e.message,
            'message',
            contains('HTTP context'),
          ),
        ),
      );
    });

    test('exposes socket and marks websocket context', () async {
      final rawReq = FakeHttpRequest(method: 'GET', uri: Uri.parse('/ws'));
      final rawSocket = FakeWebSocket();
      final ws = FlintWebSocket(rawSocket, 'controller-ws-1');

      final controller = _TestController()
        ..bind(Context(req: Request(rawReq), socket: ws));

      expect(controller.isWebSocket, isTrue);
      expect(controller.socket, same(ws));

      await rawSocket.close();
    });
  });
}
