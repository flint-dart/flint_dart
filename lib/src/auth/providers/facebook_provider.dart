// providers/facebook_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/auth/providers/base_provider.dart';
import 'package:flint_dart/src/error/auth_exception.dart';

class FacebookProvider extends AuthProvider {
  static Future<Map<String, dynamic>> authenticate({
    String? accessToken,
    String? code,
    String? callbackPath,
    required String? clientId,
    required String? clientSecret,
    required String redirectBase,
  }) async {
    if (clientId == null || clientSecret == null) {
      throw AuthException(message: 'Facebook OAuth is not configured');
    }

    String finalAccessToken = accessToken ?? '';

    // If code is provided, exchange it for access token
    if (code != null) {
      finalAccessToken = await _exchangeCodeForToken(
        code,
        clientId,
        clientSecret,
        callbackPath != null
            ? '$redirectBase$callbackPath'
            : '$redirectBase/api/auth/facebook/callback',
      );
    }

    if (finalAccessToken.isEmpty) {
      throw AuthException(
          message: 'Either accessToken or code must be provided');
    }

    // Verify token and get user profile
    final profile = await _verifyTokenAndGetProfile(finalAccessToken, clientId);

    return AuthProvider.formatUserData(
      provider: 'facebook',
      providerId: profile['id'],
      email: profile['email'],
      name: profile['name'],
      picture: profile['picture']?['data']?['url'],
      rawProfile: profile,
    );
  }

  static Future<String> _exchangeCodeForToken(
    String code,
    String clientId,
    String clientSecret,
    String redirectUri,
  ) async {
    final uri = Uri.https('graph.facebook.com', '/v19.0/oauth/access_token', {
      'client_id': clientId,
      'client_secret': clientSecret,
      'code': code,
      'redirect_uri': redirectUri,
    });

    final client = HttpClient();
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final responseBody = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw AuthException(
          message: 'Failed to exchange Facebook code: ${resp.statusCode}');
    }

    final tokenData = json.decode(responseBody) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String?;

    if (accessToken == null) {
      throw AuthException(message: 'No access token received from Facebook');
    }

    return accessToken;
  }

  static Future<Map<String, dynamic>> _verifyTokenAndGetProfile(
    String accessToken,
    String clientId,
  ) async {
    // First verify the token
    final verifyUri = Uri.https('graph.facebook.com', '/debug_token', {
      'input_token': accessToken,
      'access_token': '$clientId|$clientId',
    });

    final client = HttpClient();
    var req = await client.getUrl(verifyUri);
    var resp = await req.close();
    var responseBody = await resp.transform(utf8.decoder).join();

    if (resp.statusCode != 200) {
      throw AuthException(
          message: 'Failed to verify Facebook token: ${resp.statusCode}');
    }

    final verifyData = json.decode(responseBody) as Map<String, dynamic>;
    final isValid = verifyData['data']?['is_valid'] == true;

    if (!isValid) {
      throw AuthException(message: 'Invalid Facebook token');
    }

    // Get user profile
    final profileUri = Uri.https('graph.facebook.com', '/v19.0/me', {
      'access_token': accessToken,
      'fields': 'id,name,email,picture.type(large)',
    });

    req = await client.getUrl(profileUri);
    resp = await req.close();
    responseBody = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw AuthException(
          message: 'Failed to fetch Facebook profile: ${resp.statusCode}');
    }

    return json.decode(responseBody) as Map<String, dynamic>;
  }
}
