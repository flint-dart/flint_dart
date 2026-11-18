@TestOn('browser')
library;

import 'package:flint_client/flint_client.dart';
import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('ClientRouter', () {
    test('keeps app route prefix', () {
      final router = ClientRouter(prefix: '/auth');

      expect(router.prefix, '/auth');
      expect(router.client, isA<FlintClient>());
      expect(router.client.baseUrl, isNotEmpty);
    });

    test('groups nested route prefixes', () {
      final router = ClientRouter(prefix: '/api').group('/users');

      expect(router.prefix, '/api/users');
    });

    test('normalizes empty groups', () {
      final router = clientRouter.group('/auth');

      expect(router.prefix, '/auth');
    });

    test('exposes a default app router', () {
      expect(clientRouter.prefix, isEmpty);
      expect(clientRouter.client, isA<FlintClient>());
      expect(clientRouter.client.baseUrl, isNotEmpty);
    });

    test('allows explicit base URL overrides', () {
      final router = ClientRouter(baseUrl: 'https://api.example.test');

      expect(router.client.baseUrl, 'https://api.example.test');
    });

    test('exposes QUERY helper and generic request dispatch API', () {
      final router = ClientRouter(baseUrl: 'https://api.example.test');

      expect(router.query<Map<String, dynamic>>, isA<Function>());
      expect(router.request<Map<String, dynamic>>, isA<Function>());
    });
  });
}
