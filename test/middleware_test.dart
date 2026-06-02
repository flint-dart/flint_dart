import 'dart:io';

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
  group('StaticFileMiddleware', () {
    test('serves precompressed Brotli before gzip when accepted', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('flint_static_brotli_');
      try {
        File('${tempDir.path}/main.dart.js')
          ..createSync(recursive: true)
          ..writeAsStringSync('console.log("raw");');
        File('${tempDir.path}/main.dart.js.gz').writeAsStringSync('gzip-body');
        File('${tempDir.path}/main.dart.js.br')
            .writeAsStringSync('brotli-body');

        final headers = FakeHttpHeaders()
          ..set(HttpHeaders.acceptEncodingHeader, 'gzip, br');
        final raw = FakeHttpRequest(
          method: 'GET',
          uri: Uri.parse('/main.dart.js'),
          headers: headers,
        );
        final response = Response(raw.response, request: Request(raw));
        final handler = StaticFileMiddleware(publicFolder: tempDir.path).handle(
          (_) => throw StateError('static file should be handled'),
        );

        await handler(Context(req: Request(raw), res: response));

        final rawResponse = raw.response as FakeHttpResponse;
        expect(rawResponse.statusCode, 200);
        expect(rawResponse.buffer.toString(), 'brotli-body');
        expect(
          rawResponse.headers.value(HttpHeaders.contentEncodingHeader),
          'br',
        );
        expect(
          rawResponse.headers.value(HttpHeaders.varyHeader),
          'Accept-Encoding',
        );
        expect(rawResponse.headers.contentType?.mimeType, 'text/javascript');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('serves precompressed gzip when Brotli is unavailable', () async {
      final tempDir = Directory.systemTemp.createTempSync('flint_static_gzip_');
      try {
        File('${tempDir.path}/main.dart.js')
          ..createSync(recursive: true)
          ..writeAsStringSync('console.log("raw");');
        File('${tempDir.path}/main.dart.js.gz').writeAsStringSync('gzip-body');

        final headers = FakeHttpHeaders()
          ..set(HttpHeaders.acceptEncodingHeader, 'br;q=0, gzip');
        final raw = FakeHttpRequest(
          method: 'GET',
          uri: Uri.parse('/main.dart.js'),
          headers: headers,
        );
        final response = Response(raw.response, request: Request(raw));
        final handler = StaticFileMiddleware(publicFolder: tempDir.path).handle(
          (_) => throw StateError('static file should be handled'),
        );

        await handler(Context(req: Request(raw), res: response));

        final rawResponse = raw.response as FakeHttpResponse;
        expect(rawResponse.buffer.toString(), 'gzip-body');
        expect(
          rawResponse.headers.value(HttpHeaders.contentEncodingHeader),
          'gzip',
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

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
      final handler =
          RecordingMiddleware('trace', log).handle((ctx) async => 'ok');

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

  group('ExceptionMiddleware', () {
    test('catches ValidationError from exception library', () async {
      final middleware = ExceptionMiddleware();
      final handler = middleware.handle((ctx) async {
        throw ValidationError(
          errors: {
            'email': ['The email field is required.']
          },
        );
      });

      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/test'));
      final request = Request(raw);
      final response = Response(raw.response);

      await handler(Context(req: request, res: response));

      final rawResponse = raw.response as FakeHttpResponse;
      expect(rawResponse.statusCode, 422);
      expect(
        rawResponse.buffer.toString(),
        '{"status":false,"errors":{"email":["The email field is required."]}}',
      );
    });

    test('catches AuthException from awaited async handlers', () async {
      final middleware = ExceptionMiddleware();
      final handler = middleware.handle((ctx) async {
        await Future<void>.delayed(Duration.zero);
        throw AuthException(message: 'User already exists with this email');
      });

      final raw = FakeHttpRequest(method: 'GET', uri: Uri.parse('/test'));
      final request = Request(raw);
      final response = Response(raw.response);

      await handler(Context(req: request, res: response));

      final rawResponse = raw.response as FakeHttpResponse;
      expect(rawResponse.statusCode, 401);
      expect(
        rawResponse.buffer.toString(),
        '{"status":false,"error":"Unauthorized","message":"User already exists with this email"}',
      );
    });
  });

  group('AntiSqlInjectionMiddleware', () {
    test('blocks SQL injection in query parameters', () async {
      var handlerCalled = false;
      final middleware = AntiSqlInjectionMiddleware();
      final handler = middleware.handle((ctx) async {
        handlerCalled = true;
        return ctx.res?.send('ok');
      });

      final raw = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse("/search?q=' OR 1=1 --"),
      );
      final request = Request(raw);
      final response = Response(raw.response);

      await handler(Context(req: request, res: response));

      final rawResponse = raw.response as FakeHttpResponse;
      expect(handlerCalled, isFalse);
      expect(rawResponse.statusCode, 400);
      expect(rawResponse.buffer.toString(), contains('SQL injection'));
    });

    test('blocks SQL injection in JSON request body', () async {
      var handlerCalled = false;
      final middleware = AntiSqlInjectionMiddleware();
      final handler = middleware.handle((ctx) async {
        handlerCalled = true;
        return ctx.res?.send('ok');
      });

      final headers = FakeHttpHeaders()
        ..contentType = ContentType('application', 'json');
      final raw = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('/login'),
        headers: headers,
        bodyBytes: utf8Bytes(
            '{"email":"admin@example.com","password":"x\' OR 1=1 --"}'),
      );
      final request = Request(raw);
      final response = Response(raw.response);

      await handler(Context(req: request, res: response));

      final rawResponse = raw.response as FakeHttpResponse;
      expect(handlerCalled, isFalse);
      expect(rawResponse.statusCode, 400);
    });

    test('allows ordinary text and preserves the body for handlers', () async {
      final middleware = AntiSqlInjectionMiddleware();
      final handler = middleware.handle((ctx) async {
        final body = await ctx.req.body();
        return ctx.res?.send(body);
      });

      final headers = FakeHttpHeaders()
        ..contentType = ContentType('application', 'json');
      final raw = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('/tickets'),
        headers: headers,
        bodyBytes: utf8Bytes('{"message":"Please help me select a plan"}'),
      );
      final request = Request(raw);
      final response = Response(raw.response);

      await handler(Context(req: request, res: response));

      final rawResponse = raw.response as FakeHttpResponse;
      expect(rawResponse.statusCode, 200);
      expect(
        rawResponse.buffer.toString(),
        '{"message":"Please help me select a plan"}',
      );
    });
  });
}
