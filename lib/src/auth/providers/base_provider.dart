// providers/base_provider.dart
abstract class AuthProvider {
  static Future<Map<String, dynamic>> authenticate({
    String? idToken,
    String? accessToken,
    String? code,
    String? callbackPath,
    required String? clientId,
    required String? clientSecret,
    required String redirectBase,
  }) {
    throw UnimplementedError('authenticate() must be implemented');
  }

  static Map<String, dynamic> formatUserData({
    required String provider,
    required String providerId,
    required String? email,
    required String? name,
    String? picture,
    Map<String, dynamic>? rawProfile,
  }) {
    return {
      'provider': provider,
      'providerId': providerId,
      'email': email,
      'name': name,
      'picture': picture,
      'rawProfile': rawProfile,
      'authenticatedAt': DateTime.now().toIso8601String(),
    };
  }
}
