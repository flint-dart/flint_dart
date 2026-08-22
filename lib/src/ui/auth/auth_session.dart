import '../storage/browser_storage.dart';
import '../storage/local_storage.dart';

/// A read-only snapshot of the current browser auth session.
class AuthSessionSnapshot {
  /// Creates a session snapshot from a token and user payload.
  const AuthSessionSnapshot({required this.token, required this.user});

  /// The stored authentication token.
  final String token;

  /// The stored user payload associated with the token.
  final Map<String, dynamic> user;

  /// The user's role when the user payload contains a `role` field.
  String? get role => user['role']?.toString();
}

/// Stores and reads simple browser-side auth session state.
class AuthSessionManager {
  /// Creates a session manager using browser storage keys.
  const AuthSessionManager({
    this.tokenKey = 'auth.token',
    this.userKey = 'auth.user',
    this.storage = localStorage,
  });

  /// Storage key used for the authentication token.
  final String tokenKey;

  /// Storage key used for the serialized user payload.
  final String userKey;

  /// Browser storage backend used by this session manager.
  final BrowserStorage storage;

  /// The current token, or `null` when no usable token is stored.
  String? get token {
    final value = storage.read(tokenKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// The current user payload, or an empty map when none is stored.
  Map<String, dynamic> get user => storage.readMap(userKey);

  /// The current user's role when available.
  String? get role => user['role']?.toString();

  /// Whether a non-empty token is currently stored.
  bool get isLoggedIn => token != null;

  /// The current session snapshot, or `null` when logged out.
  AuthSessionSnapshot? get current {
    final currentToken = token;
    if (currentToken == null) return null;
    return AuthSessionSnapshot(token: currentToken, user: user);
  }

  /// Saves a token and optional user payload to browser storage.
  void save({required String token, Map<String, dynamic> user = const {}}) {
    storage.write(tokenKey, token);
    storage.writeJson(userKey, user);
  }

  /// Replaces the stored user payload without changing the token.
  void updateUser(Map<String, dynamic> user) {
    storage.writeJson(userKey, user);
  }

  /// Clears the stored token and user payload.
  void clear() {
    storage.remove(tokenKey);
    storage.remove(userKey);
  }
}

/// Shared auth session helper backed by browser local storage.
///
/// Use this for simple browser-side login state in Flint UI apps.
const authSession = AuthSessionManager();
