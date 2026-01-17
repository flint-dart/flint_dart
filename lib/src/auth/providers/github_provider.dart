// providers/github_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/auth/providers/base_provider.dart';
import 'package:flint_dart/src/error/auth_exception.dart';

class GitHubProvider {
  static Future<Map<String, dynamic>> authenticate({
    required String code,
    String? callbackPath,
    required String? clientId,
    required String? clientSecret,
    required String redirectBase,
  }) async {
    if (clientId == null || clientSecret == null) {
      throw AuthException(message: 'GitHub OAuth is not configured');
    }

    final redirectUri = callbackPath != null
        ? '$redirectBase$callbackPath'
        : '$redirectBase/api/auth/github/callback';

    // 1. Exchange code for access token
    final accessToken = await _exchangeCodeForToken(
      code,
      clientId,
      clientSecret,
      redirectUri,
    );

    // 2. Fetch user profile
    final profile = await _fetchUserProfile(accessToken);

    // 3. Get user email
    String? email = profile['email'];
    if (email == null || email.isEmpty) {
      final emails = await _fetchUserEmails(accessToken);
      final primaryEmail = emails.firstWhere(
        (e) => e['primary'] == true,
        orElse: () => emails.firstWhere((e) => e['verified'] == true),
      );
      email = primaryEmail['email'];
    }

    return AuthProvider.formatUserData(
      provider: 'github',
      providerId: profile['id'].toString(),
      email: email,
      name: profile['name'] ?? profile['login'],
      picture: profile['avatar_url'],
      rawProfile: profile,
    );
  }

  static Future<String> _exchangeCodeForToken(
    String code,
    String clientId,
    String clientSecret,
    String redirectUri,
  ) async {
    final uri = Uri.https('github.com', '/login/oauth/access_token');
    final client = HttpClient();
    final req = await client.postUrl(uri);

    req.headers
      ..set('Content-Type', 'application/json')
      ..set('Accept', 'application/json');

    final body = {
      'client_id': clientId,
      'client_secret': clientSecret,
      'code': code,
      'redirect_uri': redirectUri,
    };

    req.write(json.encode(body));
    final resp = await req.close();
    final responseBody = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw AuthException(
          message: 'Failed to exchange GitHub code: ${resp.statusCode}');
    }

    final tokenData = json.decode(responseBody) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String?;

    if (accessToken == null) {
      throw AuthException(
          message: 'No access token received from GitHub: $tokenData');
    }

    return accessToken;
  }

  static Future<Map<String, dynamic>> _fetchUserProfile(
      String accessToken) async {
    final uri = Uri.https('api.github.com', '/user');
    final client = HttpClient();
    final req = await client.getUrl(uri);

    req.headers.set('Authorization', 'Bearer $accessToken');
    req.headers.set('User-Agent', 'FlintDart-App');

    final resp = await req.close();
    final responseBody = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw AuthException(
          message: 'Failed to fetch GitHub profile: ${resp.statusCode}');
    }

    return json.decode(responseBody) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> _fetchUserEmails(String accessToken) async {
    final uri = Uri.https('api.github.com', '/user/emails');
    final client = HttpClient();
    final req = await client.getUrl(uri);

    req.headers.set('Authorization', 'Bearer $accessToken');
    req.headers.set('User-Agent', 'FlintDart-App');

    final resp = await req.close();
    final responseBody = await resp.transform(utf8.decoder).join();
    client.close();

    if (resp.statusCode != 200) {
      throw AuthException(
          message: 'Failed to fetch GitHub emails: ${resp.statusCode}');
    }

    final emails = json.decode(responseBody) as List<dynamic>;

    if (emails.isEmpty) {
      throw AuthException(message: 'No emails found for GitHub user');
    }

    return emails;
  }
}
