import 'dart:convert';
import 'dart:io';
import 'package:flint_dart/src/error/auth_exception.dart';
import 'package:flint_dart/src/error/validation_exception.dart';
import 'package:test/test.dart';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart';
import 'package:flint_dart/src/template_engine/template_engine.dart';
import 'package:path/path.dart' as path;

import 'helpers/fakes.dart';

void main() {
  group('Request', () {
    test('parses query and params', () {
      final req = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/test?foo=bar'),
      );
      final request = Request(req, params: {'id': '123'});

      expect(request.queryParam('foo'), 'bar');
      expect(request.param('id'), '123');
      expect(request['id'], '123');
      expect(request['foo'], 'bar');
    });

    test('reads cookies and bearer token', () {
      final headers = FakeHttpHeaders()
        ..set(HttpHeaders.cookieHeader, 'FLINTSESSID=abc; theme=dark')
        ..set(HttpHeaders.authorizationHeader, 'Bearer token123');

      final req = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        headers: headers,
      );
      final request = Request(req);

      expect(request.cookies['FLINTSESSID'], 'abc');
      expect(request.cookies['theme'], 'dark');
      expect(request.bearerToken, 'token123');
    });

    test('parses JSON body', () async {
      final headers = FakeHttpHeaders()..contentType = ContentType.json;
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/'),
        headers: headers,
        bodyBytes: utf8Bytes('{"a":1,"b":"x"}'),
      );
      final request = Request(req);

      final data = await request.json();
      expect(data['a'], 1);
      expect(data['b'], 'x');
    });

    test('rawBody returns undecoded request bytes', () async {
      final headers = FakeHttpHeaders()..contentType = ContentType.json;
      final rawBytes = utf8Bytes('{"name":"Ada"}');
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/'),
        headers: headers,
        bodyBytes: rawBytes,
      );
      final request = Request(req);

      expect(await request.rawBody(), rawBytes);
      expect(utf8.decode(await request.rawBody()), '{"name":"Ada"}');
    });

    test('rawBody remains available after parsed body access', () async {
      final headers = FakeHttpHeaders()..contentType = ContentType.json;
      final rawBytes = utf8Bytes('{"name":"Ada"}');
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/'),
        headers: headers,
        bodyBytes: rawBytes,
      );
      final request = Request(req);

      final data = await request.json();

      expect(data['name'], 'Ada');
      expect(await request.rawBody(), rawBytes);
    });

    test('parses urlencoded form body', () async {
      final headers = FakeHttpHeaders()
        ..contentType = ContentType('application', 'x-www-form-urlencoded',
            charset: 'utf-8');
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/'),
        headers: headers,
        bodyBytes: utf8Bytes('a=1&b=hello'),
      );
      final request = Request(req);

      final form = await request.form();
      expect(form['a'], '1');
      expect(form['b'], 'hello');
    });

    test('input reads normalized values across params, body, query, and files',
        () async {
      final boundary = 'input-boundary';
      final body = utf8Bytes(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="title"\r\n\r\n'
        'Body title\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="avatar"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n\r\n'
        'hello world\r\n'
        '--$boundary--\r\n',
      );
      final headers = FakeHttpHeaders()
        ..contentType = ContentType(
          'multipart',
          'form-data',
          parameters: {'boundary': boundary},
        );
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/upload?title=Query title&tab=files'),
        headers: headers,
        bodyBytes: body,
      );
      final request = Request(req, params: {'id': '42'});

      expect(await request.input('id'), '42');
      expect(await request.input('tab'), 'files');
      expect(await request.input('title'), 'Body title');
      expect(await request.input('avatar'), isA<UploadedFile>());
    });

    test('multipart uploaded file size is measured after buffering', () async {
      final boundary = 'test-boundary';
      final body = utf8Bytes(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="avatar"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n\r\n'
        'hello world\r\n'
        '--$boundary--\r\n',
      );
      final headers = FakeHttpHeaders()
        ..contentType = ContentType(
          'multipart',
          'form-data',
          parameters: {'boundary': boundary},
        );
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/upload'),
        headers: headers,
        bodyBytes: body,
      );
      final request = Request(req);

      final file = await request.file('avatar');
      expect(file, isNotNull);
      expect(file!.size, 11);
    });

    test('form returns multipart fields while files stay accessible separately',
        () async {
      final boundary = 'multipart-fields-boundary';
      final body = utf8Bytes(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="title"\r\n\r\n'
        'Launch update\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="avatar"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n\r\n'
        'hello world\r\n'
        '--$boundary--\r\n',
      );
      final headers = FakeHttpHeaders()
        ..contentType = ContentType(
          'multipart',
          'form-data',
          parameters: {'boundary': boundary},
        );
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/upload'),
        headers: headers,
        bodyBytes: body,
      );
      final request = Request(req);

      final form = await request.form();

      expect(form['title'], 'Launch update');
      expect(form.containsKey('avatar'), isFalse);
      expect(await request.input('avatar'), isA<UploadedFile>());
    });

    test('validate auto-detects JSON input', () async {
      final headers = FakeHttpHeaders()..contentType = ContentType.json;
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/posts'),
        headers: headers,
        bodyBytes: utf8Bytes('{"title":"Hello","email":"ada@example.com"}'),
      );
      final request = Request(req);

      final data = await request.validate({
        'title': 'required|string',
        'email': 'required|email',
      });

      expect(data['title'], 'Hello');
      expect(data['email'], 'ada@example.com');
    });

    test('validate auto-detects urlencoded form input', () async {
      final headers = FakeHttpHeaders()
        ..contentType = ContentType('application', 'x-www-form-urlencoded',
            charset: 'utf-8');
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/login'),
        headers: headers,
        bodyBytes: utf8Bytes('email=ada%40example.com&password=secret123'),
      );
      final request = Request(req);

      final data = await request.validate({
        'email': 'required|email',
        'password': 'required|string|min:8',
      });

      expect(data['email'], 'ada@example.com');
      expect(data['password'], 'secret123');
    });

    test('validate auto-detects multipart fields and file presence', () async {
      final boundary = 'multipart-validate-boundary';
      final body = utf8Bytes(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="title"\r\n\r\n'
        'Release notes\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="avatar"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n\r\n'
        'hello world\r\n'
        '--$boundary--\r\n',
      );
      final headers = FakeHttpHeaders()
        ..contentType = ContentType(
          'multipart',
          'form-data',
          parameters: {'boundary': boundary},
        );
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/upload'),
        headers: headers,
        bodyBytes: body,
      );
      final request = Request(req);

      final data = await request.validate({
        'title': 'required|string',
        'avatar': 'required',
      });

      expect(data['title'], 'Release notes');
      expect(data['avatar'], isA<UploadedFile>());
    });

    test('validate keeps confirmation fields available for confirmed rules',
        () async {
      final headers = FakeHttpHeaders()..contentType = ContentType.json;
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/register'),
        headers: headers,
        bodyBytes: utf8Bytes(
          '{"password":"secret123","password_confirmation":"secret123"}',
        ),
      );
      final request = Request(req);

      final data = await request.validate({
        'password': 'required|string|confirmed',
      });

      expect(data['password'], 'secret123');
      expect(data['password_confirmation'], 'secret123');
    });

    test('validate still rejects unknown scalar fields', () async {
      final headers = FakeHttpHeaders()..contentType = ContentType.json;
      final req = FakeHttpRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/posts'),
        headers: headers,
        bodyBytes: utf8Bytes('{"title":"Hello","role":"admin"}'),
      );
      final request = Request(req);

      expect(
        () => request.validate({'title': 'required|string'}),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors.containsKey('role'),
            'unknown role field',
            isTrue,
          ),
        ),
      );
    });

    test('requireUser throws AuthException with 401', () {
      final req = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/protected'),
      );
      final request = Request(req);

      expect(
        request.requireUser,
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', HttpStatus.unauthorized)
              .having(
                (e) => e.message,
                'message',
                'Authentication required',
              ),
        ),
      );
    });

    test('AuthException is catchable as Exception', () {
      expect(
        () => throw AuthException(message: 'nope'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Response', () {
    test('send writes body and content type', () {
      final raw = FakeHttpResponse();
      final res = Response(raw);

      res.send('hi', status: 201, contentType: 'text/plain');

      expect(raw.statusCode, 201);
      expect(raw.headers.contentType?.mimeType, 'text/plain');
      expect(raw.buffer.toString(), 'hi');
      expect(raw.closed, true);
    });

    test('json writes json and content type', () async {
      final raw = FakeHttpResponse();
      final res = Response(raw);

      await res.json({'ok': true});

      expect(raw.headers.contentType?.mimeType, 'application/json');
      expect(raw.buffer.toString(), '{"ok":true}');
      expect(raw.closed, true);
    });

    test('back redirects to referer header', () {
      final headers = FakeHttpHeaders()
        ..set(HttpHeaders.refererHeader, 'http://localhost/previous');
      final raw = FakeHttpResponse();
      final fakeReq = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/current'),
        headers: headers,
        response: raw,
      );
      final req = Request(fakeReq);
      final res = Response(raw, request: req);

      res.back();

      expect(raw.statusCode, HttpStatus.found);
      expect(raw.headers.value(HttpHeaders.locationHeader),
          'http://localhost/previous');
      expect(raw.closed, false);
    });

    test('back uses fallback when referer is missing', () {
      final raw = FakeHttpResponse();
      final fakeReq = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/current'),
        response: raw,
      );
      final req = Request(fakeReq);
      final res = Response(raw, request: req);

      res.back(fallback: '/fallback');

      expect(raw.statusCode, HttpStatus.found);
      expect(raw.headers.value(HttpHeaders.locationHeader), '/fallback');
    });

    test('withSuccess and withError set flash cookies', () {
      final raw = FakeHttpResponse();
      final res = Response(raw);

      res.withSuccess('Saved successfully');
      res.withError('Something went wrong');

      final setCookie = raw.headers['set-cookie'] ?? const <String>[];
      expect(setCookie.any((v) => v.contains('FLINT_FLASH_success=')), true);
      expect(setCookie.any((v) => v.contains('Saved%20successfully')), true);
      expect(setCookie.any((v) => v.contains('FLINT_FLASH_error=')), true);
      expect(
          setCookie.any((v) => v.contains('Something%20went%20wrong')), true);
    });

    test('send does not write debug file to project root', () {
      final debugFile = File('test.html');
      if (debugFile.existsSync()) {
        debugFile.deleteSync();
      }

      final raw = FakeHttpResponse();
      final res = Response(raw);
      res.send('Hello');

      expect(raw.buffer.toString(), contains('Hello'));
      expect(debugFile.existsSync(), isFalse);
    });

    test('flintPage renders page payload for browser UI', () {
      Response.flintPageServerRenderer = null;
      Response.flintPageServerRenderingEnabled = false;
      final raw = FakeHttpResponse();
      final req = Request(FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/dashboard'),
      ));
      final res = Response(raw, request: req);

      res.flintPage(
        'Dashboard',
        props: {
          'user': {'name': 'Ada'}
        },
        script: '/main.dart.js',
      );

      final body = raw.buffer.toString();
      expect(raw.headers.contentType?.mimeType, 'text/html');
      expect(body, contains('id="app"'));
      expect(body, contains('data-flint-page='));
      expect(body, contains('&quot;component&quot;:&quot;Dashboard&quot;'));
      expect(body, contains('&quot;name&quot;:&quot;Ada&quot;'));
      expect(
        body,
        contains('<link rel="preload" as="script" href="/main.dart.js">'),
      );
      expect(body, contains('<script defer src="/main.dart.js"></script>'));
    });

    test('flintPage can include server-rendered HTML', () {
      final raw = FakeHttpResponse();
      final res = Response(raw);

      res.flintPage(
        'Dashboard',
        script: '/main.dart.js',
        serverHtml: '<section><h1>Ready now</h1></section>',
      );

      final body = raw.buffer.toString();
      expect(
        body,
        contains(
          '<main id="app" data-flint-page="{&quot;component&quot;:&quot;Dashboard&quot;,&quot;props&quot;:{}}"><section><h1>Ready now</h1></section></main>',
        ),
      );
      expect(body, contains('<script defer src="/main.dart.js"></script>'));
    });

    test('flintPage uses app-level server renderer when enabled', () {
      final previousRenderer = Response.flintPageServerRenderer;
      final previousEnabled = Response.flintPageServerRenderingEnabled;
      try {
        Response.flintPageServerRenderer = (component, props) {
          return '<p>$component ${props['name']}</p>';
        };
        Response.flintPageServerRenderingEnabled = true;

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage(
          'Home',
          props: {'name': 'Ada'},
          script: '/main.dart.js',
        );

        expect(raw.buffer.toString(), contains('<p>Home Ada</p>'));
      } finally {
        Response.flintPageServerRenderer = previousRenderer;
        Response.flintPageServerRenderingEnabled = previousEnabled;
      }
    });

    test('flintPage defaults to app-owned Flint UI public asset path', () {
      final originalCurrent = Directory.current;
      final tempDir = Directory.systemTemp.createTempSync('flint_page_assets_');
      try {
        Directory.current = tempDir;
        File(
          path.join(
            tempDir.path,
            'public',
            'assets',
            'js',
            'flint-ui',
            'main.dart.js',
          ),
        )
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage('Dashboard');

        expect(
          raw.buffer.toString(),
          contains('/assets/js/flint-ui/main.dart.js'),
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('flintPage defaults to hashed app-owned Flint UI public asset path',
        () {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_page_hashed_assets_');
      try {
        Directory.current = tempDir;
        File(
          path.join(
            tempDir.path,
            'public',
            'assets',
            'js',
            'flint-ui',
            'main.abcdef123456.dart.js',
          ),
        )
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage('Dashboard');

        expect(
          raw.buffer.toString(),
          contains('/assets/js/flint-ui/main.abcdef123456.dart.js'),
        );
        expect(raw.buffer.toString(), isNot(contains('?v=')));
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('flintPage does not query-version hashed manifest scripts', () {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_page_hashed_manifest_');
      try {
        Directory.current = tempDir;
        final assetDir =
            Directory(path.join('public', 'assets', 'js', 'flint-ui'))
              ..createSync(recursive: true);
        File(path.join(assetDir.path, 'manifest.json')).writeAsStringSync(
          jsonEncode({
            'fallback': '/assets/js/flint-ui/main.111111111111.dart.js',
            'pages': {
              'Home': '/assets/js/flint-ui/pages/home.abcdef123456.dart.js',
            },
          }),
        );
        File(path.join(assetDir.path, 'pages', 'home.abcdef123456.dart.js'))
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage('Home');

        expect(
          raw.buffer.toString(),
          contains('/assets/js/flint-ui/pages/home.abcdef123456.dart.js'),
        );
        expect(raw.buffer.toString(), isNot(contains('?v=')));
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('flintPage uses manifest page script when available', () {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_page_manifest_');
      try {
        Directory.current = tempDir;
        final assetDir =
            Directory(path.join('public', 'assets', 'js', 'flint-ui'))
              ..createSync(recursive: true);
        File(path.join(assetDir.path, 'manifest.json')).writeAsStringSync(
          jsonEncode({
            'fallback': '/assets/js/flint-ui/main.dart.js',
            'pages': {
              'Home': '/assets/js/flint-ui/pages/home.dart.js',
            },
          }),
        );
        File(path.join(assetDir.path, 'pages', 'home.dart.js'))
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage('Home');

        expect(
          raw.buffer.toString(),
          contains('/assets/js/flint-ui/pages/home.dart.js'),
        );
        expect(
          raw.buffer.toString(),
          contains(
            '<link rel="preload" as="script" href="/assets/js/flint-ui/pages/home.dart.js',
          ),
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('flintPage registers generated service worker when available', () {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_page_service_worker_');
      try {
        Directory.current = tempDir;
        File(path.join('public', 'flint-sw.js'))
          ..createSync(recursive: true)
          ..writeAsStringSync('self.addEventListener("install", () => {});');
        File(path.join('public', 'assets', 'js', 'flint-ui', 'main.dart.js'))
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage('Home');

        expect(raw.buffer.toString(), contains('serviceWorker'));
        expect(raw.buffer.toString(), contains("register('/flint-sw.js"));
        expect(raw.buffer.toString(), contains('FLINT_PREFETCH'));
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('flintPage uses manifest fallback when page script is missing', () {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_page_manifest_fallback_');
      try {
        Directory.current = tempDir;
        final assetDir =
            Directory(path.join('public', 'assets', 'js', 'flint-ui'))
              ..createSync(recursive: true);
        File(path.join(assetDir.path, 'manifest.json')).writeAsStringSync(
          jsonEncode({
            'fallback': '/assets/js/flint-ui/main.dart.js',
            'pages': {
              'Home': '/assets/js/flint-ui/pages/home.dart.js',
            },
          }),
        );
        File(path.join(assetDir.path, 'main.dart.js'))
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage('Dashboard');

        expect(
          raw.buffer.toString(),
          contains('/assets/js/flint-ui/main.dart.js'),
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('flintPage explicit script overrides manifest lookup', () {
      final originalCurrent = Directory.current;
      final tempDir =
          Directory.systemTemp.createTempSync('flint_page_manifest_override_');
      try {
        Directory.current = tempDir;
        final assetDir =
            Directory(path.join('public', 'assets', 'js', 'flint-ui'))
              ..createSync(recursive: true);
        File(path.join(assetDir.path, 'manifest.json')).writeAsStringSync(
          jsonEncode({
            'pages': {
              'Home': '/assets/js/flint-ui/pages/home.dart.js',
            },
          }),
        );

        final raw = FakeHttpResponse();
        final res = Response(raw);

        res.flintPage('Home', script: '/custom.js');

        expect(
          raw.buffer.toString(),
          contains('<script defer src="/custom.js"></script>'),
        );
        expect(
          raw.buffer.toString(),
          contains('<link rel="preload" as="script" href="/custom.js">'),
        );
      } finally {
        Directory.current = originalCurrent;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('flintPage renders SEO metadata in the initial HTML head', () {
      final raw = FakeHttpResponse();
      final req = Request(FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('https://eupanel.example/dashboard'),
      ));
      final res = Response(raw, request: req);

      res.flintPage(
        'Dashboard',
        script: '/main.dart.js',
        meta: const FlintPageMeta(
          title: 'EuPanel Dashboard',
          description: 'Manage hosting, domains, billing, and users.',
          canonicalUrl: 'https://eupanel.example/dashboard',
          imageUrl: 'https://eupanel.example/og.png',
          siteName: 'EuPanel',
          twitterSite: '@eulogia',
          structuredData: {
            '@context': 'https://schema.org',
            '@type': 'WebApplication',
            'name': 'EuPanel',
          },
        ),
      );

      final body = raw.buffer.toString();
      expect(body, contains('<title>EuPanel Dashboard</title>'));
      expect(
        body,
        contains(
          '<meta name="description" content="Manage hosting, domains, billing, and users.">',
        ),
      );
      expect(
        body,
        contains(
          '<link rel="canonical" href="https://eupanel.example/dashboard">',
        ),
      );
      expect(
        body,
        contains('<meta property="og:title" content="EuPanel Dashboard">'),
      );
      expect(
        body,
        contains(
          '<meta property="og:image" content="https://eupanel.example/og.png">',
        ),
      );
      expect(
        body,
        contains('<meta name="twitter:site" content="@eulogia">'),
      );
      expect(
        body,
        contains('<script type="application/ld+json">'),
      );
    });
  });

  group('Template Session Helpers', () {
    test('hasSession and session render correctly inside if blocks', () {
      final engine = TemplateEngine();
      engine.sessions['success'] = 'Saved successfully';

      final rendered = engine.renderString('''
{{ if hasSession('success') }}
OK: {{ session('success') }}
{{ else }}
NO
{{ endif }}
''', {});

      expect(rendered.contains('OK:'), true);
      expect(rendered.contains('Saved successfully'), true);
      expect(rendered.contains('NO'), false);
    });

    test('session missing key renders empty string', () {
      final engine = TemplateEngine();
      final rendered =
          engine.renderString("Value: {{ session('missing') }}", {});
      expect(rendered.trim(), 'Value:');
    });

    test('hasSession missing key evaluates to false', () {
      final engine = TemplateEngine();
      final rendered = engine.renderString('''
{{ if hasSession('missing') }}
YES
{{ else }}
NO
{{ endif }}
''', {});

      expect(rendered.contains('YES'), false);
      expect(rendered.contains('NO'), true);
    });

    test('include with inline JSON data renders partial correctly', () {
      final tempDir =
          Directory.systemTemp.createTempSync('flint-include-test-');
      final partial = File('${tempDir.path}/card.flint.html')
        ..writeAsStringSync('<h3>{{ title }}</h3><p>{{ body }}</p>');

      final safePath = partial.path.replaceAll("'", "\\'");
      final template =
          "{{ include('$safePath', { \"title\": \"Hello\", \"body\": \"...\" }) }}";

      final engine = TemplateEngine();
      final rendered = engine.renderString(template, {});

      expect(rendered.contains('<h3>Hello</h3>'), true);
      expect(rendered.contains('<p>...</p>'), true);

      tempDir.deleteSync(recursive: true);
    });
  });
}
