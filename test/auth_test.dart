import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flint_dart/src/auth/auth.dart';
import 'package:flint_dart/src/auth/auth_config.dart';
import 'package:flint_dart/src/auth/auth_service.dart';
import 'package:flint_dart/src/error/auth_exception.dart';
import 'package:test/test.dart';

void main() {
  group('Auth token helpers', () {
    test('generateToken and verifyToken roundtrip payload', () {
      final payload = {
        'id': 1,
        'email': 'user@example.com',
      };

      final token = Auth.generateToken(payload);
      final decoded = Auth.verifyToken(token);

      expect(decoded, isNotNull);
      expect(decoded!['id'], 1);
      expect(decoded['email'], 'user@example.com');
      expect(decoded.containsKey('iat'), isTrue);
      expect(decoded.containsKey('exp'), isTrue);
    });

    test('verifyToken returns null for malformed token', () {
      expect(Auth.verifyToken('not-a-valid-jwt'), isNull);
    });
  });

  group('Auth providerRedirectUrl', () {
    test('builds github URL with callback and state', () {
      const redirectPath = '/auth/github/callback';
      const state = 'state123';

      final url = Auth.providerRedirectUrl(
        provider: 'github',
        redirectPath: redirectPath,
        state: state,
      );

      final uri = Uri.parse(url);
      expect(uri.host, 'github.com');
      expect(uri.path, '/login/oauth/authorize');
      expect(uri.queryParameters['redirect_uri'],
          '${Auth.config.redirectBase}$redirectPath');
      expect(uri.queryParameters['scope'], 'user:email');
      expect(uri.queryParameters['state'], state);
    });

    test('builds google URL with callback and state', () {
      const redirectPath = '/auth/google/callback';
      const state = 'state456';

      final url = Auth.providerRedirectUrl(
        provider: 'google',
        redirectPath: redirectPath,
        state: state,
      );

      final uri = Uri.parse(url);
      expect(uri.host, 'accounts.google.com');
      expect(uri.path, '/o/oauth2/v2/auth');
      expect(uri.queryParameters['redirect_uri'],
          '${Auth.config.redirectBase}$redirectPath');
      expect(uri.queryParameters['scope'], 'openid email profile');
      expect(uri.queryParameters['state'], state);
    });

    test('throws for unsupported provider', () {
      expect(
        () => Auth.providerRedirectUrl(
          provider: 'x',
          redirectPath: '/cb',
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('AuthConfig', () {
    test('validate reports missing provider configs as warnings', () {
      final config = AuthConfig(
        table: 'users',
        emailColumn: 'email',
        passwordColumn: 'password',
        redirectBase: 'http://localhost:3000',
        jwtSecret: 'secret',
      );

      final result = config.validate();
      final warnings = (result['warnings'] as List).cast<String>();

      expect(result['valid'], isTrue);
      expect(warnings.any((w) => w.contains('Google OAuth not configured')),
          isTrue);
      expect(warnings.any((w) => w.contains('GitHub OAuth not configured')),
          isTrue);
      expect(warnings.any((w) => w.contains('Facebook OAuth not configured')),
          isTrue);
      expect(warnings.any((w) => w.contains('Apple Sign In not configured')),
          isTrue);
    });

    test('copyWith overrides selected fields', () {
      final base = AuthConfig(
        table: 'users',
        emailColumn: 'email',
        passwordColumn: 'password',
        redirectBase: 'http://localhost:3000',
        jwtSecret: 'secret',
      );

      final updated = base.copyWith(
        table: 'members',
        passwordMinLength: 10,
      );

      expect(updated.table, 'members');
      expect(updated.passwordMinLength, 10);
      expect(updated.emailColumn, base.emailColumn);
    });
  });

  group('AuthService', () {
    test('validateConfig has stable structure', () {
      final result = AuthService.validateConfig();

      expect(result.containsKey('valid'), isTrue);
      expect(result.containsKey('errors'), isTrue);
      expect(result.containsKey('warnings'), isTrue);
      expect(result.containsKey('redirectBase'), isTrue);
      expect(result['errors'], isA<List>());
      expect(result['warnings'], isA<List>());
    });

    test('getAvailableProviders returns all provider flags', () {
      final result = AuthService.getAvailableProviders();
      final available = result['available'] as Map<String, dynamic>;

      expect(available.containsKey('google'), isTrue);
      expect(available.containsKey('github'), isTrue);
      expect(available.containsKey('facebook'), isTrue);
      expect(available.containsKey('apple'), isTrue);
      expect(available.values.every((v) => v is bool), isTrue);
    });

    test('getAllAuthUrls returns URLs for configured providers only', () {
      final callback = '${Auth.config.redirectBase}/auth/callback';
      final urls = AuthService.getAllAuthUrls(callbackUrl: callback);

      expect(urls, isA<Map<String, String>>());
      for (final entry in urls.entries) {
        final uri = Uri.parse(entry.value);
        expect(uri.hasScheme, isTrue);
        expect(uri.host.isNotEmpty, isTrue);
      }
    });

    test('provider URL generation behavior matches config state', () {
      const callback = 'http://localhost:3030/auth/google/callback';

      if (Auth.config.isGoogleConfigured) {
        final url = AuthService.getGoogleAuthUrl(callbackUrl: callback);
        final uri = Uri.parse(url);
        expect(uri.host, 'accounts.google.com');
        expect(uri.queryParameters['redirect_uri'], callback);
      } else {
        expect(
          () => AuthService.getGoogleAuthUrl(callbackUrl: callback),
          throwsA(isA<AuthException>()),
        );
      }
    });
  });

  group('TotpService', () {
    test('generateSecret returns base32 uppercase text', () {
      final secret = TotpService.generateSecret();
      expect(secret.isNotEmpty, isTrue);
      expect(RegExp(r'^[A-Z2-7]+$').hasMatch(secret), isTrue);
    });

    test('buildOtpAuthUrl formats issuer and email', () {
      final url = TotpService.buildOtpAuthUrl(
        secret: 'JBSWY3DPEHPK3PXP',
        email: 'qa@example.com',
        issuer: 'Flint',
      );

      expect(url.startsWith('otpauth://totp/'), isTrue);
      expect(url.contains('secret=JBSWY3DPEHPK3PXP'), isTrue);
      expect(url.contains('issuer=Flint'), isTrue);
      expect(url.contains('Flint%3Aqa%40example.com'), isTrue);
    });

    test('verifyCode accepts correct current TOTP and rejects wrong one', () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final expectedCode = _currentTotp(secret);

      final ok = TotpService.verifyCode(
        secret: secret,
        code: expectedCode,
        window: 0,
      );
      final bad = TotpService.verifyCode(
        secret: secret,
        code: '000000',
        window: 0,
      );

      expect(ok, isTrue);
      if (expectedCode != '000000') {
        expect(bad, isFalse);
      }
    });
  });
}

String _currentTotp(String secret) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final counter = now ~/ 30;
  return _hotp(secret, counter);
}

String _hotp(String secret, int counter) {
  final key = _base32Decode(secret);
  final counterBytes = Uint8List(8);
  final data = ByteData.view(counterBytes.buffer);
  data.setInt64(0, counter, Endian.big);

  final digest = Hmac(sha1, key).convert(counterBytes).bytes;
  final offset = digest.last & 0x0f;
  final binary = ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);

  final otp = binary % 1000000;
  return otp.toString().padLeft(6, '0');
}

Uint8List _base32Decode(String input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final cleaned = input.replaceAll('=', '').toUpperCase();
  int buffer = 0;
  int bitsLeft = 0;
  final out = <int>[];

  for (final ch in cleaned.split('')) {
    final index = alphabet.indexOf(ch);
    if (index < 0) continue;
    buffer = (buffer << 5) | index;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      bitsLeft -= 8;
      out.add((buffer >> bitsLeft) & 0xff);
    }
  }

  return Uint8List.fromList(out);
}
