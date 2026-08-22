@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('AuthSessionManager', () {
    tearDown(() {
      localStorage.clear();
      sessionStorage.clear();
    });

    test('saves and reads the current session', () {
      const manager = AuthSessionManager(
        tokenKey: 'flint.auth.token',
        userKey: 'flint.auth.user',
      );

      manager.save(token: 'token-123', user: {'id': 1, 'role': 'admin'});

      expect(manager.isLoggedIn, isTrue);
      expect(manager.token, 'token-123');
      expect(manager.user, containsPair('role', 'admin'));
      expect(manager.role, 'admin');
      expect(manager.current, isA<AuthSessionSnapshot>());
      expect(manager.current?.token, 'token-123');
    });

    test('returns null current session when no token exists', () {
      const manager = AuthSessionManager(
        tokenKey: 'flint.auth.missing.token',
        userKey: 'flint.auth.missing.user',
      );

      expect(manager.isLoggedIn, isFalse);
      expect(manager.token, isNull);
      expect(manager.current, isNull);
      expect(manager.user, isEmpty);
    });

    test('updates user data without changing the token', () {
      const manager = AuthSessionManager(
        tokenKey: 'flint.auth.update.token',
        userKey: 'flint.auth.update.user',
      );

      manager.save(token: 'token-123', user: {'role': 'customer'});
      manager.updateUser({'role': 'reseller'});

      expect(manager.token, 'token-123');
      expect(manager.role, 'reseller');
    });

    test('clears token and user data', () {
      const manager = AuthSessionManager(
        tokenKey: 'flint.auth.clear.token',
        userKey: 'flint.auth.clear.user',
      );

      manager.save(token: 'token-123', user: {'role': 'admin'});
      manager.clear();

      expect(manager.isLoggedIn, isFalse);
      expect(manager.token, isNull);
      expect(manager.user, isEmpty);
    });

    test('can use session storage', () {
      const manager = AuthSessionManager(
        tokenKey: 'flint.auth.session.token',
        userKey: 'flint.auth.session.user',
        storage: sessionStorage,
      );

      manager.save(token: 'session-token', user: {'role': 'admin'});

      expect(manager.token, 'session-token');
      expect(sessionStorage.read('flint.auth.session.token'), 'session-token');
      expect(localStorage.read('flint.auth.session.token'), isNull);
    });
  });
}
