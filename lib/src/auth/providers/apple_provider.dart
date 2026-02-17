// providers/apple_provider.dart
import 'dart:convert';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/auth/providers/base_provider.dart';
import 'package:flint_dart/src/error/auth_exception.dart';

class AppleProvider {
  static Future<Map<String, dynamic>> authenticate({
    required String identityToken,
    required String? clientId,
    required String? teamId,
    required String? keyId,
    required String? privateKey,
    String? authorizationCode,
    String? userData,
  }) async {
    if (clientId == null ||
        teamId == null ||
        keyId == null ||
        privateKey == null) {
      throw AuthException(message: 'Apple Sign In is not properly configured');
    }

    // Verify the identity token
    final profile = await _verifyIdentityToken(identityToken, clientId);

    // Parse user data if provided (Apple only sends this on first login)
    Map<String, dynamic>? parsedUserData;
    if (userData != null && userData.isNotEmpty) {
      try {
        parsedUserData = json.decode(userData) as Map<String, dynamic>;
      } catch (e) {
        Log.debug('Failed to parse Apple user data: ', error: e);
      }
    }

    final email = profile['email'];
    final name = parsedUserData?['name'] != null
        ? '${parsedUserData!['name']?['firstName']} ${parsedUserData['name']?['lastName']}'
        : profile['email']?.split('@').first;

    return AuthProvider.formatUserData(
      provider: 'apple',
      providerId: profile['sub'],
      email: email,
      name: name,
      rawProfile: {
        ...profile,
        if (parsedUserData != null) 'userData': parsedUserData,
      },
    );
  }

  static Future<Map<String, dynamic>> _verifyIdentityToken(
    String identityToken,
    String clientId,
  ) async {
    final allowInsecure =
        FlintEnv.getBool('ALLOW_INSECURE_APPLE_TOKEN_VERIFICATION', false);
    if (!allowInsecure) {
      throw AuthException(
        message:
            'Apple identity token signature verification is not implemented. Set ALLOW_INSECURE_APPLE_TOKEN_VERIFICATION=true only for local development.',
      );
    }

    try {
      final parts = identityToken.split('.');
      if (parts.length != 3) {
        throw AuthException(message: 'Invalid Apple identity token format');
      }

      final payload = parts[1];
      final decoded = utf8.decode(base64Url.decode(
        base64Url.normalize(payload),
      ));

      final claims = json.decode(decoded) as Map<String, dynamic>;

      // Verify issuer
      final iss = claims['iss'] as String?;
      if (iss != 'https://appleid.apple.com') {
        throw AuthException(message: 'Invalid Apple token issuer');
      }

      // Verify audience
      final aud = claims['aud'] as String?;
      if (aud != clientId) {
        throw AuthException(message: 'Invalid Apple token audience');
      }

      // Verify expiration
      final exp = claims['exp'] as int?;
      if (exp == null || DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp) {
        throw AuthException(message: 'Apple token has expired');
      }

      return claims;
    } catch (e) {
      throw AuthException(message: 'Failed to verify Apple identity token: $e');
    }
  }

  // Helper to generate client secret for Apple (needed for token validation)
  static String generateClientSecret({
    required String teamId,
    required String clientId,
    required String keyId,
    required String privateKey,
  }) {
    final _ = [teamId, clientId, keyId, privateKey];
    throw AuthException(
      message:
          'Apple client secret generation is not implemented. Provide a pre-generated secret from your Apple auth service.',
    );
  }
}
