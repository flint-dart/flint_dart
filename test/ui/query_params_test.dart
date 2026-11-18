@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('query params', () {
    late String originalUrl;

    setUp(() {
      originalUrl = currentUrl;
      replace('/query-test?page=1&tab=users&tag=a&tag=b');
    });

    tearDown(() {
      replace(originalUrl);
    });

    test('reads current URL query values', () {
      expect(query.get('page'), '1');
      expect(query.get('tab'), 'users');
      expect(query.getAll('tag'), ['a', 'b']);
      expect(query.has('page'), isTrue);
      expect(query.has('missing'), isFalse);
      expect(query.all, containsPair('page', '1'));
      expect(query.allValues['tag'], ['a', 'b']);
    });

    test('sets one query value', () {
      query.set('tab', 'settings');

      expect(currentPath, '/query-test');
      expect(query.get('page'), '1');
      expect(query.get('tab'), 'settings');
    });

    test('updates multiple query values', () {
      query.update({
        'page': 2,
        'tab': 'billing',
        'tag': ['paid', 'overdue'],
      });

      expect(query.get('page'), '2');
      expect(query.get('tab'), 'billing');
      expect(query.getAll('tag'), ['paid', 'overdue']);
    });

    test('removes query values', () {
      query.remove('tab');

      expect(query.get('tab'), isNull);
      expect(query.get('page'), '1');
    });

    test('clears query values', () {
      query.clear();

      expect(currentQuery, isEmpty);
      expect(query.all, isEmpty);
    });

    test('can push a history entry', () {
      query.set('tab', 'reports', push: true);

      expect(query.get('tab'), 'reports');
    });
  });
}
