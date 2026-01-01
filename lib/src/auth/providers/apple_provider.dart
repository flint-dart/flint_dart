// providers/apple_provider.dart
import 'dart:convert';
import 'package:flint_dart/logs.dart';
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
      throw AuthException('Apple Sign In is not properly configured');
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
    // For Apple, we need to verify the JWT ourselves
    // In production, you might want to use a proper JWT library

    try {
      // Simple verification - decode and check basic claims
      final parts = identityToken.split('.');
      if (parts.length != 3) {
        throw AuthException('Invalid Apple identity token format');
      }

      final payload = parts[1];
      final decoded = utf8.decode(base64Url.decode(
        base64Url.normalize(payload),
      ));

      final claims = json.decode(decoded) as Map<String, dynamic>;

      // Verify issuer
      final iss = claims['iss'] as String?;
      if (iss != 'https://appleid.apple.com') {
        throw AuthException('Invalid Apple token issuer');
      }

      // Verify audience
      final aud = claims['aud'] as String?;
      if (aud != clientId) {
        throw AuthException('Invalid Apple token audience');
      }

      // Verify expiration
      final exp = claims['exp'] as int?;
      if (exp == null || DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp) {
        throw AuthException('Apple token has expired');
      }

      return claims;
    } catch (e) {
      throw AuthException('Failed to verify Apple identity token: $e');
    }
  }

  // Helper to generate client secret for Apple (needed for token validation)
  static String generateClientSecret({
    required String teamId,
    required String clientId,
    required String keyId,
    required String privateKey,
  }) {
    // This is a simplified version - you'll need proper JWT implementation
    final headers = {
      'alg': 'ES256',
      'kid': keyId,
    };

    final claims = {
      'iss': teamId,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
      'aud': 'https://appleid.apple.com',
      'sub': clientId,
    };

    // In practice, you'd use a proper JWT library to sign with ES256
    // This is just a placeholder - implement proper JWT signing
    return _signJWT(headers, claims, privateKey);
  }

  static String _signJWT(
    Map<String, dynamic> headers,
    Map<String, dynamic> claims,
    String privateKey,
  ) {
    // Implement proper JWT signing with ES256
    // This is a complex operation that requires proper cryptographic libraries
    throw UnimplementedError('JWT signing for Apple not implemented');
  }
}
