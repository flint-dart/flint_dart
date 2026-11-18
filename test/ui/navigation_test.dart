@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('navigation', () {
    late String originalUrl;

    setUp(() {
      originalUrl = currentUrl;
    });

    tearDown(() {
      replace(originalUrl);
    });

    test('pushes a new browser history entry', () {
      navigate('/flint-navigation-test?tab=users#details');

      expect(currentPath, '/flint-navigation-test');
      expect(currentQuery, '?tab=users');
      expect(currentHash, '#details');
      expect(currentUri.queryParameters, containsPair('tab', 'users'));
    });

    test('replaces the current browser history entry', () {
      replace('/flint-navigation-replace?mode=edit');

      expect(currentPath, '/flint-navigation-replace');
      expect(currentQuery, '?mode=edit');
      expect(currentUri.queryParameters, containsPair('mode', 'edit'));
    });

    test('supports state objects', () {
      navigation.navigate('/flint-navigation-state', state: {'from': 'test'});

      expect(currentPath, '/flint-navigation-state');
    });
  });
}
