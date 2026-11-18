// providers/google_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/auth/providers/base_provider.dart';
import 'package:flint_dart/src/error/auth_exception.dart';

class GoogleProvider {
  static Future<Map<String, dynamic>> authenticate({
    String? idToken,
    String? code,
    String? callbackPath,
    required String? clientId,
    required String? clientSecret,
    required String redirectBase,
  }) async {
    if (clientId == null || clientSecret == null) {
      throw AuthException(message: 'Google OAuth is not configured');
    }

    Map<String, dynamic> profile;

    if (idToken != null) {
      profile = await verifyIdToken(idToken, clientId: clientId);
    } else if (code != null) {
      if (callbackPath == null) {
        throw AuthException(
            message: 'callbackPath is required when using code');
      }

      final tokens = await _exchangeCodeForToken(
        code,
        clientId,
        clientSecret,
        '$redirectBase$callbackPath',
      );

      final idTokenFromGoogle = tokens['id_token'];
      if (idTokenFromGoogle != null) {
        profile = await verifyIdToken(idTokenFromGoogle as String,
            clientId: clientId);
      } else {
        throw AuthException(message: 'No ID token received from Google');
      }
    } else {
      throw AuthException(message: 'Either idToken or code must be provided');
    }

    return AuthProvider.formatUserData(
      provider: 'google',
      providerId: profile['sub'],
      email: profile['email'],
      name: profile['name'],
      picture: profile['picture'],
      rawProfile: profile,
    );
  }

  static Future<Map<String, dynamic>> verifyIdToken(
    String idToken, {
    required String? clientId,
  }) async {
    // Your existing Google token verification logic
    final uri = Uri.https('oauth2.googleapis.com', '/tokeninfo', {
      'id_token': idToken,
    });

    final client = HttpClient();
    final req = await client.getUrl(uri);
    final resp = await req.close();

    if (resp.statusCode != 200) {
      throw AuthException(message: 'Invalid Google ID token');
    }

    final body = await resp.transform(utf8.decoder).join();
    client.close();

    final profile = json.decode(body) as Map<String, dynamic>;

    // Verify audience
    if (clientId != null && profile['aud'] != clientId) {
      throw AuthException(message: 'Invalid token audience');
    }

    return profile;
  }

  static Future<Map<String, dynamic>> _exchangeCodeForToken(
    String code,
    String clientId,
    String clientSecret,
    String redirectUri,
  ) async {
    // Your existing code exchange logic
    final uri = Uri.https('oauth2.googleapis.com', '/token');
    final client = HttpClient();
    final req = await client.postUrl(uri);
    req.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded');

    final body = {
      'code': code,
      'client_id': clientId,
      'client_secret': clientSecret,
      'redirect_uri': redirectUri,
      'grant_type': 'authorization_code',
    };

    req.write(Uri(queryParameters: body).query);
    final resp = await req.close();
    final responseBody = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw AuthException(message: 'Failed to exchange code for token');
    }

    return json.decode(responseBody) as Map<String, dynamic>;
  }
}
