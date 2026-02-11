import 'dart:io';

import 'package:test/test.dart';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart';

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
  });
}
