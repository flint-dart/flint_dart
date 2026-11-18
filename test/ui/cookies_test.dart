@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('cookies', () {
    tearDown(cookies.clear);

    test('reads and writes values', () {
      cookies.write('flint_cookie_name', 'Flint');

      expect(cookies.read('flint_cookie_name'), 'Flint');
      expect(cookies.has('flint_cookie_name'), isTrue);
      expect(cookies.has('flint_cookie_missing'), isFalse);
    });

    test('encodes names and values', () {
      cookies.write('flint cookie email', 'admin@eupanel.local');

      expect(cookies.read('flint cookie email'), 'admin@eupanel.local');
    });

    test('reads all visible cookies', () {
      cookies.write('flint_cookie_one', '1');
      cookies.write('flint_cookie_two', '2');

      expect(cookies.readAll(), containsPair('flint_cookie_one', '1'));
      expect(cookies.readAll(), containsPair('flint_cookie_two', '2'));
    });

    test('removes values', () {
      cookies.write('flint_cookie_token', 'secret');

      cookies.remove('flint_cookie_token');

      expect(cookies.read('flint_cookie_token'), isNull);
    });

    test('clears visible cookies', () {
      cookies.write('flint_cookie_one', '1');
      cookies.write('flint_cookie_two', '2');

      cookies.clear();

      expect(cookies.read('flint_cookie_one'), isNull);
      expect(cookies.read('flint_cookie_two'), isNull);
    });

    test('supports cookie options', () {
      cookies.write(
        'flint_cookie_options',
        'yes',
        maxAge: const Duration(minutes: 5),
        sameSite: CookieSameSite.lax,
      );

      expect(cookies.read('flint_cookie_options'), 'yes');
    });
  });
}
