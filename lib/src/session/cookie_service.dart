import 'package:flint_dart/flint_dart.dart';

enum SameSite { strict, lax, none }

/// ================= Cookie Service =================
class CookieService {
  static late Request _request;
  static late Response _response;

  /// Initialize per request
  static void init(Request request, Response response) {
    _request = request;
    _response = response;
  }

  /// Set a cookie
  static void set(
    String name,
    String value, {
    bool httpOnly = true,
    bool? secure,
    String path = '/',
    Duration? maxAge,
    DateTime? expires,
    String? sameSite,
  }) {
    final appEnv = FlintEnv.get('APP_ENV', 'development').toLowerCase();
    final resolvedSecure = secure ??
        FlintEnv.getBool('SESSION_COOKIE_SECURE', appEnv == 'production');
    final resolvedSameSite =
        sameSite ?? FlintEnv.get('SESSION_COOKIE_SAMESITE', 'Lax');

    _response.setCookie(
      name,
      value,
      path: path,
      httpOnly: httpOnly,
      secure: resolvedSecure,
      maxAge: maxAge?.inSeconds,
      expires: expires,
      sameSite: resolvedSameSite,
    );
  }

  /// Get a cookie
  static String? get(String name) {
    return _request.cookies[name];
  }

  /// Delete a cookie
  static void delete(String name, {String path = '/'}) {
    _response.clearCookie(name, path: path);
  }
}
