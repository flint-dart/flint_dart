import 'package:test/test.dart';
import 'package:flint_dart/flint_dart.dart';

import 'helpers/fakes.dart';

class RecordingMiddleware extends Middleware {
  final String name;
  final List<String> log;

  RecordingMiddleware(this.name, this.log);

  @override
  Handler handle(Handler next) {
    return (ctx) async {
      log.add('before-$name');
      final result = await next(ctx);
      log.add('after-$name');
      return result;
    };
  }
}

class ShortCircuitMiddleware extends Middleware {
  final int status;
  final String body;

  ShortCircuitMiddleware({this.status = 401, this.body = 'Unauthorized'});

  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final res = ctx.res;
      if (res == null) return null;
      return res.send(body, status: status);
    };
  }
}

void main() {
  group('Middleware', () {
    test('applies in declared order (outer wraps inner)', () async {
      final log = <String>[];
      final router = Router();

      router.add(
        'GET',
        '/test',
        (ctx) async {
          log.add('handler');
          ctx.res?.send('ok');
        },
        middlewares: [
          RecordingMiddleware('first', log),
          RecordingMiddleware('second', log),
        ],
      );

      final params = <String, String>{};
      final handler = router.match('GET', '/test', params);
      expect(handler, isNotNull);

      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/test'));
      final request = Request(raw);
      final response = Response(raw.response);

      await handler!(Context(req: request, res: response));

      expect(
        log,
        [
          'before-second',
          'before-first',
          'handler',
          'after-first',
          'after-second',
        ],
      );
    });

    test('can short-circuit without calling next', () async {
      final router = Router();
      var handlerCalled = false;

      router.add(
        'GET',
        '/secure',
        (ctx) async {
          handlerCalled = true;
          ctx.res?.send('ok');
        },
        middlewares: [
          ShortCircuitMiddleware(),
        ],
      );

      final params = <String, String>{};
      final handler = router.match('GET', '/secure', params);
      expect(handler, isNotNull);

      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/secure'));
      final request = Request(raw);
      final response = Response(raw.response);

      await handler!(Context(req: request, res: response));

      final rawResponse = raw.response as FakeHttpResponse;
      expect(handlerCalled, isFalse);
      expect(rawResponse.statusCode, 401);
      expect(rawResponse.buffer.toString(), 'Unauthorized');
    });
  });

  group('Context handler returns', () {
    test('returns primitive value through middleware', () async {
      final log = <String>[];
      final handler = RecordingMiddleware('trace', log)
          .handle((ctx) async => 'ok');

      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/test'));
      final request = Request(raw);
      final response = Response(raw.response);

      final result = await handler(Context(req: request, res: response));

      expect(result, 'ok');
      expect(log, ['before-trace', 'after-trace']);
    });

    test('returns map value through middleware', () async {
      final handler = RecordingMiddleware('trace', <String>[])
          .handle((ctx) async => {'ok': true});

      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/test'));
      final request = Request(raw);
      final response = Response(raw.response);

      final result = await handler(Context(req: request, res: response));

      expect(result, {'ok': true});
    });

    test('returns Response when handler sends directly', () async {
      final handler = RecordingMiddleware('trace', <String>[])
          .handle((ctx) async => ctx.res?.send('done'));

      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/test'));
      final request = Request(raw);
      final response = Response(raw.response);

      final result = await handler(Context(req: request, res: response));

      expect(result, isA<Response>());
      final rawResponse = raw.response as FakeHttpResponse;
      expect(rawResponse.buffer.toString(), 'done');
    });
  });
}
