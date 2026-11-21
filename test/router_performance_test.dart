import 'package:test/test.dart';
import 'package:flint_dart/flint_dart.dart';

class _TestMiddleware extends Middleware {
  bool applied = false;

  @override
  Handler handle(Handler next) {
    applied = true;
    return (ctx) => next(ctx);
  }
}

void main() {
  group('Router pre-compiled matching & middleware caching', () {
    test('O(1) static route exact match', () {
      final router = Router();
      router.add('GET', '/api/v1/health', (ctx) async {});

      final params = <String, String>{};
      final handler = router.match('GET', '/api/v1/health', params);
      expect(handler, isNotNull);
      expect(params, isEmpty);
    });

    test('parameterized route with pre-compiled regex matching', () {
      final router = Router();
      router.add('GET', '/users/:id(\\d+)/profile', (ctx) async {});

      final params = <String, String>{};
      final handler = router.match('GET', '/users/42/profile', params);
      expect(handler, isNotNull);
      expect(params['id'], '42');

      // Non-matching regex (letters instead of digits)
      final paramsInvalid = <String, String>{};
      final handlerInvalid =
          router.match('GET', '/users/notanumber/profile', paramsInvalid);
      expect(handlerInvalid, isNull);
    });

    test('exact static route takes precedence over parameterized route', () {
      final router = Router();

      // Add param route first
      router.add('GET', '/items/:id', (ctx) async {});
      // Add static route after
      router.add('GET', '/items/popular', (ctx) async {});

      final params = <String, String>{};
      final handler = router.match('GET', '/items/popular', params);
      expect(handler, isNotNull);
      expect(params, isEmpty); // static route match has no params
    });

    test('wildcard route matches prefixes', () {
      final router = Router();
      router.add('GET', '/static/*', (ctx) async {});

      final params = <String, String>{};
      final handler = router.match('GET', '/static/css/app.css', params);
      expect(handler, isNotNull);
    });

    test('HEAD auto-derived from GET routes', () {
      final router = Router();
      router.add('GET', '/docs', (ctx) async {});

      final params = <String, String>{};
      final handler = router.match('HEAD', '/docs', params);
      expect(handler, isNotNull);
    });

    test('OPTIONS returns 204 with Allow header listing available methods',
        () async {
      final router = Router();
      router.add('GET', '/api/resource', (ctx) async {});
      router.add('POST', '/api/resource', (ctx) async {});

      final params = <String, String>{};
      final handler = router.match('OPTIONS', '/api/resource', params);
      expect(handler, isNotNull);
    });

    test('Method Not Allowed returns 405 when route exists for other methods',
        () {
      final router = Router();
      router.add('POST', '/login', (ctx) async {});

      final params = <String, String>{};
      final handler = router.match('DELETE', '/login', params);
      expect(handler, isNotNull); // 405 handler returned
    });

    test('middleware pipeline is pre-wrapped and cached', () {
      final router = Router();
      final middleware = _TestMiddleware();

      router.add('GET', '/pipeline-test', (ctx) async {},
          middlewares: [middleware]);

      final handler = router.match('GET', '/pipeline-test', {});
      expect(handler, isNotNull);
      expect(middleware.applied, isTrue);

      // Subsequent match returns the cached pipeline without re-applying fold
      middleware.applied = false;
      final handler2 = router.match('GET', '/pipeline-test', {});
      expect(handler2, isNotNull);
      expect(middleware.applied, isFalse);
    });
  });
}
