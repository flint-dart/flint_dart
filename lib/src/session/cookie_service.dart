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
    bool secure = false,
    String path = '/',
    Duration? maxAge,
    DateTime? expires,
    String sameSite = 'Lax',
  }) {
    _response.setCookie(
      name,
      value,
      path: path,
      httpOnly: httpOnly,
      secure: secure,
      maxAge: maxAge?.inSeconds,
      expires: expires,
      sameSite: sameSite,
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
