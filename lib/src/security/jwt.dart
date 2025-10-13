import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class FlintJwt {
  final String secretKey;

  FlintJwt(this.secretKey);

  String generateToken(
    Map<String, dynamic> payload, {
    Duration expiry = const Duration(hours: 1),
  }) {
    final jwt = JWT(payload);
    return jwt.sign(SecretKey(secretKey), expiresIn: expiry);
  }

  Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secretKey));
      if (jwt.payload is Map) {
        return jwt.payload as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
