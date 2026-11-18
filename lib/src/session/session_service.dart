import 'package:flint_dart/flint_dart.dart';

/// A service to manage session data key-by-key.
class SessionService {
  static late Response _response;

  /// Initialize per request
  static void init(Request request, Response response) {
    _response = response;
  }

  // ------------------- SET A KEY -------------------
  /// Save a value to the session under the specified key
  static Future<void> set(String key, dynamic value, {Duration? ttl}) async {
    // Get existing session data
    final sessionId = CookieService.get('FLINTSESSID');
    Map<String, dynamic> data =
        await SessionManager.instance.getSession(sessionId) ?? {};

    // Update or add key
    data[key] = value;

    // Save updated session (creates new session if needed)
    await SessionManager.instance.createSession(_response.raw, data, ttl: ttl);
  }

  // ------------------- GET A KEY -------------------
  /// Retrieve a value from the session by key
  static Future<dynamic> get(String key) async {
    final sessionId = CookieService.get('FLINTSESSID');
    final data = await SessionManager.instance.getSession(sessionId);
    if (data == null) return null;
    return data[key];
  }

  // ------------------- REMOVE A KEY -------------------
  /// Remove a key from the session
  static Future<void> remove(String key) async {
    final sessionId = CookieService.get('FLINTSESSID');
    final data = await SessionManager.instance.getSession(sessionId);
    if (data == null) return;

    data.remove(key);

    // Save the updated session
    await SessionManager.instance.createSession(_response.raw, data);
  }

  // ------------------- DESTROY SESSION -------------------
  /// Destroy the entire session
  static Future<void> destroy() async {
    final sessionId = CookieService.get('FLINTSESSID');
    await SessionManager.instance.destroySession(_response.raw, sessionId);
  }
}
