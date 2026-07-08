import 'dart:io';

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

    test('default middleware serves public static assets', () async {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_static_assets_');

      try {
        Directory.current = tempDir;
        final asset = File('public/assets/js/flint-ui/main.dart.js')
          ..createSync(recursive: true)
          ..writeAsStringSync('console.log("ok");');

        final app = Flint(
          autoConnectDb: false,
          autoConnectMail: false,
          enableSwaggerDocs: false,
        );

        final raw = FakeHttpRequest(
          method: 'GET',
          uri: Uri.parse('/assets/js/flint-ui/main.dart.js'),
        );
        await app.handleRequest(raw);

        final response = raw.response as FakeHttpResponse;
        expect(asset.existsSync(), isTrue);
        expect(response.statusCode, 200);
        expect(response.buffer.toString(), 'console.log("ok");');
        expect(response.headers.contentType?.mimeType, 'text/javascript');
        expect(
          response.headers.value(HttpHeaders.cacheControlHeader),
          'public, max-age=2592000',
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('static middleware uses immutable cache for fingerprinted assets',
        () async {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_static_hash_assets_');

      try {
        Directory.current = tempDir;
        File('public/assets/js/flint-ui/pages/home.abcdef123456.dart.js')
          ..createSync(recursive: true)
          ..writeAsStringSync('console.log("home");');

        final app = Flint(
          autoConnectDb: false,
          autoConnectMail: false,
          enableSwaggerDocs: false,
        );

        final raw = FakeHttpRequest(
          method: 'GET',
          uri: Uri.parse(
            '/assets/js/flint-ui/pages/home.abcdef123456.dart.js',
          ),
        );
        await app.handleRequest(raw);

        final response = raw.response as FakeHttpResponse;
        expect(
          response.headers.value(HttpHeaders.cacheControlHeader),
          'public, max-age=31536000, immutable',
        );
        expect(
          response.headers.value(HttpHeaders.varyHeader),
          'Accept-Encoding',
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('static middleware revalidates manifest assets', () async {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_static_manifest_');

      try {
        Directory.current = tempDir;
        File('public/assets/js/flint-ui/manifest.json')
          ..createSync(recursive: true)
          ..writeAsStringSync('{"mode":"page-bundles"}');

        final app = Flint(
          autoConnectDb: false,
          autoConnectMail: false,
          enableSwaggerDocs: false,
        );

        final raw = FakeHttpRequest(
          method: 'GET',
          uri: Uri.parse('/assets/js/flint-ui/manifest.json'),
        );
        await app.handleRequest(raw);

        final response = raw.response as FakeHttpResponse;
        expect(
          response.headers.value(HttpHeaders.cacheControlHeader),
          'no-cache, no-store, must-revalidate',
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('static middleware treats query-versioned assets as immutable',
        () async {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_static_query_assets_');

      try {
        Directory.current = tempDir;
        File('public/assets/css/flint-ui/style.css')
          ..createSync(recursive: true)
          ..writeAsStringSync('body{}');

        final app = Flint(
          autoConnectDb: false,
          autoConnectMail: false,
          enableSwaggerDocs: false,
        );

        final raw = FakeHttpRequest(
          method: 'GET',
          uri: Uri.parse('/assets/css/flint-ui/style.css?v=123'),
        );
        await app.handleRequest(raw);

        final response = raw.response as FakeHttpResponse;
        expect(
          response.headers.value(HttpHeaders.cacheControlHeader),
          'public, max-age=31536000, immutable',
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
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

      final rawText = FakeHttpRequest(method: 'GET', uri: Uri.parse('/text'));
      await app.handleRequest(rawText);
      final textResponse = rawText.response as FakeHttpResponse;
      expect(textResponse.buffer.toString(), 'hello');
      expect(textResponse.headers.contentType?.mimeType, 'text/plain');

      final rawJson = FakeHttpRequest(method: 'GET', uri: Uri.parse('/json'));
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

    test('controller route builder binds controller actions', () async {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );
      final users = app.controller(_AppTestController.new);
      users.get('/users/:id', (c) => c.show());

      final raw = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('/users/42'),
      );
      await app.handleRequest(raw);

      final response = raw.response as FakeHttpResponse;
      expect(response.buffer.toString(), '{"id":"42"}');
      expect(response.headers.contentType?.mimeType, 'application/json');
    });

    test('route group can reuse app.controller for user routes', () async {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );
      app.routes(_UserRoutes());

      final createRaw = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('/users'),
        bodyBytes: utf8Bytes('{"email":"ada@example.com"}'),
      );
      createRaw.headers.contentType = ContentType.json;
      await app.handleRequest(createRaw);

      final createResponse = createRaw.response as FakeHttpResponse;
      expect(
        createResponse.buffer.toString(),
        '{"message":"User created successfully","data":{"email":"ada@example.com"},"transport":"http"}',
      );
      expect(createResponse.headers.contentType?.mimeType, 'application/json');

      final showRaw = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('/users/42'),
      );
      await app.handleRequest(showRaw);

      final showResponse = showRaw.response as FakeHttpResponse;
      expect(
        showResponse.buffer.toString(),
        '{"id":"42","message":"Profile loaded"}',
      );
      expect(showResponse.headers.contentType?.mimeType, 'application/json');
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

class _AppTestController extends Controller {
  Future<Response> show() async {
    return res.json({'id': req.params['id']});
  }
}

class _UserRoutes extends RouteGroup {
  @override
  String get prefix => '/users';

  @override
  void register(Flint app) {
    final users = app.controller(_UserController.new);

    users.post('/', (c) => c.create());
    users.get('/:id', (c) => c.showProfile());
  }
}

class _UserController extends Controller {
  Future<Response> create() async {
    final body = await req.json();

    return res.json({
      'message': 'User created successfully',
      'data': body,
      'transport': isWebSocket ? 'websocket' : 'http',
    });
  }

  Future<Response> showProfile() async {
    return res.json({
      'id': req.params['id'],
      'message': 'Profile loaded',
    });
  }
}
