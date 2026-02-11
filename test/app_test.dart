import 'package:test/test.dart';
import 'package:flint_dart/flint_dart.dart';

import 'helpers/fakes.dart';

void main() {
  group('Flint', () {
    test('normalizePath collapses slashes and trims trailing', () {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );

      expect(app.normalizePath('///api//v1///users/'), '/api/v1/users');
      expect(app.normalizePath('/'), '/');
      expect(app.normalizePath('/users'), '/users');
      expect(app.normalizePath('/users/'), '/users');
    });

    test('viewPath can be set', () {
      Flint.viewPath = '';
      final app = Flint(
        viewPath: 'views',
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );

      expect(Flint.viewPath, 'views');
      // Use the instance to avoid unused warnings.
      expect(app.normalizePath('/test'), '/test');
    });
  });

  group('env()', () {
    test('coerces by default type', () {
      expect(env('ENV_INT', 5), 5);
      expect(env('ENV_BOOL', true), true);
      expect(env('ENV_STR', 'x'), 'x');
    });

    test('auto-parses when no default provided', () {
      final temp = env('ENV_MISSING');
      expect(temp, isNull);
    });
  });

  group('Pipeline', () {
    test('auto-converts string and map results', () async {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );

      app.get('/text', (ctx) => 'hello');
      app.get('/json', (ctx) => {'ok': true});

      final rawText =
          FakeHttpRequest(method: 'GET', uri: Uri.parse('/text'));
      await app.handleRequest(rawText);
      final textResponse = rawText.response as FakeHttpResponse;
      expect(textResponse.buffer.toString(), 'hello');
      expect(textResponse.headers.contentType?.mimeType, 'text/plain');

      final rawJson =
          FakeHttpRequest(method: 'GET', uri: Uri.parse('/json'));
      await app.handleRequest(rawJson);
      final jsonResponse = rawJson.response as FakeHttpResponse;
      expect(jsonResponse.buffer.toString(), '{"ok":true}');
      expect(jsonResponse.headers.contentType?.mimeType, 'application/json');
    });
  });

  group('Route registration', () {
    test('accepts legacy handlers in RouteGroup registration', () {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );

      final group = _LegacyRouteGroup();
      expect(() => app.routes(group), returnsNormally);
    });
  });
}

class _LegacyRouteGroup extends RouteGroup {
  @override
  String get prefix => '/legacy';

  @override
  void register(Flint app) {
    app.get('/', _index);
  }

  Future<Response> _index(Request req, Response res) async {
    return res.send('ok');
  }
}
