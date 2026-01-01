// auth_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/auth/auth.dart';
import 'package:flint_dart/src/error/auth_exception.dart';

class AuthService {
  static const String _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  // In-memory stores (replace with your session/database in production)
  static final Map<String, String> _codeVerifierStore = {};
  static final Map<String, String> _callbackStore = {};

  /// Generate Google OAuth URL
  static String getGoogleAuthUrl({required String callbackUrl}) {
    final clientId = Auth.config.googleClientId;
    if (clientId == null || clientId.isEmpty) {
      throw AuthException(
          'Google OAuth is not configured. Set GOOGLE_CLIENT_ID.');
    }

    final state = _generateState(callbackUrl);
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    _storeAuthData(state, codeVerifier, callbackUrl);

    final params = {
      'client_id': clientId,
      'redirect_uri': callbackUrl,
      'response_type': 'code',
      'scope': 'email profile openid',
      'access_type': 'offline',
      'prompt': 'consent',
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };

    return _buildUrl('https://accounts.google.com/o/oauth2/v2/auth', params);
  }

  /// Generate GitHub OAuth URL
  static String getGitHubAuthUrl({required String callbackUrl}) {
    final clientId = Auth.config.githubClientId;
    if (clientId == null || clientId.isEmpty) {
      throw AuthException(
          'GitHub OAuth is not configured. Set GITHUB_CLIENT_ID.');
    }

    final state = _generateState(callbackUrl);

    _storeAuthData(state, '', callbackUrl);

    final params = {
      'client_id': clientId,
      'redirect_uri': callbackUrl,
      'scope': 'user:email',
      'state': state,
      'allow_signup': 'true',
    };

    return _buildUrl('https://github.com/login/oauth/authorize', params);
  }

  /// Generate Facebook OAuth URL
  static String getFacebookAuthUrl({required String callbackUrl}) {
    final clientId = Auth.config.facebookClientId;
    if (clientId == null || clientId.isEmpty) {
      throw AuthException(
          'Facebook OAuth is not configured. Set FACEBOOK_CLIENT_ID.');
    }

    final state = _generateState(callbackUrl);

    _storeAuthData(state, '', callbackUrl);

    final params = {
      'client_id': clientId,
      'redirect_uri': callbackUrl,
      'scope': 'email,public_profile',
      'state': state,
      'auth_type': 'rerequest',
      'display': 'popup',
    };

    return _buildUrl('https://www.facebook.com/v19.0/dialog/oauth', params);
  }

  /// Generate Apple OAuth URL
  static String getAppleAuthUrl({required String callbackUrl}) {
    final clientId = Auth.config.appleClientId;
    if (clientId == null || clientId.isEmpty) {
      throw AuthException(
          'Apple Sign In is not configured. Set APPLE_CLIENT_ID.');
    }

    final state = _generateState(callbackUrl);
    final nonce = _generateNonce();

    _storeAuthData(state, nonce, callbackUrl);

    final params = {
      'client_id': clientId,
      'redirect_uri': callbackUrl,
      'response_type': 'code id_token',
      'scope': 'name email',
      'state': state,
      'nonce': nonce,
      'response_mode': 'form_post',
    };

    return _buildUrl('https://appleid.apple.com/auth/authorize', params);
  }

  /// Get callback URL from state parameter
  static String? getCallbackUrl(String state) {
    return _callbackStore[state];
  }

  /// Verify and get code verifier for PKCE
  static String? getCodeVerifier(String state) {
    return _codeVerifierStore[state];
  }

  /// Clean up stored verification data
  static void cleanupAuthData(String state) {
    _codeVerifierStore.remove(state);
    _callbackStore.remove(state);
  }

  /// Get all available OAuth providers
  static Map<String, dynamic> getAvailableProviders() {
    final providers = <String, bool>{};
    final config = Auth.config;

    providers['google'] = config.isGoogleConfigured;
    providers['github'] = config.isGitHubConfigured;
    providers['facebook'] = config.isFacebookConfigured;
    providers['apple'] = config.isAppleConfigured;

    return {
      'available': providers,
      'redirectBase': config.redirectBase,
    };
  }

  /// Validate OAuth configuration
  static Map<String, dynamic> validateConfig() {
    final errors = <String>[];
    final warnings = <String>[];
    final config = Auth.config;

    if (!config.isGoogleConfigured) {
      warnings.add(
          'Google OAuth not configured (GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET required)');
    }
    if (!config.isGitHubConfigured) {
      warnings.add(
          'GitHub OAuth not configured (GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET required)');
    }
    if (!config.isFacebookConfigured) {
      warnings.add(
          'Facebook OAuth not configured (FACEBOOK_CLIENT_ID and FACEBOOK_CLIENT_SECRET required)');
    }
    if (!config.isAppleConfigured) {
      warnings.add(
          'Apple Sign In not configured (APPLE_CLIENT_ID, APPLE_TEAM_ID, APPLE_KEY_ID, and APPLE_PRIVATE_KEY required)');
    }

    return {
      'valid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'redirectBase': config.redirectBase,
    };
  }

  /// Generate OAuth URLs for all configured providers
  static Map<String, String> getAllAuthUrls({required String callbackUrl}) {
    final urls = <String, String>{};

    try {
      if (Auth.config.isGoogleConfigured) {
        urls['google'] = getGoogleAuthUrl(callbackUrl: callbackUrl);
      }
    } catch (e, stack) {
      Log.error('Error generating Google auth URL: ',
          error: e, stackTrace: stack);
    }

    try {
      if (Auth.config.isGitHubConfigured) {
        urls['github'] = getGitHubAuthUrl(callbackUrl: callbackUrl);
      }
    } catch (e, stack) {
      Log.error('Error generating GitHub auth URL:',
          error: e, stackTrace: stack);
    }

    try {
      if (Auth.config.isFacebookConfigured) {
        urls['facebook'] = getFacebookAuthUrl(callbackUrl: callbackUrl);
      }
    } catch (e, stack) {
      Log.error('Error generating Facebook auth URL:',
          error: e, stackTrace: stack);
    }

    try {
      if (Auth.config.isAppleConfigured) {
        urls['apple'] = getAppleAuthUrl(callbackUrl: callbackUrl);
      }
    } catch (e, stack) {
      Log.error('Error generating Apple auth URL:',
          error: e, stackTrace: stack);
    }

    return urls;
  }

  // ---------- Private Helper Methods ----------

  static String _buildUrl(String baseUrl, Map<String, String> params) {
    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$baseUrl?$queryString';
  }

  static String _generateState(String callbackUrl) {
    final random = _generateRandomString(32);
    return '${Uri.encodeComponent(random)}|${Uri.encodeComponent(callbackUrl)}';
  }

  static String _generateCodeVerifier() {
    return _generateRandomString(128);
  }

  static String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String _generateNonce() {
    return _generateRandomString(32);
  }

  static String _generateRandomString(int length) {
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(length,
          (index) => _charset.codeUnitAt(random.nextInt(_charset.length))),
    );
  }

  static void _storeAuthData(
      String state, String codeVerifier, String callbackUrl) {
    if (codeVerifier.isNotEmpty) {
      _codeVerifierStore[state] = codeVerifier;
    }
    _callbackStore[state] = callbackUrl;

    // Auto-cleanup after 10 minutes
    Future.delayed(Duration(minutes: 10), () {
      _codeVerifierStore.remove(state);
      _callbackStore.remove(state);
    });
  }
}
