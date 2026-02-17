import 'package:flint_dart/auth.dart';
import 'package:flint_dart/src/error/auth_exception.dart';
import 'package:flint_dart/src/response.dart';

extension OAuthResponse on Response {
  Response oAuthRedirect(String provider, {String? callback}) {
    String authUrl;

    // Handle callback parameter with proper URL construction
    String callbackUrl;
    if (callback != null) {
      if (callback.startsWith('http://') || callback.startsWith('https://')) {
        final base = Uri.parse(Auth.config.redirectBase);
        final requested = Uri.parse(callback);
        if (base.host != requested.host || base.scheme != requested.scheme) {
          throw AuthException(
              message:
                  'OAuth callback must use the same origin as REDIRECT_BASE.');
        }
        callbackUrl = callback;
      } else if (callback.startsWith('/')) {
        // Path provided - construct full URL
        callbackUrl = '${Auth.config.redirectBase}$callback';
      } else {
        // Relative path without leading slash
        callbackUrl = '${Auth.config.redirectBase}/$callback';
      }
    } else {
      // Default callback
      callbackUrl = '${Auth.config.redirectBase}/auth/$provider/callback';
    }

    switch (provider.toLowerCase()) {
      case 'google':
        authUrl = AuthService.getGoogleAuthUrl(callbackUrl: callbackUrl);
        break;
      case 'github':
        authUrl = AuthService.getGitHubAuthUrl(callbackUrl: callbackUrl);
        break;
      case 'facebook':
        authUrl = AuthService.getFacebookAuthUrl(callbackUrl: callbackUrl);
        break;
      case 'apple':
        authUrl = AuthService.getAppleAuthUrl(callbackUrl: callbackUrl);
        break;
      default:
        throw AuthException(message: 'Unsupported OAuth provider: $provider');
    }
    return redirect(authUrl);
  }
}
