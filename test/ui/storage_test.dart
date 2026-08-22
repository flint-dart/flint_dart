@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('localStorage', () {
    tearDown(localStorage.clear);

    test('reads and writes string values', () {
      localStorage.write('flint.test.name', 'Flint');

      expect(localStorage.read('flint.test.name'), 'Flint');
      expect(localStorage.has('flint.test.name'), isTrue);
      expect(localStorage.has('flint.test.missing'), isFalse);
    });

    test('reads and writes JSON values', () {
      localStorage.writeJson('flint.test.user', {
        'name': 'Aim',
        'role': 'admin',
      });

      expect(
        localStorage.readMap('flint.test.user'),
        containsPair('role', 'admin'),
      );
      expect(localStorage.readJson('flint.test.user'), isA<Map>());
    });

    test('removes values', () {
      localStorage.write('flint.test.token', 'secret');

      final removed = localStorage.remove('flint.test.token');

      expect(removed, 'secret');
      expect(localStorage.read('flint.test.token'), isNull);
    });

    test('clears values', () {
      localStorage.write('flint.test.one', '1');
      localStorage.write('flint.test.two', '2');

      localStorage.clear();

      expect(localStorage.read('flint.test.one'), isNull);
      expect(localStorage.read('flint.test.two'), isNull);
    });
  });

  group('sessionStorage', () {
    tearDown(sessionStorage.clear);

    test('reads and writes string values', () {
      sessionStorage.write('flint.test.name', 'Flint');

      expect(sessionStorage.read('flint.test.name'), 'Flint');
      expect(sessionStorage.has('flint.test.name'), isTrue);
      expect(sessionStorage.has('flint.test.missing'), isFalse);
    });

    test('reads and writes JSON values', () {
      sessionStorage.writeJson('flint.test.user', {
        'name': 'Aim',
        'role': 'admin',
      });

      expect(
        sessionStorage.readMap('flint.test.user'),
        containsPair('role', 'admin'),
      );
      expect(sessionStorage.readJson('flint.test.user'), isA<Map>());
    });

    test('removes values', () {
      sessionStorage.write('flint.test.token', 'secret');

      final removed = sessionStorage.remove('flint.test.token');

      expect(removed, 'secret');
      expect(sessionStorage.read('flint.test.token'), isNull);
    });

    test('clears values', () {
      sessionStorage.write('flint.test.one', '1');
      sessionStorage.write('flint.test.two', '2');

      sessionStorage.clear();

      expect(sessionStorage.read('flint.test.one'), isNull);
      expect(sessionStorage.read('flint.test.two'), isNull);
    });
  });
}
