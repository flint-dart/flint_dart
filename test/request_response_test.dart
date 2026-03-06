import 'dart:io';

import 'package:flint_dart/src/error/auth_exception.dart';
import 'package:test/test.dart';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart';
import 'package:flint_dart/src/template_engine/template_engine.dart';

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
      final headers = FakeHttpHeaders()
        ..contentType = ContentType.json;
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

    test('parses urlencoded form body', () async {
      final headers = FakeHttpHeaders()
        ..contentType = ContentType(
            'application', 'x-www-form-urlencoded', charset: 'utf-8');
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
      expect(setCookie.any((v) => v.contains('Something%20went%20wrong')), true);
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
      final rendered = engine.renderString("Value: {{ session('missing') }}", {});
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
